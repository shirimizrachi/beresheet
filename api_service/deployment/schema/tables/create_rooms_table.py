"""
DDL script for creating the rooms table in a specific schema using SQLAlchemy ORM
Usage with API engine: create_rooms_table(engine, schema_name)
"""

from sqlalchemy import Column, String, DateTime, func, Index, Unicode
from sqlalchemy.ext.declarative import declarative_base
import logging

logger = logging.getLogger(__name__)

def create_rooms_table(engine, schema_name: str, drop_if_exists: bool = True):
    """
    Create the rooms table in the specified schema using SQLAlchemy ORM
    
    Args:
        engine: SQLAlchemy engine object
        schema_name: Name of the schema where the table should be created
        drop_if_exists: Whether to drop the table if it already exists
    """
    
    try:
        # Create a new base for this table
        Base = declarative_base()
        
        class RoomsTable(Base):
            __tablename__ = 'rooms'
            __table_args__ = {'schema': schema_name}
            
            id = Column(String(36), primary_key=True)
            room_name = Column(Unicode(100), nullable=False, unique=True)
            created_at = Column(DateTime, default=func.now())
            updated_at = Column(DateTime, default=func.now(), onupdate=func.now())
        
        # Drop table if it exists and drop_if_exists is True
        if drop_if_exists:
            try:
                RoomsTable.__table__.drop(engine, checkfirst=True)
                logger.info(f"Dropped existing rooms table in schema {schema_name}")
            except Exception as e:
                logger.info(f"No existing rooms table to drop in schema {schema_name}: {e}")
        
        # Create the table
        RoomsTable.__table__.create(engine, checkfirst=True)
        
        # Create indexes for better performance
        with engine.connect() as conn:
            # Define indexes
            indexes = [
                Index(f'ix_{schema_name}_rooms_room_name', RoomsTable.room_name),
            ]
            
            # Create each index
            for index in indexes:
                try:
                    index.create(engine, checkfirst=True)
                except Exception as e:
                    logger.warning(f"Could not create index {index.name}: {e}")
            
            conn.commit()
        
        logger.info(f"Rooms table created successfully in schema '{schema_name}' with indexes.")
        print(f"Rooms table created successfully in schema '{schema_name}' with indexes.")
        return True
        
    except Exception as e:
        logger.error(f"Error creating rooms table in schema '{schema_name}': {e}")
        print(f"Error creating rooms table in schema '{schema_name}': {e}")
        return False