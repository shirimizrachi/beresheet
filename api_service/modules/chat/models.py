"""
Pydantic models for chat functionality
"""

from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime

class ChatMessageCreate(BaseModel):
    message: str = Field(..., min_length=1, max_length=2000)
    media_type: Optional[str] = Field(None, description="Type of media: image, video, audio")
    media_url: Optional[str] = Field(None, description="URL of uploaded media")

class ChatMessage(BaseModel):
    message_id: str
    user_id: str
    user_name: str
    message: str
    media_type: Optional[str] = None
    media_url: Optional[str] = None
    timestamp: datetime
    home_id: int

    class Config:
        from_attributes = True

class ChatMessageResponse(BaseModel):
    messages: List[ChatMessage]
    total_count: int
    has_more: bool = False

class MediaUploadResponse(BaseModel):
    status: str
    media_url: str
    message_id: str
    message: ChatMessage