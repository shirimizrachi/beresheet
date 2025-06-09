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
    isRegistered: bool = False

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
    isRegistered: Optional[bool] = None

class Event(EventBase):
    id: str

    class Config:
        from_attributes = True

class EventRegistration(BaseModel):
    event_id: str
    user_id: Optional[str] = None

# User Profile Models
class UserProfileBase(BaseModel):
    full_name: str
    phone_number: str
    role: str  # "resident", "staff", "instructor", "service", "caregiver"
    birthday: date
    apartment_number: str
    marital_status: str
    gender: str
    religious: str
    native_language: str
    photo: Optional[str] = None

class UserProfileCreate(UserProfileBase):
    pass

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
    photo: Optional[str] = None

class UserProfile(UserProfileBase):
    unique_id: str
    created_at: str
    updated_at: str

    class Config:
        from_attributes = True