"""
Home notification management using SQLAlchemy
Handles all notification-related database operations
"""

from datetime import datetime
from typing import Optional, List
from sqlalchemy import create_engine, Table, MetaData, text
from sqlalchemy.exc import SQLAlchemyError
from pydantic import BaseModel
from fastapi import APIRouter, HTTPException, Header
from tenant_config import get_schema_name_by_home_id
from database_utils import get_schema_engine
from users import user_db

# Create FastAPI router
router = APIRouter()

# Pydantic models for notifications
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
    id: int
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
    id: int
    user_id: str
    user_read_date: Optional[datetime]
    user_fcm: Optional[str]
    notification_id: int
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

class HomeNotificationDatabase:
    def __init__(self):
        pass

    def get_home_notification_table(self, schema_name: str):
        """Get the home_notification table for a specific schema"""
        try:
            schema_engine = get_schema_engine(schema_name)
            if not schema_engine:
                print(f"No engine found for schema {schema_name}")
                return None
            
            metadata = MetaData(schema=schema_name)
            metadata.reflect(bind=schema_engine, only=['home_notification'])
            return metadata.tables[f'{schema_name}.home_notification']
        except Exception as e:
            print(f"Error reflecting home_notification table for schema {schema_name}: {e}")
            return None

    def get_user_notification_table(self, schema_name: str):
        """Get the user_notification table for a specific schema"""
        try:
            schema_engine = get_schema_engine(schema_name)
            if not schema_engine:
                print(f"No engine found for schema {schema_name}")
                return None
            
            metadata = MetaData(schema=schema_name)
            metadata.reflect(bind=schema_engine, only=['user_notification'])
            return metadata.tables[f'{schema_name}.user_notification']
        except Exception as e:
            print(f"Error reflecting user_notification table for schema {schema_name}: {e}")
            return None

    def get_users_table(self, schema_name: str):
        """Get the users table for a specific schema"""
        try:
            schema_engine = get_schema_engine(schema_name)
            if not schema_engine:
                print(f"No engine found for schema {schema_name}")
                return None
            
            metadata = MetaData(schema=schema_name)
            metadata.reflect(bind=schema_engine, only=['users'])
            return metadata.tables[f'{schema_name}.users']
        except Exception as e:
            print(f"Error reflecting users table for schema {schema_name}: {e}")
            return None

    def create_home_notification(self, notification_data: HomeNotificationCreate, home_id: int, 
                                 current_user: dict) -> Optional[HomeNotification]:
        """Create a new home notification (always as pending-approval)"""
        try:
            schema_name = get_schema_name_by_home_id(home_id)
            if not schema_name:
                return None

            home_notification_table = self.get_home_notification_table(schema_name)
            if home_notification_table is None:
                return None

            schema_engine = get_schema_engine(schema_name)
            current_time = datetime.now()
            send_datetime = notification_data.send_datetime or current_time

            notification_dict = {
                'create_by_user_id': current_user.get('id'),
                'create_by_user_name': current_user.get('full_name', ''),
                'create_by_user_role_name': current_user.get('role', ''),
                'create_by_user_service_provider_type_name': current_user.get('service_provider_type'),
                'message': notification_data.message,
                'send_status': 'pending-approval',
                'send_floor': notification_data.send_floor,
                'send_datetime': send_datetime,
                'send_type': notification_data.send_type,
                'created_at': current_time,
                'updated_at': current_time
            }

            with schema_engine.connect() as conn:
                result = conn.execute(home_notification_table.insert().values(**notification_dict))
                conn.commit()
                
                # Get the inserted notification
                notification_id = result.inserted_primary_key[0]
                inserted_result = conn.execute(
                    home_notification_table.select().where(home_notification_table.c.id == notification_id)
                ).fetchone()

                if inserted_result:
                    return HomeNotification(
                        id=inserted_result.id,
                        create_by_user_id=inserted_result.create_by_user_id,
                        create_by_user_name=inserted_result.create_by_user_name,
                        create_by_user_role_name=inserted_result.create_by_user_role_name,
                        create_by_user_service_provider_type_name=inserted_result.create_by_user_service_provider_type_name,
                        message=inserted_result.message,
                        send_status=inserted_result.send_status,
                        send_approved_by_user_id=inserted_result.send_approved_by_user_id,
                        send_floor=inserted_result.send_floor,
                        send_datetime=inserted_result.send_datetime,
                        send_type=inserted_result.send_type,
                        created_at=inserted_result.created_at,
                        updated_at=inserted_result.updated_at
                    )
                return None

        except Exception as e:
            print(f"Error creating home notification: {e}")
            return None

    def update_notification_status(self, notification_id: int, status_update: HomeNotificationUpdate,
                                   home_id: int, current_user: dict) -> bool:
        """Update notification status and create user notifications when approved"""
        try:
            schema_name = get_schema_name_by_home_id(home_id)
            if not schema_name:
                return False

            home_notification_table = self.get_home_notification_table(schema_name)
            user_notification_table = self.get_user_notification_table(schema_name)
            users_table = self.get_users_table(schema_name)
            
            if any(table is None for table in [home_notification_table, user_notification_table, users_table]):
                return False

            schema_engine = get_schema_engine(schema_name)
            
            with schema_engine.connect() as conn:
                # Get current notification
                current_notification = conn.execute(
                    home_notification_table.select().where(home_notification_table.c.id == notification_id)
                ).fetchone()
                
                if not current_notification:
                    return False

                # Update notification status
                update_data = {
                    'send_status': status_update.send_status,
                    'updated_at': datetime.now()
                }
                
                if status_update.send_status == 'approved':
                    update_data['send_approved_by_user_id'] = current_user.get('id')

                result = conn.execute(
                    home_notification_table.update()
                    .where(home_notification_table.c.id == notification_id)
                    .values(**update_data)
                )

                # If status is approved, create user notifications for all residents
                if status_update.send_status == 'approved':
                    # Get all users with 'resident' role
                    residents = conn.execute(
                        users_table.select().where(users_table.c.role == 'resident')
                    ).fetchall()

                    # Create user notification for each resident
                    for resident in residents:
                        user_notification_data = {
                            'user_id': resident.id,
                            'user_fcm': getattr(resident, 'firebase_fcm_token', None),
                            'notification_id': notification_id,
                            'notification_sender_user_id': current_notification.create_by_user_id,
                            'notification_sender_user_name': current_notification.create_by_user_name,
                            'notification_sender_user_role_name': current_notification.create_by_user_role_name,
                            'notification_sender_user_service_provider_type_name': current_notification.create_by_user_service_provider_type_name,
                            'notification_status': 'sent',
                            'notification_time': current_notification.send_datetime,
                            'notification_message': current_notification.message,
                            'notification_type': current_notification.send_type,
                            'created_at': datetime.now(),
                            'updated_at': datetime.now()
                        }
                        
                        conn.execute(user_notification_table.insert().values(**user_notification_data))

                conn.commit()
                return result.rowcount > 0

        except Exception as e:
            print(f"Error updating notification status: {e}")
            return False

    def get_all_notifications(self, home_id: int) -> List[HomeNotification]:
        """Get all home notifications ordered by pending-approval first, then by date desc"""
        try:
            schema_name = get_schema_name_by_home_id(home_id)
            if not schema_name:
                return []

            home_notification_table = self.get_home_notification_table(schema_name)
            if home_notification_table is None:
                return []

            schema_engine = get_schema_engine(schema_name)
            
            with schema_engine.connect() as conn:
                # Use raw SQL for custom ordering
                results = conn.execute(
                    text(f"""
                        SELECT id, create_by_user_id, create_by_user_name, create_by_user_role_name,
                               create_by_user_service_provider_type_name, message, send_status,
                               send_approved_by_user_id, send_floor, send_datetime, send_type,
                               created_at, updated_at
                        FROM [{schema_name}].[home_notification]
                        ORDER BY 
                            CASE WHEN send_status = 'pending-approval' THEN 0 ELSE 1 END,
                            send_datetime DESC
                    """)
                ).fetchall()

                notifications = []
                for result in results:
                    notifications.append(HomeNotification(
                        id=result.id,
                        create_by_user_id=result.create_by_user_id,
                        create_by_user_name=result.create_by_user_name,
                        create_by_user_role_name=result.create_by_user_role_name,
                        create_by_user_service_provider_type_name=result.create_by_user_service_provider_type_name,
                        message=result.message,
                        send_status=result.send_status,
                        send_approved_by_user_id=result.send_approved_by_user_id,
                        send_floor=result.send_floor,
                        send_datetime=result.send_datetime,
                        send_type=result.send_type,
                        created_at=result.created_at,
                        updated_at=result.updated_at
                    ))
                
                return notifications

        except Exception as e:
            print(f"Error getting all notifications: {e}")
            return []

    def get_notification_by_id(self, notification_id: int, home_id: int) -> Optional[HomeNotification]:
        """Get a specific home notification by ID"""
        try:
            schema_name = get_schema_name_by_home_id(home_id)
            if not schema_name:
                return None

            home_notification_table = self.get_home_notification_table(schema_name)
            if home_notification_table is None:
                return None

            schema_engine = get_schema_engine(schema_name)
            
            with schema_engine.connect() as conn:
                result = conn.execute(
                    home_notification_table.select().where(home_notification_table.c.id == notification_id)
                ).fetchone()

                if result:
                    return HomeNotification(
                        id=result.id,
                        create_by_user_id=result.create_by_user_id,
                        create_by_user_name=result.create_by_user_name,
                        create_by_user_role_name=result.create_by_user_role_name,
                        create_by_user_service_provider_type_name=result.create_by_user_service_provider_type_name,
                        message=result.message,
                        send_status=result.send_status,
                        send_approved_by_user_id=result.send_approved_by_user_id,
                        send_floor=result.send_floor,
                        send_datetime=result.send_datetime,
                        send_type=result.send_type,
                        created_at=result.created_at,
                        updated_at=result.updated_at
                    )
                return None

        except Exception as e:
            print(f"Error getting notification by ID: {e}")
            return None

    def get_user_notifications(self, user_id: str, home_id: int) -> List[UserNotification]:
        """Get all user notifications for a specific user with status 'sent' ordered by date desc"""
        try:
            schema_name = get_schema_name_by_home_id(home_id)
            if not schema_name:
                return []

            user_notification_table = self.get_user_notification_table(schema_name)
            if user_notification_table is None:
                return []

            schema_engine = get_schema_engine(schema_name)
            
            with schema_engine.connect() as conn:
                # Use raw SQL for better control over the query
                # Get notifications with status 'sent' - these are ready for users to view
                results = conn.execute(
                    text(f"""
                        SELECT id, user_id, user_read_date, user_fcm, notification_id,
                               notification_sender_user_id, notification_sender_user_name,
                               notification_sender_user_role_name, notification_sender_user_service_provider_type_name,
                               notification_status, notification_time, notification_message,
                               notification_type, created_at, updated_at
                        FROM [{schema_name}].[user_notification]
                        WHERE user_id = :user_id AND notification_status IN ('sent', 'pending')
                        ORDER BY notification_time DESC
                    """),
                    {'user_id': user_id}
                ).fetchall()

                notifications = []
                for result in results:
                    notifications.append(UserNotification(
                        id=result.id,
                        user_id=result.user_id,
                        user_read_date=result.user_read_date,
                        user_fcm=result.user_fcm,
                        notification_id=result.notification_id,
                        notification_sender_user_id=result.notification_sender_user_id,
                        notification_sender_user_name=result.notification_sender_user_name,
                        notification_sender_user_role_name=result.notification_sender_user_role_name,
                        notification_sender_user_service_provider_type_name=result.notification_sender_user_service_provider_type_name,
                        notification_status=result.notification_status,
                        notification_time=result.notification_time,
                        notification_message=result.notification_message,
                        notification_type=result.notification_type,
                        created_at=result.created_at,
                        updated_at=result.updated_at
                    ))
                
                return notifications

        except Exception as e:
            print(f"Error getting user notifications: {e}")
            return []

    def mark_user_notification_as_read(self, notification_id: int, user_id: str, home_id: int) -> bool:
        """Mark a user notification as read by setting user_read_date"""
        try:
            schema_name = get_schema_name_by_home_id(home_id)
            if not schema_name:
                return False

            user_notification_table = self.get_user_notification_table(schema_name)
            if user_notification_table is None:
                return False

            schema_engine = get_schema_engine(schema_name)
            
            with schema_engine.connect() as conn:
                # Update the user_read_date for the specific notification and user
                result = conn.execute(
                    user_notification_table.update()
                    .where(
                        (user_notification_table.c.id == notification_id) &
                        (user_notification_table.c.user_id == user_id)
                    )
                    .values(user_read_date=datetime.now())
                )
                
                conn.commit()
                return result.rowcount > 0

        except Exception as e:
            print(f"Error marking user notification as read: {e}")
            return False

# Create global instance
home_notification_db = HomeNotificationDatabase()

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
    notification_id: int,
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
    notification_id: int,
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
    notification_id: int,
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
