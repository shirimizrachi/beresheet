"""
DDL script for creating the event_instructor table in a specific schema using SQLAlchemy ORM
Usage with API engine: create_event_instructor_table(engine, schema_name)
"""

from sqlalchemy import Column, String, Text, DateTime, func, Index, Unicode
from sqlalchemy.ext.declarative import declarative_base
import logging

logger = logging.getLogger(__name__)

def create_event_instructor_table(engine, schema_name: str, drop_if_exists: bool = True):
    """
    Create the event_instructor table in the specified schema using SQLAlchemy ORM
    
    Args:
        engine: SQLAlchemy engine object
        schema_name: Name of the schema where the table should be created
        drop_if_exists: Whether to drop the table if it already exists
    """
    
    try:
        # Create a new base for this table
        Base = declarative_base()
        
        class EventInstructorTable(Base):
            __tablename__ = 'event_instructor'
            __table_args__ = {'schema': schema_name}
            
            id = Column(String(36), primary_key=True)
            name = Column(Unicode(255), nullable=False)
            description = Column(Unicode(1000))
            photo = Column(Unicode(1000))
            created_at = Column(DateTime, default=func.now())
            updated_at = Column(DateTime, default=func.now(), onupdate=func.now())
        
        # Drop table if it exists and drop_if_exists is True
        if drop_if_exists:
            try:
                EventInstructorTable.__table__.drop(engine, checkfirst=True)
                logger.info(f"Dropped existing event_instructor table in schema {schema_name}")
            except Exception as e:
                logger.info(f"No existing event_instructor table to drop in schema {schema_name}: {e}")
        
        # Create the table
        EventInstructorTable.__table__.create(engine, checkfirst=True)
        
        # Create indexes for better performance
        with engine.connect() as conn:
            # Define indexes
            indexes = [
                Index(f'ix_{schema_name}_event_instructor_name', EventInstructorTable.name),
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
        
        logger.info(f"Event_instructor table created successfully in schema '{schema_name}' with indexes.")
        print(f"Event_instructor table created successfully in schema '{schema_name}' with indexes.")
        return True
        
    except Exception as e:
        logger.error(f"Error creating event_instructor table in schema '{schema_name}': {e}")
        print(f"Error creating event_instructor table in schema '{schema_name}': {e}")
        return False