"""
Additional admin API routes (continued from admin_routes.py due to size)
These routes will be included in the main admin_routes.py
"""

from fastapi import HTTPException
from typing import List, Optional
import logging
import importlib.util
import sys
from pathlib import Path
from sqlalchemy import text

from tenant_config import tenant_config_db, get_tenant_connection_string
from database_utils import get_tenant_engine
from .admin_service import admin_service

# Set up logging
logger = logging.getLogger(__name__)

# These functions will be added to the admin_api_router in admin_routes.py

async def create_tables_for_tenant_endpoint(tenant_name: str, drop_if_exists: bool = True):
    """
    Create all tables for a specific tenant using the API engine system
    
    Args:
        tenant_name: Name of the tenant to create tables for
        drop_if_exists: Whether to drop tables if they already exist
        
    Returns:
        Success message with details of created tables
    """
    try:
        result = await admin_service.create_tables_for_tenant(tenant_name, drop_if_exists)
        return result
        
    except Exception as e:
        logger.error(f"Error creating tables for tenant '{tenant_name}': {e}")
        raise HTTPException(status_code=500, detail=f"Error creating tables: {str(e)}")

async def get_tenant_tables_endpoint(tenant_name: str):
    """
    Get all tables for a specific tenant schema
    
    Args:
        tenant_name: Name of the tenant to get tables for
        
    Returns:
        List of tables in the tenant's schema
    """
    try:
        # Get tenant configuration
        tenant = tenant_config_db.load_tenant_config_from_db(tenant_name)
        if not tenant:
            raise HTTPException(status_code=404, detail=f"Tenant '{tenant_name}' not found")
        
        # Get tenant connection string and engine
        connection_string = get_tenant_connection_string(tenant)
        engine = get_tenant_engine(connection_string, tenant_name)
        
        if not engine:
            raise HTTPException(status_code=500, detail=f"Could not create database engine for tenant '{tenant_name}'")
        
        with engine.connect() as conn:
            # Use database-agnostic approach to get tables
            from sqlalchemy import inspect
            inspector = inspect(engine)
            
            # Get table names for the schema
            table_names = inspector.get_table_names(schema=tenant.database_schema)
            
            tables = []
            for table_name in table_names:
                # Get column count
                columns = inspector.get_columns(table_name, schema=tenant.database_schema)
                column_count = len(columns)
                
                # For row count, we'll use a simple database-agnostic query
                try:
                    if tenant.database_type == "oracle":
                        count_sql = text(f'SELECT COUNT(*) FROM "{tenant.database_schema}"."{table_name}"')
                    else:
                        count_sql = text(f'SELECT COUNT(*) FROM [{tenant.database_schema}].[{table_name}]')
                    
                    row_count_result = conn.execute(count_sql)
                    row_count = row_count_result.scalar() or 0
                except Exception:
                    # If row count query fails, default to 0
                    row_count = 0
                
                tables.append({
                    "table_name": table_name,
                    "table_type": "BASE TABLE",
                    "column_count": column_count,
                    "row_count": row_count
                })
            
            logger.info(f"Retrieved {len(tables)} tables for tenant '{tenant_name}'")
            return {
                "tenant_name": tenant_name,
                "schema": tenant.database_schema,
                "tables": tables,
                "total_tables": len(tables)
            }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error retrieving tables for tenant '{tenant_name}': {e}")
        raise HTTPException(status_code=500, detail=f"Error retrieving tables: {str(e)}")

async def recreate_table_endpoint(tenant_name: str, table_name: str, drop_if_exists: bool = True, load_data: bool = False):
    """
    Recreate a specific table for a tenant
    
    Args:
        tenant_name: Name of the tenant
        table_name: Name of the table to recreate
        drop_if_exists: Whether to drop the table if it exists
        load_data: Whether to load demo data after table creation
        
    Returns:
        Success message with recreation details
    """
    try:
        # Get tenant configuration
        tenant = tenant_config_db.load_tenant_config_from_db(tenant_name)
        if not tenant:
            raise HTTPException(status_code=404, detail=f"Tenant '{tenant_name}' not found")
        
        # Get tenant connection string and engine
        connection_string = get_tenant_connection_string(tenant)
        engine = get_tenant_engine(connection_string, tenant_name)
        
        if not engine:
            raise HTTPException(status_code=500, detail=f"Could not create database engine for tenant '{tenant_name}'")
        
        # Map table names to their creation scripts
        table_script_mapping = {
            "users": "create_users_table",
            "service_provider_types": "create_service_provider_types_table",
            "event_instructor": "create_event_instructor_table",
            "events": "create_events_table",
            "rooms": "create_rooms_table",
            "event_gallery": "create_event_gallery_table",
            "events_registration": "create_events_registration_table",
            "home_notification": "create_home_notification_table",
            "user_notification": "create_user_notification_table",
            "requests": "create_requests_table"
        }
        
        script_name = table_script_mapping.get(table_name.lower())
        if not script_name:
            raise HTTPException(status_code=400, detail=f"Unknown table '{table_name}'. Available tables: {', '.join(table_script_mapping.keys())}")
        
        # Base path for table scripts
        tables_path = Path(__file__).parent.parent.parent / "deployment" / "schema" / "tables"
        script_path = tables_path / f"{script_name}.py"
        
        if not script_path.exists():
            raise HTTPException(status_code=404, detail=f"Table creation script not found: {script_name}.py")
        
        try:
            # Load the module dynamically
            spec = importlib.util.spec_from_file_location(script_name, script_path)
            module = importlib.util.module_from_spec(spec)
            
            # Add the module to sys.modules temporarily
            sys.modules[script_name] = module
            spec.loader.exec_module(module)
            
            # Get the main creation function
            function_name = script_name.replace("create_", "create_").replace("_table", "_table")
            if not hasattr(module, function_name):
                raise HTTPException(status_code=500, detail=f"Function {function_name} not found in {script_name}")
            
            # Call the function with engine, schema, and drop flag
            success = module.__dict__[function_name](engine, tenant.database_schema, drop_if_exists)
            
            # Clean up module from sys.modules
            del sys.modules[script_name]
            
            if success:
                logger.info(f"Successfully recreated table '{table_name}' for tenant '{tenant_name}'")
                return {
                    "status": "success",
                    "message": f"Table '{table_name}' recreated successfully",
                    "tenant_name": tenant_name,
                    "table_name": table_name,
                    "schema": tenant.database_schema,
                    "dropped_before_create": drop_if_exists
                }
            else:
                raise HTTPException(status_code=500, detail=f"Failed to recreate table '{table_name}'")
                
        except Exception as e:
            logger.error(f"Error executing table recreation script {script_name}: {e}")
            raise HTTPException(status_code=500, detail=f"Error recreating table: {str(e)}")
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error recreating table '{table_name}' for tenant '{tenant_name}': {e}")
        raise HTTPException(status_code=500, detail=f"Error recreating table: {str(e)}")

