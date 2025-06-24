"""
Admin API endpoints for tenant management
Provides CRUD operations for managing tenant configurations
"""

from fastapi import APIRouter, HTTPException, Depends
from fastapi.responses import FileResponse, HTMLResponse
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from typing import List, Optional
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
import jwt
import bcrypt
from datetime import datetime, timedelta
from pathlib import Path
from database_utils import get_tenant_engine, get_tenant_connection
from sqlalchemy import text, create_engine
from azure_storage_service import azure_storage_service
from pydantic import BaseModel
from deployment.load_events import load_events_sync
from deployment.load_users import load_users_sync
from deployment.load_event_instructor import load_event_instructor_sync
from deployment.load_rooms import load_rooms_sync
from deployment.load_service_provider_types import load_service_provider_types_sync
from deployment.load_home_notification import load_home_notification_sync

# Set up logging
logger = logging.getLogger(__name__)

# JWT Configuration
JWT_SECRET_KEY = "admin_secret_key_2025"  # In production, use environment variable
JWT_ALGORITHM = "HS256"
JWT_EXPIRATION_HOURS = 8

# Security
security = HTTPBearer()

# Pydantic models for authentication
class AdminCredentials(BaseModel):
    email: str
    password: str

class TokenResponse(BaseModel):
    token: str
    user: dict
    expires_at: str
    created_at: str

class TokenValidation(BaseModel):
    token: str
    refresh: Optional[bool] = False

# Create admin router
admin_router = APIRouter(prefix="/home/admin", tags=["admin"])

# Authentication helper functions
def create_access_token(data: dict) -> str:
    """Create JWT access token"""
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(hours=JWT_EXPIRATION_HOURS)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, JWT_SECRET_KEY, algorithm=JWT_ALGORITHM)
    return encoded_jwt

def verify_token(token: str) -> dict:
    """Verify JWT token"""
    try:
        payload = jwt.decode(token, JWT_SECRET_KEY, algorithms=[JWT_ALGORITHM])
        return payload
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token has expired")
    except jwt.JWTError:
        raise HTTPException(status_code=401, detail="Invalid token")

def get_current_admin_user(credentials: HTTPAuthorizationCredentials = Depends(security)):
    """Get current authenticated admin user from token"""
    token = credentials.credentials
    payload = verify_token(token)
    return payload

async def authenticate_admin(email: str, password: str) -> dict:
    """Authenticate admin against home table"""
    try:
        from residents_db_config import get_connection_string
        engine = create_engine(get_connection_string())
        
        with engine.connect() as conn:
            # Query home table for admin user
            query = text("""
                SELECT id, name, database_name, database_type, database_schema,
                       admin_user_email, admin_user_password, created_at, updated_at
                FROM home.home
                WHERE admin_user_email = :email
            """)
            
            result = conn.execute(query, {"email": email}).fetchone()
            
            if not result:
                raise HTTPException(status_code=401, detail="Invalid credentials")
            
            # Verify password (assuming plain text for now - in production use bcrypt)
            if result.admin_user_password != password:
                raise HTTPException(status_code=401, detail="Invalid credentials")
            
            # Return user data
            return {
                "id": result.id,
                "name": result.name,
                "database_name": result.database_name,
                "database_type": result.database_type,
                "database_schema": result.database_schema,
                "admin_user_email": result.admin_user_email,
                "admin_user_password": result.admin_user_password,
                "created_at": result.created_at.isoformat(),
                "updated_at": result.updated_at.isoformat(),
            }
            
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Authentication error: {e}")
        raise HTTPException(status_code=500, detail="Authentication failed")

