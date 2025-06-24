"""
Service Request models for communication between residents and service providers
"""

from pydantic import BaseModel
from datetime import datetime
from typing import Optional

# Request Models for communication between residents and service providers
class ServiceRequestBase(BaseModel):
    resident_id: str
    service_provider_id: str
    request_message: str
    request_status: str = "open"  # "open", "in_progress", "closed", "abandoned"

class ServiceRequestCreate(BaseModel):
    service_provider_id: str
    request_message: str

class ServiceRequestUpdate(BaseModel):
    request_message: Optional[str] = None
    request_status: Optional[str] = None
    service_rating: Optional[int] = None  # 1-5 rating
    service_comment: Optional[str] = None
    chat_messages: Optional[str] = None  # JSON string

class ServiceRequest(BaseModel):
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
    service_provider_photo: Optional[str] = None
    service_provider_type_name: Optional[str] = None
    service_provider_type_description: Optional[str] = None
    
    # Request details
    request_message: str
    request_status: str
    
    # Timestamps
    request_created_at: datetime
    request_modified_at: Optional[datetime] = None
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