"""
Event management using SQLAlchemy
Handles all event-related database operations and API endpoints
"""

import uuid
from datetime import datetime, timedelta
from typing import Optional, List
from sqlalchemy import create_engine, Table, MetaData, Column, String, Integer, DateTime, Boolean, text
from sqlalchemy.orm import sessionmaker
from sqlalchemy.exc import SQLAlchemyError
from fastapi import APIRouter, HTTPException, Depends, UploadFile, File, Header
from models import Event, EventCreate, EventUpdate, EventInstructor, EventInstructorCreate, EventInstructorUpdate, EventGallery, EventRegistration
from tenant_config import get_schema_name_by_home_id, get_tenant_connection_string_by_home_id
from database_utils import get_schema_engine, get_engine_for_home
from azure_storage_service import azure_storage_service
from event_gallery import event_gallery_db
from event_instructor import event_instructor_db
from events_registration import events_registration_db
from users import user_db
import json

# Create FastAPI router
router = APIRouter()

# Header dependencies
async def get_home_id(home_id: str = Header(..., alias="homeID")):
    """Dependency to extract and validate homeID header"""
    try:
        return int(home_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid homeID format")

async def get_user_id(user_id: Optional[str] = Header(None, alias="userId")):
    """Dependency to extract user ID header"""
    return user_id

async def get_user_role(user_id: str, home_id: int) -> str:
    """Get user role from database"""
    try:
        user_profile = user_db.get_user_profile(user_id, home_id)
        if user_profile:
            return user_profile.role
        return "unknown"
    except Exception as e:
        print(f"Error getting user role: {e}")
        return "unknown"

def calculate_next_occurrence(event_datetime: datetime, recurring_pattern: str, recurring_end_date: datetime) -> datetime:
    """
    Calculate the next occurrence of a recurring event based on its pattern.
    
    Args:
        event_datetime: The original event datetime (used as reference)
        recurring_pattern: JSON string containing recurrence pattern
        recurring_end_date: When the recurring series ends
        
    Returns:
        The next occurrence datetime, or the original datetime if no future occurrence exists
    """
    try:
        if not recurring_pattern:
            return event_datetime
            
        pattern = json.loads(recurring_pattern)
        now = datetime.now()
        
        # If we're past the recurring end date, return the original datetime
        if recurring_end_date and now > recurring_end_date:
            return event_datetime
            
        # Parse time from pattern
        time_str = pattern.get('time', '14:00')  # Default to 2:00 PM
        hour, minute = map(int, time_str.split(':'))
        
        # Weekly recurrence
        if 'dayOfWeek' in pattern:
            target_day = pattern['dayOfWeek']  # 0=Sunday, 1=Monday, etc.
            interval = pattern.get('interval', 1)  # Default to 1 for weekly, 2 for bi-weekly
            
            # Find the next occurrence
            current_date = now.date()
            # Convert Python weekday (0=Monday) to our format (0=Sunday)
            current_weekday = (current_date.weekday() + 1) % 7
            days_ahead = target_day - current_weekday
            if days_ahead <= 0:
                days_ahead += 7  # Go to next week
                
            # For bi-weekly, we need to find the correct week
            if interval == 2:
                # Calculate weeks since reference date
                reference_date = event_datetime.date()
                # Convert Python weekday (0=Monday) to our format (0=Sunday)
                reference_weekday = (reference_date.weekday() + 1) % 7
                
                # Find the first target day from reference
                if reference_weekday <= target_day:
                    first_target = reference_date + timedelta(days=(target_day - reference_weekday))
                else:
                    first_target = reference_date + timedelta(days=(7 - reference_weekday + target_day))
                
                # Calculate how many intervals (2 weeks) have passed
                weeks_passed = (current_date - first_target).days // 7
                intervals_passed = weeks_passed // interval
                
                # Find next interval
                next_interval_weeks = (intervals_passed + 1) * interval
                next_date = first_target + timedelta(weeks=next_interval_weeks)
                
                # If this date is in the past, add another interval
                if next_date <= current_date:
                    next_date = first_target + timedelta(weeks=(intervals_passed + 2) * interval)
            else:
                # Regular weekly
                next_date = current_date + timedelta(days=days_ahead)
            
            next_datetime = datetime.combine(next_date, datetime.min.time().replace(hour=hour, minute=minute))
            
        # Monthly recurrence
        elif 'dayOfMonth' in pattern:
            target_day = pattern['dayOfMonth']
            current_date = now.date()
            
            # Try current month first
            try:
                next_date = current_date.replace(day=target_day)
                if next_date <= current_date:
                    # Move to next month
                    if current_date.month == 12:
                        next_date = current_date.replace(year=current_date.year + 1, month=1, day=target_day)
                    else:
                        next_date = current_date.replace(month=current_date.month + 1, day=target_day)
            except ValueError:
                # Target day doesn't exist in current month, move to next month
                if current_date.month == 12:
                    next_date = current_date.replace(year=current_date.year + 1, month=1, day=target_day)
                else:
                    next_date = current_date.replace(month=current_date.month + 1, day=target_day)
            
            next_datetime = datetime.combine(next_date, datetime.min.time().replace(hour=hour, minute=minute))
        
        else:
            # No valid pattern, return original
            return event_datetime
            
        # Check if next occurrence is within the recurring end date
        if recurring_end_date and next_datetime > recurring_end_date:
            return event_datetime
            
        return next_datetime
        
    except (json.JSONDecodeError, ValueError, KeyError) as e:
        print(f"Error calculating next occurrence: {e}")
        return event_datetime

class EventDatabase:
    def __init__(self):
        # Note: This class now uses tenant-specific connections through database_utils
        # No default engine is created as all operations use schema-specific engines
        self.metadata = MetaData()

    def get_events_table(self, schema_name: str):
        """Get the events table for a specific schema using schema-specific connection"""
        try:
            # Get schema-specific engine
            schema_engine = get_schema_engine(schema_name)
            if not schema_engine:
                print(f"No engine found for schema {schema_name}")
                return None
            
            # Reflect the events table from the specified schema
            metadata = MetaData(schema=schema_name)
            metadata.reflect(bind=schema_engine, only=['events'])
            return metadata.tables[f'{schema_name}.events']
        except Exception as e:
            print(f"Error reflecting events table for schema {schema_name}: {e}")
            return None

    def get_all_events(self, home_id: int) -> List[Event]:
        """Get all events from the appropriate schema"""
        try:
            # Get schema for home
            schema_name = get_schema_name_by_home_id(home_id)
            if not schema_name:
                return []

            # Get the events table
            events_table = self.get_events_table(schema_name)
            if events_table is None:
                return []

            events = []
            schema_engine = get_schema_engine(schema_name)
            if not schema_engine:
                return []
            with schema_engine.connect() as conn:
                results = conn.execute(events_table.select()).fetchall()
                
                for result in results:
                    events.append(Event(
                        id=result.id,
                        name=result.name,
                        type=result.type,
                        description=result.description,
                        dateTime=result.dateTime,
                        location=result.location,
                        maxParticipants=result.maxParticipants,
                        currentParticipants=result.currentParticipants,
                        image_url=result.image_url or "",
                        status=result.status if hasattr(result, 'status') else "pending-approval",
                        recurring=result.recurring if hasattr(result, 'recurring') else "none",
                        recurring_end_date=result.recurring_end_date if hasattr(result, 'recurring_end_date') else None,
                        recurring_pattern=result.recurring_pattern if hasattr(result, 'recurring_pattern') else None
                    ))
            return events

        except Exception as e:
            print(f"Error getting all events for home {home_id}: {e}")
            return []

    def get_approved_events(self, home_id: int) -> List[Event]:
        """Get all approved events ordered by date desc"""
        try:
            schema_name = get_schema_name_by_home_id(home_id)
            if not schema_name:
                return []

            events_table = self.get_events_table(schema_name)
            if events_table is None:
                return []

            events = []
            schema_engine = get_schema_engine(schema_name)
            if not schema_engine:
                return []
            with schema_engine.connect() as conn:
                results = conn.execute(
                    events_table.select()
                    .where(events_table.c.status == 'approved')
                    .order_by(events_table.c.dateTime.desc())
                ).fetchall()
                
                for result in results:
                    events.append(Event(
                        id=result.id,
                        name=result.name,
                        type=result.type,
                        description=result.description,
                        dateTime=result.dateTime,
                        location=result.location,
                        maxParticipants=result.maxParticipants,
                        currentParticipants=result.currentParticipants,
                        image_url=result.image_url or "",
                        status=result.status if hasattr(result, 'status') else "pending-approval",
                        recurring=result.recurring if hasattr(result, 'recurring') else "none",
                        recurring_end_date=result.recurring_end_date if hasattr(result, 'recurring_end_date') else None,
                        recurring_pattern=result.recurring_pattern if hasattr(result, 'recurring_pattern') else None
                    ))
            return events

        except Exception as e:
            print(f"Error getting approved events for home {home_id}: {e}")
            return []


    def get_all_events_ordered(self, home_id: int) -> List[Event]:
        """Get all events ordered by date desc (for staff/manager)"""
        try:
            schema_name = get_schema_name_by_home_id(home_id)
            if not schema_name:
                return []

            events_table = self.get_events_table(schema_name)
            if events_table is None:
                return []

            events = []
            schema_engine = get_schema_engine(schema_name)
            if not schema_engine:
                return []
            with schema_engine.connect() as conn:
                results = conn.execute(
                    events_table.select()
                    .order_by(events_table.c.dateTime.desc())
                ).fetchall()
                
                for result in results:
                    events.append(Event(
                        id=result.id,
                        name=result.name,
                        type=result.type,
                        description=result.description,
                        dateTime=result.dateTime,
                        location=result.location,
                        maxParticipants=result.maxParticipants,
                        currentParticipants=result.currentParticipants,
                        image_url=result.image_url or "",
                        status=result.status if hasattr(result, 'status') else "pending-approval",
                        recurring=result.recurring if hasattr(result, 'recurring') else "none",
                        recurring_end_date=result.recurring_end_date if hasattr(result, 'recurring_end_date') else None,
                        recurring_pattern=result.recurring_pattern if hasattr(result, 'recurring_pattern') else None
                    ))
            return events

        except Exception as e:
            print(f"Error getting all events ordered for home {home_id}: {e}")
            return []

    def get_event_by_id(self, event_id: str, home_id: int) -> Optional[Event]:
        """Get a specific event by ID from the appropriate schema"""
        try:
            # Get schema for home
            schema_name = get_schema_name_by_home_id(home_id)
            if not schema_name:
                return None

            # Get the events table
            events_table = self.get_events_table(schema_name)
            if events_table is None:
                return None

            # Query event
            schema_engine = get_schema_engine(schema_name)
            if not schema_engine:
                return []
            with schema_engine.connect() as conn:
                result = conn.execute(
                    events_table.select().where(events_table.c.id == event_id)
                ).fetchone()

                if result:
                    return Event(
                        id=result.id,
                        name=result.name,
                        type=result.type,
                        description=result.description,
                        dateTime=result.dateTime,
                        location=result.location,
                        maxParticipants=result.maxParticipants,
                        currentParticipants=result.currentParticipants,
                        image_url=result.image_url or "",
                        status=result.status if hasattr(result, 'status') else "pending-approval",
                        recurring=result.recurring if hasattr(result, 'recurring') else "none",
                        recurring_end_date=result.recurring_end_date if hasattr(result, 'recurring_end_date') else None,
                        recurring_pattern=result.recurring_pattern if hasattr(result, 'recurring_pattern') else None
                    )
                return None

        except Exception as e:
            print(f"Error getting event {event_id}: {e}")
            return None

    def create_event(self, event_data: EventCreate, home_id: int, created_by: str = None) -> Event:
        """Create a new event"""
        try:
            # Get schema for home
            schema_name = get_schema_name_by_home_id(home_id)
            if not schema_name:
                raise ValueError(f"No schema found for home ID {home_id}")

            # Get the events table
            events_table = self.get_events_table(schema_name)
            if events_table is None:
                raise ValueError(f"Events table not found in schema {schema_name}")

            # Generate unique event_id
            event_id = str(uuid.uuid4())
            current_time = datetime.now()

            # Prepare event data
            event_data_dict = {
                'id': event_id,
                'name': event_data.name,
                'type': event_data.type,
                'description': event_data.description,
                'dateTime': event_data.dateTime,
                'location': event_data.location,
                'maxParticipants': event_data.maxParticipants,
                'currentParticipants': event_data.currentParticipants if hasattr(event_data, 'currentParticipants') else 0,
                'image_url': event_data.image_url if hasattr(event_data, 'image_url') else None,
                'status': event_data.status if hasattr(event_data, 'status') else "pending-approval",
                'recurring': event_data.recurring if hasattr(event_data, 'recurring') else "none",
                'recurring_end_date': event_data.recurring_end_date if hasattr(event_data, 'recurring_end_date') else None,
                'recurring_pattern': event_data.recurring_pattern if hasattr(event_data, 'recurring_pattern') else None,
                'created_by': created_by,
                'created_at': current_time,
                'updated_at': current_time
            }

            # Insert event data
            schema_engine = get_schema_engine(schema_name)
            if not schema_engine:
                return []
            with schema_engine.connect() as conn:
                result = conn.execute(events_table.insert().values(**event_data_dict))
                conn.commit()

            # Return Event object
            return Event(
                id=event_id,
                name=event_data.name,
                type=event_data.type,
                description=event_data.description,
                dateTime=event_data.dateTime,
                location=event_data.location,
                maxParticipants=event_data.maxParticipants,
                currentParticipants=0,
                image_url=getattr(event_data, 'image_url', "") or "",
                status=getattr(event_data, 'status', "pending-approval"),
                recurring=getattr(event_data, 'recurring', "none"),
                recurring_end_date=getattr(event_data, 'recurring_end_date', None),
                recurring_pattern=getattr(event_data, 'recurring_pattern', None)
            )

        except Exception as e:
            print(f"Error creating event: {e}")
            raise

    def update_event(self, event_id: str, event_data: EventUpdate, home_id: int) -> Optional[Event]:
        """Update an existing event"""
        try:
            # Get schema for home
            schema_name = get_schema_name_by_home_id(home_id)
            if not schema_name:
                return None

            # Get the events table
            events_table = self.get_events_table(schema_name)
            if events_table is None:
                return None

            # Prepare update data (only non-None fields)
            update_data = {}
            for field, value in event_data.model_dump(exclude_unset=True).items():
                if value is not None:
                    update_data[field] = value
            
            # Add updated timestamp
            update_data['updated_at'] = datetime.now()

            # Update event
            schema_engine = get_schema_engine(schema_name)
            if not schema_engine:
                return []
            with schema_engine.connect() as conn:
                result = conn.execute(
                    events_table.update()
                    .where(events_table.c.id == event_id)
                    .values(**update_data)
                )
                conn.commit()

                if result.rowcount > 0:
                    # Fetch and return updated event
                    updated_result = conn.execute(
                        events_table.select().where(events_table.c.id == event_id)
                    ).fetchone()

                    if updated_result:
                        return Event(
                            id=updated_result.id,
                            name=updated_result.name,
                            type=updated_result.type,
                            description=updated_result.description,
                            dateTime=updated_result.dateTime,
                            location=updated_result.location,
                            maxParticipants=updated_result.maxParticipants,
                            currentParticipants=updated_result.currentParticipants,
                            image_url=updated_result.image_url or "",
                            status=updated_result.status if hasattr(updated_result, 'status') else "pending-approval",
                            recurring=updated_result.recurring if hasattr(updated_result, 'recurring') else "none",
                            recurring_end_date=updated_result.recurring_end_date if hasattr(updated_result, 'recurring_end_date') else None,
                            recurring_pattern=updated_result.recurring_pattern if hasattr(updated_result, 'recurring_pattern') else None
                        )
                return None

        except Exception as e:
            print(f"Error updating event {event_id}: {e}")
            return None

    def delete_event(self, event_id: str, home_id: int) -> bool:
        """Delete an event"""
        try:
            # Get schema for home
            schema_name = get_schema_name_by_home_id(home_id)
            if not schema_name:
                return False

            # Get the events table
            events_table = self.get_events_table(schema_name)
            if events_table is None:
                return False

            # Delete event
            schema_engine = get_schema_engine(schema_name)
            if not schema_engine:
                return []
            with schema_engine.connect() as conn:
                result = conn.execute(
                    events_table.delete().where(events_table.c.id == event_id)
                )
                conn.commit()
                return result.rowcount > 0

        except Exception as e:
            print(f"Error deleting event {event_id}: {e}")
            return False

    def get_events_by_type(self, event_type: str, home_id: int) -> List[Event]:
        """Get events by type"""
        try:
            # Get schema for home
            schema_name = get_schema_name_by_home_id(home_id)
            if not schema_name:
                return []

            # Get the events table
            events_table = self.get_events_table(schema_name)
            if events_table is None:
                return []

            events = []
            schema_engine = get_schema_engine(schema_name)
            if not schema_engine:
                return []
            with schema_engine.connect() as conn:
                results = conn.execute(
                    events_table.select().where(events_table.c.type == event_type)
                ).fetchall()
                
                for result in results:
                    events.append(Event(
                        id=result.id,
                        name=result.name,
                        type=result.type,
                        description=result.description,
                        dateTime=result.dateTime,
                        location=result.location,
                        maxParticipants=result.maxParticipants,
                        currentParticipants=result.currentParticipants,
                        image_url=result.image_url or "",
                        status=result.status if hasattr(result, 'status') else "pending-approval",
                        recurring=result.recurring if hasattr(result, 'recurring') else "none",
                        recurring_end_date=result.recurring_end_date if hasattr(result, 'recurring_end_date') else None,
                        recurring_pattern=result.recurring_pattern if hasattr(result, 'recurring_pattern') else None
                    ))
            return events

        except Exception as e:
            print(f"Error getting events by type {event_type} for home {home_id}: {e}")
            return []

    def get_upcoming_events(self, home_id: int) -> List[Event]:
        """Get upcoming events (events in the future)"""
        try:
            # Get schema for home
            schema_name = get_schema_name_by_home_id(home_id)
            if not schema_name:
                return []

            # Get the events table
            events_table = self.get_events_table(schema_name)
            if events_table is None:
                return []

            events = []
            schema_engine = get_schema_engine(schema_name)
            if not schema_engine:
                return []
            with schema_engine.connect() as conn:
                now = datetime.now()
                results = conn.execute(
                    events_table.select().where(events_table.c.dateTime > now)
                ).fetchall()
                
                for result in results:
                    events.append(Event(
                        id=result.id,
                        name=result.name,
                        type=result.type,
                        description=result.description,
                        dateTime=result.dateTime,
                        location=result.location,
                        maxParticipants=result.maxParticipants,
                        currentParticipants=result.currentParticipants,
                        image_url=result.image_url or "",
                        status=result.status if hasattr(result, 'status') else "pending-approval",
                        recurring=result.recurring if hasattr(result, 'recurring') else "none",
                        recurring_end_date=result.recurring_end_date if hasattr(result, 'recurring_end_date') else None,
                        recurring_pattern=result.recurring_pattern if hasattr(result, 'recurring_pattern') else None
                    ))
            return events

        except Exception as e:
            print(f"Error getting upcoming events for home {home_id}: {e}")
            return []


    def register_for_event(self, event_id: str, user_id: Optional[str], home_id: int) -> bool:
        """Register a user for an event"""
        try:
            # Get schema for home
            schema_name = get_schema_name_by_home_id(home_id)
            if not schema_name:
                return False

            # Get the events table
            events_table = self.get_events_table(schema_name)
            if events_table is None:
                return False

            schema_engine = get_schema_engine(schema_name)
            if not schema_engine:
                return []
            with schema_engine.connect() as conn:
                # Get current event data
                result = conn.execute(
                    events_table.select().where(events_table.c.id == event_id)
                ).fetchone()
                
                if not result:
                    return False
                
                # Check if event is full
                if result.currentParticipants >= result.maxParticipants:
                    return False
                
                # Update participant count
                update_result = conn.execute(
                    events_table.update()
                    .where(events_table.c.id == event_id)
                    .values(currentParticipants=result.currentParticipants + 1)
                )
                conn.commit()
                
                return update_result.rowcount > 0

        except Exception as e:
            print(f"Error registering for event {event_id}: {e}")
            return False

    def unregister_from_event(self, event_id: str, user_id: Optional[str], home_id: int) -> bool:
        """Unregister a user from an event"""
        try:
            # Get schema for home
            schema_name = get_schema_name_by_home_id(home_id)
            if not schema_name:
                return False

            # Get the events table
            events_table = self.get_events_table(schema_name)
            if events_table is None:
                return False

            schema_engine = get_schema_engine(schema_name)
            if not schema_engine:
                return []
            with schema_engine.connect() as conn:
                # Get current event data
                result = conn.execute(
                    events_table.select().where(events_table.c.id == event_id)
                ).fetchone()
                
                if not result:
                    return False
                
                # Update participant count (don't go below 0)
                new_count = max(0, result.currentParticipants - 1)
                update_result = conn.execute(
                    events_table.update()
                    .where(events_table.c.id == event_id)
                    .values(currentParticipants=new_count)
                )
                conn.commit()
                
                return update_result.rowcount > 0

        except Exception as e:
            print(f"Error unregistering from event {event_id}: {e}")
            return False

    def load_events_for_home(self, home_id: int, user_id: str) -> List[dict]:
        """
        Load events for home screen with specific filtering and next occurrence calculation.
        
        Database query conditions:
        - All events that dateTime is newer than now and recurring is 'none'
        - All events that recurring_end_date is newer than now and recurring is not 'none'
        
        Response filtering:
        1. For recurring events: return only if recurring end date has not passed and next occurrence is within end date
        2. For one-time events: return all events which date is newer than now
        
        Override dateTime with next occurrence for recurring events.
        Order by dateTime (after override calculation).
        """
        try:
            # Get schema for home
            schema_name = get_schema_name_by_home_id(home_id)
            if not schema_name:
                return []

            # Get the events and events_registration tables
            events_table = self.get_events_table(schema_name)
            if events_table is None:
                return []

            # Get registration table
            metadata = MetaData(schema=schema_name)
            schema_engine = get_schema_engine(schema_name)
            if not schema_engine:
                return []
            metadata.reflect(bind=schema_engine, only=['events_registration'])
            registration_table = metadata.tables[f'{schema_name}.events_registration']

            events_with_status = []
            now = datetime.now()
            
            schema_engine = get_schema_engine(schema_name)
            if not schema_engine:
                return []
            with schema_engine.connect() as conn:
                # Query database according to requirements:
                # 1. All events that dateTime is newer than now and recurring is 'none'
                # 2. All events that recurring_end_date is newer than now and recurring is not 'none'
                results = conn.execute(
                    text(f"""
                        SELECT
                            e.id,
                            e.name,
                            e.type,
                            e.description,
                            e.dateTime,
                            e.location,
                            e.maxParticipants,
                            e.currentParticipants,
                            e.image_url,
                            e.status,
                            e.recurring,
                            e.recurring_end_date,
                            e.recurring_pattern,
                            CASE
                                WHEN er.status = 'registered' THEN 1
                                ELSE 0
                            END as is_registered
                        FROM [{schema_name}].[events] e
                        LEFT JOIN [{schema_name}].[events_registration] er
                            ON e.id = er.event_id
                            AND er.user_id = :user_id
                            AND er.status = 'registered'
                        WHERE e.status = 'approved'
                            AND (
                                (e.recurring = 'none' AND e.dateTime > :now)
                                OR
                                (e.recurring != 'none' AND e.recurring_end_date > :now)
                            )
                    """),
                    {"user_id": user_id, "now": now}
                ).fetchall()
                
                for result in results:
                    # Determine the display datetime
                    display_datetime = result.dateTime
                    
                    # For recurring events, calculate next occurrence
                    if result.recurring and result.recurring != 'none':
                        if result.recurring_pattern and result.recurring_end_date:
                            next_occurrence = calculate_next_occurrence(
                                result.dateTime,
                                result.recurring_pattern,
                                result.recurring_end_date
                            )
                            
                            # Additional filtering: make sure the next iteration hasn't passed the recurring end time
                            if next_occurrence > result.recurring_end_date:
                                continue  # Skip this event - no more valid occurrences
                            
                            # Also check if next occurrence is in the future
                            if next_occurrence <= now:
                                continue  # Skip this event - next occurrence has already passed
                                
                            display_datetime = next_occurrence
                        else:
                            # Recurring event without proper pattern - skip
                            continue
                    else:
                        # For one-time events, make sure the date is newer than now
                        if result.dateTime <= now:
                            continue
                    
                    event_dict = {
                        'id': result.id,
                        'name': result.name,
                        'type': result.type,
                        'description': result.description,
                        'dateTime': display_datetime.isoformat() if display_datetime else None,
                        'location': result.location,
                        'maxParticipants': result.maxParticipants,
                        'currentParticipants': result.currentParticipants,
                        'image_url': result.image_url or "",
                        'status': result.status if hasattr(result, 'status') else "pending-approval",
                        'recurring': result.recurring if hasattr(result, 'recurring') else "none",
                        'recurring_end_date': result.recurring_end_date.isoformat() if hasattr(result, 'recurring_end_date') and result.recurring_end_date else None,
                        'recurring_pattern': result.recurring_pattern if hasattr(result, 'recurring_pattern') else None,
                        'is_registered': bool(result.is_registered)
                    }
                    events_with_status.append(event_dict)
            
            # Sort by dateTime (after override calculation for recurring events)
            events_with_status.sort(key=lambda x: x['dateTime'] if x['dateTime'] else '9999-12-31T23:59:59')
            
            return events_with_status

        except Exception as e:
            print(f"Error loading events for home {home_id}, user {user_id}: {e}")
            return []

# Create global instance
event_db = EventDatabase()

# ========================= Event API Endpoints ========================= #

# Events CRUD endpoints
@router.get("/events", response_model=List[Event])
async def get_events(
    type: Optional[str] = Query(None, description="Filter by event type"),
    upcoming: Optional[bool] = Query(False, description="Get only upcoming events"),
    approved_only: Optional[bool] = Query(False, description="Get only approved events"),
    home_id: int = Depends(get_home_id),
    firebase_token: Optional[str] = Header(None, alias="firebaseToken"),
    user_id: Optional[str] = Depends(get_user_id)
):
    """Get events with various filtering options"""
    # Log headers for tracking (can be expanded for analytics/auditing)
    print(f"Request from homeID: {home_id}, userID: {user_id}")
    
    if approved_only:
        # For homepage - show only approved events
        events = event_db.get_approved_events(home_id)
    elif upcoming:
        events = event_db.get_upcoming_events(home_id)
    elif type:
        events = event_db.get_events_by_type(type, home_id)
    else:
        # Show all events for everyone
        events = event_db.get_all_events_ordered(home_id)
    
    return events

@router.get("/events/home")
async def get_events_for_home(
    home_id: int = Depends(get_home_id),
    user_id: str = Depends(get_user_id),
    firebase_token: Optional[str] = Header(None, alias="firebaseToken")
):
    """Get events for home screen with proper recurring event handling"""
    if not user_id:
        raise HTTPException(status_code=400, detail="User ID is required")
    
    print(f"Getting events for home {home_id}, user {user_id}")
    
    events_with_status = event_db.load_events_for_home(home_id, user_id)
    return events_with_status

@router.get("/events/{event_id}", response_model=Event)
async def get_event(
    event_id: str,
    home_id: int = Depends(get_home_id),
    firebase_token: Optional[str] = Header(None, alias="firebaseToken"),
    user_id: Optional[str] = Depends(get_user_id)
):
    """Get a specific event by ID"""
    event = event_db.get_event_by_id(event_id, home_id)
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    return event

@router.post("/events", response_model=Event, status_code=201)
async def create_event(
    name: str = Form(...),
    type: str = Form(...),
    description: str = Form(...),
    dateTime: str = Form(...),
    location: str = Form(...),
    maxParticipants: int = Form(...),
    currentParticipants: int = Form(0),
    status: str = Form("pending-approval"),
    recurring: str = Form("none"),
    recurring_end_date: Optional[str] = Form(None),
    recurring_pattern: Optional[str] = Form(None),
    instructor_name: Optional[str] = Form(None),
    instructor_desc: Optional[str] = Form(None),
    instructor_photo: Optional[str] = Form(None),
    image: Optional[UploadFile] = File(None),
    home_id: int = Depends(get_home_id),
    firebase_token: Optional[str] = Header(None, alias="firebaseToken"),
    user_id: Optional[str] = Depends(get_user_id)
):
    """Create a new event with image upload"""
    try:
        # Parse dateTime
        try:
            event_datetime = datetime.fromisoformat(dateTime.replace('Z', '+00:00'))
        except ValueError:
            raise HTTPException(status_code=400, detail="Invalid dateTime format")
        
        # Parse optional datetime fields
        parsed_recurring_end_date = None
        if recurring_end_date:
            try:
                parsed_recurring_end_date = datetime.fromisoformat(recurring_end_date.replace('Z', '+00:00'))
            except ValueError:
                raise HTTPException(status_code=400, detail="Invalid recurring_end_date format")
        
        # First create event without image
        event_data = EventCreate(
            name=name,
            type=type,
            description=description,
            dateTime=event_datetime,
            location=location,
            maxParticipants=maxParticipants,
            image_url="",  # Will be updated after image upload
            currentParticipants=currentParticipants,
            status=status,
            recurring=recurring,
            recurring_end_date=parsed_recurring_end_date,
            recurring_pattern=recurring_pattern,
            instructor_name=instructor_name,
            instructor_desc=instructor_desc,
            instructor_photo=instructor_photo
        )
        
        # Create the event
        new_event = event_db.create_event(event_data, home_id, created_by=user_id)
        
        # Handle image upload after event creation
        if image:
            # Validate image file
            if not image.content_type or not image.content_type.startswith('image/'):
                raise HTTPException(status_code=400, detail="Uploaded file must be an image")
            
            # Read image data
            image_data = await image.read()
            
            # Upload to Azure Storage using event_id as filename
            success, result = azure_storage_service.upload_event_image(
                home_id=home_id,
                event_id=new_event.id,
                image_data=image_data,
                original_filename=image.filename or "event_image.jpg",
                content_type=image.content_type
            )
            
            if not success:
                raise HTTPException(status_code=400, detail=f"Image upload failed: {result}")
            
            # Update event with image URL
            from models import EventUpdate
            event_update = EventUpdate(image_url=result)
            updated_event = event_db.update_event(new_event.id, event_update, home_id)
            if updated_event:
                new_event = updated_event
        
        return new_event
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Error creating event: {str(e)}")

@router.put("/events/{event_id}", response_model=Event)
async def update_event(
    event_id: str,
    name: Optional[str] = Form(None),
    type: Optional[str] = Form(None),
    description: Optional[str] = Form(None),
    dateTime: Optional[str] = Form(None),
    location: Optional[str] = Form(None),
    maxParticipants: Optional[int] = Form(None),
    currentParticipants: Optional[int] = Form(None),
    status: Optional[str] = Form(None),
    recurring: Optional[str] = Form(None),
    recurring_end_date: Optional[str] = Form(None),
    recurring_pattern: Optional[str] = Form(None),
    instructor_name: Optional[str] = Form(None),
    instructor_desc: Optional[str] = Form(None),
    instructor_photo: Optional[str] = Form(None),
    image: Optional[UploadFile] = File(None),
    home_id: int = Depends(get_home_id),
    firebase_token: Optional[str] = Header(None, alias="firebaseToken"),
    user_id: Optional[str] = Depends(get_user_id)
):
    """Update an existing event with image upload"""
    try:
        # Prepare update data
        update_data = {}
        
        if name is not None:
            update_data['name'] = name
        if type is not None:
            update_data['type'] = type
        if description is not None:
            update_data['description'] = description
        if location is not None:
            update_data['location'] = location
        if maxParticipants is not None:
            update_data['maxParticipants'] = maxParticipants
        if currentParticipants is not None:
            update_data['currentParticipants'] = currentParticipants
        if status is not None:
            update_data['status'] = status
        if recurring is not None:
            update_data['recurring'] = recurring
        if recurring_pattern is not None:
            update_data['recurring_pattern'] = recurring_pattern
        if instructor_name is not None:
            update_data['instructor_name'] = instructor_name
        if instructor_desc is not None:
            update_data['instructor_desc'] = instructor_desc
        if instructor_photo is not None:
            update_data['instructor_photo'] = instructor_photo
        
        # Parse datetime fields
        if dateTime is not None:
            try:
                update_data['dateTime'] = datetime.fromisoformat(dateTime.replace('Z', '+00:00'))
            except ValueError:
                raise HTTPException(status_code=400, detail="Invalid dateTime format")
        
        if recurring_end_date is not None:
            try:
                update_data['recurring_end_date'] = datetime.fromisoformat(recurring_end_date.replace('Z', '+00:00'))
            except ValueError:
                raise HTTPException(status_code=400, detail="Invalid recurring_end_date format")
        
        # Handle image update
        if image:
            # Validate image file
            if not image.content_type or not image.content_type.startswith('image/'):
                raise HTTPException(status_code=400, detail="Uploaded file must be an image")
            
            # Read image data
            image_data = await image.read()
            
            # Upload to Azure Storage using event_id as filename
            success, result = azure_storage_service.upload_event_image(
                home_id=home_id,
                event_id=event_id,
                image_data=image_data,
                original_filename=image.filename or "event_image.jpg",
                content_type=image.content_type
            )
            
            if not success:
                raise HTTPException(status_code=400, detail=f"Image upload failed: {result}")
            
            update_data['image_url'] = result
        
        # Create EventUpdate object
        event_update = EventUpdate(**update_data)
        
        # Update the event
        updated_event = event_db.update_event(event_id, event_update, home_id)
        if not updated_event:
            raise HTTPException(status_code=404, detail="Event not found")
        
        return updated_event
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Error updating event: {str(e)}")

@router.delete("/events/{event_id}")
async def delete_event(
    event_id: str,
    home_id: int = Depends(get_home_id),
    firebase_token: Optional[str] = Header(None, alias="firebaseToken"),
    user_id: Optional[str] = Depends(get_user_id)
):
    """Delete an event"""
    success = event_db.delete_event(event_id, home_id)
    if not success:
        raise HTTPException(status_code=404, detail="Event not found")
    return {"message": "Event deleted successfully"}

# Event registration endpoints
@router.post("/events/{event_id}/register")
async def register_for_event(
    event_id: str,
    home_id: int = Depends(get_home_id),
    user_id: Optional[str] = Depends(get_user_id),
    firebase_token: Optional[str] = Header(None, alias="firebaseToken")
):
    """Register for an event"""
    if not user_id:
        raise HTTPException(status_code=400, detail="User ID is required for registration")
    
    # Check if event exists
    event = event_db.get_event_by_id(event_id, home_id)
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    
    # Get user info for registration - ensure all fields are populated
    user_profile = user_db.get_user_profile(user_id, home_id)
    if not user_profile:
        raise HTTPException(status_code=404, detail="User profile not found - cannot register for event")
    
    # Ensure we have the user's name and phone
    user_name = user_profile.full_name or "Unknown User"
    user_phone = user_profile.phone_number or ""
    
    print(f"Registering user {user_id} ({user_name}, {user_phone}) for event {event_id}")
    
    success = events_registration_db.register_for_event(
        event_id=event_id,
        user_id=user_id,
        user_name=user_name,
        user_phone=user_phone,
        home_id=home_id
    )
    
    if not success:
        raise HTTPException(status_code=400, detail="Unable to register for event. Event may be full or you may already be registered.")
    
    return {"message": "Successfully registered for event", "event_id": event_id}

@router.post("/events/{event_id}/unregister")
async def unregister_from_event(
    event_id: str,
    home_id: int = Depends(get_home_id),
    user_id: Optional[str] = Depends(get_user_id),
    firebase_token: Optional[str] = Header(None, alias="firebaseToken")
):
    """Unregister from an event"""
    if not user_id:
        raise HTTPException(status_code=400, detail="User ID is required for unregistration")
    
    # Check if event exists
    event = event_db.get_event_by_id(event_id, home_id)
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    
    success = events_registration_db.unregister_from_event(
        event_id=event_id,
        user_id=user_id,
        home_id=home_id
    )
    
    if not success:
        raise HTTPException(status_code=400, detail="Unable to unregister from event. You may not be registered for this event.")
    
    return {"message": "Successfully unregistered from event", "event_id": event_id}

# Additional helper imports needed
from fastapi import Query, Form

@router.put("/events/{event_id}/vote-review")
async def update_vote_and_review(
    event_id: str,
    vote_review_data: dict,
    home_id: int = Depends(get_home_id),
    user_id: Optional[str] = Depends(get_user_id),
    firebase_token: Optional[str] = Header(None, alias="firebaseToken")
):
    """Update vote and/or add review for an event registration"""
    if not user_id:
        raise HTTPException(status_code=400, detail="User ID is required")
    
    # Check if event exists
    event = event_db.get_event_by_id(event_id, home_id)
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    
    # Check if user is registered for this event
    is_registered = events_registration_db.is_user_registered(event_id, user_id, home_id)
    if not is_registered:
        raise HTTPException(status_code=400, detail="User must be registered for this event to vote or review")
    
    # Update vote and/or review
    success = events_registration_db.update_vote_and_review(
        event_id=event_id,
        user_id=user_id,
        vote=vote_review_data.get('vote'),
        review_text=vote_review_data.get('review_text'),
        home_id=home_id
    )
    
    if not success:
        raise HTTPException(status_code=400, detail="Failed to update vote and review")
    
    return {"message": "Vote and review updated successfully", "event_id": event_id}

@router.get("/events/{event_id}/vote-review")
async def get_vote_and_review(
    event_id: str,
    home_id: int = Depends(get_home_id),
    user_id: Optional[str] = Depends(get_user_id),
    firebase_token: Optional[str] = Header(None, alias="firebaseToken")
):
    """Get vote and reviews for an event registration"""
    if not user_id:
        raise HTTPException(status_code=400, detail="User ID is required")
    
    # Check if event exists
    event = event_db.get_event_by_id(event_id, home_id)
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    
    # Get vote and reviews data
    vote_data = events_registration_db.get_vote_and_reviews(event_id, user_id, home_id)
    
    if not vote_data:
        raise HTTPException(status_code=404, detail="Registration not found for this event")
    
    return vote_data

async def require_manager_role(user_id: str, home_id: int):
    """Dependency to ensure user has manager role"""
    role = await get_user_role(user_id, home_id)
    if role != "manager":
        raise HTTPException(status_code=403, detail="Manager role required")
    return True

@router.get("/events/{event_id}/votes-reviews/all")
async def get_all_votes_and_reviews(
    event_id: str,
    home_id: int = Depends(get_home_id),
    current_user_id: str = Header(..., alias="currentUserId"),
    firebase_token: Optional[str] = Header(None, alias="firebaseToken")
):
    """Get all votes and reviews for an event - requires manager role"""
    # Check if current user has manager role
    await require_manager_role(current_user_id, home_id)
    
    # Check if event exists
    event = event_db.get_event_by_id(event_id, home_id)
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    
    # Get all registrations for this event
    registrations = events_registration_db.get_event_registrations(event_id, home_id)
    
    # Filter and format votes and reviews data
    votes_reviews_data = []
    for registration in registrations:
        reg_dict = registration.to_dict()
        if reg_dict.get('vote') is not None or (reg_dict.get('reviews') and reg_dict.get('reviews').strip()):
            # Parse reviews if they exist
            reviews_list = []
            if reg_dict.get('reviews'):
                try:
                    import json
                    reviews_list = json.loads(reg_dict['reviews'])
                except (json.JSONDecodeError, Exception):
                    reviews_list = []
            
            votes_reviews_data.append({
                'registration_id': reg_dict['id'],
                'user_id': reg_dict['user_id'],
                'user_name': reg_dict['user_name'],
                'vote': reg_dict.get('vote'),
                'reviews': reviews_list,
                'registration_date': reg_dict['registration_date']
            })
    
    return {
        'event_id': event_id,
        'event_name': event.name,
        'total_votes_reviews': len(votes_reviews_data),
        'votes_reviews': votes_reviews_data
    }

# Event type endpoints
@router.get("/events/types/{event_type}", response_model=List[Event])
async def get_events_by_type(event_type: str, home_id: int = Depends(get_home_id)):
    """Get all events of a specific type"""
    events = event_db.get_events_by_type(event_type, home_id)
    return events

@router.get("/events/upcoming/all", response_model=List[Event])
async def get_upcoming_events(home_id: int = Depends(get_home_id)):
    """Get all upcoming events"""
    events = event_db.get_upcoming_events(home_id)
    return events

# ------------------------- Event Gallery Endpoints ------------------------- #
@router.get("/events/{event_id}/gallery", response_model=List[EventGallery])
async def get_event_gallery(
    event_id: str,
    home_id: int = Depends(get_home_id),
    user_id: Optional[str] = Depends(get_user_id),
    firebase_token: Optional[str] = Header(None, alias="firebaseToken")
):
    """Get all gallery images for an event"""
    # Check if event exists
    event = event_db.get_event_by_id(event_id, home_id)
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    
    gallery_images = event_gallery_db.get_event_gallery(event_id, home_id)
    return gallery_images

@router.post("/events/{event_id}/gallery", response_model=List[EventGallery], status_code=201)
async def upload_gallery_images(
    event_id: str,
    images: List[UploadFile] = File(...),
    home_id: int = Depends(get_home_id),
    user_id: Optional[str] = Depends(get_user_id),
    firebase_token: Optional[str] = Header(None, alias="firebaseToken")
):
    """Upload multiple images to event gallery (max 3)"""
    # Check if event exists
    event = event_db.get_event_by_id(event_id, home_id)
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    
    # Limit to 3 images maximum
    if len(images) > 3:
        raise HTTPException(status_code=400, detail="Maximum 3 images allowed per upload")
    
    # Validate all images
    image_files = []
    for image in images:
        if not image.content_type or not image.content_type.startswith('image/'):
            raise HTTPException(status_code=400, detail=f"File {image.filename} must be an image")
        
        # Read image data
        image_data = await image.read()
        image_files.append({
            'filename': image.filename or "gallery_image.jpg",
            'content': image_data,
            'content_type': image.content_type
        })
    
    try:
        # Upload images to gallery
        created_galleries = event_gallery_db.upload_gallery_images(
            event_id=event_id,
            home_id=home_id,
            image_files=image_files,
            created_by=user_id
        )
        
        if not created_galleries:
            raise HTTPException(status_code=400, detail="Failed to upload images")
        
        return created_galleries
        
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Error uploading gallery images: {str(e)}")

@router.get("/events/{event_id}/gallery/{photo_id}", response_model=EventGallery)
async def get_gallery_photo(
    event_id: str,
    photo_id: str,
    home_id: int = Depends(get_home_id),
    user_id: Optional[str] = Depends(get_user_id),
    firebase_token: Optional[str] = Header(None, alias="firebaseToken")
):
    """Get a specific gallery photo"""
    # Check if event exists
    event = event_db.get_event_by_id(event_id, home_id)
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    
    photo = event_gallery_db.get_gallery_photo(photo_id, home_id)
    if not photo:
        raise HTTPException(status_code=404, detail="Gallery photo not found")
    
    # Verify photo belongs to the event
    if photo.event_id != event_id:
        raise HTTPException(status_code=404, detail="Gallery photo not found for this event")
    
    return photo

@router.delete("/events/{event_id}/gallery/{photo_id}")
async def delete_gallery_photo(
    event_id: str,
    photo_id: str,
    home_id: int = Depends(get_home_id),
    user_id: Optional[str] = Depends(get_user_id),
    firebase_token: Optional[str] = Header(None, alias="firebaseToken")
):
    """Delete a specific gallery photo"""
    # Check if event exists
    event = event_db.get_event_by_id(event_id, home_id)
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    
    # Get photo to verify it belongs to the event
    photo = event_gallery_db.get_gallery_photo(photo_id, home_id)
    if not photo or photo.event_id != event_id:
        raise HTTPException(status_code=404, detail="Gallery photo not found for this event")
    
    success = event_gallery_db.delete_gallery_photo(photo_id, home_id)
    if not success:
        raise HTTPException(status_code=404, detail="Gallery photo not found")
    
    return {"message": "Gallery photo deleted successfully"}

@router.delete("/events/{event_id}/gallery")
async def delete_event_gallery(
    event_id: str,
    home_id: int = Depends(get_home_id),
    user_id: Optional[str] = Depends(get_user_id),
    firebase_token: Optional[str] = Header(None, alias="firebaseToken")
):
    """Delete all gallery photos for an event"""
    # Check if event exists
    event = event_db.get_event_by_id(event_id, home_id)
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    
    success = event_gallery_db.delete_event_gallery(event_id, home_id)
    if not success:
        raise HTTPException(status_code=400, detail="Failed to delete event gallery")
    
    return {"message": "Event gallery deleted successfully"}

# ------------------------- Event Instructor Endpoints ------------------------- #
@router.get("/event-instructors", response_model=List[EventInstructor])
async def get_event_instructors(
    home_id: int = Depends(get_home_id),
):
    """List all event instructors - public access"""
    instructors = event_instructor_db.get_all_event_instructors(home_id)
    return instructors

@router.get("/event-instructors/{instructor_id}", response_model=EventInstructor)
async def get_event_instructor(
    instructor_id: str,
    home_id: int = Depends(get_home_id),
):
    """Get a specific event instructor by ID"""
    instructor = event_instructor_db.get_event_instructor_by_id(instructor_id, home_id)
    if not instructor:
        raise HTTPException(status_code=404, detail="Event instructor not found")
    return instructor

@router.post("/event-instructors", response_model=EventInstructor, status_code=201)
async def create_event_instructor(
    name: str = Form(...),
    description: Optional[str] = Form(None),
    photo: Optional[UploadFile] = File(None),
    home_id: int = Depends(get_home_id),
    current_user_id: str = Header(..., alias="currentUserId"),
):
    """Create a new event instructor with photo upload - manager role required"""
    # Check if current user has manager role
    await require_manager_role(current_user_id, home_id)
    
    try:
        # First create instructor without photo
        instructor_data = EventInstructorCreate(
            name=name,
            description=description
        )
        
        # Create the instructor
        new_instructor = event_instructor_db.create_event_instructor(instructor_data, home_id)
        if not new_instructor:
            raise HTTPException(status_code=400, detail="Unable to create event instructor")
        
        # Handle photo upload if provided
        if photo:
            # Validate photo file
            if not photo.content_type or not photo.content_type.startswith('image/'):
                raise HTTPException(status_code=400, detail="Uploaded file must be an image")
            
            # Read photo data
            photo_data = await photo.read()
            
            # Upload to Azure Storage using instructor_id as filename
            success, result = azure_storage_service.upload_event_instructor_photo(
                home_id=home_id,
                instructor_id=new_instructor.id,
                image_data=photo_data,
                original_filename=photo.filename or "instructor_photo.jpg",
                content_type=photo.content_type
            )
            
            if not success:
                raise HTTPException(status_code=400, detail=f"Photo upload failed: {result}")
            
            # Update instructor with photo URL
            instructor_update = EventInstructorUpdate(photo=result)
            updated_instructor = event_instructor_db.update_event_instructor(new_instructor.id, instructor_update, home_id)
            if updated_instructor:
                new_instructor = updated_instructor
        
        return new_instructor
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Error creating event instructor: {str(e)}")

@router.put("/event-instructors/{instructor_id}", response_model=EventInstructor)
async def update_event_instructor(
    instructor_id: str,
    name: Optional[str] = Form(None),
    description: Optional[str] = Form(None),
    photo: Optional[UploadFile] = File(None),
    home_id: int = Depends(get_home_id),
    current_user_id: str = Header(..., alias="currentUserId"),
):
    """Update an event instructor with photo upload - manager role required"""
    # Check if current user has manager role
    await require_manager_role(current_user_id, home_id)
    
    try:
        # Check if instructor exists
        existing_instructor = event_instructor_db.get_event_instructor_by_id(instructor_id, home_id)
        if not existing_instructor:
            raise HTTPException(status_code=404, detail="Event instructor not found")
        
        # Prepare update data
        update_data = {}
        
        if name is not None:
            update_data['name'] = name
        if description is not None:
            update_data['description'] = description
        
        # Handle photo update if provided
        if photo:
            # Validate photo file
            if not photo.content_type or not photo.content_type.startswith('image/'):
                raise HTTPException(status_code=400, detail="Uploaded file must be an image")
            
            # Read photo data
            photo_data = await photo.read()
            
            # Upload to Azure Storage using instructor_id as filename
            success, result = azure_storage_service.upload_event_instructor_photo(
                home_id=home_id,
                instructor_id=instructor_id,
                image_data=photo_data,
                original_filename=photo.filename or "instructor_photo.jpg",
                content_type=photo.content_type
            )
            
            if not success:
                raise HTTPException(status_code=400, detail=f"Photo upload failed: {result}")
            
            update_data['photo'] = result
        
        # Create EventInstructorUpdate object
        instructor_update = EventInstructorUpdate(**update_data)
        
        # Update the instructor
        updated_instructor = event_instructor_db.update_event_instructor(instructor_id, instructor_update, home_id)
        if not updated_instructor:
            raise HTTPException(status_code=404, detail="Event instructor not found")
        
        return updated_instructor
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Error updating event instructor: {str(e)}")

@router.delete("/event-instructors/{instructor_id}")
async def delete_event_instructor(
    instructor_id: str,
    home_id: int = Depends(get_home_id),
    current_user_id: str = Header(..., alias="currentUserId"),
):
    """Delete an event instructor by ID - manager role required"""
    # Check if current user has manager role
    await require_manager_role(current_user_id, home_id)
    
    success = event_instructor_db.delete_event_instructor(instructor_id, home_id)
    if not success:
        raise HTTPException(status_code=404, detail="Event instructor not found")
    return {"message": "Event instructor deleted successfully"}

# Event Registration Management endpoints
@router.get("/registrations/user/{user_id}")
async def get_user_registrations(
    user_id: str,
    home_id: int = Depends(get_home_id),
    firebase_token: Optional[str] = Header(None, alias="firebaseToken")
):
    """Get all registrations for a specific user"""
    registrations = events_registration_db.get_user_registrations(user_id, home_id)
    return [reg.to_dict() for reg in registrations]

@router.get("/registrations/event/{event_id}")
async def get_event_registrations(
    event_id: str,
    home_id: int = Depends(get_home_id),
    current_user_id: str = Header(..., alias="currentUserId"),
    firebase_token: Optional[str] = Header(None, alias="firebaseToken")
):
    """Get all registrations for a specific event - requires manager role"""
    # Check if current user has manager role
    await require_manager_role(current_user_id, home_id)
    
    registrations = events_registration_db.get_event_registrations(event_id, home_id)
    return [reg.to_dict() for reg in registrations]

@router.get("/registrations/all")
async def get_all_registrations(
    home_id: int = Depends(get_home_id),
    current_user_id: str = Header(..., alias="currentUserId"),
    firebase_token: Optional[str] = Header(None, alias="firebaseToken")
):
    """Get all registrations - requires manager role"""
    # Check if current user has manager role
    await require_manager_role(current_user_id, home_id)
    
    registrations = events_registration_db.get_all_registrations(home_id)
    return [reg.to_dict() for reg in registrations]

@router.get("/registrations/check/{event_id}/{user_id}")
async def check_registration_status(
    event_id: str,
    user_id: str,
    home_id: int = Depends(get_home_id),
    firebase_token: Optional[str] = Header(None, alias="firebaseToken")
):
    """Check if a user is registered for an event"""
    is_registered = events_registration_db.is_user_registered(event_id, user_id, home_id)
    return {"is_registered": is_registered, "event_id": event_id, "user_id": user_id}

@router.delete("/registrations/admin/{event_id}/{user_id}")
async def admin_unregister_user(
    event_id: str,
    user_id: str,
    home_id: int = Depends(get_home_id),
    current_user_id: str = Header(..., alias="currentUserId"),
    firebase_token: Optional[str] = Header(None, alias="firebaseToken")
):
    """Admin endpoint to unregister a user from an event - requires manager role"""
    # Check if current user has manager role
    await require_manager_role(current_user_id, home_id)
    
    success = events_registration_db.unregister_from_event(event_id, user_id, home_id)
    if not success:
        raise HTTPException(status_code=400, detail="Unable to unregister user from event")
    
    return {"message": "User successfully unregistered from event", "event_id": event_id, "user_id": user_id}