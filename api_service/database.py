import json
import os
from typing import List, Optional
from models import Event, EventCreate, EventUpdate, UserProfile, UserProfileCreate, UserProfileUpdate
from datetime import datetime
import uuid

class EventDatabase:
    def __init__(self, data_file: str = "events_data.json"):
        self.data_file = data_file
        self.events = []
        self.load_initial_data()
    
    def load_initial_data(self):
        """Load initial data from the original events.json file"""
        try:
            # Try to load from existing data file first
            if os.path.exists(self.data_file):
                with open(self.data_file, 'r', encoding='utf-8') as f:
                    data = json.load(f)
                    self.events = [Event(**event) for event in data]
            else:
                # Load from the events.json file in the data folder
                original_file = "data/events.json"
                if os.path.exists(original_file):
                    with open(original_file, 'r', encoding='utf-8') as f:
                        data = json.load(f)
                        self.events = [Event(**event) for event in data]
                        self.save_data()
                else:
                    # Create empty events list if no data file exists
                    self.events = []
                    self.save_data()
        except Exception as e:
            print(f"Error loading initial data: {e}")
            self.events = []
    
    def save_data(self):
        """Save events to JSON file"""
        try:
            data = [event.model_dump() for event in self.events]
            with open(self.data_file, 'w', encoding='utf-8') as f:
                json.dump(data, f, indent=2, default=str)
        except Exception as e:
            print(f"Error saving data: {e}")
    
    def get_all_events(self) -> List[Event]:
        """Get all events"""
        return self.events
    
    def get_event_by_id(self, event_id: str) -> Optional[Event]:
        """Get event by ID"""
        for event in self.events:
            if event.id == event_id:
                return event
        return None
    
    def create_event(self, event_data: EventCreate) -> Event:
        """Create a new event"""
        event_id = str(uuid.uuid4())
        new_event = Event(
            id=event_id,
            **event_data.model_dump()
        )
        self.events.append(new_event)
        self.save_data()
        return new_event
    
    def update_event(self, event_id: str, event_data: EventUpdate) -> Optional[Event]:
        """Update an existing event"""
        for i, event in enumerate(self.events):
            if event.id == event_id:
                update_data = event_data.model_dump(exclude_unset=True)
                updated_event = event.model_copy(update=update_data)
                self.events[i] = updated_event
                self.save_data()
                return updated_event
        return None
    
    def delete_event(self, event_id: str) -> bool:
        """Delete an event"""
        for i, event in enumerate(self.events):
            if event.id == event_id:
                del self.events[i]
                self.save_data()
                return True
        return False
    
    def get_events_by_type(self, event_type: str) -> List[Event]:
        """Get events by type"""
        return [event for event in self.events if event.type.lower() == event_type.lower()]
    
    def get_upcoming_events(self) -> List[Event]:
        """Get upcoming events (events in the future)"""
        now = datetime.now()
        return [event for event in self.events if event.dateTime > now]
    
    def register_for_event(self, event_id: str, user_id: Optional[str] = None) -> bool:
        """Register for an event (increase current participants)"""
        event = self.get_event_by_id(event_id)
        if event and event.currentParticipants < event.maxParticipants:
            for i, e in enumerate(self.events):
                if e.id == event_id:
                    self.events[i] = e.model_copy(update={
                        "currentParticipants": e.currentParticipants + 1,
                        "isRegistered": True
                    })
                    self.save_data()
                    return True
        return False
    
    def unregister_from_event(self, event_id: str, user_id: Optional[str] = None) -> bool:
        """Unregister from an event (decrease current participants)"""
        event = self.get_event_by_id(event_id)
        if event and event.currentParticipants > 0:
            for i, e in enumerate(self.events):
                if e.id == event_id:
                    self.events[i] = e.model_copy(update={
                        "currentParticipants": max(0, e.currentParticipants - 1),
                        "isRegistered": False
                    })
                    self.save_data()
                    return True
        return False

