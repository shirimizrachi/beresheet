"""
DDL script for creating the users table in a specific schema using SQLAlchemy ORM
Usage with API engine: create_users_table(engine, schema_name)
"""

from sqlalchemy import Column, String, Integer, Date, DateTime, func, Index, Unicode
from sqlalchemy.ext.declarative import declarative_base
import logging

logger = logging.getLogger(__name__)

def create_users_table(engine, schema_name: str, drop_if_exists: bool = True):
    """
    Create the users table in the specified schema using SQLAlchemy ORM
    
    Args:
        engine: SQLAlchemy engine object
        schema_name: Name of the schema where the table should be created
        drop_if_exists: Whether to drop the table if it already exists
    """
    
    try:
        # Create a new base for this table
        Base = declarative_base()
        
        class UsersTable(Base):
            __tablename__ = 'users'
            __table_args__ = {'schema': schema_name}
            
            id = Column(String(50), primary_key=True)
            firebase_id = Column(String(50), unique=True, nullable=False)
            home_id = Column(Integer, nullable=False)
            password = Column(String(255), nullable=False)
            display_name = Column(Unicode(100))
            full_name = Column(Unicode(100))
            email = Column(String(255))
            phone_number = Column(String(20), unique=True, nullable=False)
            birth_date = Column(Date)
            birthday = Column(Date)
            gender = Column(Unicode(10))
            city = Column(Unicode(50))
            address = Column(Unicode(255))
            apartment_number = Column(String(50))
            marital_status = Column(Unicode(20))
            religious = Column(Unicode(50))
            native_language = Column(Unicode(50))
            role = Column(String(50), default='resident')
            service_provider_type_name = Column(Unicode(100))
            service_provider_type_id = Column(String(50))
            firebase_fcm_token = Column(String(500))
            photo = Column(String(500))
            created_at = Column(DateTime, default=func.now())
            updated_at = Column(DateTime, default=func.now(), onupdate=func.now())
        
        # Drop table if it exists and drop_if_exists is True
        if drop_if_exists:
            try:
                UsersTable.__table__.drop(engine, checkfirst=True)
                logger.info(f"Dropped existing users table in schema {schema_name}")
            except Exception as e:
                logger.info(f"No existing users table to drop in schema {schema_name}: {e}")
        
        # Create the table
        UsersTable.__table__.create(engine, checkfirst=True)
        
        # Create indexes for better performance
        with engine.connect() as conn:
            # Define indexes - exclude firebase_id since it has unique constraint
            # Both Oracle and SQL Server automatically create indexes for unique constraints
            indexes = [
                # Skip firebase_id since it has unique constraint (automatic index)
                Index(f'ix_{schema_name}_users_home_id', UsersTable.home_id),
                Index(f'ix_{schema_name}_users_phone_number', UsersTable.phone_number),
                Index(f'ix_{schema_name}_users_role', UsersTable.role),
                Index(f'ix_{schema_name}_users_service_provider_type_name', UsersTable.service_provider_type_name),
                Index(f'ix_{schema_name}_users_service_provider_type_id', UsersTable.service_provider_type_id),
                Index(f'ix_{schema_name}_users_firebase_fcm_token', UsersTable.firebase_fcm_token),
            ]
            
            logger.info(f"Skipping index on 'firebase_id' column - automatically created by unique constraint")
            
            # Create each index
            for index in indexes:
                try:
                    # Drop index first if it exists to avoid ORA-01408 error
                    try:
                        index.drop(engine, checkfirst=True)
                        logger.info(f"Dropped existing index {index.name}")
                    except Exception as drop_e:
                        logger.debug(f"No existing index {index.name} to drop: {drop_e}")
                    
                    # Now create the index
                    index.create(engine, checkfirst=False)
                    logger.info(f"Created index {index.name}")
                except Exception as e:
                    logger.warning(f"Could not create index {index.name}: {e}")
            
            conn.commit()
        
        logger.info(f"Users table created successfully in schema '{schema_name}' with indexes.")
        print(f"Users table created successfully in schema '{schema_name}' with indexes.")
        return True
        
    except Exception as e:
        logger.error(f"Error creating users table in schema '{schema_name}': {e}")
        print(f"Error creating users table in schema '{schema_name}': {e}")
        return False