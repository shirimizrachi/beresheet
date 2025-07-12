"""
DDL script for creating the user_notification table in a specific schema using SQLAlchemy ORM
Usage with API engine: create_user_notification_table(engine, schema_name)
"""

from sqlalchemy import Column, String, DateTime, Text, func, Index, CheckConstraint, Unicode
from sqlalchemy.ext.declarative import declarative_base
import logging

logger = logging.getLogger(__name__)

def create_user_notification_table(engine, schema_name: str, drop_if_exists: bool = True):
    """
    Create the user_notification table in the specified schema using SQLAlchemy ORM
    
    Args:
        engine: SQLAlchemy engine object
        schema_name: Name of the schema where the table should be created
        drop_if_exists: Whether to drop the table if it already exists
    """
    
    try:
        # Create a new base for this table
        Base = declarative_base()
        
        class UserNotificationTable(Base):
            __tablename__ = 'user_notification'
            __table_args__ = (
                CheckConstraint("notification_status IN ('pending', 'sent', 'read', 'canceled')", 
                               name=f'ck_{schema_name}_user_notification_status'),
                CheckConstraint("notification_type IN ('regular', 'urgent')", 
                               name=f'ck_{schema_name}_user_notification_type'),
                {'schema': schema_name}
            )
            
            id = Column(String(36), primary_key=True)
            user_id = Column(String(50), nullable=False)
            user_read_date = Column(DateTime)
            user_fcm = Column(Text)
            notification_id = Column(String(36), nullable=False)
            notification_sender_user_id = Column(String(50), nullable=False)
            notification_sender_user_name = Column(Unicode(255), nullable=False)
            notification_sender_user_role_name = Column(Unicode(100), nullable=False)
            notification_sender_user_service_provider_type_name = Column(Unicode(255))
            notification_status = Column(String(20), nullable=False, default='pending')
            notification_time = Column(DateTime, nullable=False, default=func.now())
            notification_message = Column(Unicode(1000), nullable=False)
            notification_type = Column(String(20), nullable=False, default='regular')
            created_at = Column(DateTime, default=func.now())
            updated_at = Column(DateTime, default=func.now(), onupdate=func.now())
        
        # Drop table if it exists and drop_if_exists is True
        if drop_if_exists:
            try:
                UserNotificationTable.__table__.drop(engine, checkfirst=True)
                logger.info(f"Dropped existing user_notification table in schema {schema_name}")
            except Exception as e:
                logger.info(f"No existing user_notification table to drop in schema {schema_name}: {e}")
        
        # Create the table
        UserNotificationTable.__table__.create(engine, checkfirst=True)
        
        # Create indexes for better performance
        with engine.connect() as conn:
            # Define indexes
            indexes = [
                Index(f'ix_{schema_name}_user_notification_user_id', UserNotificationTable.user_id),
                Index(f'ix_{schema_name}_user_notification_notification_id', UserNotificationTable.notification_id),
                Index(f'ix_{schema_name}_user_notification_status', UserNotificationTable.notification_status),
                Index(f'ix_{schema_name}_user_notification_time', UserNotificationTable.notification_time),
                Index(f'ix_{schema_name}_user_notification_user_status', UserNotificationTable.user_id, UserNotificationTable.notification_status),
                Index(f'ix_{schema_name}_user_notification_notif_user', UserNotificationTable.notification_id, UserNotificationTable.user_id),
            ]
            
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
        
        logger.info(f"User notification table created successfully in schema '{schema_name}' with indexes and constraints.")
        print(f"User notification table created successfully in schema '{schema_name}' with indexes and constraints.")
        return True
        
    except Exception as e:
        logger.error(f"Error creating user notification table in schema '{schema_name}': {e}")
        print(f"Error creating user notification table in schema '{schema_name}': {e}")
        return False
