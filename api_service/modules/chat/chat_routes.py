"""
Chat API routes for community chat functionality
"""

from fastapi import APIRouter, HTTPException, Header, Depends, File, UploadFile, Form, Query
from typing import List, Optional
from .models import ChatMessage, ChatMessageCreate, ChatMessageResponse, MediaUploadResponse
from .chat import chat_db

router = APIRouter(prefix="/chat", tags=["chat"])

# Header dependencies
async def get_home_id(home_id: str = Header(..., alias="homeID")):
    """Dependency to extract and validate homeID header"""
    if not home_id:
        raise HTTPException(status_code=400, detail="homeID header is required")
    try:
        return int(home_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="homeID must be a valid integer")

async def get_user_id(user_id: Optional[str] = Header(None, alias="userId")):
    """Dependency to extract user ID header"""
    if not user_id:
        raise HTTPException(status_code=400, detail="userId header is required")
    return user_id

async def get_user_role(user_id: str, home_id: int) -> str:
    """Get user role from database"""
    from modules.users import user_db
    user = user_db.get_user_profile(user_id, home_id)
    if not user:
        raise HTTPException(status_code=404, detail="User profile not found")
    return user.role

# ------------------------- Chat Endpoints ------------------------- #

@router.post("/messages", response_model=ChatMessage, status_code=201)
async def send_message(
    message: ChatMessageCreate,
    home_id: int = Depends(get_home_id),
    user_id: str = Depends(get_user_id),
):
    """Send a text message to community chat"""
    if not message.message.strip():
        raise HTTPException(status_code=400, detail="Message cannot be empty")
    
    new_message = chat_db.add_message(message, user_id, home_id)
    if not new_message:
        raise HTTPException(status_code=400, detail="Unable to send message")
    
    return new_message

@router.get("/messages", response_model=ChatMessageResponse)
async def get_messages(
    home_id: int = Depends(get_home_id),
    user_id: str = Depends(get_user_id),
    limit: int = Query(20, ge=1, le=100, description="Number of messages to retrieve"),
    offset: int = Query(0, ge=0, description="Number of messages to skip"),
):
    """Get chat messages for the community"""
    messages = chat_db.get_messages(home_id, limit, offset)
    total_count = chat_db.get_message_count(home_id)
    has_more = (offset + len(messages)) < total_count
    
    return ChatMessageResponse(
        messages=messages,
        total_count=total_count,
        has_more=has_more
    )

@router.get("/messages/recent", response_model=List[ChatMessage])
async def get_recent_messages(
    home_id: int = Depends(get_home_id),
    user_id: str = Depends(get_user_id),
    limit: int = Query(5, ge=1, le=10, description="Number of recent messages to retrieve"),
):
    """Get recent messages for footer display"""
    messages = chat_db.get_recent_messages(home_id, limit)
    return messages

@router.post("/upload-media", response_model=MediaUploadResponse)
async def upload_media(
    file: UploadFile = File(...),
    message: Optional[str] = Form(""),
    home_id: int = Depends(get_home_id),
    user_id: str = Depends(get_user_id)
):
    """Upload media (image, video, or audio) with optional text message"""
    try:
        # Validate file type
        if not file.content_type:
            raise HTTPException(status_code=400, detail="File type not specified")
        
        # Determine media type from content type
        media_type = None
        if file.content_type.startswith('image/'):
            media_type = 'image'
        elif file.content_type.startswith('video/'):
            media_type = 'video'
        elif file.content_type.startswith('audio/'):
            media_type = 'audio'
        else:
            raise HTTPException(status_code=400, detail="Unsupported file type")
        
        # Read file data
        file_data = await file.read()
        
        # Upload to Storage
        from storage.storage_service import azure_storage_service
        success, result = azure_storage_service.upload_chat_media(
            home_id=home_id,
            user_id=user_id,
            media_data=file_data,
            original_filename=file.filename or "media",
            content_type=file.content_type
        )
        
        if not success:
            raise HTTPException(status_code=400, detail=f"Upload failed: {result}")
        
        # Create chat message with media
        media_url = result
        message_text = message or f"Shared {media_type}"
        
        chat_message = chat_db.add_media_message(
            message_text=message_text,
            media_type=media_type,
            media_url=media_url,
            user_id=user_id,
            home_id=home_id
        )
        
        if not chat_message:
            raise HTTPException(status_code=400, detail="Unable to create message with media")
        
        return MediaUploadResponse(
            status="success",
            media_url=media_url,
            message_id=chat_message.message_id,
            message=chat_message
        )
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

@router.get("/stats")
async def get_chat_stats(
    home_id: int = Depends(get_home_id),
    user_id: str = Depends(get_user_id),
):
    """Get chat statistics"""
    total_messages = chat_db.get_message_count(home_id)
    recent_messages = chat_db.get_recent_messages(home_id, 5)
    
    return {
        "total_messages": total_messages,
        "recent_message_count": len(recent_messages),
        "has_messages": total_messages > 0
    }