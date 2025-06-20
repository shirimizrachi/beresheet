"""
Admin API endpoints for tenant management
Provides CRUD operations for managing tenant configurations
"""

from fastapi import APIRouter, HTTPException, Depends
from fastapi.responses import FileResponse, HTMLResponse
from typing import List
from tenant_config import (
    TenantConfig,
    TenantCreate,
    TenantUpdate,
    tenant_config_db,
    get_tenant_connection_string
)
import logging
import os
import importlib.util
import sys
from pathlib import Path
from database_utils import get_tenant_engine, get_tenant_connection
from sqlalchemy import text
from azure_storage_service import azure_storage_service

# Set up logging
logger = logging.getLogger(__name__)

# Create admin router
admin_router = APIRouter(prefix="/home/admin", tags=["admin"])

@admin_router.get("/", response_class=HTMLResponse)
async def admin_root():
    """Serve the admin web interface"""
    try:
        # Path to the admin HTML file
        admin_html_path = os.path.join(os.path.dirname(__file__), "admin_web.html")
        
        if os.path.exists(admin_html_path):
            return FileResponse(admin_html_path, media_type="text/html")
        else:
            # Fallback to a simple HTML response if file not found
            return HTMLResponse(content="""
            <!DOCTYPE html>
            <html>
            <head>
                <title>Tenant Management Admin</title>
                <style>
                    body { font-family: Arial, sans-serif; margin: 40px; }
                    .container { max-width: 800px; margin: 0 auto; }
                    .error { color: #e74c3c; background: #fadbd8; padding: 15px; border-radius: 5px; }
                </style>
            </head>
            <body>
                <div class="container">
                    <h1>🏠 Multi-Tenant Management Admin</h1>
                    <div class="error">
                        <h3>Admin interface not available</h3>
                        <p>The admin web interface file is missing. Please ensure admin_web.html exists in the api_service directory.</p>
                        <p>Available API endpoints:</p>
                        <ul>
                            <li><a href="/home/admin/api/tenants">GET /home/admin/api/tenants</a> - List all tenants</li>
                            <li><a href="/home/admin/api/health">GET /home/admin/api/health</a> - Health check</li>
                            <li>POST /home/admin/api/tenants - Create tenant</li>
                            <li>PUT /home/admin/api/tenants/{id} - Update tenant</li>
                            <li>DELETE /home/admin/api/tenants/{id} - Delete tenant</li>
                        </ul>
                    </div>
                </div>
            </body>
            </html>
            """)
    except Exception as e:
        logger.error(f"Error serving admin interface: {e}")
        return HTMLResponse(content=f"""
        <html><body>
            <h1>Error</h1>
            <p>Failed to load admin interface: {str(e)}</p>
            <p><a href="/home/admin/api/tenants">View API directly</a></p>
        </body></html>
        """, status_code=500)

# Admin API endpoints
admin_api_router = APIRouter(prefix="/home/admin/api", tags=["admin-api"])

@admin_api_router.get("/tenants", response_model=List[TenantConfig])
async def get_all_tenants():
    """
    Get all tenant configurations
    
    Returns:
        List of all tenant configurations
    """
    try:
        tenants = tenant_config_db.get_all_tenants()
        logger.info(f"Retrieved {len(tenants)} tenant configurations")
        return tenants
    except Exception as e:
        logger.error(f"Error retrieving tenants: {e}")
        raise HTTPException(status_code=500, detail=f"Error retrieving tenants: {str(e)}")

@admin_api_router.get("/tenants/{tenant_name}", response_model=TenantConfig)
async def get_tenant_by_name(tenant_name: str):
    """
    Get a specific tenant configuration by name
    
    Args:
        tenant_name: Name of the tenant to retrieve
        
    Returns:
        Tenant configuration if found
    """
    try:
        tenant = tenant_config_db.load_tenant_config_from_db(tenant_name)
        if not tenant:
            raise HTTPException(status_code=404, detail=f"Tenant '{tenant_name}' not found")
        
        logger.info(f"Retrieved tenant configuration for '{tenant_name}'")
        return tenant
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error retrieving tenant '{tenant_name}': {e}")
        raise HTTPException(status_code=500, detail=f"Error retrieving tenant: {str(e)}")

