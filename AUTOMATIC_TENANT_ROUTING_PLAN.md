# Automatic Tenant Routing Implementation Plan

## Objective
Replace ALL `/api/*` endpoints with `/{tenant_name}/api/*` automatically, without manually converting each endpoint.

## Solution Overview
Create an automatic tenant routing system that:
1. Takes the existing `api_router` with all endpoints
2. Automatically creates new routes at `/{tenant_name}/api/*`
3. Validates tenant exists and homeID header matches
4. Removes legacy `/api/*` endpoints completely
5. Zero code changes to existing endpoint functions

## Architecture

```mermaid
graph TB
    subgraph "Current Endpoints"
        A[api_router.get("/events")]
        B[api_router.get("/users")]
        C[api_router.post("/events")]
        D[api_router.get("/rooms")]
    end
    
    subgraph "Automatic Transformation"
        E[TenantAPIRouter]
        F[Wraps ALL existing routes]
        G[Adds tenant validation]
    end
    
    subgraph "New Endpoints"
        H[GET /{tenant_name}/api/events]
        I[GET /{tenant_name}/api/users]
        J[POST /{tenant_name}/api/events]
        K[GET /{tenant_name}/api/rooms]
    end
    
    A --> E
    B --> E
    C --> E
    D --> E
    E --> F
    F --> G
    G --> H
    G --> I
    G --> J
    G --> K
```

## Implementation Strategy

### 1. TenantAPIRouter Class
Automatically wraps ALL existing API routes with tenant validation:

```python
class TenantAPIRouter:
    def __init__(self, original_api_router: APIRouter):
        self.tenant_router = APIRouter()
        self._wrap_all_routes(original_api_router)
    
    def _wrap_all_routes(self, api_router):
        for route in api_router.routes:
            self._create_tenant_route(route)
```

### 2. Automatic Route Creation
For each existing route, create a new tenant-aware version:

```python
def _create_tenant_route(self, original_route):
    # Original: GET /events
    # New: GET /{tenant_name}/api/events
    
    original_path = original_route.path  # "/events"
    tenant_path = f"/{{tenant_name}}/api{original_path}"
    
    # Create wrapper that adds tenant validation
    wrapped_endpoint = self._wrap_endpoint(original_route.endpoint)
    
    # Create new route with tenant validation
    self.tenant_router.add_api_route(
        path=tenant_path,
        endpoint=wrapped_endpoint,
        methods=original_route.methods,
        response_model=original_route.response_model,
        dependencies=[Depends(validate_tenant_and_header)],
        # Copy all other properties...
    )
```

### 3. Tenant Validation
Validate tenant name from URL and ensure homeID header matches:

```python
async def validate_tenant_and_header(
    tenant_name: str = Path(...),
    home_id: int = Depends(get_home_id)  # Existing header dependency
):
    # Load tenant config by name
    tenant_config = load_tenant_config_from_db(tenant_name)
    if not tenant_config:
        raise HTTPException(404, f"Tenant '{tenant_name}' not found")
    
    # Verify homeID header matches tenant
    if tenant_config.id != home_id:
        raise HTTPException(400, 
            f"HomeID {home_id} doesn't match tenant '{tenant_name}' (expected {tenant_config.id})")
    
    return tenant_config
```

### 4. Endpoint Wrapper
Preserve all existing functionality:

```python
def _wrap_endpoint(self, original_endpoint):
    async def tenant_aware_endpoint(*args, **kwargs):
        # Tenant validation happens in dependency
        # All existing logic runs unchanged
        return await original_endpoint(*args, **kwargs)
    
    # Preserve function signature and metadata
    tenant_aware_endpoint.__name__ = original_endpoint.__name__
    tenant_aware_endpoint.__annotations__ = original_endpoint.__annotations__
    
    return tenant_aware_endpoint
```

## URL Transformation Examples

### Before (Current)
- `GET /api/events` + `homeID: 1` header
- `GET /api/users` + `homeID: 1` header  
- `POST /api/events` + `homeID: 1` header
- `GET /api/rooms` + `homeID: 1` header

### After (Automatic)
- `GET /beresheet/api/events` + `homeID: 1` header ✅
- `GET /beresheet/api/users` + `homeID: 1` header ✅
- `POST /beresheet/api/events` + `homeID: 1` header ✅
- `GET /beresheet/api/rooms` + `homeID: 1` header ✅

### ALL Endpoints Automatically Supported
- `/{tenant_name}/api/events`
- `/{tenant_name}/api/users`
- `/{tenant_name}/api/rooms`
- `/{tenant_name}/api/event-instructors`
- `/{tenant_name}/api/service-provider-types`
- `/{tenant_name}/api/requests`
- `/{tenant_name}/api/registrations`
- `/{tenant_name}/api/auth/login`
- **Every single existing endpoint!**

## Implementation Steps

### 1. Create Automatic Router
```python
# api_service/tenant_auto_router.py
class TenantAPIRouter:
    # Implementation details...
```

### 2. Update Main Application
```python
# api_service/main.py

# Create tenant-aware router from existing api_router
tenant_api_router = TenantAPIRouter(api_router)

# Mount ONLY tenant routes (no more /api/*)
app.include_router(tenant_api_router.tenant_router)

# Remove legacy api_router completely
# app.include_router(api_router)  # DELETED
```

### 3. Zero Changes to Endpoints
ALL existing endpoint files remain exactly the same:
- `events.py` - No changes
- `users.py` - No changes  
- `rooms.py` - No changes
- `request_service.py` - No changes
- etc.

## Validation Logic

### Valid Requests
✅ `GET /beresheet/api/events` + `homeID: 1` (beresheet ID is 1)
✅ `GET /demo/api/events` + `homeID: 2` (demo ID is 2)
✅ `POST /beresheet/api/users` + `homeID: 1` (beresheet ID is 1)

### Invalid Requests  
❌ `GET /beresheet/api/events` + `homeID: 2` (beresheet is ID 1, not 2)
❌ `GET /nonexistent/api/events` + `homeID: 1` (tenant doesn't exist)
❌ `GET /api/events` (legacy endpoint removed)

## Benefits

✅ **Complete Migration**: No legacy `/api/*` endpoints
✅ **Zero Endpoint Changes**: All existing code unchanged
✅ **Automatic Coverage**: ALL endpoints get tenant support
✅ **Security**: URL tenant must match homeID header
✅ **Clean URLs**: Consistent `/{tenant_name}/api/*` pattern
✅ **Maintainable**: New endpoints automatically get tenant support

## File Changes Required

### New Files
- `api_service/tenant_auto_router.py` - Automatic tenant routing system

### Modified Files  
- `api_service/main.py` - Replace api_router with tenant_api_router (5 lines)

### Unchanged Files
- ALL endpoint files (events.py, users.py, etc.) - Zero changes!
- ALL models and database code - Zero changes!
- ALL existing dependencies - Zero changes!

This provides a complete migration to tenant-based URLs with maximum automation and minimal code changes.