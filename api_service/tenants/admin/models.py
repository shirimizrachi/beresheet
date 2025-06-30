"""
SQLAlchemy models for residents database tables
Abstract models that work across different database engines (SQL Server, MySQL, Oracle)
"""

import os
from sqlalchemy import Column, Integer, String, DateTime, Text, Boolean, func
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.schema import CreateSchema
from datetime import datetime

Base = declarative_base()

class HomeModel(Base):
    """
    Home table model for managing all homes
    Works across SQL Server, MySQL, and Oracle
    """
    __tablename__ = 'home'
    
    # Use manual ID assignment for cross-database compatibility
    id = Column(Integer, primary_key=True)
    
    name = Column(String(50), nullable=False, unique=True)
    database_name = Column(String(50), nullable=False)
    database_type = Column(String(20), nullable=False, default='mssql')
    database_schema = Column(String(50), nullable=False)
    admin_user_email = Column(String(100), nullable=False)
    admin_user_password = Column(String(100), nullable=False)
    created_at = Column(DateTime, nullable=False, default=func.now())
    updated_at = Column(DateTime, nullable=False, default=func.now(), onupdate=func.now())

class HomeIndexModel(Base):
    """
    Home Index table model for phone number to home mapping
    Works across SQL Server, MySQL, and Oracle
    """
    __tablename__ = 'home_index'
    
    phone_number = Column(String(20), primary_key=True)
    home_id = Column(Integer, nullable=False)
    home_name = Column(String(50), nullable=False)
    created_at = Column(DateTime, nullable=False, default=func.now())
    updated_at = Column(DateTime, nullable=False, default=func.now(), onupdate=func.now())

def create_home_table(engine, schema_name: str = None):
    """
    Create home table using SQLAlchemy model
    
    Args:
        engine: SQLAlchemy engine
        schema_name: Schema name to create table in (optional)
    """
    # Create a copy of the model with schema if provided
    if schema_name:
        # Create a new Base for the schema-specific model
        SchemaBase = declarative_base()
        
        class HomeModelWithSchema(SchemaBase):
            __tablename__ = 'home'
            __table_args__ = {'schema': schema_name}
            
            # Copy all columns from the original model
            id = Column(Integer, primary_key=True)
            name = Column(String(50), nullable=False, unique=True)
            database_name = Column(String(50), nullable=False)
            database_type = Column(String(20), nullable=False, default='mssql')
            database_schema = Column(String(50), nullable=False)
            admin_user_email = Column(String(100), nullable=False)
            admin_user_password = Column(String(100), nullable=False)
            created_at = Column(DateTime, nullable=False, default=func.now())
            updated_at = Column(DateTime, nullable=False, default=func.now(), onupdate=func.now())
        
        HomeModelWithSchema.metadata.create_all(engine)
    else:
        HomeModel.metadata.create_all(engine)

def create_home_index_table(engine, schema_name: str = None):
    """
    Create home_index table using SQLAlchemy model
    
    Args:
        engine: SQLAlchemy engine
        schema_name: Schema name to create table in (optional)
    """
    # Create a copy of the model with schema if provided
    if schema_name:
        # Create a new Base for the schema-specific model
        SchemaBase = declarative_base()
        
        class HomeIndexModelWithSchema(SchemaBase):
            __tablename__ = 'home_index'
            __table_args__ = {'schema': schema_name}
            
            # Copy all columns from the original model
            phone_number = Column(String(20), primary_key=True)
            home_id = Column(Integer, nullable=False)
            home_name = Column(String(50), nullable=False)
            created_at = Column(DateTime, nullable=False, default=func.now())
            updated_at = Column(DateTime, nullable=False, default=func.now(), onupdate=func.now())
        
        HomeIndexModelWithSchema.metadata.create_all(engine)
    else:
        HomeIndexModel.metadata.create_all(engine)

def create_all_tables(engine, home_schema_name: str = None, home_index_name: str = None):
    """
    Create all tables using SQLAlchemy models
    
    Args:
        engine: SQLAlchemy engine
        home_schema_name: Schema name for home table (optional)
        home_index_name: Schema name for home_index table (optional)
    """
    create_home_table(engine, home_schema_name)
    create_home_index_table(engine, home_index_name)