@admin_api_router.post("/tenants", response_model=TenantConfig, status_code=201)
async def create_tenant(tenant: TenantCreate):
    """
    Create a new tenant configuration with full setup:
    1. Create the schema and user
    2. Create the tables in the new schema
    3. Initialize tables with demo data
    
    Args:
        tenant: Tenant configuration to create
        
    Returns:
        Created tenant configuration with setup details
    """
    try:
        # Check if tenant name already exists
        existing_tenant = tenant_config_db.load_tenant_config_from_db(tenant.name)
        if existing_tenant:
            raise HTTPException(status_code=400, detail=f"Tenant '{tenant.name}' already exists")
        
        # Validate tenant name (must be alphanumeric)
        if not tenant.name.replace("_", "").replace("-", "").isalnum():
            raise HTTPException(status_code=400, detail="Tenant name must be alphanumeric (with optional hyphens and underscores)")
        
        # Create the tenant configuration first
        new_tenant = tenant_config_db.create_tenant(tenant)
        if not new_tenant:
            raise HTTPException(status_code=400, detail="Failed to create tenant")
        
        logger.info(f"Created new tenant '{tenant.name}' with ID {new_tenant.id}")
        
        # Step 1: Create the schema and user
        try:
            schema_result = await create_schema_and_user(new_tenant.database_schema)
            logger.info(f"Step 1 completed: Created schema and user for tenant '{tenant.name}'")
        except Exception as e:
            logger.error(f"Step 1 failed for tenant '{tenant.name}': {e}")
            # If schema creation fails, we should clean up the tenant config
            tenant_config_db.delete_tenant(new_tenant.id)
            raise HTTPException(status_code=500, detail=f"Failed to create schema and user: {str(e)}")
        
        # Step 2: Create tables in the new schema
        try:
            tables_result = await create_tables_for_tenant(new_tenant.name, drop_if_exists=True)
            logger.info(f"Step 2 completed: Created tables for tenant '{tenant.name}'")
        except Exception as e:
            logger.error(f"Step 2 failed for tenant '{tenant.name}': {e}")
            # Note: We don't clean up schema here as it might be needed for debugging
            raise HTTPException(status_code=500, detail=f"Failed to create tables: {str(e)}")
        
        # Step 3: Initialize tables with demo data
        try:
            init_result = await init_tables_for_tenant(new_tenant.name)
            logger.info(f"Step 3 completed: Initialized tables for tenant '{tenant.name}'")
        except Exception as e:
            logger.error(f"Step 3 failed for tenant '{tenant.name}': {e}")
            # Note: We don't fail the whole process if data initialization fails
            logger.warning(f"Tenant '{tenant.name}' created successfully but data initialization failed: {str(e)}")
        
        # Add setup information to the response
        setup_info = {
            "schema_created": schema_result.get("status") == "success" if 'schema_result' in locals() else False,
            "tables_created": tables_result.get("status") in ["success", "partial_success"] if 'tables_result' in locals() else False,
            "data_initialized": init_result.get("status") in ["success", "partial_success"] if 'init_result' in locals() else False,
            "setup_details": {
                "schema_info": schema_result if 'schema_result' in locals() else None,
                "tables_info": tables_result if 'tables_result' in locals() else None,
                "init_info": init_result if 'init_result' in locals() else None
            }
        }
        
        logger.info(f"Tenant '{tenant.name}' fully created and configured")
        
        # Return the tenant config (the response_model expects TenantConfig)
        # We'll log the setup info but return the standard tenant config
        logger.info(f"Setup summary for tenant '{tenant.name}': {setup_info}")
        return new_tenant
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error creating tenant '{tenant.name}': {e}")
        raise HTTPException(status_code=500, detail=f"Error creating tenant: {str(e)}")

@admin_api_router.put("/tenants/{tenant_id}", response_model=TenantConfig)
async def update_tenant(tenant_id: int, tenant_update: TenantUpdate):
    """
    Update a tenant configuration
    
    Args:
        tenant_id: ID of the tenant to update
        tenant_update: Fields to update
        
    Returns:
        Updated tenant configuration
    """
    try:
        # Check if tenant exists
        tenants = tenant_config_db.get_all_tenants()
        existing_tenant = next((t for t in tenants if t.id == tenant_id), None)
        
        if not existing_tenant:
            raise HTTPException(status_code=404, detail=f"Tenant with ID {tenant_id} not found")
        
        # Update the tenant
        updated_tenant = tenant_config_db.update_tenant(tenant_id, tenant_update)
        if not updated_tenant:
            raise HTTPException(status_code=400, detail="Failed to update tenant")
        
        logger.info(f"Updated tenant with ID {tenant_id}")
        return updated_tenant
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error updating tenant with ID {tenant_id}: {e}")
        raise HTTPException(status_code=500, detail=f"Error updating tenant: {str(e)}")

