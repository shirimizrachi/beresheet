"""
Database utilities for schema-specific connections
Shared utilities for users, events, and events_registration modules
Enhanced for multi-tenant architecture
"""

import logging
from sqlalchemy import create_engine, event
from typing import Dict, Optional
from tenant_config import get_tenant_connection_string_by_home_id, get_schema_name_by_home_id, get_tenant_connection_string, load_tenant_config_from_db


class SchemaEngineManager:
    """Manages database engines for different schemas"""
    
    def __init__(self):
        self._schema_engines: Dict[str, any] = {}
    
    def get_schema_engine(self, schema_name: str):
        """Get the engine for a specific schema"""
        if schema_name in self._schema_engines:
            return self._schema_engines[schema_name]
        
        # Get tenant config for the schema
        all_tenants = []
        try:
            from tenant_config import get_all_tenants
            all_tenants = get_all_tenants()
        except Exception as e:
            print(f"Failed to load tenant configurations: {e}")
            return None
        
        # Find tenant with matching schema
        tenant_config = None
        for tenant in all_tenants:
            if tenant.database_schema == schema_name:
                tenant_config = tenant
                break
        
        if not tenant_config:
            print(f"No tenant configuration found for schema: {schema_name}")
            return None
        
        # Get schema-specific connection string
        schema_connection_string = get_tenant_connection_string(tenant_config)
        
        # Log the tenant connection being used (without password for security)
        safe_connection_string = schema_connection_string
        if ":" in safe_connection_string and "@" in safe_connection_string:
            # Find password part and replace it with ***
            parts = safe_connection_string.split("://")[1]
            if "@" in parts:
                user_pass, rest = parts.split("@", 1)
                if ":" in user_pass:
                    user, password = user_pass.split(":", 1)
                    safe_connection_string = schema_connection_string.replace(f":{password}@", ":***@")
        
        # Create and cache schema-specific engine
        try:
            schema_engine = create_engine(schema_connection_string)
            self._schema_engines[schema_name] = schema_engine
            return schema_engine
        except Exception as e:
            print(f"Error creating engine for schema {schema_name}: {e}")
            return None
    
    def get_engine_for_home(self, home_id: int):
        """Get the engine for a specific home ID"""
        schema_name = get_schema_name_by_home_id(home_id)
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
            
            # Test the connection immediately to catch errors early
            with engine.connect() as test_conn:
                from sqlalchemy import text
                test_conn.execute(text('SELECT 1 FROM DUAL'))
            
            schema_engine_manager._tenant_engines[tenant_name] = engine
            
        except Exception as e:
            logging.error(f"Error creating tenant engine for {tenant_name}: {e}")
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
        except Exception as e:
            logging.warning(f"Could not set schema context for {tenant_name}: {e}")
        
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