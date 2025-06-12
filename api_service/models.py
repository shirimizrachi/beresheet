from pydantic import BaseModel
from datetime import datetime, date
from typing import Optional

class EventBase(BaseModel):
    name: str
    type: str  # "class", "performance", "cultural", "leisure"
    description: str
    dateTime: datetime
    location: str
    maxParticipants: int
    image_url: str
    currentParticipants: int = 0
    status: str = "pending-approval"  # "active", "canceled", "suspended", "pending-approval"
    recurring: str = "none"  # "none", "daily", "weekly", "monthly", "yearly", "custom"
    recurring_end_date: Optional[datetime] = None
    recurring_pattern: Optional[str] = None  # JSON string with custom pattern details

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