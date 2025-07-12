"""
DDL script for creating the home_notification table in a specific schema using SQLAlchemy ORM
Usage with API engine: create_home_notification_table(engine, schema_name)
"""

from sqlalchemy import Column, String, Integer, DateTime, Text, func, Index, CheckConstraint, Unicode
from sqlalchemy.ext.declarative import declarative_base
import logging

logger = logging.getLogger(__name__)

def create_home_notification_table(engine, schema_name: str, drop_if_exists: bool = True):
    """
    Create the home_notification table in the specified schema using SQLAlchemy ORM
    
    Args:
        engine: SQLAlchemy engine object
        schema_name: Name of the schema where the table should be created
        drop_if_exists: Whether to drop the table if it already exists
    """
    
    try:
        # Create a new base for this table
        Base = declarative_base()
        
        class HomeNotificationTable(Base):
            __tablename__ = 'home_notification'
            __table_args__ = (
                CheckConstraint("send_status IN ('pending-approval', 'approved', 'canceled', 'sent')", 
                               name=f'ck_{schema_name}_home_notification_send_status'),
                CheckConstraint("send_type IN ('regular', 'urgent')", 
                               name=f'ck_{schema_name}_home_notification_send_type'),
                {'schema': schema_name}
            )
            
            id = Column(String(36), primary_key=True)
            create_by_user_id = Column(String(50), nullable=False)
            create_by_user_name = Column(Unicode(255), nullable=False)
            create_by_user_role_name = Column(Unicode(100), nullable=False)
            create_by_user_service_provider_type_name = Column(Unicode(255))
            message = Column(Unicode(1000), nullable=False)
            send_status = Column(String(50), nullable=False, default='pending-approval')
            send_approved_by_user_id = Column(String(50))
            send_floor = Column(Integer)
            send_datetime = Column(DateTime, nullable=False, default=func.now())
            send_type = Column(String(20), nullable=False, default='regular')
            created_at = Column(DateTime, default=func.now())
            updated_at = Column(DateTime, default=func.now(), onupdate=func.now())
        
        # Drop table if it exists and drop_if_exists is True
        if drop_if_exists:
            try:
                HomeNotificationTable.__table__.drop(engine, checkfirst=True)
                logger.info(f"Dropped existing home_notification table in schema {schema_name}")
            except Exception as e:
                logger.info(f"No existing home_notification table to drop in schema {schema_name}: {e}")
        
        # Create the table
        HomeNotificationTable.__table__.create(engine, checkfirst=True)
        
        # Create indexes for better performance
        with engine.connect() as conn:
            # Define indexes
            indexes = [
                Index(f'ix_{schema_name}_home_notification_send_status', HomeNotificationTable.send_status),
                Index(f'ix_{schema_name}_home_notification_send_datetime', HomeNotificationTable.send_datetime),
                Index(f'ix_{schema_name}_home_notification_create_by_user_id', HomeNotificationTable.create_by_user_id),
                Index(f'ix_{schema_name}_home_notification_send_floor', HomeNotificationTable.send_floor),
                Index(f'ix_{schema_name}_home_notification_status_date', HomeNotificationTable.send_status, HomeNotificationTable.send_datetime.desc()),
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
        
        logger.info(f"Home notification table created successfully in schema '{schema_name}' with indexes and constraints.")
        print(f"Home notification table created successfully in schema '{schema_name}' with indexes and constraints.")
        return True
        
    except Exception as e:
        logger.error(f"Error creating home notification table in schema '{schema_name}': {e}")
        print(f"Error creating home notification table in schema '{schema_name}': {e}")
        return False
