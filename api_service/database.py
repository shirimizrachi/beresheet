import json
import os
from typing import List, Optional
from models import Event, EventCreate, EventUpdate
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

# Global database instance
db = EventDatabase()