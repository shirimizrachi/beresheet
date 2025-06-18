"""
Events Registration management using SQLAlchemy
Handles all event registration-related database operations
"""

import uuid
from datetime import datetime
from typing import Optional, List, Dict, Any
from sqlalchemy import create_engine, Table, MetaData, Column, String, Integer, DateTime, text
from sqlalchemy.orm import sessionmaker
from sqlalchemy.exc import SQLAlchemyError
from home_mapping import get_connection_string, get_schema_for_home

class EventRegistration:
    def __init__(self, id: str, event_id: str, user_id: str, user_name: str = None,
                 user_phone: str = None, registration_date: datetime = None,
                 status: str = "registered", vote: int = None, reviews: str = None,
                 instructor_name: str = None, instructor_desc: str = None,
                 instructor_photo: str = None):
        self.id = id
        self.event_id = event_id
        self.user_id = user_id
        self.user_name = user_name
        self.user_phone = user_phone
        self.registration_date = registration_date or datetime.now()
        self.status = status
        self.vote = vote
        self.reviews = reviews
        self.instructor_name = instructor_name
        self.instructor_desc = instructor_desc
        self.instructor_photo = instructor_photo

    def to_dict(self) -> Dict[str, Any]:
        return {
            'id': self.id,
            'event_id': self.event_id,
            'user_id': self.user_id,
            'user_name': self.user_name,
            'user_phone': self.user_phone,
            'registration_date': self.registration_date.isoformat() if self.registration_date else None,
            'status': self.status,
            'vote': self.vote,
            'reviews': self.reviews,
            'instructor_name': self.instructor_name,
            'instructor_desc': self.instructor_desc,
            'instructor_photo': self.instructor_photo
        }

