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

def _calculate_last_occurrence(event_datetime: datetime, pattern: dict, recurring_end_date: datetime) -> datetime:
    """
    Calculate the last occurrence of a recurring event before the end date.
    
    Args:
        event_datetime: The original event datetime
        pattern: Parsed recurrence pattern dict
        recurring_end_date: When the recurring series ends
        
    Returns:
        The last occurrence datetime before the end date
    """
    try:
        # Parse time from pattern, fallback to original event time
        time_str = pattern.get('time')
        if time_str:
            hour, minute = map(int, time_str.split(':'))
        else:
            hour, minute = event_datetime.hour, event_datetime.minute
        
        end_date = recurring_end_date.date()
        
        # Weekly recurrence
        if 'dayOfWeek' in pattern:
            target_day = pattern['dayOfWeek']  # 0=Sunday, 1=Monday, etc.
            interval = pattern.get('interval', 1)
            
            # Start from the original event date and find all occurrences
            reference_date = event_datetime.date()
            
            if interval > 1:
                # For bi-weekly or other intervals
                reference_weekday = (reference_date.weekday() + 1) % 7
                
                # Find the first target day from reference
                if reference_weekday == target_day:
                    first_target = reference_date
                elif reference_weekday < target_day:
                    first_target = reference_date + timedelta(days=(target_day - reference_weekday))
                else:
                    first_target = reference_date + timedelta(days=(7 - reference_weekday + target_day))
                
                # Find the last occurrence before end date
                last_occurrence = first_target
                current_candidate = first_target
                while current_candidate <= end_date:
                    last_occurrence = current_candidate
                    current_candidate = first_target + timedelta(weeks=interval * ((current_candidate - first_target).days // 7 // interval + 1))
                
            else:
                # Regular weekly
                current_candidate = reference_date
                last_occurrence = reference_date
                
                while current_candidate <= end_date:
                    current_weekday = (current_candidate.weekday() + 1) % 7
                    if current_weekday == target_day:
                        last_occurrence = current_candidate
                    current_candidate += timedelta(days=1)
            
            return datetime.combine(last_occurrence, datetime.min.time().replace(hour=hour, minute=minute))
            
        # Monthly recurrence
        elif 'dayOfMonth' in pattern:
            target_day = pattern['dayOfMonth']
            
            # Start from original event and find last valid occurrence
            current_candidate = event_datetime.date()
            last_occurrence = event_datetime.date()
            
            while current_candidate <= end_date:
                try:
                    test_date = current_candidate.replace(day=target_day)
                    if test_date <= end_date:
                        last_occurrence = test_date
                except ValueError:
                    # Target day doesn't exist in this month
                    pass
                
                # Move to next month
                if current_candidate.month == 12:
                    current_candidate = current_candidate.replace(year=current_candidate.year + 1, month=1, day=1)
                else:
                    current_candidate = current_candidate.replace(month=current_candidate.month + 1, day=1)
            
            return datetime.combine(last_occurrence, datetime.min.time().replace(hour=hour, minute=minute))
        
        else:
            # No valid pattern, return original
            return event_datetime
            
    except Exception as e:
        print(f"Error calculating last occurrence: {e}")
        return event_datetime

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
        
        # If we're past the recurring end date, calculate and return the last occurrence
        if recurring_end_date and now > recurring_end_date:
            return _calculate_last_occurrence(event_datetime, pattern, recurring_end_date)
            
        # Parse time from pattern, fallback to original event time
        time_str = pattern.get('time')
        if time_str:
            hour, minute = map(int, time_str.split(':'))
        else:
            # Use original event time if no time specified in pattern
            hour, minute = event_datetime.hour, event_datetime.minute
        
        # Weekly recurrence
        if 'dayOfWeek' in pattern:
            target_day = pattern['dayOfWeek']  # 0=Sunday, 1=Monday, etc.
            interval = pattern.get('interval', 1)  # Default to 1 for weekly, 2 for bi-weekly
            
            # Start from the original event date
            reference_date = event_datetime.date()
            current_candidate = reference_date
            
            # For bi-weekly or other intervals
            if interval > 1:
                # Convert Python weekday (0=Monday) to our format (0=Sunday)
                reference_weekday = (reference_date.weekday() + 1) % 7
                
                # Find the first target day from reference
                if reference_weekday == target_day:
                    first_target = reference_date
                elif reference_weekday < target_day:
                    first_target = reference_date + timedelta(days=(target_day - reference_weekday))
                else:
                    first_target = reference_date + timedelta(days=(7 - reference_weekday + target_day))
                
                # Find next occurrence after current time
                current_candidate = first_target
                while current_candidate <= now.date():
                    current_candidate = first_target + timedelta(weeks=interval * ((current_candidate - first_target).days // 7 // interval + 1))
                
                next_date = current_candidate
            else:
                # Regular weekly - find next occurrence of target day
                current_candidate = reference_date
                while True:
                    # Convert Python weekday (0=Monday) to our format (0=Sunday)
                    current_weekday = (current_candidate.weekday() + 1) % 7
                    
                    if current_weekday == target_day and current_candidate > now.date():
                        break
                    
                    current_candidate += timedelta(days=1)
                
                next_date = current_candidate
            
            next_datetime = datetime.combine(next_date, datetime.min.time().replace(hour=hour, minute=minute))
            
        # Monthly recurrence
        elif 'dayOfMonth' in pattern:
            target_day = pattern['dayOfMonth']
            
            # Start from the original event date
            current_candidate = event_datetime.date()
            
            # Find next occurrence of target day that's after current time
            while True:
                try:
                    test_date = current_candidate.replace(day=target_day)
                    if test_date > now.date():
                        next_date = test_date
                        break
                except ValueError:
                    # Target day doesn't exist in this month
                    pass
                
                # Move to next month
                if current_candidate.month == 12:
                    current_candidate = current_candidate.replace(year=current_candidate.year + 1, month=1, day=1)
                else:
                    current_candidate = current_candidate.replace(month=current_candidate.month + 1, day=1)
            
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

    def _create_event_from_result(self, result) -> Event:
        """Helper function to create Event object from database result with next_date_time calculation"""
        # Calculate next_date_time using the existing function
        recurring_pattern = result.recurring_pattern if hasattr(result, 'recurring_pattern') else None
        recurring_end_date = result.recurring_end_date if hasattr(result, 'recurring_end_date') else None
        next_occurrence = calculate_next_occurrence(
            result.date_time,
            recurring_pattern,
            recurring_end_date
        )
        
        return Event(
            id=result.id,
            name=result.name,
            type=result.type,
            description=result.description,
            date_time=result.date_time,
            next_date_time=next_occurrence,
            location=result.location,
            max_participants=result.max_participants,
            current_participants=result.current_participants,
            image_url=result.image_url or "",
            duration=result.duration,
            status=result.status if hasattr(result, 'status') else "pending-approval",
            recurring=result.recurring if hasattr(result, 'recurring') else "none",
            recurring_end_date=result.recurring_end_date if hasattr(result, 'recurring_end_date') else None,
            recurring_pattern=result.recurring_pattern if hasattr(result, 'recurring_pattern') else None,
            instructor_name=result.instructor_name if hasattr(result, 'instructor_name') else None,
            instructor_desc=result.instructor_desc if hasattr(result, 'instructor_desc') else None,
            instructor_photo=result.instructor_photo if hasattr(result, 'instructor_photo') else None
        )

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
                        events.append(self._create_event_from_result(result))
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
                    .order_by(events_table.c.date_time.desc())
                ).fetchall()
                
                for result in results:
                    events.append(self._create_event_from_result(result))
            return events

        except Exception as e:
            print(f"Error getting approved events for home {home_id}: {e}")
            return []


    def get_all_events_ordered(self, home_id: int) -> List[Event]:
        """Get all events ordered by updated_at desc (for staff/manager)"""
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
                    .order_by(events_table.c.updated_at.desc())
                ).fetchall()
                
                for result in results:
                    events.append(self._create_event_from_result(result))
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
                    return self._create_event_from_result(result)
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
                'date_time': event_data.date_time,
                'location': event_data.location,
                'max_participants': event_data.max_participants,
                'current_participants': event_data.current_participants if hasattr(event_data, 'current_participants') else 0,
                'image_url': event_data.image_url if hasattr(event_data, 'image_url') else None,
                'duration': event_data.duration if hasattr(event_data, 'duration') else 60,
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

            # Calculate next_date_time for the created event
            recurring_pattern = getattr(event_data, 'recurring_pattern', None)
            recurring_end_date = getattr(event_data, 'recurring_end_date', None)
            next_occurrence = calculate_next_occurrence(
                event_data.date_time,
                recurring_pattern,
                recurring_end_date
            )
            
            # Return Event object
            return Event(
                id=event_id,
                name=event_data.name,
                type=event_data.type,
                description=event_data.description,
                date_time=event_data.date_time,
                next_date_time=next_occurrence,
                location=event_data.location,
                max_participants=event_data.max_participants,
                current_participants=0,
                image_url=getattr(event_data, 'image_url', "") or "",
                duration=getattr(event_data, 'duration', 60),
                status=getattr(event_data, 'status', "pending-approval"),
                recurring=getattr(event_data, 'recurring', "none"),
                recurring_end_date=getattr(event_data, 'recurring_end_date', None),
                recurring_pattern=getattr(event_data, 'recurring_pattern', None),
                instructor_name=getattr(event_data, 'instructor_name', None),
                instructor_desc=getattr(event_data, 'instructor_desc', None),
                instructor_photo=getattr(event_data, 'instructor_photo', None)
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
                        return self._create_event_from_result(updated_result)
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
                    events.append(self._create_event_from_result(result))
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
                    events_table.select().where(events_table.c.date_time > now)
                ).fetchall()
                
                for result in results:
                    events.append(self._create_event_from_result(result))
            return events

        except Exception as e:
            print(f"Error getting upcoming events for home {home_id}: {e}")
            return []

    def get_events_by_status(self, status: str, home_id: int) -> List[Event]:
        """Get events by status"""
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
                    .where(events_table.c.status == status)
                    .order_by(events_table.c.date_time.desc())
                ).fetchall()
                
                for result in results:
                    events.append(self._create_event_from_result(result))
            return events

        except Exception as e:
            print(f"Error getting events by status {status} for home {home_id}: {e}")
            return []

    def get_completed_events_with_reviews(self, home_id: int) -> List[Event]:
        """
        Get completed events with their reviews and voting data.
        
        Filtering logic:
        - For one-time events: event date_time has passed
        - For recurring events: next occurrence has passed (all occurrences completed)
        
        Returns all voting and review data from event registration table.
        """
        try:
            schema_name = get_schema_name_by_home_id(home_id)
            if not schema_name:
                return []

            events_table = self.get_events_table(schema_name)
            if events_table is None:
                return []

            schema_engine = get_schema_engine(schema_name)
            if not schema_engine:
                return []
                
            # Get registration table for reviews
            metadata = MetaData(schema=schema_name)
            metadata.reflect(bind=schema_engine, only=['events_registration'])
            registration_table = metadata.tables[f'{schema_name}.events_registration']

            events = []
            now = datetime.now()
            
            with schema_engine.connect() as conn:
                # Query all approved events using SQLAlchemy
                events_query = events_table.select().where(events_table.c.status == 'approved').order_by(events_table.c.date_time.desc())
                event_results = conn.execute(events_query).fetchall()
                
                for result in event_results:
                    # Check if event is completed based on date/time logic
                    is_completed = False
                    
                    if result.recurring and result.recurring != 'none':
                        # For recurring events, check if next occurrence has passed
                        if result.recurring_pattern and result.recurring_end_date:
                            try:
                                next_occurrence = calculate_next_occurrence(
                                    result.date_time,
                                    result.recurring_pattern,
                                    result.recurring_end_date
                                )
                                # Event is completed if next occurrence is past the end date or in the past
                                is_completed = (next_occurrence > result.recurring_end_date or next_occurrence <= now)
                            except Exception as e:
                                print(f"Error calculating next occurrence for event {result.id}: {e}")
                                # If we can't calculate, check if original date has passed
                                is_completed = result.date_time <= now
                        else:
                            # No proper recurring pattern, check original date
                            is_completed = result.date_time <= now
                    else:
                        # For one-time events, check if date has passed
                        is_completed = result.date_time <= now
                    
                    # Only include completed events
                    if not is_completed:
                        continue
                    
                    # Get all voting and review data for this event using SQLAlchemy
                    from sqlalchemy import and_, or_
                    
                    reviews_query = registration_table.select().where(
                        and_(
                            registration_table.c.event_id == result.id,
                            registration_table.c.status == 'registered',
                            or_(
                                registration_table.c.vote.isnot(None),
                                and_(
                                    registration_table.c.reviews.isnot(None),
                                    registration_table.c.reviews != ''
                                )
                            )
                        )
                    ).order_by(registration_table.c.registration_date.desc())
                    
                    review_results = conn.execute(reviews_query).fetchall()
                    
                    # Consolidate all reviews and calculate average rating
                    all_reviews = []
                    all_ratings = []
                    
                    for review_result in review_results:
                        user_name = review_result.user_name or "Anonymous"
                        user_id = review_result.user_id
                        
                        # Add rating to the list for average calculation
                        if review_result.vote is not None:
                            all_ratings.append(review_result.vote)
                        
                        # Parse the reviews JSON field which contains multiple reviews from this user
                        if review_result.reviews and review_result.reviews.strip():
                            try:
                                user_reviews = json.loads(review_result.reviews)
                                # user_reviews is a list like [{"date": "2025-07-12T22:15:49.419809", "review": "text"}, ...]
                                for review_item in user_reviews:
                                    review_dict = {
                                        "user_name": user_name,
                                        "user_id": user_id,
                                        "comment": review_item.get("review", ""),
                                        "date": review_item.get("date", ""),
                                        "registration_date": review_result.registration_date.isoformat() if review_result.registration_date else ""
                                    }
                                    all_reviews.append(review_dict)
                            except (json.JSONDecodeError, TypeError, Exception) as e:
                                print(f"Error parsing reviews JSON for event {result.id}, user {user_id}: {e}")
                                # Fallback: treat as single review text
                                review_dict = {
                                    "user_name": user_name,
                                    "user_id": user_id,
                                    "comment": review_result.reviews,
                                    "date": "",
                                    "registration_date": review_result.registration_date.isoformat() if review_result.registration_date else ""
                                }
                                all_reviews.append(review_dict)
                    
                    # Sort all reviews by date (newest first)
                    all_reviews.sort(key=lambda x: x.get("date", ""), reverse=True)
                    
                    # Calculate average rating
                    average_rating = 0
                    if all_ratings:
                        average_rating = round(sum(all_ratings) / len(all_ratings), 1)
                    
                    # Format final reviews data structure
                    reviews_data = {
                        "average_rating": average_rating,
                        "total_ratings": len(all_ratings),
                        "reviews": all_reviews
                    }
                    
                    event = Event(
                        id=result.id,
                        name=result.name,
                        type=result.type,
                        description=result.description,
                        date_time=result.date_time,
                        location=result.location,
                        max_participants=result.max_participants,
                        current_participants=result.current_participants,
                        image_url=result.image_url or "",
                        status=result.status,
                        recurring=result.recurring if result.recurring else "none",
                        recurring_end_date=result.recurring_end_date,
                        recurring_pattern=result.recurring_pattern,
                        instructor_name=result.instructor_name if hasattr(result, 'instructor_name') else None,
                        instructor_desc=result.instructor_desc if hasattr(result, 'instructor_desc') else None,
                        instructor_photo=result.instructor_photo if hasattr(result, 'instructor_photo') else None,
                        reviews=reviews_data
                    )
                    events.append(event)
            
            print(f"DEBUG: get_completed_events_with_reviews - Returning {len(events)} completed events with reviews")
            return events

        except Exception as e:
            print(f"Error getting completed events with reviews for home {home_id}: {e}")
            import traceback
            traceback.print_exc()
            return []

    def get_events_with_gallery(self, home_id: int) -> List[Event]:
        """Get events with their gallery photos using SQLAlchemy (any status)"""
        try:
            schema_name = get_schema_name_by_home_id(home_id)
            if not schema_name:
                return []

            events_table = self.get_events_table(schema_name)
            if events_table is None:
                return []

            schema_engine = get_schema_engine(schema_name)
            if not schema_engine:
                return []
                
            # Get gallery table for photos
            metadata = MetaData(schema=schema_name)
            metadata.reflect(bind=schema_engine, only=['event_gallery'])
            gallery_table = metadata.tables[f'{schema_name}.event_gallery']

            events = []
            with schema_engine.connect() as conn:
                # First, get all completed events that have gallery photos
                # Using SQLAlchemy for database-agnostic query
                from sqlalchemy import select, distinct
                
                # Get unique event IDs that have gallery photos
                events_with_gallery = conn.execute(
                    select(distinct(gallery_table.c.event_id))
                    .where(gallery_table.c.event_id.is_not(None))
                ).fetchall()
                
                event_ids_with_gallery = [row[0] for row in events_with_gallery]
                
                if not event_ids_with_gallery:
                    return []
                
                # Get all events that have gallery photos (any status)
                events_results = conn.execute(
                    events_table.select()
                    .where(events_table.c.id.in_(event_ids_with_gallery))
                    .order_by(events_table.c.date_time.desc())
                ).fetchall()
                
                # For each event, get its gallery photos
                for result in events_results:
                    gallery_results = conn.execute(
                        gallery_table.select()
                        .where(gallery_table.c.event_id == result.id)
                        .order_by(gallery_table.c.created_at)
                    ).fetchall()
                    
                    # Build gallery data
                    gallery_data = []
                    for gallery_item in gallery_results:
                        gallery_data.append({
                            "id": gallery_item.photo_id,
                            "image_url": gallery_item.photo,
                            "thumbnail_url": gallery_item.thumbnail_url,
                            "created_at": gallery_item.created_at.isoformat() if gallery_item.created_at else ""
                        })
                    
                    event = Event(
                        id=result.id,
                        name=result.name,
                        type=result.type,
                        description=result.description,
                        date_time=result.date_time,
                        location=result.location,
                        max_participants=result.max_participants,
                        current_participants=result.current_participants,
                        image_url=result.image_url or "",
                        status=result.status,
                        recurring=result.recurring if hasattr(result, 'recurring') else "none",
                        recurring_end_date=result.recurring_end_date if hasattr(result, 'recurring_end_date') else None,
                        recurring_pattern=result.recurring_pattern if hasattr(result, 'recurring_pattern') else None,
                        instructor_name=result.instructor_name if hasattr(result, 'instructor_name') else None,
                        instructor_desc=result.instructor_desc if hasattr(result, 'instructor_desc') else None,
                        instructor_photo=result.instructor_photo if hasattr(result, 'instructor_photo') else None,
                        gallery_photos=gallery_data
                    )
                    events.append(event)
            
            return events

        except Exception as e:
            print(f"Error getting completed events with gallery for home {home_id}: {e}")
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
                if result.current_participants >= result.max_participants:
                    return False
                
                # Update participant count
                update_result = conn.execute(
                    events_table.update()
                    .where(events_table.c.id == event_id)
                    .values(current_participants=result.current_participants + 1)
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
                new_count = max(0, result.current_participants - 1)
                update_result = conn.execute(
                    events_table.update()
                    .where(events_table.c.id == event_id)
                    .values(current_participants=new_count)
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
        - All events that date_time is newer than now and recurring is 'none'
        - All events that recurring_end_date is newer than now and recurring is not 'none'
        
        Response filtering:
        1. For recurring events: return only if recurring end date has not passed and next occurrence is within end date
        2. For one-time events: return all events which date is newer than now
        
        Override date_time with next occurrence for recurring events.
        Order by date_time (after override calculation).
        """
        try:
            print(f"DEBUG: load_events_for_home - Starting for home_id: {home_id}, user_id: {user_id}")
            
            # Get schema for home
            schema_name = get_schema_name_by_home_id(home_id)
            print(f"DEBUG: load_events_for_home - Schema name: {schema_name}")
            if not schema_name:
                print("DEBUG: load_events_for_home - No schema name found")
                return []

            # Get the events and events_registration tables
            events_table = self.get_events_table(schema_name)
            if events_table is None:
                print("DEBUG: load_events_for_home - Events table not found")
                return []

            # Get registration table
            metadata = MetaData(schema=schema_name)
            schema_engine = get_schema_engine(schema_name)
            if not schema_engine:
                print("DEBUG: load_events_for_home - No schema engine found")
                return []
            
            print("DEBUG: load_events_for_home - Reflecting events_registration table")
            metadata.reflect(bind=schema_engine, only=['events_registration'])
            registration_table = metadata.tables[f'{schema_name}.events_registration']

            events_with_status = []
            now = datetime.now()
            print(f"DEBUG: load_events_for_home - Current time: {now}")
            
            schema_engine = get_schema_engine(schema_name)
            if not schema_engine:
                return []
            with schema_engine.connect() as conn:
                print("DEBUG: load_events_for_home - Executing query...")
                # Query database according to requirements:
                # 1. All events that date_time is newer than now and recurring is 'none'
                # 2. All events that recurring_end_date is newer than now and recurring is not 'none'
                try:
                    results = conn.execute(
                        text(f"""
                            SELECT
                                e.id,
                                e.name,
                                e.type,
                                e.description,
                                e.date_time,
                                e.location,
                                e.max_participants,
                                e.current_participants,
                                e.image_url,
                                e.duration,
                                e.status,
                                e.recurring,
                                e.recurring_end_date,
                                e.recurring_pattern,
                                e.instructor_name,
                                e.instructor_desc,
                                e.instructor_photo,
                                CASE
                                    WHEN er.status = 'registered' THEN 1
                                    ELSE 0
                                END as is_registered
                            FROM {schema_name}.events e
                            LEFT JOIN {schema_name}.events_registration er
                                ON e.id = er.event_id
                                AND er.user_id = :user_id
                                AND er.status = 'registered'
                            WHERE e.status = 'approved'
                                AND (
                                    (e.recurring = 'none' AND e.date_time > :now)
                                    OR
                                    (e.recurring != 'none' AND e.recurring_end_date > :now)
                                )
                        """),
                        {"user_id": user_id, "now": now}
                    ).fetchall()
                    print(f"DEBUG: load_events_for_home - Query executed successfully, got {len(results)} results")
                except Exception as query_error:
                    print(f"DEBUG: load_events_for_home - Query execution failed: {str(query_error)}")
                    raise
                
                for result in results:
                    print(f"DEBUG: load_events_for_home - Processing event: {result.id} - {result.name}")
                    
                    # Use the existing _create_event_from_result function to get proper Event object
                    event_obj = self._create_event_from_result(result)
                    
                    # For recurring events, make sure the next iteration hasn't passed the recurring end time
                    if result.recurring and result.recurring != 'none':
                        if result.recurring_pattern and result.recurring_end_date:
                            # Additional filtering: make sure the next iteration hasn't passed the recurring end time
                            if event_obj.next_date_time > result.recurring_end_date:
                                continue  # Skip this event - no more valid occurrences
                            
                            # Also check if next occurrence is in the future
                            if event_obj.next_date_time <= now:
                                continue  # Skip this event - next occurrence has already passed
                        else:
                            # Recurring event without proper pattern - skip
                            continue
                    else:
                        # For one-time events, make sure the date is newer than now
                        if event_obj.next_date_time <= now:
                            continue
                    
                    # Convert Event object to dict and append is_registered field
                    event_dict = event_obj.model_dump()
                    # Convert datetime objects to ISO strings
                    event_dict['date_time'] = event_obj.date_time.isoformat() if event_obj.date_time else None
                    event_dict['next_date_time'] = event_obj.next_date_time.isoformat() if event_obj.next_date_time else None
                    event_dict['recurring_end_date'] = event_obj.recurring_end_date.isoformat() if event_obj.recurring_end_date else None
                    # Add the registration status
                    event_dict['is_registered'] = bool(result.is_registered)
                    events_with_status.append(event_dict)
            
            # Sort by next_date_time (the calculated next occurrence that the mobile app uses)
            events_with_status.sort(key=lambda x: x['next_date_time'] if x['next_date_time'] else '9999-12-31T23:59:59')
            
            print(f"DEBUG: load_events_for_home - Returning {len(events_with_status)} events")
            # Debug: Print first event to see structure
            if events_with_status:
                print(f"DEBUG: load_events_for_home - First event structure: {events_with_status[0]}")
            return events_with_status

        except Exception as e:
            print(f"ERROR: load_events_for_home - Exception for home {home_id}, user {user_id}: {e}")
            import traceback
            traceback.print_exc()
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
