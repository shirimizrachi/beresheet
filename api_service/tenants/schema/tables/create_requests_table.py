"""
DDL script for creating the requests table in a specific schema using SQLAlchemy ORM
Usage with API engine: create_requests_table(engine, schema_name)
"""

from sqlalchemy import Column, String, Integer, DateTime, Text, func, Index, event, Unicode, UnicodeText
from sqlalchemy.ext.declarative import declarative_base
import logging

logger = logging.getLogger(__name__)

def create_requests_table(engine, schema_name: str, drop_if_exists: bool = True):
    """
    Create the requests table in the specified schema using SQLAlchemy ORM
    
    Args:
        engine: SQLAlchemy engine object
        schema_name: Name of the schema where the table should be created
        drop_if_exists: Whether to drop the table if it already exists
    """
    
    try:
        # Create a new base for this table
        Base = declarative_base()
        
        class RequestsTable(Base):
            __tablename__ = 'requests'
            __table_args__ = {'schema': schema_name}
            
            id = Column(String(50), primary_key=True)
            
            # Resident information
            resident_id = Column(String(50), nullable=False)
            resident_phone_number = Column(String(20))
            resident_full_name = Column(Unicode(100))
            resident_fcm_token = Column(String(500))
            
            # Service provider information
            service_provider_id = Column(String(50), nullable=False)
            service_provider_full_name = Column(Unicode(100))
            service_provider_phone_number = Column(String(20))
            service_provider_fcm_token = Column(String(500))
            service_provider_type_name = Column(Unicode(100))
            service_provider_type_description = Column(Unicode(500))
            
            # Request details
            request_message = Column(UnicodeText, nullable=False)
            request_status = Column(String(20), default='open')  # 'open', 'in_progress', 'closed', 'abandoned'
            
            # Timestamps
            request_created_at = Column(DateTime, default=func.now())
            request_read_at = Column(DateTime)
            request_closed_by_resident_at = Column(DateTime)
            request_closed_by_service_provider_at = Column(DateTime)
            
            # Communication and feedback
            chat_messages = Column(UnicodeText)  # JSON string array of chat messages
            service_rating = Column(Integer)  # 1-5 rating
            service_comment = Column(UnicodeText)
            
            # Duration calculation (in minutes)
            request_duration_minutes = Column(Integer)
            
            # Standard audit fields
            created_at = Column(DateTime, default=func.now())
            updated_at = Column(DateTime, default=func.now(), onupdate=func.now())
        
        # Drop table if it exists and drop_if_exists is True
        if drop_if_exists:
            try:
                RequestsTable.__table__.drop(engine, checkfirst=True)
                logger.info(f"Dropped existing requests table in schema {schema_name}")
            except Exception as e:
                logger.info(f"No existing requests table to drop in schema {schema_name}: {e}")
        
        # Create the table
        RequestsTable.__table__.create(engine, checkfirst=True)
        
        # Create indexes for better performance
        with engine.connect() as conn:
            # Define indexes
            indexes = [
                Index(f'ix_{schema_name}_requests_resident_id', RequestsTable.resident_id),
                Index(f'ix_{schema_name}_requests_service_provider_id', RequestsTable.service_provider_id),
                Index(f'ix_{schema_name}_requests_status', RequestsTable.request_status),
                Index(f'ix_{schema_name}_requests_created_at', RequestsTable.request_created_at),
                Index(f'ix_{schema_name}_requests_service_provider_status', RequestsTable.service_provider_id, RequestsTable.request_status),
                Index(f'ix_{schema_name}_requests_resident_status', RequestsTable.resident_id, RequestsTable.request_status),
                Index(f'ix_{schema_name}_requests_service_provider_type_name', RequestsTable.service_provider_type_name),
                Index(f'ix_{schema_name}_requests_service_type_status', RequestsTable.service_provider_type_name, RequestsTable.request_status),
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
        
        logger.info(f"Requests table created successfully in schema '{schema_name}' with indexes.")
        print(f"Requests table created successfully in schema '{schema_name}' with indexes.")
        print(f"Table supports communication tracking between residents and service providers.")
        return True
        
    except Exception as e:
        logger.error(f"Error creating requests table in schema '{schema_name}': {e}")
        print(f"Error creating requests table in schema '{schema_name}': {e}")
        return False