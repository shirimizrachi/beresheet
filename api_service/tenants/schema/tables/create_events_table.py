"""
DDL script for creating the events table in a specific schema using SQLAlchemy ORM
Usage with API engine: create_events_table(engine, schema_name)
"""

from sqlalchemy import Column, String, Integer, DateTime, Text, func, Index, Unicode
from sqlalchemy.ext.declarative import declarative_base
import logging

logger = logging.getLogger(__name__)

def create_events_table(engine, schema_name: str, drop_if_exists: bool = True):
    """
    Create the events table in the specified schema using SQLAlchemy ORM
    
    Args:
        engine: SQLAlchemy engine object
        schema_name: Name of the schema where the table should be created
        drop_if_exists: Whether to drop the table if it already exists
    """
    
    try:
        # Create a new base for this table
        Base = declarative_base()
        
        class EventsTable(Base):
            __tablename__ = 'events'
            __table_args__ = {'schema': schema_name}
            
            id = Column(String(50), primary_key=True)
            name = Column(Unicode(100), nullable=False)
            type = Column(Unicode(50), nullable=False)
            description = Column(Unicode(1000))
            date_time = Column(DateTime, nullable=False)
            location = Column(Unicode(200))
            max_participants = Column(Integer, nullable=False, default=0)
            current_participants = Column(Integer, nullable=False, default=0)
            image_url = Column(String(500))
            recurring = Column(String(50), default='none')
            recurring_end_date = Column(DateTime)
            recurring_pattern = Column(Unicode(1000))
            instructor_name = Column(Unicode(100))
            instructor_desc = Column(Unicode(1000))
            instructor_photo = Column(String(500))
            created_at = Column(DateTime, default=func.now())
            updated_at = Column(DateTime, default=func.now(), onupdate=func.now())
            created_by = Column(String(50))
            status = Column(String(20), default='active')
        
        # Drop table if it exists and drop_if_exists is True
        if drop_if_exists:
            try:
                EventsTable.__table__.drop(engine, checkfirst=True)
                logger.info(f"Dropped existing events table in schema {schema_name}")
            except Exception as e:
                logger.info(f"No existing events table to drop in schema {schema_name}: {e}")
        
        # Create the table
        EventsTable.__table__.create(engine, checkfirst=True)
        
        # Create indexes for better performance
        with engine.connect() as conn:
            # Define indexes
            indexes = [
                Index(f'ix_{schema_name}_events_type', EventsTable.type),
                Index(f'ix_{schema_name}_events_datetime', EventsTable.date_time),
                Index(f'ix_{schema_name}_events_status', EventsTable.status),
                Index(f'ix_{schema_name}_events_created_by', EventsTable.created_by),
                Index(f'ix_{schema_name}_events_type_datetime', EventsTable.type, EventsTable.date_time),
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
        
        logger.info(f"Events table created successfully in schema '{schema_name}' with indexes.")
        print(f"Events table created successfully in schema '{schema_name}' with indexes.")
        return True
        
    except Exception as e:
        logger.error(f"Error creating events table in schema '{schema_name}': {e}")
        print(f"Error creating events table in schema '{schema_name}': {e}")
        return False