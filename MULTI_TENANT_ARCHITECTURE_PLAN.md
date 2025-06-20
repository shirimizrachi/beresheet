# Multi-Tenant API Architecture Implementation Plan

## Overview
Transform the existing FastAPI application into a multi-tenant architecture where each tenant (homeId) has its own database schema and URL endpoints.

## Current State Analysis
- API currently uses single [`api_router = APIRouter(prefix="/api")`](api_service/main.py:69) 
- Uses header-based [`get_home_id()`](api_service/main.py:75) dependency for tenant identification
- Has existing schema-based routing via [`home_mapping.py`](api_service/home_mapping.py:1)
- Current web endpoint serves Flutter web at [`/web`](api_service/main.py:847)

## Target Architecture

### URL Structure
- `/{tenant_id}/api/*` - Tenant-specific API endpoints
- `/{tenant_id}/web/*` - Tenant-specific web interface  
- `/home/admin` - Admin interface for tenant management
- `/` - Root endpoint

### Examples
- `http://localhost:8000/beresheet/api/events`
- `http://localhost:8000/beresheet/web`
- `http://localhost:8000/demo/api/users`
- `http://localhost:8000/demo/web`
- `http://localhost:8000/home/admin`

## Architecture Diagram

```mermaid
graph TB
    subgraph "Multi-Tenant API Architecture"
        A[FastAPI App] --> B[Tenant Router]
        A --> C[Admin Router]
        A --> D[Root Router]
        
        B --> E[/{tenant_id}/api/*]
        B --> F[/{tenant_id}/web/*]
        
        C --> G[/home/admin/*]
        
        subgraph "Database Layer"
            H[(Admin DB: home_admin)] --> I[Tenant Configurations]
            J[(Tenant DB: home)] --> K[Beresheet Schema]
            J --> L[Demo Schema]
        end
        
        subgraph "Tenant Configuration"
            M[Tenant Validator] --> N[Dynamic DB Connection]
            N --> O[Schema Selection]
        end
        
        E --> M
        F --> M
        G --> H
    end
```

## Implementation Plan

### Phase 1: Database & Configuration Setup

#### 1. Create Admin Database Structure
- Create new database: `home_admin` (separate from tenant data)
- Create schema: `home` within `home_admin`
- Create table: `home` for tenant configurations

#### 2. Tenant Configuration Model
```python
class TenantConfig(BaseModel):
    id: int
    name: str
    database_name: str  
    database_type: str
    database_schema: str
    admin_user_email: str
    admin_user_password: str
```

#### 3. Database Connection Management
- Extend [`database_utils.py`](api_service/database_utils.py:1) to support admin database
- Create tenant configuration loader from admin database
- Dynamic connection string generation based on tenant config

### Phase 2: Tenant Validation & Routing

#### 1. Tenant Validation Dependency
```python
def get_tenant(tenant_id: str = Path(...)):
    tenant_config = load_tenant_config_from_db(tenant_id)
    if not tenant_config:
        raise HTTPException(404, "Tenant not found")
    return tenant_config
```

#### 2. Multi-Tenant Router Setup
```python
# Replace current api_router with tenant-aware router
tenant_router = APIRouter()

@tenant_router.get("/api/items/")
async def get_items(tenant = Depends(get_tenant)):
    # Use tenant.database_schema for connection
    return {"tenant": tenant.name, "items": [...]}

# Mount under dynamic tenant prefix
app.include_router(tenant_router, prefix="/{tenant_id}")
```

### Phase 3: Admin Interface Implementation

#### 1. Admin Database Service
- Create [`admin.py`](api_service/admin.py:1) for tenant CRUD operations
- Connection to `home_admin` database with connection string:
  ```
  mssql+pyodbc://localhost\SQLEXPRESS/home_admin?driver=ODBC+Driver+17+for+SQL+Server&TrustServerCertificate=yes&Trusted_Connection=yes
  ```
- Tenant management endpoints

#### 2. Admin Router
```python
admin_router = APIRouter(prefix="/home/admin")

@admin_router.get("/tenants")
async def get_tenants():
    # Return all tenant configurations

@admin_router.post("/tenants")
async def create_tenant(tenant: TenantCreate):
    # Create new tenant configuration
```

#### 3. Admin Web Interface
- Serve admin web page at `/home/admin`
- CRUD interface for tenant management

### Phase 4: URL Structure Implementation

#### Replace Current Web Routing
- Remove existing `/web` endpoints
- Implement tenant-specific web serving at `/{tenant_id}/web`
- Each tenant serves the same Flutter web app but with tenant context

### Phase 5: Initialization & Migration

#### 1. Database Setup Scripts
- Create `home_admin` database
- Create `home` schema and table within `home_admin`
- Insert initial tenant configurations

