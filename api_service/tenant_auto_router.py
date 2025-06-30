"""
Automatic Tenant API Router
Automatically wraps ALL existing API endpoints with tenant validation
Transforms /api/* endpoints to /{tenant_name}/api/* without code changes
"""

from fastapi import APIRouter, HTTPException, Path, Depends, Header, Request
from fastapi.routing import APIRoute
from fastapi.responses import FileResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles
from typing import Any, Callable, Dict, List, Optional, Union
import inspect
import os
from tenant_config import load_tenant_config_from_db
import logging

logger = logging.getLogger(__name__)

async def get_home_id_header(home_id: str = Header(..., alias="homeID")):
    """Extract and validate homeID header"""
    if not home_id:
        raise HTTPException(status_code=400, detail="homeID header is required")
    try:
        return int(home_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="homeID must be a valid integer")

async def validate_tenant_and_header(
    tenant_name: str = Path(..., description="Tenant name from URL"),
    home_id: int = Depends(get_home_id_header)
):
    """
    Validate that the tenant name from URL matches the homeID header
    
    Args:
        tenant_name: Tenant name from URL path
        home_id: Home ID from header
        
    Returns:
        Tenant configuration if valid
        
    Raises:
        HTTPException: If tenant not found or homeID doesn't match
    """
    # Load tenant configuration by name
    tenant_config = load_tenant_config_from_db(tenant_name)
    if not tenant_config:
        raise HTTPException(
            status_code=404,
            detail=f"Tenant '{tenant_name}' not found"
        )
    
    # Verify homeID header matches tenant ID
    if tenant_config.id != home_id:
        raise HTTPException(
            status_code=400,
            detail=f"HomeID header ({home_id}) doesn't match tenant '{tenant_name}' (expected {tenant_config.id})"
        )
    
    # Log tenant validation
    logger.info(f"✅ TENANT VALIDATED - Tenant '{tenant_name}' (ID: {tenant_config.id}) for request")
    print(f"✅ TENANT VALIDATED - Tenant '{tenant_name}' (ID: {tenant_config.id}, Schema: {tenant_config.database_schema})")
    
    return tenant_config

async def validate_tenant_only(tenant_name: str = Path(..., description="Tenant name from URL")):
    """
    Validate only the tenant name without requiring homeID header
    Used for auth endpoints where users don't have homeID yet
    
    Args:
        tenant_name: Tenant name from URL path
        
    Returns:
        Tenant configuration if valid
        
    Raises:
        HTTPException: If tenant not found
    """
    # Load tenant configuration by name
    tenant_config = load_tenant_config_from_db(tenant_name)
    if not tenant_config:
        raise HTTPException(
            status_code=404,
            detail=f"Tenant '{tenant_name}' not found"
        )
    
    # Log tenant validation for auth requests
    logger.info(f"✅ TENANT VALIDATED (AUTH) - Tenant '{tenant_name}' (ID: {tenant_config.id}) for auth request")
    print(f"✅ TENANT VALIDATED (AUTH) - Tenant '{tenant_name}' (ID: {tenant_config.id}, Schema: {tenant_config.database_schema})")
    
    return tenant_config

async def validate_tenant_and_header_or_redirect(
    request: Request,
    tenant_name: str
):
    """
    Validate tenant and authentication for web routes, redirect to login if authentication fails
    Supports both header-based auth (for mobile app) and cookie-based auth (for web browser)
    
    Args:
        request: FastAPI request object
        tenant_name: Tenant name from URL path
        
    Returns:
        Tenant configuration if valid, RedirectResponse if authentication fails
        
    Raises:
        HTTPException: If tenant not found
    """
    # Load tenant configuration by name
    tenant_config = load_tenant_config_from_db(tenant_name)
    if not tenant_config:
        raise HTTPException(
            status_code=404,
            detail=f"Tenant '{tenant_name}' not found"
        )
    
    # Method 1: Check homeID header (for mobile app requests)
    home_id = request.headers.get("homeID")
    if home_id:
        try:
            home_id_int = int(home_id)
            # Verify homeID header matches tenant ID
            if tenant_config.id == home_id_int:
                logger.info(f"Validated tenant '{tenant_name}' (ID: {tenant_config.id}) for request via homeID header")
                return tenant_config
        except ValueError:
            pass
    
    # Method 2: Check JWT cookie (for web browser requests)
    jwt_token = request.cookies.get("web_jwt_token")
    if jwt_token:
        try:
            # Import JWT verification here to avoid circular imports
            from web_jwt_auth import verify_web_jwt_token
            payload = verify_web_jwt_token(jwt_token)
            if payload and payload.get("home_id") == tenant_config.id:
                logger.info(f"Validated tenant '{tenant_name}' (ID: {tenant_config.id}) for request via JWT cookie")
                return tenant_config
        except Exception as e:
            logger.warning(f"Error validating JWT token: {e}")
    
    # No valid authentication found, redirect to login
    logger.info(f"No valid authentication for tenant '{tenant_name}', redirecting to login")
    return RedirectResponse(url=f"/{tenant_name}/login", status_code=302)

