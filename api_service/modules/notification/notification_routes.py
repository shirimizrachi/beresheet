"""
Notification API routes
"""

from typing import List, Optional
from fastapi import APIRouter, HTTPException, Header
from .models import HomeNotificationCreate, HomeNotificationUpdate, HomeNotification, UserNotification
from .notification import home_notification_db
from ..users import user_db

# Create FastAPI router
router = APIRouter()


# Helper function to get current user from session
async def get_current_user_from_session(authorization: str = Header(None)) -> dict:
    """Get current user from web session token"""
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Authorization header missing or invalid")
    
    session_token = authorization.split(" ")[1]
    
    # For now, we'll extract home_id from a separate header or use a default
    # In a real implementation, you'd decode the session token to get this info
    home_id = 1  # This should be extracted from the session token
    
    session_info = user_db.validate_web_session(session_token, home_id)
    if not session_info:
        raise HTTPException(status_code=401, detail="Invalid or expired session")
    
    # Get user details
    user_profile = user_db.get_user_profile(session_info['user_id'], home_id)
    if not user_profile:
        raise HTTPException(status_code=401, detail="User not found")
    
    return {
        'id': user_profile.id,
        'full_name': user_profile.full_name,
        'role': user_profile.role,
        'service_provider_type': getattr(user_profile, 'service_provider_type', None),
        'home_id': home_id
    }


# API Endpoints
@router.post("/home-notifications")
async def create_home_notification(
    notification: HomeNotificationCreate,
    authorization: str = Header(None)
):
    """Create a new home notification (always as pending-approval)"""
    try:
        current_user = await get_current_user_from_session(authorization)
        home_id = current_user['home_id']
        
        result = home_notification_db.create_home_notification(notification, home_id, current_user)
        if result:
            return {"message": "Home notification created successfully", "id": result.id}
        else:
            raise HTTPException(status_code=500, detail="Failed to create notification")
            
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")


@router.put("/home-notifications/{notification_id}")
async def update_home_notification_status(
    notification_id: str,
    notification_update: HomeNotificationUpdate,
    authorization: str = Header(None)
):
    """Update home notification status and create user notifications when approved"""
    try:
        current_user = await get_current_user_from_session(authorization)
        home_id = current_user['home_id']
        
        # Validate status
        valid_statuses = ['pending-approval', 'approved', 'canceled', 'sent']
        if notification_update.send_status not in valid_statuses:
            raise HTTPException(status_code=400, detail="Invalid status")
        
        success = home_notification_db.update_notification_status(
            notification_id, notification_update, home_id, current_user
        )
        
        if success:
            return {"message": "Notification status updated successfully"}
        else:
            raise HTTPException(status_code=404, detail="Notification not found or update failed")
            
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")


@router.get("/home-notifications", response_model=List[HomeNotification])
async def get_home_notifications(
    authorization: str = Header(None)
):
    """Get all home notifications ordered by pending-approval first, then by date desc"""
    try:
        current_user = await get_current_user_from_session(authorization)
        home_id = current_user['home_id']
        
        notifications = home_notification_db.get_all_notifications(home_id)
        return notifications
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")


@router.get("/home-notifications/{notification_id}", response_model=HomeNotification)
async def get_home_notification(
    notification_id: str,
    authorization: str = Header(None)
):
    """Get a specific home notification by ID"""
    try:
        current_user = await get_current_user_from_session(authorization)
        home_id = current_user['home_id']
        
        notification = home_notification_db.get_notification_by_id(notification_id, home_id)
        if notification:
            return notification
        else:
            raise HTTPException(status_code=404, detail="Notification not found")
            
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")


@router.patch("/user-notifications/{notification_id}/read")
async def mark_user_notification_as_read(
    notification_id: str,
    authorization: str = Header(None),
    home_id: Optional[str] = Header(None, alias="homeID"),
    user_id: Optional[str] = Header(None, alias="userId")
):
    """Mark a user notification as read"""
    try:
        # Try mobile authentication first (homeID and userId headers)
        if home_id and user_id:
            try:
                home_id_int = int(home_id)
                success = home_notification_db.mark_user_notification_as_read(notification_id, user_id, home_id_int)
                if success:
                    return {"message": "Notification marked as read successfully"}
                else:
                    raise HTTPException(status_code=404, detail="Notification not found or already read")
            except ValueError:
                raise HTTPException(status_code=400, detail="homeID must be a valid integer")
        
        # Fall back to web session authentication
        current_user = await get_current_user_from_session(authorization)
        home_id_int = current_user['home_id']
        user_id = current_user['id']
        
        success = home_notification_db.mark_user_notification_as_read(notification_id, user_id, home_id_int)
        if success:
            return {"message": "Notification marked as read successfully"}
        else:
            raise HTTPException(status_code=404, detail="Notification not found or already read")
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")


@router.get("/user-notifications", response_model=List[UserNotification])
async def get_user_notifications(
    authorization: str = Header(None),
    home_id: Optional[str] = Header(None, alias="homeID"),
    user_id: Optional[str] = Header(None, alias="userId")
):
    """Get all user notifications for the current user with status 'sent'"""
    try:
        # Try mobile authentication first (homeID and userId headers)
        if home_id and user_id:
            try:
                home_id_int = int(home_id)
                notifications = home_notification_db.get_user_notifications(user_id, home_id_int)
                return notifications
            except ValueError:
                raise HTTPException(status_code=400, detail="homeID must be a valid integer")
        
        # Fall back to web session authentication
        current_user = await get_current_user_from_session(authorization)
        home_id_int = current_user['home_id']
        user_id = current_user['id']
        
        notifications = home_notification_db.get_user_notifications(user_id, home_id_int)
        return notifications
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")