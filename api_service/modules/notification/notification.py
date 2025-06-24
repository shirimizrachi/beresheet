"""
Home notification service class using SQLAlchemy
Handles all notification-related database operations
"""

from datetime import datetime
from typing import Optional, List
from sqlalchemy import create_engine, Table, MetaData, text
from sqlalchemy.exc import SQLAlchemyError
import uuid

from .models import HomeNotification, HomeNotificationCreate, HomeNotificationUpdate, UserNotification
from ...tenant_config import get_schema_name_by_home_id
from ...database_utils import get_schema_engine


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

            # Generate GUID for notification ID
            notification_id = str(uuid.uuid4())

            schema_engine = get_schema_engine(schema_name)
            current_time = datetime.now()
            send_datetime = notification_data.send_datetime or current_time

            notification_dict = {
                'id': notification_id,
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
                conn.execute(home_notification_table.insert().values(**notification_dict))
                conn.commit()
                
                # Get the inserted notification
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

    def update_notification_status(self, notification_id: str, status_update: HomeNotificationUpdate,
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
                        user_notification_id = str(uuid.uuid4())
                        
                        user_notification_data = {
                            'id': user_notification_id,
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

    def get_notification_by_id(self, notification_id: str, home_id: int) -> Optional[HomeNotification]:
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

    def mark_user_notification_as_read(self, notification_id: str, user_id: str, home_id: int) -> bool:
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