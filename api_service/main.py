from fastapi import FastAPI, HTTPException, Query, File, UploadFile, Header, Depends, Form
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from typing import List, Optional
from datetime import datetime
from modules.events import event_db, router as events_router, events_registration_db, event_instructor_db, event_gallery_db, room_db
from modules.notification import router as home_notification_router
from modules.users import user_db, service_provider_type_db, router as users_router
from modules.service_requests import request_db, router as service_requests_router
from storage.storage_service import azure_storage_service
import uvicorn
import os

# Create FastAPI app
app = FastAPI(
    title="Multi-Tenant Events API",
    description="Multi-tenant API for managing events with tenant-specific routing",
    version="2.0.0"
)

# Add middleware for request logging
from fastapi import Request
from fastapi.responses import Response
import time

@app.middleware("http")
async def log_requests(request: Request, call_next):
    start_time = time.time()
    
    # Only log specific request types (API, web, home)
    path = request.url.path
    should_log = (
        path.startswith('/api') or
        path.startswith('/web') or
        path.startswith('/home') or
        any(f'/{part}/api' in path or f'/{part}/web' in path for part in path.split('/')[1:2])
    )
    
    if should_log:
        # Log incoming request details
        print(f"\n=== INCOMING REQUEST ===")
        print(f"Method: {request.method}")
        print(f"URL: {request.url}")
        print(f"Path: {request.url.path}")
        print(f"Query: {request.url.query}")
        #print(f"Headers: {dict(request.headers)}")
    
    response = await call_next(request)
    
    if should_log:
        process_time = time.time() - start_time
        print(f"Status: {response.status_code}")
        print(f"Process time: {process_time:.4f}s")
        print(f"========================\n")
    
    return response

# Add CORS middleware to allow requests from Flutter web and mobile
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify exact origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Import multi-tenant routing components
from modules.admin import admin_router, admin_api_router
from web_jwt_auth import web_jwt_router
from tenant_config import get_all_tenants
from tenant_auto_router import create_tenant_api_router

# Create API router (will be automatically wrapped with tenant routing)
from fastapi import APIRouter
api_router = APIRouter(prefix="/api")

# Web build paths for Flutter web (dual builds)
tenant_web_build_path = "web-tenant"
admin_web_build_path = "web-admin"

# Mount static files for Flutter web (dual builds)
import os
if os.path.exists(tenant_web_build_path):
    app.mount("/static/tenant", StaticFiles(directory=tenant_web_build_path), name="tenant-static")

if os.path.exists(admin_web_build_path):
    app.mount("/static/admin", StaticFiles(directory=admin_web_build_path), name="admin-static")

# Header dependencies
async def get_home_id(home_id: str = Header(..., alias="homeID")):
    """Dependency to extract and validate homeID header"""
    if not home_id:
        raise HTTPException(status_code=400, detail="homeID header is required")
    try:
        return int(home_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="homeID must be a valid integer")

async def get_firebase_token(firebase_token: Optional[str] = Header(None, alias="firebaseToken")):
    """Dependency to extract Firebase token header"""
    return firebase_token

async def get_user_id(user_id: Optional[str] = Header(None, alias="userId")):
    """Dependency to extract user ID header"""
    return user_id

async def get_user_role(user_id: str, home_id: int) -> str:
    """Get user role from database"""
    user = user_db.get_user_profile(user_id, home_id)
    if not user:
        raise HTTPException(status_code=404, detail="User profile not found")
    return user.role

async def require_manager_role(user_id: str, home_id: int):
    """Dependency to ensure user has manager role"""
    role = await get_user_role(user_id, home_id)
    if role != "manager":
        raise HTTPException(status_code=403, detail="Manager role required")
    return True

@app.get("/")
async def root():
    """Root endpoint - show available tenants"""
    try:
        tenants = get_all_tenants()
        tenant_links = {}
        for tenant in tenants:
            tenant_links[tenant.name] = {
                "web": f"/{tenant.name}/web",
                "api": f"/{tenant.name}/api",
                "docs": f"/{tenant.name}/docs"
            }
        
        return {
            "message": "Multi-Tenant Events API",
            "version": "2.0.0",
            "available_tenants": tenant_links,
            "admin": "/home/admin",
            "api_docs": "/docs"
        }
    except Exception as e:
        return {
            "message": "Multi-Tenant Events API",
            "version": "2.0.0",
            "error": f"Could not load tenants: {str(e)}",
            "admin": "/home/admin",
            "api_docs": "/docs"
        }

@app.get("/api/health")
async def global_health_check():
    """Global health check endpoint for Kubernetes - no tenant validation required"""
    return {"status": "healthy", "service": "residents-api", "version": "2.0.0"}

@app.get("/health")
async def simple_health_check():
    """Simple health check endpoint for load balancers - no tenant validation required"""
    return {"status": "healthy"}

