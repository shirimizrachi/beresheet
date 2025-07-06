"""
User management using SQLAlchemy
Handles all user-related database operations
"""

import uuid
import asyncio
import logging
from datetime import datetime, date, timedelta
from typing import Optional, List, Dict
from sqlalchemy import create_engine, Table, MetaData, Column, String, Integer, Date, DateTime, text
from sqlalchemy.orm import sessionmaker
from sqlalchemy.exc import SQLAlchemyError, IntegrityError
from .models import UserProfile, UserProfileCreate, UserProfileUpdate
from tenant_config import get_schema_name_by_home_id, get_all_homes
from database_utils import get_schema_engine, get_engine_for_home, get_connection_for_home
from home_index import home_index_db

logger = logging.getLogger(__name__)

def normalize_phone_number(phone_number: str) -> str:
    """
    Normalize phone number by removing leading zeros
    
    Args:
        phone_number: The phone number to normalize
        
    Returns:
        Normalized phone number without leading zeros
    """
    if not phone_number:
        return phone_number
    
    # Remove leading zeros
    normalized = phone_number.lstrip('0')
    
    # If the entire string was zeros, return a single zero
    if not normalized:
        normalized = '0'
    
    return normalized

class UserDatabase:
    def __init__(self):
        # Note: This class now uses tenant-specific connections through database_utils
        # No default engine is created as all operations use schema-specific engines
        self.metadata = MetaData()

    def get_user_table(self, schema_name: str):
        """Get the users table for a specific schema using schema-specific connection"""
        try:
            # Get schema-specific engine
            schema_engine = get_schema_engine(schema_name)
            if not schema_engine:
                print(f"No engine found for schema {schema_name}")
                return None
            
            # Reflect the users table from the specified schema
            metadata = MetaData(schema=schema_name)
            metadata.reflect(bind=schema_engine, only=['users'])
            
            return metadata.tables[f'{schema_name}.users']
        except Exception as e:
            print(f"Error reflecting users table for schema {schema_name}: {e}")
            return None

    def create_user_profile(self, firebase_id: str, user_data: UserProfileCreate, home_id: int) -> Optional[UserProfile]:
        """Create a new user profile with minimal required data and auto-generated password"""
        try:
            # Get schema for home
            schema_name = get_schema_name_by_home_id(home_id)
            if not schema_name:
                raise ValueError(f"No schema found for home ID {home_id}")

            # Get the users table
            users_table = self.get_user_table(schema_name)
            if users_table is None:
                raise ValueError(f"Users table not found in schema {schema_name}")

            # Generate unique id and auto-generate password from phone number
            user_id = str(uuid.uuid4())
            current_time = datetime.now()
            auto_password = user_data.phone_number  # Password is the phone number

            # Prepare user data using actual values from user_data (no defaults)
            user_data_dict = {
                'id': user_id,  # Primary key
                'firebase_id': firebase_id,
                'home_id': user_data.home_id,
                'phone_number': user_data.phone_number,
                'password': auto_password,  # Auto-generated password
                'full_name': user_data.full_name,
                'role': user_data.role,
                'birthday': user_data.birthday,
                'apartment_number': user_data.apartment_number,
                'marital_status': user_data.marital_status,
                'gender': user_data.gender,
                'religious': user_data.religious,
                'native_language': user_data.native_language,
                'service_provider_type_name': user_data.service_provider_type_name,
                'service_provider_type_id': user_data.service_provider_type_id,
                'photo': None,  # Will be updated later with actual photo
                'created_at': current_time,  # Use datetime object like events module
                'updated_at': current_time   # Use datetime object like events module
            }

            # Insert user data using schema-specific engine
            schema_engine = get_schema_engine(schema_name)
            with schema_engine.connect() as conn:
                try:
                    result = conn.execute(users_table.insert().values(**user_data_dict))
                    conn.commit()
                except IntegrityError as e:
                    # Check if it's a unique constraint violation for phone number
                    error_message = str(e).lower()
                    if 'unique' in error_message and ('phone' in error_message or 'phone_number' in error_message):
                        raise ValueError(f"A user with phone number {user_data.phone_number} already exists")
                    else:
                        # Re-raise other integrity errors
                        raise

            # Create matching entry in home_index table
            try:
                # Get home name from tenant config for home_index entry
                from tenant_config import get_all_homes
                home_name = None
                for home in get_all_homes():
                    if home['id'] == home_id:
                        home_name = home['name']
                        break
                
                if home_name:
                    home_index_success = home_index_db.create_home_entry(
                        phone_number=user_data.phone_number,
                        home_id=home_id,
                        home_name=home_name
                    )
                    if not home_index_success:
                        print(f"Warning: Failed to create home_index entry for user {user_data.phone_number}")
                else:
                    print(f"Warning: Could not find home name for home_id {home_id}")
            except Exception as e:
                print(f"Warning: Error creating home_index entry for user {user_data.phone_number}: {e}")

            # Create and return UserProfile object using actual values
            return UserProfile(
                id=user_id,
                firebase_id=firebase_id,
                home_id=user_data.home_id,
                phone_number=user_data.phone_number,
                password=auto_password,
                full_name=user_data.full_name,
                role=user_data.role,
                birthday=user_data.birthday,
                apartment_number=user_data.apartment_number,
                marital_status=user_data.marital_status,
                gender=user_data.gender,
                religious=user_data.religious,
                native_language=user_data.native_language,
                service_provider_type_name=user_data.service_provider_type_name,
                service_provider_type_id=user_data.service_provider_type_id,
                photo=None,
                created_at=current_time.isoformat(),
                updated_at=current_time.isoformat()
            )

        except Exception as e:
            print(f"Error creating user profile {firebase_id}: {e}")
            raise

    def get_user_profile_by_phone(self, phone_number: str, home_id: int) -> Optional[UserProfile]:
        """Get a user profile by phone number from the appropriate schema"""
        try:
            # Normalize phone number by removing leading zeros
            normalized_phone = normalize_phone_number(phone_number)
            
            # Get schema for home
            schema_name = get_schema_name_by_home_id(home_id)
            if not schema_name:
                return None

            # Get the users table
            users_table = self.get_user_table(schema_name)
            if users_table is None:
                return None

            # Query user by normalized phone_number using schema-specific engine
            schema_engine = get_schema_engine(schema_name)
            with schema_engine.connect() as conn:
                result = conn.execute(
                    users_table.select().where(users_table.c.phone_number == normalized_phone)
                ).fetchone()

                if result:
                    # Convert result to UserProfile
                    return UserProfile(
                        id=result.id,
                        firebase_id=result.firebase_id,
                        home_id=result.home_id,
                        phone_number=result.phone_number,
                        password=result.password,
                        full_name=result.full_name,
                        role=result.role,
                        birthday=result.birthday,
                        apartment_number=result.apartment_number,
                        marital_status=result.marital_status,
                        gender=result.gender,
                        religious=result.religious,
                        native_language=result.native_language,
                        photo=result.photo,
                        service_provider_type_id=getattr(result, 'service_provider_type_id', None),
                        service_provider_type_name=getattr(result, 'service_provider_type_name', None),
                        created_at=result.created_at.isoformat() if isinstance(result.created_at, datetime) else result.created_at,
                        updated_at=result.updated_at.isoformat() if isinstance(result.updated_at, datetime) else result.updated_at
                    )
                return None

        except Exception as e:
            print(f"Error getting user profile by phone {phone_number}: {e}")
            return None

    def get_user_profile(self, user_id: str, home_id: int) -> Optional[UserProfile]:
        """Get a user profile by id from the appropriate schema"""
        try:
            # Get schema for home
            schema_name = get_schema_name_by_home_id(home_id)
            if not schema_name:
                return None

            # Get the users table
            users_table = self.get_user_table(schema_name)
            if users_table is None:
                return None

            # Query user by user_id using schema-specific engine
            schema_engine = get_schema_engine(schema_name)
            with schema_engine.connect() as conn:
                result = conn.execute(
                    users_table.select().where(users_table.c.id == user_id)
                ).fetchone()

                if result:
                    # Convert result to UserProfile
                    return UserProfile(
                        id=result.id,
                        firebase_id=result.firebase_id,
                        home_id=result.home_id,
                        phone_number=result.phone_number,
                        password=result.password,
                        full_name=result.full_name,
                        role=result.role,
                        birthday=result.birthday,
                        apartment_number=result.apartment_number,
                        marital_status=result.marital_status,
                        gender=result.gender,
                        religious=result.religious,
                        native_language=result.native_language,
                        photo=result.photo,
                        service_provider_type_id=getattr(result, 'service_provider_type_id', None),
                        service_provider_type_name=getattr(result, 'service_provider_type_name', None),
                        created_at=result.created_at.isoformat() if isinstance(result.created_at, datetime) else result.created_at,
                        updated_at=result.updated_at.isoformat() if isinstance(result.updated_at, datetime) else result.updated_at
                    )
                return None

        except Exception as e:
            print(f"Error getting user profile {user_id}: {e}")
            return None

    def update_user_profile(self, user_id: str, user_data: UserProfileUpdate, home_id: int) -> Optional[UserProfile]:
        """Update an existing user profile"""
        try:
            print(f"Updating user {user_id} with data: {user_data.model_dump()}")
            
            # Get schema for home
            schema_name = get_schema_name_by_home_id(home_id)
            if not schema_name:
                return None

            # Get the users table
            users_table = self.get_user_table(schema_name)
            if users_table is None:
                return None

            # Prepare update data (only non-None fields)
            update_data = {}
            for field, value in user_data.model_dump().items():
                if value is not None:
                    update_data[field] = value
            
            print(f"Update data prepared: {update_data}")
            
            # Add updated timestamp (use datetime object like events module)
            update_data['updated_at'] = datetime.now()

            # Update user using schema-specific engine
            schema_engine = get_schema_engine(schema_name)
            with schema_engine.connect() as conn:
                result = conn.execute(
                    users_table.update()
                    .where(users_table.c.id == user_id)
                    .values(**update_data)
                )
                conn.commit()
                
                print(f"Update result: {result.rowcount} rows affected")

                if result.rowcount > 0:
                    # Fetch and return updated user
                    updated_result = conn.execute(
                        users_table.select().where(users_table.c.id == user_id)
                    ).fetchone()

                    if updated_result:
                        print(f"Updated user from DB: full_name={updated_result.full_name}, apartment_number={updated_result.apartment_number}")
                        return UserProfile(
                            id=updated_result.id,
                            firebase_id=updated_result.firebase_id,
                            home_id=updated_result.home_id,
                            phone_number=updated_result.phone_number,
                            password=updated_result.password,
                            full_name=updated_result.full_name,
                            role=updated_result.role,
                            birthday=updated_result.birthday,
                            apartment_number=updated_result.apartment_number,
                            marital_status=updated_result.marital_status,
                            gender=updated_result.gender,
                            religious=updated_result.religious,
                            native_language=updated_result.native_language,
                            photo=updated_result.photo,
                            service_provider_type_id=getattr(updated_result, 'service_provider_type_id', None),
                            service_provider_type_name=getattr(updated_result, 'service_provider_type_name', None),
                            created_at=updated_result.created_at.isoformat() if isinstance(updated_result.created_at, datetime) else updated_result.created_at,
                            updated_at=updated_result.updated_at.isoformat() if isinstance(updated_result.updated_at, datetime) else updated_result.updated_at
                        )
                return None

        except Exception as e:
            print(f"Error updating user profile {user_id}: {e}")
            import traceback
            traceback.print_exc()
            return None

    def delete_user_profile(self, user_id: str, home_id: int) -> bool:
        """Delete a user profile"""
        try:
            # Get schema for home
            schema_name = get_schema_name_by_home_id(home_id)
            if not schema_name:
                return False

            # Get the users table
            users_table = self.get_user_table(schema_name)
            if users_table is None:
                return False

            # Delete user using schema-specific engine
            schema_engine = get_schema_engine(schema_name)
            with schema_engine.connect() as conn:
                result = conn.execute(
                    users_table.delete().where(users_table.c.id == user_id)
                )
                conn.commit()
                return result.rowcount > 0

        except Exception as e:
            print(f"Error deleting user profile {user_id}: {e}")
            return False

    def update_user_fcm_token(self, user_id: str, fcm_token: str, home_id: int) -> bool:
        """Update only the Firebase FCM token for a user"""
        try:
            # Get schema for home
            schema_name = get_schema_name_by_home_id(home_id)
            if not schema_name:
                return False

            # Get the users table
            users_table = self.get_user_table(schema_name)
            if users_table is None:
                return False

            # Update only the FCM token and updated timestamp (use datetime object like events module)
            update_data = {
                'firebase_fcm_token': fcm_token,
                'updated_at': datetime.now()
            }

            # Update user using schema-specific engine
            schema_engine = get_schema_engine(schema_name)
            with schema_engine.connect() as conn:
                result = conn.execute(
                    users_table.update()
                    .where(users_table.c.id == user_id)
                    .values(**update_data)
                )
                conn.commit()
                return result.rowcount > 0

        except Exception as e:
            print(f"Error updating FCM token for user {user_id}: {e}")
            return False

    def get_all_users(self, home_id: int) -> List[UserProfile]:
        """Get all users from the appropriate schema"""
        try:
            # Get schema for home
            schema_name = get_schema_name_by_home_id(home_id)
            if not schema_name:
                return []

            # Get the users table
            users_table = self.get_user_table(schema_name)
            if users_table is None:
                return []

            users = []
            # Use schema-specific engine
            schema_engine = get_schema_engine(schema_name)
            with schema_engine.connect() as conn:
                results = conn.execute(users_table.select().order_by(users_table.c.updated_at.desc())).fetchall()
                
                for result in results:
                    users.append(UserProfile(
                        id=result.id,
                        firebase_id=result.firebase_id,
                        home_id=result.home_id,
                        phone_number=result.phone_number,
                        password=result.password,
                        full_name=result.full_name,
                        role=result.role,
                        birthday=result.birthday,
                        apartment_number=result.apartment_number,
                        marital_status=result.marital_status,
                        gender=result.gender,
                        religious=result.religious,
                        native_language=result.native_language,
                        photo=result.photo,
                        service_provider_type_name=getattr(result, 'service_provider_type_name', None),
                        service_provider_type_id=getattr(result, 'service_provider_type_id', None),
                        created_at=result.created_at.isoformat() if isinstance(result.created_at, datetime) else result.created_at,
                        updated_at=result.updated_at.isoformat() if isinstance(result.updated_at, datetime) else result.updated_at
                    ))
            return users

        except Exception as e:
            print(f"Error getting all users for home {home_id}: {e}")
            return []

    def save_user_photo(self, user_id: str, photo_data: bytes, home_id: int) -> str:
        """Save user photo (placeholder - implement file storage logic)"""
        # This would typically save to file system and return path
        # For now, return a placeholder path
        return f"/photos/{user_id}.jpg"

    def get_user_photo_path(self, user_id: str, home_id: int) -> Optional[str]:
        """Get user photo path (placeholder)"""
        # This would typically check if photo exists and return path
        # For now, return None
        return None

    def get_available_homes(self) -> List[Dict]:
        """Get all available homes from tenant configuration"""
        return get_all_homes()
    
    def get_service_providers_ordered_by_requests(self, home_id: int, user_id: Optional[str] = None) -> List['ServiceProviderProfile']:
        """Get service providers ordered by most recent request interaction with the requesting user"""
        try:
            # Get schema for home
            schema_name = get_schema_name_by_home_id(home_id)
            if not schema_name:
                return []

            # Get the users table
            users_table = self.get_user_table(schema_name)
            if users_table is None:
                return []

            # Use schema-specific engine
            schema_engine = get_schema_engine(schema_name)
            with schema_engine.connect() as conn:
                if user_id:
                    # Get service providers ordered by most recent request from this specific user
                    from sqlalchemy import text
                    query_sql = text(f"""
                        SELECT DISTINCT u.*,
                               spt.name as service_provider_type_name,
                               spt.description as service_provider_type_description,
                               COALESCE(MAX(r.updated_at), MAX(r.request_created_at), '1900-01-01') as last_interaction,
                               COUNT(CASE WHEN r.resident_id = :user_id THEN r.id END) as request_count
                        FROM [{schema_name}].[users] u
                        LEFT JOIN [{schema_name}].[requests] r ON u.id = r.service_provider_id
                        LEFT JOIN [{schema_name}].[service_provider_types] spt ON u.service_provider_type_id = spt.id
                        WHERE u.role = 'service'
                        GROUP BY u.id, u.firebase_id, u.home_id, u.phone_number, u.password, u.full_name, u.role,
                                 u.birthday, u.apartment_number, u.marital_status, u.gender, u.religious,
                                 u.native_language, u.photo, u.created_at, u.updated_at, u.firebase_fcm_token,
                                 u.service_provider_type_name, u.service_provider_type_id, spt.name, spt.description
                        HAVING COUNT(CASE WHEN r.resident_id = :user_id THEN r.id END) >= 0
                        ORDER BY last_interaction DESC
                    """)
                    
                    results = conn.execute(query_sql, {'user_id': user_id}).fetchall()
                else:
                    # Fallback: just get all service providers without ordering, but still join with service_provider_types
                    from sqlalchemy import text
                    fallback_query_sql = text(f"""
                        SELECT u.*, spt.name as service_provider_type_name, spt.description as service_provider_type_description, 0 as request_count
                        FROM [{schema_name}].[users] u
                        LEFT JOIN [{schema_name}].[service_provider_types] spt ON u.service_provider_type_id = spt.id
                        WHERE u.role = 'service'
                    """)
                    results = conn.execute(fallback_query_sql).fetchall()
                
                service_providers = []
                for result in results:
                    from .models import ServiceProviderProfile
                    service_providers.append(ServiceProviderProfile(
                        id=result.id,
                        firebase_id=result.firebase_id,
                        home_id=result.home_id,
                        phone_number=result.phone_number,
                        password=result.password,
                        full_name=result.full_name,
                        role=result.role,
                        birthday=result.birthday,
                        apartment_number=result.apartment_number,
                        marital_status=result.marital_status,
                        gender=result.gender,
                        religious=result.religious,
                        native_language=result.native_language,
                        photo=result.photo,
                        service_provider_type_name=getattr(result, 'service_provider_type_name', None),
                        service_provider_type_id=result.service_provider_type_id,
                        service_provider_type_description=getattr(result, 'service_provider_type_description', None),
                        request_count=getattr(result, 'request_count', 0),
                        firebase_fcm_token=getattr(result, 'firebase_fcm_token', None),
                        created_at=result.created_at.isoformat() if isinstance(result.created_at, datetime) else result.created_at,
                        updated_at=result.updated_at.isoformat() if isinstance(result.updated_at, datetime) else result.updated_at
                    ))
                return service_providers

        except Exception as e:
            print(f"Error getting service providers ordered by requests for home {home_id}: {e}")
            # Fallback to the original method
            return [user for user in self.get_all_users(home_id) if user.role == "service"]

    def authenticate_user(self, phone_number: str, password: str, home_id: int) -> Optional[UserProfile]:
        """Authenticate user with phone number and password"""
        try:
            # Normalize phone number by removing leading zeros
            normalized_phone = normalize_phone_number(phone_number)
            
            # Get user by phone number (this will also normalize internally)
            user = self.get_user_profile_by_phone(normalized_phone, home_id)
            if not user:
                return None
            
            # Check password (plain text comparison)
            if user.password == password:
                return user
            
            return None
        except Exception as e:
            print(f"Error authenticating user {phone_number}: {e}")
            return None

    # SESSION-BASED AUTHENTICATION METHODS REMOVED
    # Replaced with JWT authentication in web_jwt_auth.py

    def get_user_home_info(self, phone_number: str) -> Optional[Dict[str, any]]:
        """Get user's home information by phone number using home_index"""
        try:
            # Normalize phone number by removing leading zeros
            normalized_phone = normalize_phone_number(phone_number)
            
            home_info = home_index_db.get_home_by_phone(normalized_phone)
            if home_info:
                return {
                    'home_id': home_info['home_id'],
                    'home_name': home_info['home_name']
                }
            return None
        except Exception as e:
            print(f"Error getting user home info for phone {phone_number}: {e}")
            return None

    async def upload_user_profile_photo(self, user_id: str, photo, home_id: int, tenant_name: str = None) -> str:
        """
        Upload photo for a user profile and return the photo URL.
        This function can be used by both create and update operations.
        
        Args:
            user_id: The ID of the user
            photo: The uploaded photo file (UploadFile or mock upload file)
            home_id: The home ID
            tenant_name: The tenant name for storage container naming
            
        Returns:
            str: The blob path of the uploaded photo
            
        Raises:
            Exception: If photo validation or upload fails
        """
        from fastapi import HTTPException
        from storage.storage_service import StorageServiceProxy
        import uuid
        
        # Validate file type
        if not hasattr(photo, 'content_type') or not photo.content_type or not photo.content_type.startswith('image/'):
            raise HTTPException(status_code=400, detail="File must be an image")
        
        # Generate unique filename
        file_extension = photo.filename.split('.')[-1] if photo.filename and '.' in photo.filename else 'jpg'
        unique_filename = f"{uuid.uuid4()}.{file_extension}"
        blob_path = f"{home_id}/users/photos/{unique_filename}"
        
        # Read file content (handle both sync and async read methods)
        if hasattr(photo, 'read') and callable(photo.read):
            if asyncio.iscoroutinefunction(photo.read):
                photo_content = await photo.read()
            else:
                photo_content = photo.read()
        else:
            raise HTTPException(status_code=400, detail="Invalid photo file")
        
        # Upload to Azure Storage using the dedicated user photo upload method
        if not tenant_name:
            raise HTTPException(status_code=400, detail="Tenant name is required for photo upload")
        
        logger.info(f"Uploading photo for user {user_id} with tenant_name: {tenant_name}")
        
        storage_service = StorageServiceProxy()
        success, result = storage_service.upload_user_photo(
            home_id=home_id,
            user_id=user_id,
            image_data=photo_content,
            original_filename=photo.filename or "user_photo.jpg",
            content_type=photo.content_type,
            tenant_name=tenant_name
        )
        
        if not success:
            logger.error(f"Photo upload failed for user {user_id}: {result}")
            raise HTTPException(status_code=500, detail=f"Failed to upload photo: {result}")
        
        logger.info(f"Photo uploaded successfully for user {user_id}: {result}")
        return result

# Create global instance
user_db = UserDatabase()