@admin_api_router.delete("/tenants/{tenant_id}")
async def delete_tenant(tenant_id: int):
    """
    Delete a tenant configuration
    
    Args:
        tenant_id: ID of the tenant to delete
        
    Returns:
        Success message
    """
    try:
        # Check if tenant exists
        tenants = tenant_config_db.get_all_tenants()
        existing_tenant = next((t for t in tenants if t.id == tenant_id), None)
        
        if not existing_tenant:
            raise HTTPException(status_code=404, detail=f"Tenant with ID {tenant_id} not found")
        
        # Delete the tenant
        success = tenant_config_db.delete_tenant(tenant_id)
        if not success:
            raise HTTPException(status_code=400, detail="Failed to delete tenant")
        
        logger.info(f"Deleted tenant '{existing_tenant.name}' with ID {tenant_id}")
        return {"message": f"Tenant '{existing_tenant.name}' deleted successfully"}
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error deleting tenant with ID {tenant_id}: {e}")
        raise HTTPException(status_code=500, detail=f"Error deleting tenant: {str(e)}")

@admin_api_router.get("/tenants/{tenant_name}/connection")
async def get_tenant_connection_info(tenant_name: str):
    """
    Get connection information for a tenant (for testing purposes)
    
    Args:
        tenant_name: Name of the tenant
        
    Returns:
        Connection information (without sensitive data)
    """
    try:
        tenant = tenant_config_db.load_tenant_config_from_db(tenant_name)
        if not tenant:
            raise HTTPException(status_code=404, detail=f"Tenant '{tenant_name}' not found")
        
        connection_string = get_tenant_connection_string(tenant)
        
        # Return connection info without password
        return {
            "tenant_name": tenant.name,
            "database_name": tenant.database_name,
            "database_type": tenant.database_type,
            "database_schema": tenant.database_schema,
            "connection_template": connection_string.replace("Trusted_Connection=yes", "Trusted_Connection=yes [REDACTED]")
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting connection info for tenant '{tenant_name}': {e}")
        raise HTTPException(status_code=500, detail=f"Error getting connection info: {str(e)}")

@admin_api_router.get("/health")
async def admin_health_check():
    """
    Health check for admin API
    
    Returns:
        Health status and tenant count
    """
    try:
        tenants = tenant_config_db.get_all_tenants()
        return {
            "status": "healthy",
            "tenant_count": len(tenants),
            "admin_database": "connected"
        }
    except Exception as e:
        logger.error(f"Admin health check failed: {e}")
        return {
            "status": "unhealthy",
            "error": str(e),
            "admin_database": "disconnected"
        }

@admin_api_router.post("/tenants/{tenant_name}/create_tables")
async def create_tables_for_tenant(tenant_name: str, drop_if_exists: bool = True):
    """
    Create all tables for a specific tenant using the API engine system
    
    Args:
        tenant_name: Name of the tenant to create tables for
        drop_if_exists: Whether to drop tables if they already exist
        
    Returns:
        Success message with details of created tables
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
        
        # List of table creation modules to execute
        table_scripts = [
            "create_users_table",
            "create_service_provider_types_table",
            "create_event_instructor_table",
            "create_events_table",
            "create_rooms_table",
            "create_event_gallery_table",
            "create_events_registration_table",
            "create_home_notification_table",
            "create_user_notification_table",
            "create_requests_table"
        ]
        
        created_tables = []
        failed_tables = []
        
        # Base path for table scripts
        tables_path = Path(__file__).parent / "deployment" / "schema" / "tables"
        
        for script_name in table_scripts:
            try:
                script_path = tables_path / f"{script_name}.py"
                
                if not script_path.exists():
                    logger.warning(f"Table script not found: {script_path}")
                    failed_tables.append(f"{script_name} (file not found)")
                    continue
                
                # Load the module dynamically
                spec = importlib.util.spec_from_file_location(script_name, script_path)
                module = importlib.util.module_from_spec(spec)
                
                # Add the module to sys.modules temporarily
                sys.modules[script_name] = module
                spec.loader.exec_module(module)
                
                # Get the main creation function (assumes it follows naming convention)
                function_name = script_name.replace("create_", "create_").replace("_table", "_table")
                if hasattr(module, function_name):
                    # Call the function with engine, schema, and drop flag
                    success = module.__dict__[function_name](engine, tenant.database_schema, drop_if_exists)
                    if success:
                        created_tables.append(script_name.replace("create_", "").replace("_table", ""))
                        logger.info(f"Successfully created table using {script_name}")
                    else:
                        failed_tables.append(script_name)
                        logger.error(f"Failed to create table using {script_name}")
                else:
                    logger.error(f"Function {function_name} not found in {script_name}")
                    failed_tables.append(f"{script_name} (function not found)")
                
                # Clean up module from sys.modules
                del sys.modules[script_name]
                
            except Exception as e:
                logger.error(f"Error executing table script {script_name}: {e}")
                failed_tables.append(f"{script_name} ({str(e)})")
        
        # Prepare response
        response = {
            "tenant_name": tenant_name,
            "schema": tenant.database_schema,
            "created_tables": created_tables,
            "failed_tables": failed_tables,
            "total_attempted": len(table_scripts),
            "total_created": len(created_tables),
            "total_failed": len(failed_tables)
        }
        
        if failed_tables:
            response["status"] = "partial_success"
            response["message"] = f"Created {len(created_tables)} tables successfully, {len(failed_tables)} failed"
        else:
            response["status"] = "success"
            response["message"] = f"All {len(created_tables)} tables created successfully"
        
        logger.info(f"Table creation completed for tenant '{tenant_name}': {response['message']}")
        return response
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error creating tables for tenant '{tenant_name}': {e}")
        raise HTTPException(status_code=500, detail=f"Error creating tables: {str(e)}")

@admin_api_router.post("/tenants/{tenant_name}/init_tables")
async def init_tables_for_tenant(tenant_name: str):
    """
    Initialize tables with demo data for a specific tenant using the API engine system
    
    Args:
        tenant_name: Name of the tenant to initialize data for
        
    Returns:
        Success message with details of initialized tables
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
        
        # List of data initialization operations to execute
        data_operations = [
            ("insert_users_data", "insert_users_data", True),  # (script_name, function_name, use_external_script)
            ("create_users_profile_photo", "upload_users_profile_photos", False)  # Use local function
        ]
        
        initialized_data = []
        failed_data = []
        
        # Base path for data scripts
        data_path = Path(__file__).parent / "deployment" / "schema" / "demo" / "tables_data"
        
        for script_name, function_name, use_external_script in data_operations:
            try:
                if use_external_script:
                    # Load external script dynamically
                    script_path = data_path / f"{script_name}.py"
                    
                    if not script_path.exists():
                        logger.warning(f"Data script not found: {script_path}")
                        failed_data.append(f"{script_name} (file not found)")
                        continue
                    
                    # Load the module dynamically
                    spec = importlib.util.spec_from_file_location(script_name, script_path)
                    module = importlib.util.module_from_spec(spec)
                    
                    # Add the module to sys.modules temporarily
                    sys.modules[script_name] = module
                    spec.loader.exec_module(module)
                    
                    if hasattr(module, function_name):
                        success = module.__dict__[function_name](engine, tenant.database_schema)
                        
                        if success:
                            initialized_data.append(script_name.replace("create_", "").replace("_data", ""))
                            logger.info(f"Successfully initialized data using {script_name}")
                        else:
                            failed_data.append(script_name)
                            logger.error(f"Failed to initialize data using {script_name}")
                    else:
                        logger.error(f"Function {function_name} not found in {script_name}")
                        failed_data.append(f"{script_name} (function not found)")
                    
                    # Clean up module from sys.modules
                    del sys.modules[script_name]
                else:
                    # Use local function
                    if script_name == "create_users_profile_photo":
                        success = upload_users_profile_photos(engine, tenant.database_schema, tenant.id)
                        
                        if success:
                            initialized_data.append("users_profile_photo")
                            logger.info(f"Successfully initialized profile photos")
                        else:
                            failed_data.append(script_name)
                            logger.error(f"Failed to initialize profile photos")
                
            except Exception as e:
                logger.error(f"Error executing data operation {script_name}: {e}")
                failed_data.append(f"{script_name} ({str(e)})")
        
        # Prepare response
        response = {
            "tenant_name": tenant_name,
            "schema": tenant.database_schema,
            "initialized_data": initialized_data,
            "failed_data": failed_data,
            "total_attempted": len(data_scripts),
            "total_initialized": len(initialized_data),
            "total_failed": len(failed_data)
        }
        
        if failed_data:
            response["status"] = "partial_success"
            response["message"] = f"Initialized {len(initialized_data)} data sets successfully, {len(failed_data)} failed"
        else:
            response["status"] = "success"
            response["message"] = f"All {len(initialized_data)} data sets initialized successfully"
        
        logger.info(f"Data initialization completed for tenant '{tenant_name}': {response['message']}")
        return response
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error initializing data for tenant '{tenant_name}': {e}")
        raise HTTPException(status_code=500, detail=f"Error initializing data: {str(e)}")

@admin_api_router.get("/tenants/{tenant_name}/tables")
async def get_tenant_tables(tenant_name: str):
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
            # Query to get all tables in the tenant's schema
            tables_sql = text("""
                SELECT
                    t.table_name,
                    t.table_type,
                    COALESCE(
                        (SELECT COUNT(*)
                         FROM INFORMATION_SCHEMA.COLUMNS c
                         WHERE c.table_schema = t.table_schema
                         AND c.table_name = t.table_name), 0) as column_count,
                    COALESCE(
                        (SELECT TOP 1 p.rows
                         FROM sys.tables st
                         INNER JOIN sys.partitions p ON st.object_id = p.object_id
                         INNER JOIN sys.schemas s ON st.schema_id = s.schema_id
                         WHERE s.name = :schema_name
                         AND st.name = t.table_name
                         AND p.index_id IN (0,1)), 0) as row_count
                FROM INFORMATION_SCHEMA.TABLES t
                WHERE t.table_schema = :schema_name
                AND t.table_type = 'BASE TABLE'
                ORDER BY t.table_name
            """)
            
            result = conn.execute(tables_sql, {"schema_name": tenant.database_schema})
            tables = []
            
            for row in result:
                tables.append({
                    "table_name": row.table_name,
                    "table_type": row.table_type,
                    "column_count": row.column_count,
                    "row_count": row.row_count
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

@admin_api_router.post("/tenants/{tenant_name}/tables/{table_name}/recreate")
async def recreate_table(tenant_name: str, table_name: str, drop_if_exists: bool = True, load_data: bool = False):
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
        tables_path = Path(__file__).parent / "deployment" / "schema" / "tables"
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

@admin_api_router.post("/tenants/{tenant_name}/tables/{table_name}/load_data")
async def load_data_for_table(tenant_name: str, table_name: str):
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
    Load demo data for a specific table
    
    Args:
        tenant_name: Name of the tenant
        table_name: Name of the table to load data for
        engine: Database engine
        schema_name: Database schema name
        tenant_id: Tenant ID
        
    Returns:
        Boolean indicating success
    """
    try:
        # Map table names to their data loading operations
        table_data_mapping = {
            "users": ("insert_users_data", "insert_users_data", True),
            "service_provider_types": ("insert_service_provider_types_data", "insert_service_provider_types_data", True),
            "event_instructor": ("insert_event_instructor_data", "insert_event_instructor_data", True),
            "events": ("insert_events_data", "insert_events_data", True),
            "rooms": ("insert_rooms_data", "insert_rooms_data", True),
            "home_notification": ("insert_home_notification_data", "insert_home_notification_data", True),
            "user_notification": ("insert_user_notification_data", "insert_user_notification_data", True)
        }
        
        data_operation = table_data_mapping.get(table_name.lower())
        if not data_operation:
            logger.warning(f"No demo data available for table '{table_name}'")
            return False
        
        script_name, function_name, use_external_script = data_operation
        
        if use_external_script:
            # Base path for data scripts
            data_path = Path(__file__).parent / "deployment" / "schema" / "demo" / "tables_data"
            script_path = data_path / f"{script_name}.py"
            
            if not script_path.exists():
                logger.warning(f"Data script not found: {script_path}")
                return False
            
            # Load the module dynamically
            spec = importlib.util.spec_from_file_location(script_name, script_path)
            module = importlib.util.module_from_spec(spec)
            
            # Add the module to sys.modules temporarily
            sys.modules[script_name] = module
            spec.loader.exec_module(module)
            
            if hasattr(module, function_name):
                success = module.__dict__[function_name](engine, schema_name)
                
                # Clean up module from sys.modules
                del sys.modules[script_name]
                
                if success:
                    logger.info(f"Successfully loaded demo data for table '{table_name}'")
                    
                    # Special handling for users table - load profile photos
                    if table_name.lower() == "users":
                        try:
                            photo_success = upload_users_profile_photos(engine, schema_name, tenant_id)
                            if photo_success:
                                logger.info(f"Successfully loaded profile photos for users table")
                        except Exception as e:
                            logger.warning(f"Failed to load profile photos: {e}")
                    
                    return True
                else:
                    logger.error(f"Failed to load demo data for table '{table_name}'")
                    return False
            else:
                logger.error(f"Function {function_name} not found in {script_name}")
                return False
        
        return False
        
    except Exception as e:
        logger.error(f"Error loading demo data for table '{table_name}': {e}")
        return False

@admin_api_router.post("/create_schema/{schema_name}")
async def create_schema_and_user(schema_name: str):
    """
    Create a new database schema and a user with full permissions
    
    Args:
        schema_name: Name of the schema to create
        
    Returns:
        Success message with schema and user creation details
    """
    try:
        # Validate schema name (must be alphanumeric)
        if not schema_name.replace("_", "").replace("-", "").isalnum():
            raise HTTPException(status_code=400, detail="Schema name must be alphanumeric (with optional hyphens and underscores)")
        
        # Get admin database connection with elevated privileges for schema creation
        from residents_db_config import get_admin_connection_string
        from sqlalchemy import create_engine
        admin_connection_string = get_admin_connection_string()
        admin_engine = create_engine(admin_connection_string)
        
        with admin_engine.connect() as conn:
            # Check if schema already exists
            check_schema_sql = text("""
                SELECT COUNT(*) as count
                FROM INFORMATION_SCHEMA.SCHEMATA
                WHERE SCHEMA_NAME = :schema_name
            """)
            result = conn.execute(check_schema_sql, {"schema_name": schema_name}).fetchone()
            
            if result.count > 0:
                raise HTTPException(status_code=400, detail=f"Schema '{schema_name}' already exists")
            
            # Create the schema
            create_schema_sql = text(f"CREATE SCHEMA [{schema_name}]")
            conn.execute(create_schema_sql)
            
            # Check if login already exists
            check_login_sql = text("""
                SELECT COUNT(*) as count
                FROM sys.sql_logins
                WHERE name = :login_name
            """)
            login_result = conn.execute(check_login_sql, {"login_name": schema_name}).fetchone()
            
            if login_result.count == 0:
                # Create SQL Server login
                create_login_sql = text(f"""
                    CREATE LOGIN [{schema_name}]
                    WITH PASSWORD = '{schema_name}2025!',
                    DEFAULT_DATABASE = [residents],
                    CHECK_EXPIRATION = OFF,
                    CHECK_POLICY = OFF
                """)
                conn.execute(create_login_sql)
                logger.info(f"Created login '{schema_name}'")
            else:
                logger.info(f"Login '{schema_name}' already exists, skipping creation")
            
            # Create database user for the login
            create_user_sql = text(f"""
                CREATE USER [{schema_name}] FOR LOGIN [{schema_name}]
            """)
            conn.execute(create_user_sql)
            
            # Grant full permissions on the schema to the user
            grant_permissions_sql = text(f"""
                -- Grant schema ownership
                ALTER AUTHORIZATION ON SCHEMA::[{schema_name}] TO [{schema_name}];
                
                -- Grant additional permissions
                GRANT CREATE TABLE TO [{schema_name}];
                GRANT CREATE VIEW TO [{schema_name}];
                GRANT CREATE PROCEDURE TO [{schema_name}];
                GRANT CREATE FUNCTION TO [{schema_name}];
                
                -- Grant permissions on the schema
                GRANT CONTROL ON SCHEMA::[{schema_name}] TO [{schema_name}];
                GRANT ALTER ON SCHEMA::[{schema_name}] TO [{schema_name}];
                GRANT EXECUTE ON SCHEMA::[{schema_name}] TO [{schema_name}];
                GRANT INSERT ON SCHEMA::[{schema_name}] TO [{schema_name}];
                GRANT SELECT ON SCHEMA::[{schema_name}] TO [{schema_name}];
                GRANT UPDATE ON SCHEMA::[{schema_name}] TO [{schema_name}];
                GRANT DELETE ON SCHEMA::[{schema_name}] TO [{schema_name}];
                GRANT REFERENCES ON SCHEMA::[{schema_name}] TO [{schema_name}];
            """)
            conn.execute(grant_permissions_sql)
            
            conn.commit()
            
            response = {
                "status": "success",
                "message": f"Schema '{schema_name}' and user created successfully",
                "schema_name": schema_name,
                "user_name": schema_name,
                "password": f"{schema_name}2025!",
                "permissions": "Full permissions on schema",
                "login_created": login_result.count == 0,  # True if we created a new login
                "connection_info": {
                    "database": "residents",
                    "schema": schema_name,
                    "username": schema_name,
                    "password": f"{schema_name}2025!"
                }
            }
            
            logger.info(f"Successfully created schema '{schema_name}' with user and full permissions")
            return response
            
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error creating schema '{schema_name}': {e}")
        raise HTTPException(status_code=500, detail=f"Error creating schema: {str(e)}")

def upload_users_profile_photos(engine, schema_name: str, home_id: int = 1):
    """
    Upload profile photos for users from demo_data/users-profile directory using provided engine
    
    Args:
        engine: SQLAlchemy engine object
        schema_name: Name of the schema where the users table exists
        home_id: Home ID for the tenant (default: 1)
    """
    
    # Get the directory where this script is located
    script_dir = Path(__file__).parent
    photos_dir = script_dir / "deployment" / "schema" / "demo" / "profile_images"
    
    if not photos_dir.exists():
        logger.warning(f"Photos directory does not exist: {photos_dir}")
        return False
    
    try:
        with engine.connect() as conn:
            # Get all photo files
            photo_files = list(photos_dir.glob("*.jpg")) + list(photos_dir.glob("*.jpeg")) + list(photos_dir.glob("*.png"))
            
            if not photo_files:
                logger.warning("No photo files found in profile_images directory")
                return False
            
            logger.info(f"Found {len(photo_files)} photo files")
            
            success_count = 0
            failed_count = 0
            
            for photo_file in photo_files:
                # Extract user_id from filename (remove extension)
                user_id = photo_file.stem
                
                try:
                    # Check if user exists in database
                    check_user_sql = text(f"""
                        SELECT COUNT(*) as count FROM [{schema_name}].[users] WHERE id = :user_id
                    """)
                    result = conn.execute(check_user_sql, {"user_id": user_id}).fetchone()
                    
                    if result.count == 0:
                        logger.warning(f"User '{user_id}' not found in database, skipping photo: {photo_file.name}")
                        failed_count += 1
                        continue
                    
                    # Read the photo file
                    with open(photo_file, 'rb') as f:
                        image_data = f.read()
                    
                    # Determine content type
                    extension = photo_file.suffix.lower()
                    if extension in ['.jpg', '.jpeg']:
                        content_type = 'image/jpeg'
                    elif extension == '.png':
                        content_type = 'image/png'
                    else:
                        content_type = 'image/jpeg'  # Default
                    
                    # Upload to Azure Storage
                    success, result_message = azure_storage_service.upload_user_photo(
                        home_id=home_id,
                        user_id=user_id,
                        image_data=image_data,
                        original_filename=photo_file.name,
                        content_type=content_type
                    )
                    
                    if success:
                        # Update user's photo URL in database
                        update_user_sql = text(f"""
                            UPDATE [{schema_name}].[users]
                            SET photo = :photo_url, updated_at = GETDATE()
                            WHERE id = :user_id
                        """)
                        conn.execute(update_user_sql, {
                            "photo_url": result_message,
                            "user_id": user_id
                        })
                        conn.commit()
                        
                        logger.info(f"Successfully uploaded photo for user '{user_id}': {photo_file.name}")
                        success_count += 1
                    else:
                        logger.error(f"Failed to upload photo for user '{user_id}': {result_message}")
                        failed_count += 1
                        
                except Exception as e:
                    logger.error(f"Error processing photo for user '{user_id}': {e}")
                    failed_count += 1
            
            logger.info(f"Profile photo upload completed: {success_count} successful, {failed_count} failed")
            
            return success_count > 0
            
    except Exception as e:
        logger.error(f"Error connecting to database or uploading photos: {e}")
        return False

# Export the routers
__all__ = ["admin_router", "admin_api_router"]