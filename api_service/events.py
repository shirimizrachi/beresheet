"""
Event management using SQLAlchemy
Handles all event-related database operations
"""

import uuid
from datetime import datetime
from typing import Optional, List
from sqlalchemy import create_engine, Table, MetaData, Column, String, Integer, DateTime, Boolean, text
from sqlalchemy.orm import sessionmaker
from sqlalchemy.exc import SQLAlchemyError
from models import Event, EventCreate, EventUpdate
from home_mapping import get_connection_string, get_schema_for_home
from database_utils import get_schema_engine, get_engine_for_home

class EventDatabase:
    def __init__(self):
        self.connection_string = get_connection_string()
        self.engine = create_engine(self.connection_string)
        self.SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=self.engine)
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
            schema_name = get_schema_for_home(home_id)
            if not schema_name:
                return []

            # Get the events table
            events_table = self.get_events_table(schema_name)
            if events_table is None:
                return []

            events = []
            with self.engine.connect() as conn:
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
                        image_url=result.image_url,
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
            schema_name = get_schema_for_home(home_id)
            if not schema_name:
                return []

            events_table = self.get_events_table(schema_name)
            if events_table is None:
                return []

            events = []
            with self.engine.connect() as conn:
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
                        image_url=result.image_url,
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
            schema_name = get_schema_for_home(home_id)
            if not schema_name:
                return []

            events_table = self.get_events_table(schema_name)
            if events_table is None:
                return []

            events = []
            with self.engine.connect() as conn:
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
                        image_url=result.image_url,
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
            schema_name = get_schema_for_home(home_id)
            if not schema_name:
                return None

            # Get the events table
            events_table = self.get_events_table(schema_name)
            if events_table is None:
                return None

            # Query event
            with self.engine.connect() as conn:
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
                        image_url=result.image_url,
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
            schema_name = get_schema_for_home(home_id)
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
            with self.engine.connect() as conn:
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
                image_url=getattr(event_data, 'image_url', None),
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
            schema_name = get_schema_for_home(home_id)
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
            with self.engine.connect() as conn:
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
                            image_url=updated_result.image_url,
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
            schema_name = get_schema_for_home(home_id)
            if not schema_name:
                return False

            # Get the events table
            events_table = self.get_events_table(schema_name)
            if events_table is None:
                return False

            # Delete event
            with self.engine.connect() as conn:
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
            schema_name = get_schema_for_home(home_id)
            if not schema_name:
                return []

            # Get the events table
            events_table = self.get_events_table(schema_name)
            if events_table is None:
                return []

            events = []
            with self.engine.connect() as conn:
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
                        image_url=result.image_url,
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
            schema_name = get_schema_for_home(home_id)
            if not schema_name:
                return []

            # Get the events table
            events_table = self.get_events_table(schema_name)
            if events_table is None:
                return []

            events = []
            with self.engine.connect() as conn:
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
                        image_url=result.image_url,
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
            schema_name = get_schema_for_home(home_id)
            if not schema_name:
                return False

            # Get the events table
            events_table = self.get_events_table(schema_name)
            if events_table is None:
                return False

            with self.engine.connect() as conn:
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
            schema_name = get_schema_for_home(home_id)
            if not schema_name:
                return False

            # Get the events table
            events_table = self.get_events_table(schema_name)
            if events_table is None:
                return False

            with self.engine.connect() as conn:
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

# Create global instance
event_db = EventDatabase()