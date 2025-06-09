from pydantic import BaseModel
from datetime import datetime
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