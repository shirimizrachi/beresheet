"""
Event-related Pydantic models
"""

from pydantic import BaseModel, Field
from datetime import datetime, date
from typing import Optional, Dict, Any
import json

class RecurrencePatternData(BaseModel):
    """Recurrence pattern structure for events"""
    dayOfWeek: Optional[int] = Field(None, description="Day of week (0=Sunday, 1=Monday, ..., 6=Saturday)")
    dayOfMonth: Optional[int] = Field(None, description="Day of month (1-31) for monthly events")
    time: Optional[str] = Field(None, description="Time in HH:MM format (e.g., '14:00')")
    interval: Optional[int] = Field(None, description="Interval for recurring events (e.g., 2 for bi-weekly)")

class EventBase(BaseModel):
    name: str
    type: str  # "event", "sport", "cultural", "art", "english", "religion"
    description: str
    date_time: datetime  # Initial occurrence date for recurring events
    location: str
    max_participants: int
    image_url: Optional[str] = ""  # Allow None and default to empty string
    duration: int = 60  # Duration in minutes, default 60 minutes
    current_participants: int = 0
    status: str = "pending-approval"  # "pending-approval", "approved", "rejected", "cancelled", "done"
    recurring: str = "none"  # "none", "weekly", "bi-weekly", "monthly"
    recurring_end_date: Optional[datetime] = None
    recurring_pattern: Optional[str] = None  # JSON string with RecurrencePatternData
    instructor_name: Optional[str] = None
    instructor_desc: Optional[str] = None
    instructor_photo: Optional[str] = None
    reviews: Optional[Any] = []  # Event reviews for completed events (can be list or dict with average_rating)
    gallery_photos: Optional[list] = []  # Gallery photos for completed events

class EventCreate(EventBase):
    pass

class EventUpdate(BaseModel):
    name: Optional[str] = None
    type: Optional[str] = None
    description: Optional[str] = None
    date_time: Optional[datetime] = None
    location: Optional[str] = None
    max_participants: Optional[int] = None
    image_url: Optional[str] = None
    duration: Optional[int] = None
    current_participants: Optional[int] = None
    status: Optional[str] = None
    recurring: Optional[str] = None
    recurring_end_date: Optional[datetime] = None
    recurring_pattern: Optional[str] = None
    instructor_name: Optional[str] = None
    instructor_desc: Optional[str] = None
    instructor_photo: Optional[str] = None

class Event(EventBase):
    id: str
    next_date_time: datetime  # Calculated next occurrence for recurring events

    class Config:
        from_attributes = True

class EventWithRegistrationStatus(BaseModel):
    """Event model with registration status for homepage"""
    id: str
    name: str
    type: str
    description: str
    date_time: str  # ISO string - original event date
    next_date_time: str  # ISO string - calculated next occurrence
    location: str
    max_participants: int
    current_participants: int
    image_url: str
    duration: int = 60  # Duration in minutes
    status: str
    recurring: str
    recurring_end_date: Optional[str] = None  # ISO string
    recurring_pattern: Optional[str] = None
    instructor_name: Optional[str] = None
    instructor_desc: Optional[str] = None
    instructor_photo: Optional[str] = None
    is_registered: bool

    class Config:
        from_attributes = True

# Event Registration Models
class EventRegistration(BaseModel):
    event_id: str
    user_id: Optional[str] = None

class EventRegistrationRecord(BaseModel):
    id: str
    event_id: str
    user_id: str
    user_name: Optional[str] = None
    user_phone: Optional[str] = None
    registration_date: datetime
    status: str = "registered"  # "registered", "cancelled", "attended"
    vote: Optional[int] = None  # 1-5 star rating
    reviews: Optional[str] = None  # JSON array of review objects
    instructor_name: Optional[str] = None
    instructor_desc: Optional[str] = None
    instructor_photo: Optional[str] = None
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True

class EventRegistrationCreate(BaseModel):
    event_id: str
    user_id: str
    user_name: Optional[str] = None
    user_phone: Optional[str] = None
    reviews: Optional[str] = None

class EventRegistrationUpdate(BaseModel):
    status: Optional[str] = None
    vote: Optional[int] = None
    reviews: Optional[str] = None
    user_name: Optional[str] = None
    user_phone: Optional[str] = None

class EventVoteAndReviewUpdate(BaseModel):
    """Model for updating vote and reviews for an event registration"""
    vote: Optional[int] = Field(None, ge=1, le=5, description="Star rating from 1 to 5")
    review_text: Optional[str] = Field(None, description="Review text to add")

# Event Instructor Models
class EventInstructor(BaseModel):
    id: str
    name: str
    description: Optional[str] = None
    photo: Optional[str] = None

    class Config:
        from_attributes = True

class EventInstructorCreate(BaseModel):
    name: str
    description: Optional[str] = None

class EventInstructorUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    photo: Optional[str] = None

# Event Gallery Models
class EventGalleryBase(BaseModel):
    event_id: str
    photo: str
    thumbnail_url: Optional[str] = None
    status: str = "private"  # "private" or "public"

class EventGalleryCreate(EventGalleryBase):
    pass

class EventGalleryUpdate(BaseModel):
    photo: Optional[str] = None
    thumbnail_url: Optional[str] = None
    status: Optional[str] = None

class EventGallery(EventGalleryBase):
    photo_id: str
    created_at: datetime
    updated_at: datetime
    created_by: Optional[str] = None

    class Config:
        from_attributes = True

class EventGalleryUpload(BaseModel):
    """Model for uploading multiple images to event gallery"""
    event_id: str