class UserDatabase:
    def __init__(self, data_dir: str = "data/users"):
        self.data_dir = data_dir
        self.photos_dir = os.path.join(data_dir, "photos")
        # Ensure directories exist
        os.makedirs(self.data_dir, exist_ok=True)
        os.makedirs(self.photos_dir, exist_ok=True)
    
    def _get_user_file_path(self, unique_id: str) -> str:
        """Get the file path for a user's JSON data"""
        return os.path.join(self.data_dir, f"{unique_id}.json")
    
    def _get_photo_file_path(self, unique_id: str) -> str:
        """Get the file path for a user's photo"""
        return os.path.join(self.photos_dir, f"{unique_id}.jpeg")
    
    def get_user_profile(self, unique_id: str) -> Optional[UserProfile]:
        """Get user profile by unique ID"""
        try:
            file_path = self._get_user_file_path(unique_id)
            if os.path.exists(file_path):
                with open(file_path, 'r', encoding='utf-8') as f:
                    data = json.load(f)
                    return UserProfile(**data)
            return None
        except Exception as e:
            print(f"Error loading user profile {unique_id}: {e}")
            return None
    
    def create_user_profile(self, unique_id: str, user_data: UserProfileCreate) -> UserProfile:
        """Create a new user profile with minimal required data"""
        try:
            current_time = datetime.now().isoformat()
            # Generate unique user_id
            user_id = str(uuid.uuid4())
            
            # Create user profile with minimal data and defaults
            new_user = UserProfile(
                unique_id=unique_id,
                created_at=current_time,
                updated_at=current_time,
                user_id=user_id,
                resident_id=user_data.resident_id,
                phone_number=user_data.phone_number,
                # Default values for required fields
                full_name="",  # To be updated later
                role="resident",  # Default role
                birthday=datetime.now().date(),  # Default to today, to be updated
                apartment_number="",  # To be updated later
                marital_status="single",  # Default
                gender="",  # To be updated later
                religious="",  # To be updated later
                native_language="hebrew",  # Default
                photo=None
            )
            
            file_path = self._get_user_file_path(unique_id)
            with open(file_path, 'w', encoding='utf-8') as f:
                json.dump(new_user.model_dump(), f, indent=2, default=str)
            
            return new_user
        except Exception as e:
            print(f"Error creating user profile {unique_id}: {e}")
            raise
    
    def update_user_profile(self, unique_id: str, user_data: UserProfileUpdate) -> Optional[UserProfile]:
        """Update an existing user profile"""
        try:
            existing_user = self.get_user_profile(unique_id)
            if not existing_user:
                return None
            
            update_data = user_data.model_dump(exclude_unset=True)
            update_data['updated_at'] = datetime.now().isoformat()
            
            updated_user = existing_user.model_copy(update=update_data)
            
            file_path = self._get_user_file_path(unique_id)
            with open(file_path, 'w', encoding='utf-8') as f:
                json.dump(updated_user.model_dump(), f, indent=2, default=str)
            
            return updated_user
        except Exception as e:
            print(f"Error updating user profile {unique_id}: {e}")
            return None
    
    def delete_user_profile(self, unique_id: str) -> bool:
        """Delete a user profile and associated photo"""
        try:
            file_path = self._get_user_file_path(unique_id)
            photo_path = self._get_photo_file_path(unique_id)
            
            # Delete user data file
            if os.path.exists(file_path):
                os.remove(file_path)
            
            # Delete photo file if it exists
            if os.path.exists(photo_path):
                os.remove(photo_path)
            
            return True
        except Exception as e:
            print(f"Error deleting user profile {unique_id}: {e}")
            return False
    
    def get_all_users(self) -> List[UserProfile]:
        """Get all user profiles"""
        try:
            users = []
            if os.path.exists(self.data_dir):
                for filename in os.listdir(self.data_dir):
                    if filename.endswith('.json'):
                        unique_id = filename[:-5]  # Remove .json extension
                        user = self.get_user_profile(unique_id)
                        if user:
                            users.append(user)
            return users
        except Exception as e:
            print(f"Error loading all user profiles: {e}")
            return []
    
    def save_user_photo(self, unique_id: str, photo_data: bytes) -> str:
        """Save user photo and return the file path"""
        try:
            photo_path = self._get_photo_file_path(unique_id)
            with open(photo_path, 'wb') as f:
                f.write(photo_data)
            return photo_path
        except Exception as e:
            print(f"Error saving photo for user {unique_id}: {e}")
            raise
    
    def get_user_photo_path(self, unique_id: str) -> Optional[str]:
        """Get the photo file path if it exists"""
        photo_path = self._get_photo_file_path(unique_id)
        return photo_path if os.path.exists(photo_path) else None

# Global database instances
db = EventDatabase()
user_db = UserDatabase()