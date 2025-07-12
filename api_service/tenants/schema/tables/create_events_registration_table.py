"""
DDL script for creating the events_registration table in a specific schema using SQLAlchemy ORM
Usage with API engine: create_events_registration_table(engine, schema_name)
"""

from sqlalchemy import Column, String, Integer, DateTime, Text, func, Index, UniqueConstraint, CheckConstraint, Unicode
from sqlalchemy.ext.declarative import declarative_base
import logging

logger = logging.getLogger(__name__)

def create_events_registration_table(engine, schema_name: str, drop_if_exists: bool = True):
    """
    Create the events_registration table in the specified schema using SQLAlchemy ORM
    
    Args:
        engine: SQLAlchemy engine object
        schema_name: Name of the schema where the table should be created
        drop_if_exists: Whether to drop the table if it already exists
    """
    
    try:
        # Create a new base for this table
        Base = declarative_base()
        
        class EventsRegistrationTable(Base):
            __tablename__ = 'events_registration'
            __table_args__ = (
                UniqueConstraint('event_id', 'user_id', name=f'uk_{schema_name}_events_registration_user_event'),
                CheckConstraint('vote >= 1 AND vote <= 5', name=f'ck_{schema_name}_events_registration_vote'),
                {'schema': schema_name}
            )
            
            id = Column(String(50), primary_key=True)
            event_id = Column(String(50), nullable=False)
            user_id = Column(String(50), nullable=False)
            user_name = Column(Unicode(100))
            user_phone = Column(String(20))
            registration_date = Column(DateTime, default=func.now())
            status = Column(String(20), default='registered')
            vote = Column(Integer)
            reviews = Column(Unicode(1000))
            instructor_name = Column(Unicode(100))
            instructor_desc = Column(Unicode(1000))
            instructor_photo = Column(String(500))
            created_at = Column(DateTime, default=func.now())
            updated_at = Column(DateTime, default=func.now(), onupdate=func.now())
        
        # Drop table if it exists and drop_if_exists is True
        if drop_if_exists:
            try:
                EventsRegistrationTable.__table__.drop(engine, checkfirst=True)
                logger.info(f"Dropped existing events_registration table in schema {schema_name}")
            except Exception as e:
                logger.info(f"No existing events_registration table to drop in schema {schema_name}: {e}")
        
        # Create the table
        EventsRegistrationTable.__table__.create(engine, checkfirst=True)
        
        # Create indexes for better performance
        with engine.connect() as conn:
            # Define indexes - exclude columns that have unique constraints since both Oracle and SQL Server
            # automatically create indexes for unique constraints
            indexes = [
                # Skip event_id and user_id since they're covered by unique constraint (event_id, user_id)
                Index(f'ix_{schema_name}_events_registration_date', EventsRegistrationTable.registration_date),
                Index(f'ix_{schema_name}_events_registration_status', EventsRegistrationTable.status),
                # Note: Composite index (event_id, registration_date) might also conflict with unique constraint
                # so we'll skip it to be safe
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
        
        logger.info(f"Events registration table created successfully in schema '{schema_name}' with indexes and constraints.")
        print(f"Events registration table created successfully in schema '{schema_name}' with indexes and constraints.")
        return True
        
    except Exception as e:
        logger.error(f"Error creating events registration table in schema '{schema_name}': {e}")
        print(f"Error creating events registration table in schema '{schema_name}': {e}")
        return False