# Authentication endpoints
@admin_router.post("/api/auth/login", response_model=TokenResponse)
async def admin_login(credentials: AdminCredentials):
    """Admin login endpoint"""
    try:
        user_data = await authenticate_admin(credentials.email, credentials.password)
        
        # Create JWT token
        token_data = {"sub": user_data["admin_user_email"], "user_id": user_data["id"]}
        access_token = create_access_token(token_data)
        
        # Calculate expiration time
        expires_at = datetime.utcnow() + timedelta(hours=JWT_EXPIRATION_HOURS)
        created_at = datetime.utcnow()
        
        return TokenResponse(
            token=access_token,
            user=user_data,
            expires_at=expires_at.isoformat(),
            created_at=created_at.isoformat()
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Login error: {e}")
        raise HTTPException(status_code=500, detail="Login failed")

@admin_router.post("/api/auth/validate")
async def validate_admin_token(validation: TokenValidation):
    """Validate admin token"""
    try:
        payload = verify_token(validation.token)
        
        if validation.refresh:
            # Create new token with extended expiration
            new_token = create_access_token({"sub": payload["sub"], "user_id": payload["user_id"]})
            return {"valid": True, "new_token": new_token}
        
        return {"valid": True}
        
    except HTTPException as e:
        return {"valid": False, "error": str(e.detail)}
    except Exception as e:
        logger.error(f"Token validation error: {e}")
        return {"valid": False, "error": "Validation failed"}

@admin_router.post("/api/auth/logout")
async def admin_logout(current_user: dict = Depends(get_current_admin_user)):
    """Admin logout endpoint"""
    # In a real implementation, you might blacklist the token
    return {"message": "Logged out successfully"}

@admin_router.get("/html", response_class=HTMLResponse)
async def admin_html():
    """Serve the legacy admin HTML interface"""
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

# Flutter Web Admin Routes (admin-specific build)
web_build_path = "../build/web-admin"

@admin_router.get("/", response_class=HTMLResponse)
async def serve_admin_flutter_web():
    """Serve the Flutter web admin panel - main entry point"""
    if os.path.exists(web_build_path):
        index_path = os.path.join(web_build_path, "index.html")
        if os.path.exists(index_path):
            # Read and modify index.html to inject correct base href for admin
            with open(index_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Replace base href with admin-specific path
            content = content.replace('<base href="/">', '<base href="/home/admin/">')
            content = content.replace('<base href="/web/">', '<base href="/home/admin/">')
            # Also handle case where there's no base tag
            if '<base href=' not in content and '<head>' in content:
                content = content.replace('<head>', '<head>\n  <base href="/home/admin/">')
            
            return HTMLResponse(content=content, media_type="text/html")
        else:
            raise HTTPException(status_code=404, detail="Admin web interface not found")
    else:
        raise HTTPException(status_code=404, detail="Flutter web build not found. Run 'flutter build web' to generate web assets.")

@admin_router.get("/login", response_class=HTMLResponse)
async def serve_admin_login():
    """Serve the Flutter web admin login page"""
    # Same as main admin route - Flutter handles the routing internally
    return await serve_admin_flutter_web()

@admin_router.get("/dashboard", response_class=HTMLResponse)
async def serve_admin_dashboard():
    """Serve the Flutter web admin dashboard"""
    # Same as main admin route - Flutter handles the routing internally
    return await serve_admin_flutter_web()

@admin_router.get("/{path:path}")
async def serve_admin_assets(path: str):
    """Serve Flutter web static assets for admin panel"""
    # Skip API routes and HTML route
    if path.startswith('api/') or path == 'html':
        raise HTTPException(status_code=404, detail="Not found")
    
    # Security check to prevent directory traversal
    if ".." in path or path.startswith("/"):
        raise HTTPException(status_code=400, detail="Invalid path")
    
    if os.path.exists(web_build_path):
        asset_path = os.path.join(web_build_path, path)
        if os.path.exists(asset_path) and os.path.isfile(asset_path):
            return FileResponse(asset_path)
        else:
            # If asset not found, return the main index.html for SPA routing
            index_path = os.path.join(web_build_path, "index.html")
            if os.path.exists(index_path):
                return await serve_admin_flutter_web()
            else:
                raise HTTPException(status_code=404, detail="Asset not found")
    else:
        raise HTTPException(status_code=404, detail="Flutter web build not found")

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
            init_result = await init_data_for_tenant(new_tenant.name)
            logger.info(f"Step 3 completed: Initialized data for tenant '{tenant.name}'")
        except Exception as e:
            logger.error(f"Step 3 failed for tenant '{tenant.name}': {e}")
            # Note: We don't fail the whole process if data initialization fails
            logger.warning(f"Tenant '{tenant.name}' created successfully but data initialization failed: {str(e)}")
        
        # Step 4: Create blob container for tenant
        try:
            blob_result = await create_blob_container_for_tenant(new_tenant.name)
            logger.info(f"Step 4 completed: Created blob container for tenant '{tenant.name}'")
        except Exception as e:
            logger.error(f"Step 4 failed for tenant '{tenant.name}': {e}")
            # Note: We don't fail the whole process if blob container creation fails
            logger.warning(f"Tenant '{tenant.name}' created successfully but blob container creation failed: {str(e)}")
        
        # Add setup information to the response
        setup_info = {
            "schema_created": schema_result.get("status") == "success" if 'schema_result' in locals() else False,
            "tables_created": tables_result.get("status") in ["success", "partial_success"] if 'tables_result' in locals() else False,
            "data_initialized": init_result.get("status") in ["success", "partial_success"] if 'init_result' in locals() else False,
            "blob_container_created": blob_result.get("status") == "success" if 'blob_result' in locals() else False,
            "setup_details": {
                "schema_info": schema_result if 'schema_result' in locals() else None,
                "tables_info": tables_result if 'tables_result' in locals() else None,
                "init_info": init_result if 'init_result' in locals() else None,
                "blob_info": blob_result if 'blob_result' in locals() else None
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

@admin_api_router.post("/create_schema/{schema_name}")
async def create_schema_and_user(schema_name: str):
    """
    Create a new database schema and a user with full permissions
    Automatically detects database engine and uses appropriate implementation
    
    Args:
        schema_name: Name of the schema to create
        
    Returns:
        Success message with schema and user creation details
    """
    try:
        # Get admin database connection with elevated privileges for schema creation
        from residents_db_config import get_admin_connection_string, get_server_info, DATABASE_ENGINE
        
        admin_connection_string = get_admin_connection_string()
        server_info = get_server_info()
        database_engine = DATABASE_ENGINE
        
        # Import and use the appropriate database-specific function
        if database_engine == "mysql":
            from deployment.admin.mysql.schema_operations import create_schema_and_user_mysql
            result = create_schema_and_user_mysql(schema_name, admin_connection_string)
        else:
            from deployment.admin.sqlserver.schema_operations import create_schema_and_user_sqlserver
            result = create_schema_and_user_sqlserver(schema_name, admin_connection_string)
        
        # Check result status
        if result["status"] == "error":
            raise HTTPException(status_code=400, detail=result["message"])
        
        logger.info(f"Successfully created schema '{schema_name}' using {database_engine} implementation")
        return result
            
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error creating schema '{schema_name}': {e}")
        raise HTTPException(status_code=500, detail=f"Error creating schema: {str(e)}")

async def create_blob_container_for_tenant(tenant_name: str):
    """
    Create Azure Blob Storage container for a tenant
    
    Args:
        tenant_name: Name of the tenant to create blob container for
        
    Returns:
        Dictionary with status and details of blob container creation
    """
    try:
        # Import the blob container creation function
        from deployment.schema.resources.create_blob_container import create_blob_container
        
        # Create the blob container
        success = create_blob_container(tenant_name)
        
        if success:
            response = {
                "status": "success",
                "message": f"Blob container created successfully for tenant '{tenant_name}'",
                "container_name": f"{tenant_name}-images",
                "tenant_name": tenant_name
            }
            logger.info(f"Successfully created blob container for tenant '{tenant_name}'")
            return response
        else:
            response = {
                "status": "failed",
                "message": f"Failed to create blob container for tenant '{tenant_name}'",
                "container_name": f"{tenant_name}-images",
                "tenant_name": tenant_name
            }
            logger.error(f"Failed to create blob container for tenant '{tenant_name}'")
            return response
            
    except Exception as e:
        error_message = f"Error creating blob container for tenant '{tenant_name}': {str(e)}"
        logger.error(error_message)
        return {
            "status": "error",
            "message": error_message,
            "container_name": f"{tenant_name}-images",
            "tenant_name": tenant_name,
            "error": str(e)
        }

@admin_api_router.post("/tenants/{tenant_name}/init_data_for_tenant")
async def init_data_for_tenant(tenant_name: str):
    """
    Initialize demo data for a tenant including service provider types, users, home notifications, rooms, event instructors, events with images
    
    Args:
        tenant_name: Name of the tenant to initialize data for
        
    Returns:
        Success message with details of data initialization
    """
    try:
        # Get tenant configuration
        tenant = tenant_config_db.load_tenant_config_from_db(tenant_name)
        if not tenant:
            raise HTTPException(status_code=404, detail=f"Tenant '{tenant_name}' not found")
        
        # Load service provider types first (since users may reference them)
        service_types_success = load_service_provider_types_sync(tenant_name, tenant.id)
        
        # Load users data (since events and notifications may reference users)
        users_success = load_users_sync(tenant_name, tenant.id)
        
        # Load home notifications (since they are created by users)
        notifications_success = load_home_notification_sync(tenant_name, tenant.id)
        
        # Load rooms data (since events may reference rooms)
        rooms_success = load_rooms_sync(tenant_name, tenant.id)
        
        # Load event instructors data (since events may reference instructors)
        instructors_success = load_event_instructor_sync(tenant_name, tenant.id)
        
        # Load events data using the new function
        events_success = load_events_sync(tenant_name, tenant.id)
        
        # Determine overall success
        overall_success = service_types_success and users_success and notifications_success and rooms_success and instructors_success and events_success
        
        # Prepare data types list
        successful_data_types = []
        failed_data_types = []
        
        if service_types_success:
            successful_data_types.append("service_provider_types")
        else:
            failed_data_types.append("service_provider_types")
        
        if users_success:
            successful_data_types.extend(["users", "users_images"])
        else:
            failed_data_types.extend(["users", "users_images"])
            
        if notifications_success:
            successful_data_types.append("home_notifications")
        else:
            failed_data_types.append("home_notifications")
            
        if rooms_success:
            successful_data_types.append("rooms")
        else:
            failed_data_types.append("rooms")
            
        if instructors_success:
            successful_data_types.extend(["event_instructors", "instructor_images"])
        else:
            failed_data_types.extend(["event_instructors", "instructor_images"])
            
        if events_success:
            successful_data_types.extend(["events", "events_images"])
        else:
            failed_data_types.extend(["events", "events_images"])
        
        if overall_success:
            response = {
                "status": "success",
                "message": f"Demo data initialized successfully for tenant '{tenant_name}'",
                "tenant_name": tenant_name,
                "tenant_id": tenant.id,
                "successful_data_types": successful_data_types,
                "failed_data_types": failed_data_types
            }
            logger.info(f"Demo data initialization completed for tenant '{tenant_name}'")
            return response
        elif service_types_success or users_success or notifications_success or rooms_success or instructors_success or events_success:
            response = {
                "status": "partial_success",
                "message": f"Demo data partially initialized for tenant '{tenant_name}'",
                "tenant_name": tenant_name,
                "tenant_id": tenant.id,
                "successful_data_types": successful_data_types,
                "failed_data_types": failed_data_types
            }
            logger.warning(f"Demo data initialization partially completed for tenant '{tenant_name}'")
            return response
        else:
            response = {
                "status": "failed",
                "message": f"Failed to initialize demo data for tenant '{tenant_name}'",
                "tenant_name": tenant_name,
                "tenant_id": tenant.id,
                "successful_data_types": successful_data_types,
                "failed_data_types": failed_data_types
            }
            logger.error(f"Demo data initialization failed for tenant '{tenant_name}'")
            return response
            
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error initializing demo data for tenant '{tenant_name}': {e}")
        raise HTTPException(status_code=500, detail=f"Error initializing demo data: {str(e)}")

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
                    
                    # Get tenant name from schema_name for Azure Storage
                    # We need to get the tenant name from the schema to use for container naming
                    from tenant_config import get_all_tenants
                    tenant_name = None
                    tenants = get_all_tenants()
                    for tenant in tenants:
                        if tenant.database_schema == schema_name and tenant.id == home_id:
                            tenant_name = tenant.name
                            break
                    
                    if not tenant_name:
                        logger.warning(f"Could not find tenant name for schema '{schema_name}' and home_id '{home_id}', using schema name as fallback")
                        tenant_name = schema_name
                    
                    # Upload to Azure Storage with tenant name
                    success, result_message = azure_storage_service.upload_user_photo(
                        home_id=home_id,
                        user_id=user_id,
                        image_data=image_data,
                        original_filename=photo_file.name,
                        content_type=content_type,
                        tenant_name=tenant_name
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