#### 2. Initial Tenant Data
```sql
-- Insert beresheet tenant
INSERT INTO home.home (id, name, database_name, database_type, 
                      database_schema, admin_user_email, admin_user_password)
VALUES (1, 'beresheet', 'home', 'mssql', 'beresheet', 
        'ranmizrachi@gmail.com', '123456');

-- Insert demo tenant  
INSERT INTO home.home (id, name, database_name, database_type,
                      database_schema, admin_user_email, admin_user_password)
VALUES (2, 'demo', 'home', 'mssql', 'demo',
        'ranmizrachi@gmail.com', '123456');
```

#### 3. Migration from Current System
- Update [`home_mapping.py`](api_service/home_mapping.py:1) to use database-driven configuration
- Migrate existing header-based system to path-based routing

## Key Implementation Details

### Tenant Configuration Loading
```python
def load_tenant_config_from_db(tenant_id: str) -> Optional[TenantConfig]:
    # Connect to admin database
    admin_connection_string = "mssql+pyodbc://localhost\\SQLEXPRESS/home_admin?driver=ODBC+Driver+17+for+SQL+Server&TrustServerCertificate=yes&Trusted_Connection=yes"
    admin_engine = create_engine(admin_connection_string)
    with admin_engine.connect() as conn:
        result = conn.execute(
            text("SELECT * FROM home.home WHERE name = :tenant_id"),
            {"tenant_id": tenant_id}
        )
        row = result.fetchone()
        if row:
            return TenantConfig(**dict(row))
    return None
```

### Dynamic Connection String Generation
```python
def get_tenant_connection_string(tenant_config: TenantConfig) -> str:
    if tenant_config.database_type == "mssql":
        return f"mssql+pyodbc://localhost\\SQLEXPRESS/{tenant_config.database_name}?driver=ODBC+Driver+17+for+SQL+Server&TrustServerCertificate=yes&Trusted_Connection=yes"
    # Add support for other database types as needed
```

### Schema Context in Database Operations
All existing database operations will be updated to use tenant-specific connections and schemas.

## File Structure Changes

### New Files to Create
- [`api_service/admin.py`](api_service/admin.py:1) - Admin tenant management
- [`api_service/tenant_config.py`](api_service/tenant_config.py:1) - Tenant configuration models and database operations
- [`api_service/multi_tenant_router.py`](api_service/multi_tenant_router.py:1) - Tenant-aware routing
- [`deployment/create_admin_database.py`](deployment/create_admin_database.py:1) - Admin database setup
- [`deployment/create_tenant_table.py`](deployment/create_tenant_table.py:1) - Tenant configuration table
- [`deployment/init_tenant_data.py`](deployment/init_tenant_data.py:1) - Initial tenant data

### Files to Modify
- [`api_service/main.py`](api_service/main.py:1) - Update routing structure
- [`api_service/database_utils.py`](api_service/database_utils.py:1) - Add admin database support
- [`api_service/home_mapping.py`](api_service/home_mapping.py:1) - Database-driven configuration

## Database Schema

### Admin Database (`home_admin`)
```sql
CREATE DATABASE home_admin;
USE home_admin;
CREATE SCHEMA home;

CREATE TABLE home.home (
    id INT PRIMARY KEY,
    name NVARCHAR(50) NOT NULL UNIQUE,
    database_name NVARCHAR(50) NOT NULL,
    database_type NVARCHAR(20) NOT NULL DEFAULT 'mssql',
    database_schema NVARCHAR(50) NOT NULL,
    admin_user_email NVARCHAR(100) NOT NULL,
    admin_user_password NVARCHAR(100) NOT NULL,
    created_at DATETIME2 DEFAULT GETDATE(),
    updated_at DATETIME2 DEFAULT GETDATE()
);
```

### Tenant Database (`home`)
- Existing database with tenant-specific schemas (`beresheet`, `demo`)
- Each schema contains all tenant-specific tables (users, events, etc.)

## Benefits of This Architecture

1. **True Multi-Tenancy**: Each tenant gets isolated database schemas
2. **Dynamic Configuration**: Tenant configurations stored in database, not code
3. **Scalable**: Easy to add new tenants without code changes
4. **Secure**: Tenant isolation at database level
5. **Maintainable**: Clean separation of tenant and admin concerns
6. **RESTful URLs**: Intuitive tenant-specific endpoints
7. **Admin Isolation**: Tenant management completely separated from tenant data

## Implementation Order

1. **Phase 1**: Database setup and tenant configuration system
2. **Phase 2**: Tenant validation and basic routing
3. **Phase 3**: Admin interface implementation
4. **Phase 4**: Complete URL structure and web serving
5. **Phase 5**: Data migration and initialization

This plan provides a complete roadmap for transforming the existing single-tenant API into a robust multi-tenant architecture.