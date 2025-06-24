"""
Admin API routes for tenant management and administrative operations
"""

from fastapi import APIRouter, HTTPException, Depends
from fastapi.responses import FileResponse, HTMLResponse
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from typing import List, Optional
import logging
import os
import importlib.util
import sys
from pathlib import Path
from datetime import datetime, timedelta
from sqlalchemy import text

from tenant_config import (
    TenantConfig,
    TenantCreate,
    TenantUpdate,
    tenant_config_db,
    get_tenant_connection_string
)
from database_utils import get_tenant_engine
from .models import AdminCredentials, TokenResponse, TokenValidation
from .admin_auth import (
    create_access_token, verify_token, get_current_admin_user, authenticate_admin
)
from .admin_service import admin_service

# Set up logging
logger = logging.getLogger(__name__)

# Create admin router
admin_router = APIRouter(prefix="/home/admin", tags=["admin"])

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
        expires_at = datetime.utcnow() + timedelta(hours=8)  # JWT_EXPIRATION_HOURS
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
        admin_html_path = os.path.join(os.path.dirname(__file__), "..", "..", "admin_web.html")
        
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
            schema_result = await admin_service.create_schema_and_user(new_tenant.database_schema)
            logger.info(f"Step 1 completed: Created schema and user for tenant '{tenant.name}'")
        except Exception as e:
            logger.error(f"Step 1 failed for tenant '{tenant.name}': {e}")
            # If schema creation fails, we should clean up the tenant config
            tenant_config_db.delete_tenant(new_tenant.id)
            raise HTTPException(status_code=500, detail=f"Failed to create schema and user: {str(e)}")
        
        # Step 2: Create tables in the new schema
        try:
            tables_result = await admin_service.create_tables_for_tenant(new_tenant.name, drop_if_exists=True)
            logger.info(f"Step 2 completed: Created tables for tenant '{tenant.name}'")
        except Exception as e:
            logger.error(f"Step 2 failed for tenant '{tenant.name}': {e}")
            # Note: We don't clean up schema here as it might be needed for debugging
            raise HTTPException(status_code=500, detail=f"Failed to create tables: {str(e)}")
        
        # Step 3: Initialize tables with demo data
        try:
            init_result = await admin_service.init_data_for_tenant(new_tenant.name)
            logger.info(f"Step 3 completed: Initialized data for tenant '{tenant.name}'")
        except Exception as e:
            logger.error(f"Step 3 failed for tenant '{tenant.name}': {e}")
            # Note: We don't fail the whole process if data initialization fails
            logger.warning(f"Tenant '{tenant.name}' created successfully but data initialization failed: {str(e)}")
        
        # Step 4: Create blob container for tenant
        try:
            blob_result = await admin_service.create_blob_container_for_tenant(new_tenant.name)
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

# Additional endpoints for table management
from .admin_routes_additional import (
    create_tables_for_tenant_endpoint,
    get_tenant_tables_endpoint,
    recreate_table_endpoint,
    load_data_for_table_endpoint,
    init_data_for_tenant_endpoint,
    create_schema_and_user_endpoint
)

@admin_api_router.post("/tenants/{tenant_name}/create_tables")
async def create_tables_for_tenant(tenant_name: str, drop_if_exists: bool = True):
    """
    Create all tables for a specific tenant using the API engine system
    """
    return await create_tables_for_tenant_endpoint(tenant_name, drop_if_exists)

@admin_api_router.get("/tenants/{tenant_name}/tables")
async def get_tenant_tables(tenant_name: str):
    """
    Get all tables for a specific tenant schema
    """
    return await get_tenant_tables_endpoint(tenant_name)

@admin_api_router.post("/tenants/{tenant_name}/tables/{table_name}/recreate")
async def recreate_table(tenant_name: str, table_name: str, drop_if_exists: bool = True, load_data: bool = False):
    """
    Recreate a specific table for a tenant
    """
    return await recreate_table_endpoint(tenant_name, table_name, drop_if_exists, load_data)

@admin_api_router.post("/tenants/{tenant_name}/tables/{table_name}/load_data")
async def load_data_for_table(tenant_name: str, table_name: str):
    """
    Load demo data for a specific table without recreating it
    """
    return await load_data_for_table_endpoint(tenant_name, table_name)

@admin_api_router.post("/tenants/{tenant_name}/init_data_for_tenant")
async def init_data_for_tenant(tenant_name: str):
    """
    Initialize demo data for a tenant including service provider types, users,
    home notifications, rooms, event instructors, events with images
    """
    return await init_data_for_tenant_endpoint(tenant_name)

@admin_api_router.post("/create_schema/{schema_name}")
async def create_schema_and_user(schema_name: str):
    """
    Create a new database schema and a user with full permissions
    Automatically detects database engine and uses appropriate implementation
    """
    return await create_schema_and_user_endpoint(schema_name)