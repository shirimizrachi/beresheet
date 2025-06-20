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
    Create a new tenant configuration
    
    Args:
        tenant: Tenant configuration to create
        
    Returns:
        Created tenant configuration
    """
    try:
        # Check if tenant name already exists
        existing_tenant = tenant_config_db.load_tenant_config_from_db(tenant.name)
        if existing_tenant:
            raise HTTPException(status_code=400, detail=f"Tenant '{tenant.name}' already exists")
        
        # Validate tenant name (must be alphanumeric)
        if not tenant.name.replace("_", "").replace("-", "").isalnum():
            raise HTTPException(status_code=400, detail="Tenant name must be alphanumeric (with optional hyphens and underscores)")
        
        # Create the tenant
        new_tenant = tenant_config_db.create_tenant(tenant)
        if not new_tenant:
            raise HTTPException(status_code=400, detail="Failed to create tenant")
        
        logger.info(f"Created new tenant '{tenant.name}' with ID {new_tenant.id}")
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

# Export the routers
__all__ = ["admin_router", "admin_api_router"]