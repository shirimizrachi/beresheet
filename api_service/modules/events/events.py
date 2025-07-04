"""
Event management using SQLAlchemy
Handles all event-related database operations
"""

import uuid
import logging
from datetime import datetime, timedelta
from typing import Optional, List
from sqlalchemy import create_engine, Table, MetaData, Column, String, Integer, DateTime, Boolean, text
from sqlalchemy.orm import sessionmaker
from sqlalchemy.exc import SQLAlchemyError
from .models import Event, EventCreate, EventUpdate
from tenant_config import get_schema_name_by_home_id, get_tenant_connection_string_by_home_id
from database_utils import get_schema_engine, get_engine_for_home
import json

logger = logging.getLogger(__name__)

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

    async def upload_event_instructor_photo(self, instructor_id: str, photo, home_id: int, tenant_name: str = None) -> str:
        """
        Upload photo for an event instructor and return the photo URL.
        This function can be used by both create and update operations.
        
        Args:
            instructor_id: The ID of the instructor
            photo: The uploaded photo file (UploadFile or mock upload file)
            home_id: The home ID
            tenant_name: The tenant name for storage container naming
            
        Returns:
            str: The URL of the uploaded photo
            
        Raises:
            Exception: If photo validation or upload fails
        """
        from fastapi import HTTPException
        from storage.storage_service import StorageServiceProxy
        import asyncio
        
        # Validate photo file
        if not hasattr(photo, 'content_type') or not photo.content_type or not photo.content_type.startswith('image/'):
            raise HTTPException(status_code=400, detail="Uploaded file must be an image")
        
        # Read photo data (handle both sync and async read methods)
        if hasattr(photo, 'read') and callable(photo.read):
            if asyncio.iscoroutinefunction(photo.read):
                photo_data = await photo.read()
            else:
                photo_data = photo.read()
        else:
            raise HTTPException(status_code=400, detail="Invalid photo file")
        
        # Upload to Azure Storage using instructor_id as filename
        if not tenant_name:
            raise HTTPException(status_code=400, detail="Tenant name is required for photo upload")
        
        logger.info(f"Uploading photo for instructor {instructor_id} with tenant_name: {tenant_name}")
        
        storage_service = StorageServiceProxy()
        success, result = storage_service.upload_event_instructor_photo(
            home_id=home_id,
            instructor_id=instructor_id,
            image_data=photo_data,
            original_filename=photo.filename or "instructor_photo.jpg",
            content_type=photo.content_type,
            tenant_name=tenant_name
        )
        
        if not success:
            logger.error(f"Photo upload failed for instructor {instructor_id}: {result}")
            raise HTTPException(status_code=400, detail=f"Photo upload failed: {result}")
        
        logger.info(f"Photo uploaded successfully for instructor {instructor_id}: {result}")
        return result

    async def upload_event_image(self, event_id: str, photo, home_id: int, tenant_name: str = None) -> str:
        """
        Upload image for an event and return the image URL.
        This function can be used by both create and update operations.
        
        Args:
            event_id: The ID of the event
            photo: The uploaded photo file (UploadFile or mock upload file)
            home_id: The home ID
            tenant_name: The tenant name for storage container naming
            
        Returns:
            str: The URL of the uploaded image
            
        Raises:
            Exception: If photo validation or upload fails
        """
        from fastapi import HTTPException
        from storage.storage_service import StorageServiceProxy
        import asyncio
        
        # Validate photo file
        if not hasattr(photo, 'content_type') or not photo.content_type or not photo.content_type.startswith('image/'):
            raise HTTPException(status_code=400, detail="Uploaded file must be an image")
        
        # Read photo data (handle both sync and async read methods)
        if hasattr(photo, 'read') and callable(photo.read):
            if asyncio.iscoroutinefunction(photo.read):
                photo_data = await photo.read()
            else:
                photo_data = photo.read()
        else:
            raise HTTPException(status_code=400, detail="Invalid photo file")
        
        # Upload to Azure Storage using event_id as filename
        if not tenant_name:
            raise HTTPException(status_code=400, detail="Tenant name is required for image upload")
        
        logger.info(f"Uploading image for event {event_id} with tenant_name: {tenant_name}")
        
        storage_service = StorageServiceProxy()
        success, result = storage_service.upload_event_image(
            home_id=home_id,
            event_id=event_id,
            image_data=photo_data,
            original_filename=photo.filename or "event_image.jpg",
            content_type=photo.content_type,
            tenant_name=tenant_name
        )
        
        if not success:
            logger.error(f"Image upload failed for event {event_id}: {result}")
            raise HTTPException(status_code=400, detail=f"Image upload failed: {result}")
        
        logger.info(f"Image uploaded successfully for event {event_id}: {result}")
        return result

# Create global instance
event_db = EventDatabase()