async def load_data_for_table_endpoint(tenant_name: str, table_name: str):
    """
    Load demo data for a specific table without recreating it
    
    Args:
        tenant_name: Name of the tenant
        table_name: Name of the table to load data for
        
    Returns:
        Success message with data loading details
    """
    try:
        # Get tenant configuration
        tenant = tenant_config_db.load_tenant_config_from_db(tenant_name)
        if not tenant:
            raise HTTPException(status_code=404, detail=f"Tenant '{tenant_name}' not found")
        
        # Get tenant connection string and engine
        connection_string = get_tenant_connection_string(tenant)
        engine = get_tenant_engine(connection_string, tenant_name)
        
        if not engine:
            raise HTTPException(status_code=500, detail=f"Could not create database engine for tenant '{tenant_name}'")
        
        # Load data for the specific table
        data_loaded = await load_table_data(tenant_name, table_name, engine, tenant.database_schema, tenant.id)
        
        if data_loaded:
            logger.info(f"Successfully loaded demo data for table '{table_name}' in tenant '{tenant_name}'")
            return {
                "status": "success",
                "message": f"Demo data loaded successfully for table '{table_name}'",
                "tenant_name": tenant_name,
                "table_name": table_name,
                "schema": tenant.database_schema,
                "data_loaded": True
            }
        else:
            raise HTTPException(status_code=400, detail=f"Failed to load demo data for table '{table_name}'. Data may not be available for this table.")
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error loading data for table '{table_name}' in tenant '{tenant_name}': {e}")
        raise HTTPException(status_code=500, detail=f"Error loading data: {str(e)}")

async def load_table_data(tenant_name: str, table_name: str, engine, schema_name: str, tenant_id: int):
    """
    Load demo data for a specific table using the new loading functions
    
    Args:
        tenant_name: Name of the tenant
        table_name: Name of the table to load data for
        engine: Database engine (kept for compatibility but not used)
        schema_name: Database schema name (kept for compatibility but not used)
        tenant_id: Tenant ID
        
    Returns:
        Boolean indicating success
    """
    try:
        from tenants.load_events import load_events_sync
        from tenants.load_users import load_users_sync
        from tenants.load_event_instructor import load_event_instructor_sync
        from tenants.load_rooms import load_rooms_sync
        from tenants.load_service_provider_types import load_service_provider_types_sync
        from tenants.load_home_notification import load_home_notification_sync
        
        # Map table names to their new loading functions
        table_loader_mapping = {
            "users": load_users_sync,
            "service_provider_types": load_service_provider_types_sync,
            "event_instructor": load_event_instructor_sync,
            "events": load_events_sync,
            "rooms": load_rooms_sync,
            "home_notification": load_home_notification_sync,
            # Note: user_notification is automatically created by home_notification, so we redirect to that
            "user_notification": load_home_notification_sync
        }
        
        loader_function = table_loader_mapping.get(table_name.lower())
        if not loader_function:
            logger.warning(f"No loader available for table '{table_name}'. Available tables: {', '.join(table_loader_mapping.keys())}")
            return False
        
        # Call the appropriate loading function
        logger.info(f"Loading data for table '{table_name}' using new loading function")
        success = loader_function(tenant_name, tenant_id)
        
        if success:
            logger.info(f"Successfully loaded demo data for table '{table_name}' using new loading system")
            return True
        else:
            logger.error(f"Failed to load demo data for table '{table_name}' using new loading system")
            return False
        
    except Exception as e:
        logger.error(f"Error loading demo data for table '{table_name}': {e}")
        return False

async def init_data_for_tenant_endpoint(tenant_name: str):
    """
    Initialize demo data for a tenant including service provider types, users, 
    home notifications, rooms, event instructors, events with images
    """
    try:
        result = await admin_service.init_data_for_tenant(tenant_name)
        return result
        
    except Exception as e:
        logger.error(f"Error initializing demo data for tenant '{tenant_name}': {e}")
        raise HTTPException(status_code=500, detail=f"Error initializing demo data: {str(e)}")

async def create_schema_and_user_endpoint(schema_name: str):
    """
    Create a new database schema and a user with full permissions
    Automatically detects database engine and uses appropriate implementation
    """
    try:
        result = await admin_service.create_schema_and_user(schema_name)
        
        # Check result status
        if result["status"] == "error":
            raise HTTPException(status_code=400, detail=result["message"])
        
        return result
            
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error creating schema '{schema_name}': {e}")
        raise HTTPException(status_code=500, detail=f"Error creating schema: {str(e)}")