@app.get("/debug/routes")
async def debug_routes():
    """Debug endpoint to show all registered routes"""
    routes = []
    for route in app.routes:
        if hasattr(route, 'path'):
            routes.append({
                "path": route.path,
                "methods": getattr(route, 'methods', []),
                "name": getattr(route, 'name', None)
            })
    return {"total_routes": len(routes), "routes": routes}

@api_router.get("/")
async def api_root():
    """API root endpoint"""
    return {
        "message": "Beresheet Events API",
        "version": "1.0.0",
        "docs": "/docs"
    }

@api_router.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy", "events_count": len(event_db.get_all_events())}





# Statistics endpoint
@api_router.get("/stats")
async def get_stats(home_id: int = Depends(get_home_id)):
    """Get API statistics"""
    all_events = event_db.get_all_events(home_id)
    upcoming_events = event_db.get_upcoming_events(home_id)
    
    # Count events by type
    type_counts = {}
    for event in all_events:
        type_counts[event.type] = type_counts.get(event.type, 0) + 1
    
    return {
        "total_events": len(all_events),
        "upcoming_events": len(upcoming_events),
        "events_by_type": type_counts,
        "total_participants": sum(event.currentParticipants for event in all_events),
        "available_spots": sum(event.maxParticipants - event.currentParticipants for event in all_events)
    }

# Homes endpoint
@api_router.get("/homes")
async def get_available_homes():
    """Get all available homes for creating user profiles"""
    homes = user_db.get_available_homes()
    return homes

# Rooms endpoints have been moved to modules/events/events_routes.py



# Service Provider Types endpoints have been moved to modules/users/users_routes.py

# Service Requests endpoints have been moved to modules/service_requests/service_requests_routes.py

# User endpoints have been moved to modules/users/users_routes.py

# Create complete tenant router with API and web endpoints
tenant_router = create_tenant_api_router(api_router)

# Create tenant-aware notification router
from tenant_auto_router import create_tenant_api_router
tenant_notification_router = create_tenant_api_router(home_notification_router)

# Create tenant-aware events router
tenant_events_router = create_tenant_api_router(events_router)

# Create tenant-aware users router
tenant_users_router = create_tenant_api_router(users_router)

# Create tenant-aware service requests router
tenant_service_requests_router = create_tenant_api_router(service_requests_router)

# Create tenant-aware web JWT auth router
tenant_web_jwt_router = create_tenant_api_router(web_jwt_router)

# Create global discovery router (not tenant-specific)
global_router = APIRouter()

@global_router.get("/api/users/get_user_home")
async def global_get_user_home(phone_number: str = Query(...)):
    """Global endpoint to get user's home information by phone number - used for tenant discovery"""
    try:
        # Import the normalization function
        from modules.users.users import normalize_phone_number
        
        # Normalize phone number by removing leading zeros
        normalized_phone = normalize_phone_number(phone_number)
        
        home_info = user_db.get_user_home_info(normalized_phone)
        if not home_info:
            raise HTTPException(
                status_code=404,
                detail="User not found. Please contact support to set up your account."
            )
        return home_info
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@global_router.get("/api/home_index/get_home_by_phone")
async def global_get_home_by_phone(phone_number: str = Query(...)):
    """Global endpoint to get home information by phone number directly from home_index - used for tenant discovery"""
    try:
        # Import the normalization function
        from modules.users.users import normalize_phone_number
        from home_index import home_index_db
        
        # Normalize phone number by removing leading zeros
        normalized_phone = normalize_phone_number(phone_number)
        
        home_info = home_index_db.get_home_by_phone(normalized_phone)
        if not home_info:
            raise HTTPException(
                status_code=404,
                detail="User not found. Please contact support to set up your account."
            )
        return home_info
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# Include routers in the correct order
# 1. Admin API routes first (highest priority) - must come before catch-all routes
app.include_router(admin_api_router)
app.include_router(admin_router)

# 2. Global discovery endpoints (no tenant prefix)
app.include_router(global_router)

# 3. Complete tenant router (/{tenant_name}/api/* and /{tenant_name}/web)
app.include_router(tenant_router)

# 3. Tenant notification routes (/{tenant_name}/api/notifications/*)
app.include_router(tenant_notification_router)

# 4. Tenant events routes (/{tenant_name}/api/events/*)
app.include_router(tenant_events_router)

# 5. Tenant users routes (/{tenant_name}/api/users/*)
app.include_router(tenant_users_router)

# 6. Tenant service requests routes (/{tenant_name}/api/requests/*)
app.include_router(tenant_service_requests_router)

# 7. Tenant web JWT auth routes (/{tenant_name}/api/web-auth/*)
app.include_router(tenant_web_jwt_router)

# Note: ALL endpoints are now tenant-specific:
# - /{tenant_name}/api/* for all API endpoints
# - /{tenant_name}/web for web interface
# - /home/admin for tenant management

if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
        log_level="info"
    )