class TenantAPIRouter:
    """
    Automatic tenant router that wraps existing API endpoints
    Transforms /api/* routes to /{tenant_name}/api/* routes
    """
    
    def __init__(self, original_api_router: APIRouter):
        """
        Initialize tenant router from existing API router
        
        Args:
            original_api_router: The existing APIRouter with /api/* endpoints
        """
        self.original_router = original_api_router
        self.tenant_router = APIRouter()
        self._wrapped_routes = []
        
        # Wrap all existing routes
        self._wrap_all_routes()
        
        logger.info(f"Created TenantAPIRouter with {len(self._wrapped_routes)} wrapped routes")
    
    def _wrap_all_routes(self):
        """Wrap all routes from the original API router"""
        for route in self.original_router.routes:
            if isinstance(route, APIRoute):
                self._wrap_single_route(route)
    
    def _wrap_single_route(self, original_route: APIRoute):
        """
        Wrap a single route with tenant validation
        
        Args:
            original_route: The original APIRoute to wrap
        """
        try:
            # Get original route details
            original_path = original_route.path
            original_endpoint = original_route.endpoint
            original_methods = original_route.methods
            
            # Create new tenant-aware path
            # /api/events -> /{tenant_name}/api/events
            tenant_path = f"/{{tenant_name}}{original_path}"
            
            # Create wrapped endpoint function
            wrapped_endpoint = self._create_wrapped_endpoint(original_endpoint, original_route)
            
            # Copy route properties
            route_kwargs = {
                'path': tenant_path,
                'endpoint': wrapped_endpoint,
                'methods': original_methods,
                'response_model': original_route.response_model,
                'status_code': original_route.status_code,
                'tags': original_route.tags,
                'summary': original_route.summary,
                'description': original_route.description,
                'response_description': original_route.response_description,
                'responses': original_route.responses,
                'deprecated': original_route.deprecated,
                'operation_id': f"tenant_{original_route.operation_id}" if original_route.operation_id else None,
                'response_model_include': original_route.response_model_include,
                'response_model_exclude': original_route.response_model_exclude,
                'response_model_by_alias': original_route.response_model_by_alias,
                'response_model_exclude_unset': original_route.response_model_exclude_unset,
                'response_model_exclude_defaults': original_route.response_model_exclude_defaults,
                'response_model_exclude_none': original_route.response_model_exclude_none,
                'include_in_schema': original_route.include_in_schema,
            }
            
            # Check if this is an auth endpoint that should not require homeID header
            is_auth_endpoint = original_path.startswith('/api/auth/')
            
            # Add tenant validation dependency but replace the homeID dependency
            # to avoid duplicate header processing
            dependencies = []
            
            if is_auth_endpoint:
                # For auth endpoints, only validate tenant name (not homeID header)
                logger.info(f"Setting up auth endpoint {original_path} -> {tenant_path} with validate_tenant_only")
                dependencies.append(Depends(validate_tenant_only))
            else:
                # For regular endpoints, validate both tenant and homeID header
                logger.info(f"Setting up regular endpoint {original_path} with validate_tenant_and_header")
                dependencies.append(Depends(validate_tenant_and_header))
            
            # Add other dependencies but skip homeID dependency to avoid duplication
            if original_route.dependencies:
                for dep in original_route.dependencies:
                    # Skip homeID dependency as it's handled in tenant validation
                    if hasattr(dep, 'dependency') and hasattr(dep.dependency, '__name__'):
                        if dep.dependency.__name__ != 'get_home_id':
                            dependencies.append(dep)
                    else:
                        dependencies.append(dep)
            
            route_kwargs['dependencies'] = dependencies
            
            # Add the route to tenant router
            self.tenant_router.add_api_route(**route_kwargs)
            
            self._wrapped_routes.append({
                'original_path': original_path,
                'tenant_path': tenant_path,
                'methods': original_methods,
                'endpoint': original_endpoint.__name__ if hasattr(original_endpoint, '__name__') else str(original_endpoint),
                'is_auth_endpoint': is_auth_endpoint
            })
            
            logger.debug(f"Wrapped route: {original_path} -> {tenant_path} (auth: {is_auth_endpoint})")
            
        except Exception as e:
            logger.error(f"Failed to wrap route {original_route.path}: {e}")
            raise
    
    def _create_wrapped_endpoint(self, original_endpoint: Callable, original_route: APIRoute) -> Callable:
        """
        Create a wrapped endpoint function that includes tenant validation
        
        Args:
            original_endpoint: The original endpoint function
            original_route: The original route object
            
        Returns:
            Wrapped endpoint function
        """
        # Check if this is an auth endpoint that should not require homeID header
        is_auth_endpoint = original_route.path.startswith('/api/auth/')
        
        # Get the original function signature
        sig = inspect.signature(original_endpoint)
        
        # Modify signature to replace homeID dependency parameter
        new_params = []
        for param_name, param in sig.parameters.items():
            if param_name == 'home_id' and hasattr(param.default, 'dependency'):
                # Replace homeID dependency with our tenant validation
                if is_auth_endpoint:
                    new_param = param.replace(default=Depends(get_home_id_from_tenant_auth))
                else:
                    new_param = param.replace(default=Depends(get_home_id_from_tenant))
                new_params.append((param_name, new_param))
            else:
                new_params.append((param_name, param))
        
        # Create new signature
        new_sig = sig.replace(parameters=[param for name, param in new_params])
        
        async def wrapped_endpoint(*args, **kwargs):
            """
            Wrapped endpoint that validates tenant and calls original endpoint
            """
            try:
                # Call the original endpoint with all arguments
                if inspect.iscoroutinefunction(original_endpoint):
                    return await original_endpoint(*args, **kwargs)
                else:
                    return original_endpoint(*args, **kwargs)
            except Exception as e:
                logger.error(f"Error in wrapped endpoint {original_endpoint.__name__}: {e}")
                raise
        
        # Preserve function metadata
        wrapped_endpoint.__name__ = f"tenant_{original_endpoint.__name__}"
        wrapped_endpoint.__doc__ = original_endpoint.__doc__
        wrapped_endpoint.__annotations__ = original_endpoint.__annotations__
        wrapped_endpoint.__signature__ = new_sig
        
        return wrapped_endpoint
    
    def get_route_summary(self) -> Dict[str, Any]:
        """
        Get a summary of all wrapped routes
        
        Returns:
            Dictionary with route summary information
        """
        return {
            'total_routes': len(self._wrapped_routes),
            'routes': self._wrapped_routes,
            'tenant_router_routes': len(self.tenant_router.routes)
        }

