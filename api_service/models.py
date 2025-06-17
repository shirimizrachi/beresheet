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
    dateTime: datetime  # Initial occurrence date for recurring events
    location: str
    maxParticipants: int
    image_url: Optional[str] = ""  # Allow None and default to empty string
    currentParticipants: int = 0
    status: str = "pending-approval"  # "pending-approval", "approved", "rejected", "cancelled"
    recurring: str = "none"  # "none", "weekly", "bi-weekly", "monthly"
    recurring_end_date: Optional[datetime] = None
    recurring_pattern: Optional[str] = None  # JSON string with RecurrencePatternData

class EventCreate(EventBase):
    pass

class EventUpdate(BaseModel):
    name: Optional[str] = None
    type: Optional[str] = None
    description: Optional[str] = None
    dateTime: Optional[datetime] = None
    location: Optional[str] = None
    maxParticipants: Optional[int] = None
    image_url: Optional[str] = None
    currentParticipants: Optional[int] = None
    status: Optional[str] = None
    recurring: Optional[str] = None
    recurring_end_date: Optional[datetime] = None
    recurring_pattern: Optional[str] = None

class Event(EventBase):
    id: str

    class Config:
        from_attributes = True

class EventWithRegistrationStatus(BaseModel):
    """Event model with registration status for homepage"""
    id: str
    name: str
    type: str
    description: str
    dateTime: str  # ISO string
    location: str
    maxParticipants: int
    currentParticipants: int
    image_url: str
    status: str
    recurring: str
    recurring_end_date: Optional[str] = None  # ISO string
    recurring_pattern: Optional[str] = None
    is_registered: bool

    class Config:
        from_attributes = True

# Room Models
class Room(BaseModel):
    id: int
    room_name: str

    class Config:
        from_attributes = True


class RoomCreate(BaseModel):
    room_name: str
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
    notes: Optional[str] = None
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True

class EventRegistrationCreate(BaseModel):
    event_id: str
    user_id: str
    user_name: Optional[str] = None
    user_phone: Optional[str] = None
    notes: Optional[str] = None

class EventRegistrationUpdate(BaseModel):
    status: Optional[str] = None
    notes: Optional[str] = None
    user_name: Optional[str] = None
    user_phone: Optional[str] = None

# User Profile Models
class UserProfileBase(BaseModel):
    full_name: str
    phone_number: str
    role: str  # "resident", "staff", "instructor", "service", "caregiver", "manager"
    birthday: date
    apartment_number: str
    marital_status: str
    gender: str
    religious: str
    native_language: str
    home_id: int  # Not displayed in profile page, used for internal operations
    id: str  # Unique user identifier (primary key)
    photo: Optional[str] = None
    service_provider_type: Optional[str] = None
    firebase_fcm_token: Optional[str] = None

class UserProfileCreate(BaseModel):
    home_id: int
    phone_number: str

class UserProfileUpdate(BaseModel):
    full_name: Optional[str] = None
    phone_number: Optional[str] = None
    role: Optional[str] = None
    birthday: Optional[date] = None
    apartment_number: Optional[str] = None
    marital_status: Optional[str] = None
    gender: Optional[str] = None
    religious: Optional[str] = None
    native_language: Optional[str] = None
    home_id: Optional[int] = None
    photo: Optional[str] = None
    service_provider_type: Optional[str] = None
    firebase_fcm_token: Optional[str] = None

class UserProfile(UserProfileBase):
    firebase_id: str
    password: str  # Password field (not exposed in API responses)
    created_at: str
    updated_at: str

    class Config:
        from_attributes = True

# Authentication Models
class LoginRequest(BaseModel):
    phone_number: str
    password: str
    home_id: int

class LoginResponse(BaseModel):
    success: bool
    session_id: Optional[str] = None
    user_id: Optional[str] = None
    home_id: Optional[int] = None
    user_role: Optional[str] = None
    message: str

class SessionInfo(BaseModel):
    session_id: str
    user_id: str
    home_id: int
    user_role: str
    is_active: bool
    expires_at: str

# Service Provider Types Models
class ServiceProviderType(BaseModel):
    id: int
    name: str
    description: Optional[str] = None

    class Config:
        from_attributes = True

class ServiceProviderTypeCreate(BaseModel):
    name: str
    description: Optional[str] = None

class ServiceProviderTypeUpdate(BaseModel):
    description: Optional[str] = None  # Only description can be updated

# Request Models for communication between residents and service providers
class RequestBase(BaseModel):
    resident_id: str
    service_provider_id: str
    request_message: str
    request_status: str = "open"  # "open", "in_progress", "closed", "abandoned"

class RequestCreate(BaseModel):
    service_provider_id: str
    request_message: str

class RequestUpdate(BaseModel):
    request_message: Optional[str] = None
    request_status: Optional[str] = None
    service_rating: Optional[int] = None  # 1-5 rating
    service_comment: Optional[str] = None
    chat_messages: Optional[str] = None  # JSON string

class Request(BaseModel):
    id: str
    
    # Resident information
    resident_id: str
    resident_phone_number: Optional[str] = None
    resident_full_name: Optional[str] = None
    resident_fcm_token: Optional[str] = None
    
    # Service provider information
    service_provider_id: str
    service_provider_full_name: Optional[str] = None
    service_provider_phone_number: Optional[str] = None
    service_provider_fcm_token: Optional[str] = None
    service_provider_type: Optional[str] = None
    
    # Request details
    request_message: str
    request_status: str
    
    # Timestamps
    request_created_at: datetime
    request_read_at: Optional[datetime] = None
    request_closed_by_resident_at: Optional[datetime] = None
    request_closed_by_service_provider_at: Optional[datetime] = None
    
    # Communication and feedback
    chat_messages: Optional[str] = None  # JSON string
    service_rating: Optional[int] = None
    service_comment: Optional[str] = None
    
    # Duration
    request_duration_minutes: Optional[int] = None
    
    # Audit fields
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True

class ChatMessage(BaseModel):
    """Model for individual chat messages within a request"""
    sender_id: str
    sender_type: str  # "resident" or "service_provider"
    message: str
    timestamp: datetime
    message_id: Optional[str] = None

class RequestStatusUpdate(BaseModel):
    """Model for updating request status with optional timestamps"""
    request_status: str
    mark_as_read: Optional[bool] = False
    close_by_resident: Optional[bool] = False
    close_by_service_provider: Optional[bool] = False

# Event Instructor Models
class EventInstructor(BaseModel):
    id: int
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