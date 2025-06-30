"""
DDL script for creating the service_provider_types table in a specific schema using SQLAlchemy ORM
Usage with API engine: create_service_provider_types_table(engine, schema_name)
"""

from sqlalchemy import Column, String, DateTime, func, Index, Unicode
from sqlalchemy.ext.declarative import declarative_base
import logging

logger = logging.getLogger(__name__)

def create_service_provider_types_table(engine, schema_name: str, drop_if_exists: bool = True):
    """
    Create the service_provider_types table in the specified schema using SQLAlchemy ORM
    
    Args:
        engine: SQLAlchemy engine object
        schema_name: Name of the schema where the table should be created
        drop_if_exists: Whether to drop the table if it already exists
    """
    
    try:
        # Create a new base for this table
        Base = declarative_base()
        
        class ServiceProviderTypesTable(Base):
            __tablename__ = 'service_provider_types'
            __table_args__ = {'schema': schema_name}
            
            id = Column(String(36), primary_key=True)
            name = Column(Unicode(100), unique=True, nullable=False)
            description = Column(Unicode(500))
            created_at = Column(DateTime, default=func.now())
            updated_at = Column(DateTime, default=func.now(), onupdate=func.now())
        
        # Drop table if it exists and drop_if_exists is True
        if drop_if_exists:
            try:
                ServiceProviderTypesTable.__table__.drop(engine, checkfirst=True)
                logger.info(f"Dropped existing service_provider_types table in schema {schema_name}")
            except Exception as e:
                logger.info(f"No existing service_provider_types table to drop in schema {schema_name}: {e}")
        
        # Create the table
        ServiceProviderTypesTable.__table__.create(engine, checkfirst=True)
        
        # Note: No additional indexes needed for 'name' column since it has a unique constraint
        # Both Oracle and SQL Server automatically create indexes for unique constraints
        logger.info(f"Index for 'name' column automatically created by unique constraint")
        
        logger.info(f"Service provider types table created successfully in schema '{schema_name}' with indexes.")
        print(f"Service provider types table created successfully in schema '{schema_name}' with indexes.")
        return True
        
    except Exception as e:
        logger.error(f"Error creating service_provider_types table in schema '{schema_name}': {e}")
        print(f"Error creating service_provider_types table in schema '{schema_name}': {e}")
        return False