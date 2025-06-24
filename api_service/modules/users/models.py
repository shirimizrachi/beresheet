"""
User-related Pydantic models
"""

from pydantic import BaseModel, Field
from datetime import datetime, date
from typing import Optional, Dict, Any

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
    service_provider_type_id: Optional[str] = None
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
    service_provider_type_id: Optional[str] = None
    service_provider_type_name: Optional[str] = None
    service_provider_type_description: Optional[str] = None
    firebase_fcm_token: Optional[str] = None

class UserProfile(UserProfileBase):
    firebase_id: str
    password: str  # Password field (not exposed in API responses)
    created_at: str
    updated_at: str

    class Config:
        from_attributes = True

class ServiceProviderProfile(UserProfileBase):
    """Extended user profile for service providers in service request screens"""
    service_provider_type_name: Optional[str] = None
    service_provider_type_description: Optional[str] = None
    request_count: Optional[int] = None

    class Config:
        from_attributes = True

# Authentication Models
class LoginRequest(BaseModel):
    phone_number: str
    password: str
    home_id: int

# Service Provider Types Models
class ServiceProviderType(BaseModel):
    id: str
    name: str
    description: Optional[str] = None

    class Config:
        from_attributes = True

class ServiceProviderTypeCreate(BaseModel):
    name: str
    description: Optional[str] = None

class ServiceProviderTypeUpdate(BaseModel):
    description: Optional[str] = None  # Only description can be updated

# Request Models have been moved to modules/service_requests/models.py