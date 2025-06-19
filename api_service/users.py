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
from home_mapping import get_connection_string, get_schema_for_home, get_all_homes
from database_utils import get_schema_engine, get_engine_for_home, get_connection_for_home

class UserDatabase:
    def __init__(self):
        self.connection_string = get_connection_string()
        self.engine = create_engine(self.connection_string)
        self.SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=self.engine)
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
            schema_name = get_schema_for_home(home_id)
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
            schema_name = get_schema_for_home(home_id)
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
            schema_name = get_schema_for_home(home_id)
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
            schema_name = get_schema_for_home(home_id)
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
            schema_name = get_schema_for_home(home_id)
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
            schema_name = get_schema_for_home(home_id)
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
            schema_name = get_schema_for_home(home_id)
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
        """Get all available homes from home mapping"""
        return get_all_homes()
    
    def get_service_providers_ordered_by_requests(self, home_id: int, user_id: Optional[str] = None) -> List[UserProfile]:
        """Get service providers ordered by most recent request interaction with the requesting user"""
        try:
            # Get schema for home
            schema_name = get_schema_for_home(home_id)
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
                    service_providers.append(UserProfile(
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

    def create_web_session(self, user_id: str, home_id: int, user_role: str) -> Optional[str]:
        """Create a web session for authenticated user"""
        try:
            # Get schema for home
            schema_name = get_schema_for_home(home_id)
            if not schema_name:
                return None

            # Generate session ID
            session_id = str(uuid.uuid4())
            current_time = datetime.now()
            expires_at = current_time + timedelta(hours=24)  # 24 hours from now

            # Insert session data using schema-specific engine
            schema_engine = get_schema_engine(schema_name)
            with schema_engine.connect() as conn:
                # Check if web_sessions table exists, if not create it
                create_sessions_table_sql = text(f"""
                    IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES
                                  WHERE TABLE_SCHEMA = '{schema_name}' AND TABLE_NAME = 'web_sessions')
                    BEGIN
                        CREATE TABLE [{schema_name}].[web_sessions] (
                            session_id NVARCHAR(255) PRIMARY KEY,
                            user_id NVARCHAR(50) NOT NULL,
                            home_id INT NOT NULL,
                            user_role NVARCHAR(20) NOT NULL,
                            created_at DATETIME2 DEFAULT GETDATE(),
                            expires_at DATETIME2 NOT NULL,
                            is_active BIT DEFAULT 1
                        );
                    END
                """)
                conn.execute(create_sessions_table_sql)

                # Insert new session
                insert_session_sql = text(f"""
                    INSERT INTO [{schema_name}].[web_sessions]
                    (session_id, user_id, home_id, user_role, created_at, expires_at, is_active)
                    VALUES (:session_id, :user_id, :home_id, :user_role, :created_at, :expires_at, 1)
                """)
                
                conn.execute(insert_session_sql, {
                    'session_id': session_id,
                    'user_id': user_id,
                    'home_id': home_id,
                    'user_role': user_role,
                    'created_at': current_time,
                    'expires_at': expires_at
                })
                conn.commit()

            return session_id

        except Exception as e:
            print(f"Error creating web session for user {user_id}: {e}")
            return None

    def validate_web_session(self, session_id: str, home_id: int) -> Optional[Dict]:
        """Validate web session and return session info"""
        try:
            # Get schema for home
            schema_name = get_schema_for_home(home_id)
            if not schema_name:
                return None

            # Use schema-specific engine
            schema_engine = get_schema_engine(schema_name)
            with schema_engine.connect() as conn:
                # Query session
                query_sql = text(f"""
                    SELECT session_id, user_id, home_id, user_role, expires_at, is_active
                    FROM [{schema_name}].[web_sessions]
                    WHERE session_id = :session_id AND is_active = 1
                """)
                
                result = conn.execute(query_sql, {'session_id': session_id}).fetchone()
                
                if result:
                    # Check if session is expired
                    if result.expires_at < datetime.now():
                        # Deactivate expired session
                        deactivate_sql = text(f"""
                            UPDATE [{schema_name}].[web_sessions]
                            SET is_active = 0
                            WHERE session_id = :session_id
                        """)
                        conn.execute(deactivate_sql, {'session_id': session_id})
                        conn.commit()
                        return None
                    
                    return {
                        'session_id': result.session_id,
                        'user_id': result.user_id,
                        'home_id': result.home_id,
                        'user_role': result.user_role,
                        'expires_at': result.expires_at.isoformat(),
                        'is_active': bool(result.is_active)
                    }
                
                return None

        except Exception as e:
            print(f"Error validating web session {session_id}: {e}")
            return None

    def invalidate_web_session(self, session_id: str, home_id: int) -> bool:
        """Invalidate/logout web session"""
        try:
            # Get schema for home
            schema_name = get_schema_for_home(home_id)
            if not schema_name:
                return False

            # Use schema-specific engine
            schema_engine = get_schema_engine(schema_name)
            with schema_engine.connect() as conn:
                # Deactivate session
                deactivate_sql = text(f"""
                    UPDATE [{schema_name}].[web_sessions]
                    SET is_active = 0
                    WHERE session_id = :session_id
                """)
                result = conn.execute(deactivate_sql, {'session_id': session_id})
                conn.commit()
                return result.rowcount > 0

        except Exception as e:
            print(f"Error invalidating web session {session_id}: {e}")
            return False

# Create global instance
user_db = UserDatabase()