async def get_home_id_from_tenant(tenant_config = Depends(validate_tenant_and_header)) -> int:
    """
    Extract home_id from validated tenant configuration
    This replaces the original get_home_id dependency in wrapped endpoints
    
    Args:
        tenant_config: Validated tenant configuration
        
    Returns:
        Home ID for the tenant
    """
    return tenant_config.id

async def get_home_id_from_tenant_auth(tenant_config = Depends(validate_tenant_only)) -> int:
    """
    Extract home_id from validated tenant configuration for auth endpoints
    This replaces the original get_home_id dependency in auth endpoints
    
    Args:
        tenant_config: Validated tenant configuration
        
    Returns:
        Home ID for the tenant
    """
    return tenant_config.id

def create_tenant_api_router(original_api_router: APIRouter) -> APIRouter:
    """
    Convenience function to create a tenant-aware router
    
    Args:
        original_api_router: The existing APIRouter with /api/* endpoints
        
    Returns:
        New APIRouter with /{tenant_name}/api/* and /{tenant_name}/web endpoints
    """
    tenant_wrapper = TenantAPIRouter(original_api_router)
    
    # Add web routes for serving Flutter web app (tenant-specific build)
    web_build_path = "web-tenant"
    if os.path.exists(web_build_path):
        # Add login route (no authentication required)
        @tenant_wrapper.tenant_router.get("/{tenant_name}/login")
        async def serve_login_page(tenant_name: str = Path(...)):
            """Serve the login page - no authentication required"""
            # Just validate that the tenant exists
            tenant_config = load_tenant_config_from_db(tenant_name)
            if not tenant_config:
                raise HTTPException(
                    status_code=404,
                    detail=f"Tenant '{tenant_name}' not found"
                )
            
            index_path = os.path.join(web_build_path, "index.html")
            if os.path.exists(index_path):
                # Read and modify index.html to inject correct base href
                with open(index_path, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                # Replace base href with tenant-specific path for login
                content = content.replace('<base href="/">', f'<base href="/{tenant_name}/login/">')
                content = content.replace('<base href="/web/">', f'<base href="/{tenant_name}/login/">')
                # Also handle case where there's no base tag
                if '<base href=' not in content and '<head>' in content:
                    content = content.replace('<head>', f'<head>\n  <base href="/{tenant_name}/login/">')
                
                from fastapi.responses import HTMLResponse
                response = HTMLResponse(content=content, media_type="text/html")
                
                # Set cookie with tenant info for the login page
                response.set_cookie(
                    key="tenant_info",
                    value=f"{tenant_name}:{tenant_config.id}",
                    max_age=3600,  # 1 hour
                    httponly=False,  # Allow JavaScript access
                    secure=False,   # Set to True in production with HTTPS
                    samesite="lax"
                )
                
                return response
            else:
                raise HTTPException(status_code=404, detail="Web interface not found")
        
        # Add authenticated web routes (requires session and homeID header)
        @tenant_wrapper.tenant_router.get("/{tenant_name}/web")
        async def serve_web_index(
            request: Request,
            tenant_name: str = Path(...)
        ):
            """Serve the main Flutter web app index.html - requires authentication"""
            # Check authentication and redirect to login if needed
            auth_result = await validate_tenant_and_header_or_redirect(request, tenant_name)
            if isinstance(auth_result, RedirectResponse):
                return auth_result
            
            index_path = os.path.join(web_build_path, "index.html")
            if os.path.exists(index_path):
                # Read and modify index.html to inject correct base href for tenant
                with open(index_path, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                # Replace base href with tenant-specific path for the web management panel
                content = content.replace('<base href="/">', f'<base href="/{tenant_name}/web/">')
                content = content.replace('<base href="/web/">', f'<base href="/{tenant_name}/web/">')
                # Also handle case where there's no base tag
                if '<base href=' not in content and '<head>' in content:
                    content = content.replace('<head>', f'<head>\n  <base href="/{tenant_name}/web/">')
                
                from fastapi.responses import HTMLResponse
                return HTMLResponse(content=content, media_type="text/html")
            else:
                raise HTTPException(status_code=404, detail="Web interface not found")
        
        # Serve static assets for both login and authenticated routes
        @tenant_wrapper.tenant_router.get("/{tenant_name}/login/{path:path}")
        async def serve_login_assets(path: str, tenant_name: str = Path(...)):
            """Serve Flutter web static assets for login page"""
            # Just validate that the tenant exists
            tenant_config = load_tenant_config_from_db(tenant_name)
            if not tenant_config:
                raise HTTPException(
                    status_code=404,
                    detail=f"Tenant '{tenant_name}' not found"
                )
            
            # Security check to prevent directory traversal
            if ".." in path or path.startswith("/"):
                raise HTTPException(status_code=400, detail="Invalid path")
            
            asset_path = os.path.join(web_build_path, path)
            if os.path.exists(asset_path) and os.path.isfile(asset_path):
                return FileResponse(asset_path)
            else:
                raise HTTPException(status_code=404, detail="Asset not found")
        
        @tenant_wrapper.tenant_router.get("/{tenant_name}/web/{path:path}")
        async def serve_web_assets(
            request: Request,
            path: str,
            tenant_name: str = Path(...)
        ):
            """Serve Flutter web static assets for authenticated web app"""
            # Check authentication and redirect to login if needed
            auth_result = await validate_tenant_and_header_or_redirect(request, tenant_name)
            if isinstance(auth_result, RedirectResponse):
                return auth_result
            
            # Security check to prevent directory traversal
            if ".." in path or path.startswith("/"):
                raise HTTPException(status_code=400, detail="Invalid path")
            
            asset_path = os.path.join(web_build_path, path)
            if os.path.exists(asset_path) and os.path.isfile(asset_path):
                return FileResponse(asset_path)
            else:
                raise HTTPException(status_code=404, detail="Asset not found")
        
        logger.info(f"Added web static file routes from {web_build_path}")
    else:
        # If web build doesn't exist, add a simple endpoint
        @tenant_wrapper.tenant_router.get("/{tenant_name}/web")
        async def web_not_available(tenant_name: str = Path(...)):
            return {
                "message": f"Web interface for tenant '{tenant_name}' is not available",
                "note": "Flutter web build not found. Run 'flutter build web' to generate the web assets."
            }
        
        logger.warning(f"Web build path {web_build_path} not found. Added fallback endpoint.")
    
    return tenant_wrapper.tenant_router

# Export the main class and convenience function
__all__ = ['TenantAPIRouter', 'create_tenant_api_router', 'validate_tenant_and_header', 'validate_tenant_only', 'get_home_id_from_tenant_auth']