"""
Notification models using Pydantic
"""

from datetime import datetime
from typing import Optional
from pydantic import BaseModel


class HomeNotificationBase(BaseModel):
    message: str
    send_floor: Optional[int] = None
    send_datetime: Optional[datetime] = None
    send_type: str = "regular"


class HomeNotificationCreate(HomeNotificationBase):
    pass


class HomeNotificationUpdate(BaseModel):
    send_status: str


class HomeNotification(BaseModel):
    id: str
    create_by_user_id: str
    create_by_user_name: str
    create_by_user_role_name: str
    create_by_user_service_provider_type_name: Optional[str]
    message: str
    send_status: str
    send_approved_by_user_id: Optional[str]
    send_floor: Optional[int]
    send_datetime: datetime
    send_type: str
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class UserNotification(BaseModel):
    id: str
    user_id: str
    user_read_date: Optional[datetime]
    user_fcm: Optional[str]
    notification_id: str
    notification_sender_user_id: str
    notification_sender_user_name: str
    notification_sender_user_role_name: str
    notification_sender_user_service_provider_type_name: Optional[str]
    notification_status: str
    notification_time: datetime
    notification_message: str
    notification_type: str
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True