class EventRegistrationDatabase:
    def __init__(self):
        self.connection_string = get_connection_string()
        self.engine = create_engine(self.connection_string)
        self.SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=self.engine)
        self.metadata = MetaData()

    def get_events_registration_table(self, schema_name: str):
        """Get the events_registration table for a specific schema"""
        try:
            # Reflect the events_registration table from the specified schema
            metadata = MetaData(schema=schema_name)
            metadata.reflect(bind=self.engine, only=['events_registration'])
            return metadata.tables[f'{schema_name}.events_registration']
        except Exception as e:
            print(f"Error reflecting events_registration table for schema {schema_name}: {e}")
            return None

    def get_events_table(self, schema_name: str):
        """Get the events table for a specific schema"""
        try:
            # Reflect the events table from the specified schema
            metadata = MetaData(schema=schema_name)
            metadata.reflect(bind=self.engine, only=['events'])
            return metadata.tables[f'{schema_name}.events']
        except Exception as e:
            print(f"Error reflecting events table for schema {schema_name}: {e}")
            return None

    def register_for_event(self, event_id: str, user_id: str, user_name: str = None,
                          user_phone: str = None, home_id: int = None) -> bool:
        """Register a user for an event"""
        try:
            # Get schema for home
            schema_name = get_schema_for_home(home_id)
            if not schema_name:
                return False

            # Get the registration and events tables
            registration_table = self.get_events_registration_table(schema_name)
            events_table = self.get_events_table(schema_name)
            if registration_table is None or events_table is None:
                return False

            with self.engine.connect() as conn:
                # Check if already registered with 'registered' status
                existing_registration = conn.execute(
                    registration_table.select().where(
                        (registration_table.c.event_id == event_id) &
                        (registration_table.c.user_id == user_id) &
                        (registration_table.c.status == 'registered')
                    )
                ).fetchone()
                
                if existing_registration:
                    return False  # Already registered with 'registered' status
                
                # Check if there's a cancelled registration that we can reactivate
                cancelled_registration = conn.execute(
                    registration_table.select().where(
                        (registration_table.c.event_id == event_id) &
                        (registration_table.c.user_id == user_id) &
                        (registration_table.c.status == 'cancelled')
                    )
                ).fetchone()
                
                # Get current event data
                event_result = conn.execute(
                    events_table.select().where(events_table.c.id == event_id)
                ).fetchone()
                
                if not event_result:
                    return False  # Event not found
                
                # Check if event is full
                current_registrations = conn.execute(
                    text(f"""
                        SELECT COUNT(*) as count
                        FROM [{schema_name}].[events_registration]
                        WHERE event_id = :event_id AND status = 'registered'
                    """),
                    {"event_id": event_id}
                ).fetchone()
                
                if current_registrations.count >= event_result.maxParticipants:
                    return False  # Event is full
                
                current_time = datetime.now()
                
                if cancelled_registration:
                    # Reactivate cancelled registration
                    print(f"Reactivating cancelled registration for user {user_id} and event {event_id}")
                    conn.execute(
                        registration_table.update()
                        .where(
                            (registration_table.c.event_id == event_id) &
                            (registration_table.c.user_id == user_id) &
                            (registration_table.c.status == 'cancelled')
                        )
                        .values(
                            status='registered',
                            registration_date=current_time,
                            updated_at=current_time,
                            user_name=user_name or cancelled_registration.user_name or 'Unknown User',
                            user_phone=user_phone or cancelled_registration.user_phone or ''
                        )
                    )
                    print(f"Registration reactivated successfully for user {user_id} and event {event_id}")
                else:
                    # Create new registration record
                    registration_id = str(uuid.uuid4())
                    registration_data = {
                        'id': registration_id,
                        'event_id': event_id,
                        'user_id': user_id,
                        'user_name': user_name or 'Unknown User',
                        'user_phone': user_phone or '',
                        'registration_date': current_time,
                        'status': 'registered',
                        'vote': None,  # Can be updated later if needed
                        'reviews': None,  # Can be updated later if needed
                        'instructor_name': getattr(event_result, 'instructor_name', None),
                        'instructor_desc': getattr(event_result, 'instructor_desc', None),
                        'instructor_photo': getattr(event_result, 'instructor_photo', None),
                        'created_at': current_time,
                        'updated_at': current_time
                    }
                    
                    print(f"Creating new registration record: {registration_data}")
                    conn.execute(registration_table.insert().values(**registration_data))
                    print(f"Registration record created successfully for user {user_id} and event {event_id}")
                
                # Update event participant count
                new_count = current_registrations.count + 1
                print(f"Updating event {event_id} participant count from {current_registrations.count} to {new_count}")
                conn.execute(
                    events_table.update()
                    .where(events_table.c.id == event_id)
                    .values(currentParticipants=new_count)
                )
                
                conn.commit()
                print(f"Event {event_id} participant count updated successfully to {new_count}")
                return True

        except Exception as e:
            print(f"Error registering for event {event_id}: {e}")
            return False

    def unregister_from_event(self, event_id: str, user_id: str, home_id: int = None) -> bool:
        """Unregister a user from an event"""
        try:
            # Get schema for home
            schema_name = get_schema_for_home(home_id)
            if not schema_name:
                return False

            # Get the registration and events tables
            registration_table = self.get_events_registration_table(schema_name)
            events_table = self.get_events_table(schema_name)
            if registration_table is None or events_table is None:
                return False

            with self.engine.connect() as conn:
                # Check if user is registered
                existing_registration = conn.execute(
                    registration_table.select().where(
                        (registration_table.c.event_id == event_id) &
                        (registration_table.c.user_id == user_id) &
                        (registration_table.c.status == 'registered')
                    )
                ).fetchone()
                
                if not existing_registration:
                    return False  # Not registered
                
                # Update registration status to cancelled
                conn.execute(
                    registration_table.update()
                    .where(
                        (registration_table.c.event_id == event_id) &
                        (registration_table.c.user_id == user_id)
                    )
                    .values(status='cancelled', updated_at=datetime.now())
                )
                
                # Update event participant count
                current_registrations = conn.execute(
                    text(f"""
                        SELECT COUNT(*) as count 
                        FROM [{schema_name}].[events_registration] 
                        WHERE event_id = :event_id AND status = 'registered'
                    """),
                    {"event_id": event_id}
                ).fetchone()
                
                conn.execute(
                    events_table.update()
                    .where(events_table.c.id == event_id)
                    .values(currentParticipants=current_registrations.count)
                )
                
                conn.commit()
                return True

        except Exception as e:
            print(f"Error unregistering from event {event_id}: {e}")
            return False

    def is_user_registered(self, event_id: str, user_id: str, home_id: int = None) -> bool:
        """Check if a user is registered for an event"""
        try:
            # Get schema for home
            schema_name = get_schema_for_home(home_id)
            if not schema_name:
                return False

            # Get the registration table
            registration_table = self.get_events_registration_table(schema_name)
            if registration_table is None:
                return False

            with self.engine.connect() as conn:
                result = conn.execute(
                    registration_table.select().where(
                        (registration_table.c.event_id == event_id) &
                        (registration_table.c.user_id == user_id) &
                        (registration_table.c.status == 'registered')
                    )
                ).fetchone()
                
                return result is not None

        except Exception as e:
            print(f"Error checking registration status for event {event_id}: {e}")
            return False

    def get_user_registrations(self, user_id: str, home_id: int = None) -> List[EventRegistration]:
        """Get all registrations for a user"""
        try:
            # Get schema for home
            schema_name = get_schema_for_home(home_id)
            if not schema_name:
                return []

            # Get the registration table
            registration_table = self.get_events_registration_table(schema_name)
            if registration_table is None:
                return []

            registrations = []
            with self.engine.connect() as conn:
                results = conn.execute(
                    registration_table.select()
                    .where(
                        (registration_table.c.user_id == user_id) &
                        (registration_table.c.status == 'registered')
                    )
                    .order_by(registration_table.c.registration_date.desc())
                ).fetchall()
                
                for result in results:
                    registrations.append(EventRegistration(
                        id=result.id,
                        event_id=result.event_id,
                        user_id=result.user_id,
                        user_name=result.user_name,
                        user_phone=result.user_phone,
                        registration_date=result.registration_date,
                        status=result.status,
                        vote=getattr(result, 'vote', None),
                        reviews=getattr(result, 'reviews', None),
                        instructor_name=getattr(result, 'instructor_name', None),
                        instructor_desc=getattr(result, 'instructor_desc', None),
                        instructor_photo=getattr(result, 'instructor_photo', None)
                    ))
            
            return registrations

        except Exception as e:
            print(f"Error getting user registrations for user {user_id}: {e}")
            return []

    def get_event_registrations(self, event_id: str, home_id: int = None) -> List[EventRegistration]:
        """Get all registrations for an event"""
        try:
            # Get schema for home
            schema_name = get_schema_for_home(home_id)
            if not schema_name:
                return []

            # Get the registration table
            registration_table = self.get_events_registration_table(schema_name)
            if registration_table is None:
                return []

            registrations = []
            with self.engine.connect() as conn:
                results = conn.execute(
                    registration_table.select()
                    .where(
                        (registration_table.c.event_id == event_id) &
                        (registration_table.c.status == 'registered')
                    )
                    .order_by(registration_table.c.registration_date)
                ).fetchall()
                
                for result in results:
                    registrations.append(EventRegistration(
                        id=result.id,
                        event_id=result.event_id,
                        user_id=result.user_id,
                        user_name=result.user_name,
                        user_phone=result.user_phone,
                        registration_date=result.registration_date,
                        status=result.status,
                        vote=getattr(result, 'vote', None),
                        reviews=getattr(result, 'reviews', None),
                        instructor_name=getattr(result, 'instructor_name', None),
                        instructor_desc=getattr(result, 'instructor_desc', None),
                        instructor_photo=getattr(result, 'instructor_photo', None)
                    ))
            
            return registrations

        except Exception as e:
            print(f"Error getting event registrations for event {event_id}: {e}")
            return []

    def get_all_registrations(self, home_id: int = None) -> List[EventRegistration]:
        """Get all registrations (for management purposes)"""
        try:
            # Get schema for home
            schema_name = get_schema_for_home(home_id)
            if not schema_name:
                return []

            # Get the registration table
            registration_table = self.get_events_registration_table(schema_name)
            if registration_table is None:
                return []

            registrations = []
            with self.engine.connect() as conn:
                results = conn.execute(
                    registration_table.select()
                    .where(registration_table.c.status == 'registered')
                    .order_by(registration_table.c.registration_date.desc())
                ).fetchall()
                
                for result in results:
                    registrations.append(EventRegistration(
                        id=result.id,
                        event_id=result.event_id,
                        user_id=result.user_id,
                        user_name=result.user_name,
                        user_phone=result.user_phone,
                        registration_date=result.registration_date,
                        status=result.status,
                        vote=getattr(result, 'vote', None),
                        reviews=getattr(result, 'reviews', None),
                        instructor_name=getattr(result, 'instructor_name', None),
                        instructor_desc=getattr(result, 'instructor_desc', None),
                        instructor_photo=getattr(result, 'instructor_photo', None)
                    ))
            
            return registrations

        except Exception as e:
            print(f"Error getting all registrations: {e}")
            return []

    def update_vote_and_review(self, event_id: str, user_id: str, vote: int = None,
                              review_text: str = None, home_id: int = None) -> bool:
        """Update vote and/or add review for an event registration"""
        try:
            import json
            from datetime import datetime
            
            # Get schema for home
            schema_name = get_schema_for_home(home_id)
            if not schema_name:
                return False

            # Get the registration table
            registration_table = self.get_events_registration_table(schema_name)
            if registration_table is None:
                return False

            with self.engine.connect() as conn:
                # Find the registration
                registration = conn.execute(
                    registration_table.select().where(
                        (registration_table.c.event_id == event_id) &
                        (registration_table.c.user_id == user_id) &
                        (registration_table.c.status == 'registered')
                    )
                ).fetchone()
                
                if not registration:
                    return False  # Registration not found
                
                # Prepare update data
                update_data = {'updated_at': datetime.now()}
                
                # Update vote if provided
                if vote is not None:
                    if 1 <= vote <= 5:
                        update_data['vote'] = vote
                    else:
                        return False  # Invalid vote value
                
                # Update reviews if review_text is provided
                if review_text is not None and review_text.strip():
                    try:
                        # Parse existing reviews or create new list
                        existing_reviews = []
                        if registration.reviews:
                            existing_reviews = json.loads(registration.reviews)
                        
                        # Add new review
                        new_review = {
                            'date': datetime.now().isoformat(),
                            'review': review_text.strip()
                        }
                        existing_reviews.append(new_review)
                        
                        # Store as JSON string
                        update_data['reviews'] = json.dumps(existing_reviews)
                    except (json.JSONDecodeError, Exception) as e:
                        print(f"Error processing reviews: {e}")
                        # If existing reviews are corrupted, start fresh
                        new_review = {
                            'date': datetime.now().isoformat(),
                            'review': review_text.strip()
                        }
                        update_data['reviews'] = json.dumps([new_review])
                
                # Perform the update
                conn.execute(
                    registration_table.update()
                    .where(
                        (registration_table.c.event_id == event_id) &
                        (registration_table.c.user_id == user_id)
                    )
                    .values(**update_data)
                )
                
                conn.commit()
                return True

        except Exception as e:
            print(f"Error updating vote and review for event {event_id}: {e}")
            return False

    def get_vote_and_reviews(self, event_id: str, user_id: str, home_id: int = None) -> Dict[str, Any]:
        """Get vote and reviews for a specific event registration"""
        try:
            import json
            
            # Get schema for home
            schema_name = get_schema_for_home(home_id)
            if not schema_name:
                return {}

            # Get the registration table
            registration_table = self.get_events_registration_table(schema_name)
            if registration_table is None:
                return {}

            with self.engine.connect() as conn:
                registration = conn.execute(
                    registration_table.select().where(
                        (registration_table.c.event_id == event_id) &
                        (registration_table.c.user_id == user_id) &
                        (registration_table.c.status == 'registered')
                    )
                ).fetchone()
                
                if not registration:
                    return {}
                
                # Parse reviews
                reviews = []
                if registration.reviews:
                    try:
                        reviews = json.loads(registration.reviews)
                    except json.JSONDecodeError:
                        reviews = []
                
                return {
                    'registration_id': registration.id,
                    'event_id': event_id,
                    'user_id': user_id,
                    'vote': registration.vote,
                    'reviews': reviews
                }

        except Exception as e:
            print(f"Error getting vote and reviews for event {event_id}: {e}")
            return {}

# Create global instance
events_registration_db = EventRegistrationDatabase()