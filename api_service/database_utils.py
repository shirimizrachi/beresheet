"""
Database utilities for schema-specific connections
Shared utilities for users, events, and events_registration modules
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