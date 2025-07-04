"""
User management using SQLAlchemy
Handles all user-related database operations
"""

import uuid
from datetime import datetime, date, timedelta
from typing import Optional, List, Dict
from sqlalchemy import create_engine, Table, MetaData, Column, String, Integer, Date, DateTime, text
from sqlalchemy.orm import sessionmaker
from sqlalchemy.exc import SQLAlchemyError
from models import UserProfile, UserProfileCreate, UserProfileUpdate
from tenant_config import get_schema_name_by_home_id, get_all_homes
from database_utils import get_schema_engine, get_engine_for_home, get_connection_for_home
from home_index import home_index_db

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

            # Prepare user data with defaults
            user_data_dict = {
                'id': user_id,  # Primary key
                'firebase_id': firebase_id,
                'home_id': user_data.home_id,
                'phone_number': user_data.phone_number,
                'password': auto_password,  # Auto-generated password
                'full_name': "",  # To be updated later
                'role': "resident",  # Default role
                'birthday': current_time.date(),  # Default to today, to be updated
                'apartment_number': "",  # To be updated later
                'marital_status': "single",  # Default
                'gender': "",  # To be updated later
                'religious': "",  # To be updated later
                'native_language': "hebrew",  # Default
                'photo': None,
                'created_at': current_time.isoformat(),
                'updated_at': current_time.isoformat()
            }

            # Insert user data using schema-specific engine
            schema_engine = get_schema_engine(schema_name)
            with schema_engine.connect() as conn:
                result = conn.execute(users_table.insert().values(**user_data_dict))
                conn.commit()

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

            # Create and return UserProfile object
            return UserProfile(
                id=user_id,
                firebase_id=firebase_id,
                home_id=user_data.home_id,
                phone_number=user_data.phone_number,
                password=auto_password,
                full_name="",
                role="resident",
                birthday=current_time.date(),
                apartment_number="",
                marital_status="single",
                gender="",
                religious="",
                native_language="hebrew",
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
            # Get schema for home
            schema_name = get_schema_name_by_home_id(home_id)
            if not schema_name:
                return None

            # Get the users table
            users_table = self.get_user_table(schema_name)
            if users_table is None:
                return None

            # Query user by phone_number using schema-specific engine
            schema_engine = get_schema_engine(schema_name)
            with schema_engine.connect() as conn:
                result = conn.execute(
                    users_table.select().where(users_table.c.phone_number == phone_number)
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
                        service_provider_type=getattr(result, 'service_provider_type', None),
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
                        service_provider_type=getattr(result, 'service_provider_type', None),
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
            
            # Add updated timestamp
            update_data['updated_at'] = datetime.now().isoformat()

            # Update user using schema-specific engine
            schema_engine = get_schema_engine(schema_name)
            with schema_engine.connect() as conn:
                result = conn.execute(
                    users_table.update()
                    .where(users_table.c.id == user_id)
                    .values(**update_data)
                )
                conn.commit()

                if result.rowcount > 0:
                    # Fetch and return updated user
                    updated_result = conn.execute(
                        users_table.select().where(users_table.c.id == user_id)
                    ).fetchone()

                    if updated_result:
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
                            service_provider_type=getattr(updated_result, 'service_provider_type', None),
                            created_at=updated_result.created_at.isoformat() if isinstance(updated_result.created_at, datetime) else updated_result.created_at,
                            updated_at=updated_result.updated_at.isoformat() if isinstance(updated_result.updated_at, datetime) else updated_result.updated_at
                        )
                return None

        except Exception as e:
            print(f"Error updating user profile {user_id}: {e}")
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

            # Update only the FCM token and updated timestamp
            update_data = {
                'firebase_fcm_token': fcm_token,
                'updated_at': datetime.now().isoformat()
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
                results = conn.execute(users_table.select()).fetchall()
                
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
                                 u.service_provider_type, u.service_provider_type_id, spt.name, spt.description
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
                    from models import ServiceProviderProfile
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
                        service_provider_type=result.service_provider_type,
                        service_provider_type_id=result.service_provider_type_id,
                        service_provider_type_name=getattr(result, 'service_provider_type_name', None),
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
            # Get user by phone number
            user = self.get_user_profile_by_phone(phone_number, home_id)
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
            home_info = home_index_db.get_home_by_phone(phone_number)
            if home_info:
                return {
                    'home_id': home_info['home_id'],
                    'home_name': home_info['home_name']
                }
            return None
        except Exception as e:
            print(f"Error getting user home info for phone {phone_number}: {e}")
            return None

# Create global instance
user_db = UserDatabase()