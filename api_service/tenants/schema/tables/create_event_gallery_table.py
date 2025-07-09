"""
DDL script for creating the event_gallery table in a specific schema using SQLAlchemy ORM
Usage with API engine: create_event_gallery_table(engine, schema_name)
"""

from sqlalchemy import Column, String, DateTime, func, Index
from sqlalchemy.ext.declarative import declarative_base
import logging

logger = logging.getLogger(__name__)

def create_event_gallery_table(engine, schema_name: str, drop_if_exists: bool = True):
    """
    Create the event_gallery table in the specified schema using SQLAlchemy ORM
    
    Args:
        engine: SQLAlchemy engine object
        schema_name: Name of the schema where the table should be created
        drop_if_exists: Whether to drop the table if it already exists
    """
    
    try:
        # Create a new base for this table
        Base = declarative_base()
        
        class EventGalleryTable(Base):
            __tablename__ = 'event_gallery'
            __table_args__ = {'schema': schema_name}
            
            photo_id = Column(String(50), primary_key=True)
            event_id = Column(String(50), nullable=False)
            photo = Column(String(500), nullable=False)
            thumbnail_url = Column(String(500))
            status = Column(String(20), nullable=False, default='private')
            created_at = Column(DateTime, default=func.now())
            updated_at = Column(DateTime, default=func.now(), onupdate=func.now())
            created_by = Column(String(50))
        
        # Drop table if it exists and drop_if_exists is True
        if drop_if_exists:
            try:
                EventGalleryTable.__table__.drop(engine, checkfirst=True)
                logger.info(f"Dropped existing event_gallery table in schema {schema_name}")
            except Exception as e:
                logger.info(f"No existing event_gallery table to drop in schema {schema_name}: {e}")
        
        # Create the table
        EventGalleryTable.__table__.create(engine, checkfirst=True)
        
        # Create indexes for better performance
        with engine.connect() as conn:
            # Define indexes
            indexes = [
                Index(f'ix_{schema_name}_event_gallery_event_id', EventGalleryTable.event_id),
                Index(f'ix_{schema_name}_event_gallery_created_at', EventGalleryTable.created_at),
                Index(f'ix_{schema_name}_event_gallery_created_by', EventGalleryTable.created_by),
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
        
        logger.info(f"Event gallery table created successfully in schema '{schema_name}' with indexes.")
        print(f"Event gallery table created successfully in schema '{schema_name}' with indexes.")
        return True
        
    except Exception as e:
        logger.error(f"Error creating event_gallery table in schema '{schema_name}': {e}")
        print(f"Error creating event_gallery table in schema '{schema_name}': {e}")
        return False