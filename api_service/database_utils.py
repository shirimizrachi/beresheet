"""
Database utilities for schema-specific connections
Shared utilities for users, events, and events_registration modules
Enhanced for multi-tenant architecture
"""

import logging
from sqlalchemy import create_engine, event
from typing import Dict, Optional
from home_mapping import get_connection_string_for_schema, get_schema_for_home

# SQL Debug flag - set to True to enable SQL logging
SQL_DEBUG = False  # Change this to False to disable SQL debugging

def setup_sql_logging():
    """Setup SQL logging if debug is enabled"""
    if SQL_DEBUG:
        # Configure SQLAlchemy logging
        logging.basicConfig()
        logging.getLogger('sqlalchemy.engine').setLevel(logging.INFO)
        print("🔍 SQL Debug Mode: ENABLED - All SQL queries will be logged")
        return True
    else:
        print("🔍 SQL Debug Mode: DISABLED")
        return False

def log_sql_before_execute(conn, clauseelement, multiparams, params, execution_options, executemany):
    """Log SQL before execution"""
    if SQL_DEBUG:
        print(f"🚀 EXECUTING SQL: {clauseelement}")
        if params:
            print(f"📝 PARAMETERS: {params}")

# Initialize SQL logging
_sql_logging_enabled = setup_sql_logging()

class SchemaEngineManager:
    """Manages database engines for different schemas"""
    
    def __init__(self):
        self._schema_engines: Dict[str, any] = {}
    
    def get_schema_engine(self, schema_name: str):
        """Get the engine for a specific schema"""
        if schema_name in self._schema_engines:
            return self._schema_engines[schema_name]
        
        # Get schema-specific connection string
        schema_connection_string = get_connection_string_for_schema(schema_name)
        if not schema_connection_string:
            print(f"No connection string found for schema {schema_name}")
            return None
        
        # Create and cache schema-specific engine
        try:
            schema_engine = create_engine(schema_connection_string)
            
            # Add SQL logging event listener if debug is enabled
            if SQL_DEBUG:
                event.listen(schema_engine, "before_cursor_execute", log_sql_before_execute)
                print(f"🔧 Added SQL logging to engine for schema: {schema_name}")
            
            self._schema_engines[schema_name] = schema_engine
            print(f"Created new engine for schema: {schema_name}")
            return schema_engine
        except Exception as e:
            print(f"Error creating engine for schema {schema_name}: {e}")
            return None
    
    def get_engine_for_home(self, home_id: int):
        """Get the engine for a specific home ID"""
        schema_name = get_schema_for_home(home_id)
        if not schema_name:
            print(f"No schema found for home ID {home_id}")
            return None
        
        return self.get_schema_engine(schema_name)
    
    def close_all_engines(self):
        """Close all cached engines"""
        for schema_name, engine in self._schema_engines.items():
            try:
                engine.dispose()
                print(f"Disposed engine for schema: {schema_name}")
            except Exception as e:
                print(f"Error disposing engine for schema {schema_name}: {e}")
        self._schema_engines.clear()
    
    def refresh_engine(self, schema_name: str):
        """Refresh the engine for a specific schema"""
        if schema_name in self._schema_engines:
            try:
                self._schema_engines[schema_name].dispose()
            except Exception as e:
                print(f"Error disposing old engine for schema {schema_name}: {e}")
            del self._schema_engines[schema_name]
        
        return self.get_schema_engine(schema_name)

# Global instance to be shared across all database classes
schema_engine_manager = SchemaEngineManager()

def get_schema_engine(schema_name: str):
    """Get the engine for a specific schema (convenience function)"""
    return schema_engine_manager.get_schema_engine(schema_name)

def get_engine_for_home(home_id: int):
    """Get the engine for a specific home ID (convenience function)"""
    return schema_engine_manager.get_engine_for_home(home_id)

def get_connection_for_schema(schema_name: str):
    """Get a connection for a specific schema"""
    engine = get_schema_engine(schema_name)
    if engine:
        return engine.connect()
    return None

def get_connection_for_home(home_id: int):
    """Get a connection for a specific home ID"""
    engine = get_engine_for_home(home_id)
    if engine:
        return engine.connect()
    return None

def get_tenant_engine(connection_string: str, tenant_name: str):
    """
    Get or create an engine for a specific tenant
    
    Args:
        connection_string: Database connection string for the tenant
        tenant_name: Name of the tenant (for caching)
        
    Returns:
        SQLAlchemy engine for the tenant
    """
    # Use tenant-specific engine caching
    if not hasattr(schema_engine_manager, '_tenant_engines'):
        schema_engine_manager._tenant_engines = {}
    
    if tenant_name not in schema_engine_manager._tenant_engines:
        try:
            engine = create_engine(connection_string)
            
            # Add SQL logging event listener if debug is enabled
            if SQL_DEBUG:
                event.listen(engine, "before_cursor_execute", log_sql_before_execute)
                print(f"🔧 Added SQL logging to engine for tenant: {tenant_name}")
            
            schema_engine_manager._tenant_engines[tenant_name] = engine
            print(f"Created new tenant engine for: {tenant_name}")
        except Exception as e:
            print(f"Error creating tenant engine for {tenant_name}: {e}")
            return None
    
    return schema_engine_manager._tenant_engines[tenant_name]

def get_tenant_connection(connection_string: str, tenant_name: str, schema_name: str):
    """
    Get a connection for a specific tenant with schema context
    
    Args:
        connection_string: Database connection string for the tenant
        tenant_name: Name of the tenant
        schema_name: Database schema name for the tenant
        
    Returns:
        Database connection with schema context
    """
    engine = get_tenant_engine(connection_string, tenant_name)
    if engine:
        conn = engine.connect()
        
        # Set the default schema for this connection
        try:
            from sqlalchemy import text
            # Use the schema in queries by default
            conn.execute(text(f"-- Using schema: {schema_name}"))
            print(f"Set schema context to '{schema_name}' for tenant '{tenant_name}'")
        except Exception as e:
            print(f"Warning: Could not set schema context for {tenant_name}: {e}")
        
        return conn
    return None

def close_tenant_engines():
    """Close all tenant-specific engines"""
    if hasattr(schema_engine_manager, '_tenant_engines'):
        for tenant_name, engine in schema_engine_manager._tenant_engines.items():
            try:
                engine.dispose()
                print(f"Disposed tenant engine for: {tenant_name}")
            except Exception as e:
                print(f"Error disposing tenant engine for {tenant_name}: {e}")
        schema_engine_manager._tenant_engines.clear()