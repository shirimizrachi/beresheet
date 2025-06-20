# Multi-Tenant API Setup Guide

This guide walks you through setting up and using the new multi-tenant architecture for the Beresheet Events API.

## Overview

The multi-tenant architecture allows you to:
- Host multiple tenants with isolated data in separate database schemas
- Access tenant-specific endpoints: `/{tenant_name}/api/*` and `/{tenant_name}/web/*`
- **ALL existing API endpoints automatically work with tenant URLs**
- Manage tenants through an admin interface at `/home/admin`
- Complete migration from `/api/*` to tenant-based URLs

## Quick Start

### 1. Database Setup

Run the automated setup script:

```bash
cd deployment
python setup_multi_tenant.py
```

This will:
- Create the admin database (`home_admin`)
- Create the tenant configuration table
- Set up demo schema
- Insert default tenants (beresheet, demo)

### 2. Start the API Server

```bash
cd api_service
python main.py
```

The server will start on `http://localhost:8000`

### 3. Test the Setup

```bash
cd api_service
python test_multi_tenant.py
```

## Available Endpoints

### Root Endpoint
- `GET /` - Shows available tenants and their endpoints

### Admin Interface
- `GET /home/admin` - Web interface for tenant management
- `GET /home/admin/api/tenants` - List all tenants
- `POST /home/admin/api/tenants` - Create new tenant
- `PUT /home/admin/api/tenants/{id}` - Update tenant
- `DELETE /home/admin/api/tenants/{id}` - Delete tenant

### Tenant-Specific Endpoints (ALL AUTOMATICALLY CREATED)
- `GET /{tenant_name}/web` - Tenant web application
- `GET /{tenant_name}/api/events` - Events endpoint
- `GET /{tenant_name}/api/users` - Users endpoint
- `GET /{tenant_name}/api/rooms` - Rooms endpoint
- `GET /{tenant_name}/api/event-instructors` - Event instructors endpoint
- `GET /{tenant_name}/api/service-provider-types` - Service provider types endpoint
- `GET /{tenant_name}/api/requests` - Requests endpoint
- `POST /{tenant_name}/api/events` - Create event endpoint
- `PUT /{tenant_name}/api/events/{id}` - Update event endpoint
- **... and ALL other existing API endpoints automatically!**

### Legacy Endpoints
- ❌ `/api/*` endpoints have been **completely removed**
- ✅ All API access now requires tenant-specific URLs

## Default Tenants

Two tenants are created by default:

### Beresheet
- **URL**: `http://localhost:8000/beresheet/`
- **API**: `http://localhost:8000/beresheet/api/`
- **Web**: `http://localhost:8000/beresheet/web`
- **Schema**: `beresheet` (in `home` database)

### Demo
- **URL**: `http://localhost:8000/demo/`
- **API**: `http://localhost:8000/demo/api/`
- **Web**: `http://localhost:8000/demo/web`
- **Schema**: `demo` (in `home` database)

## Adding New Tenants

### Via Admin Interface

1. Go to `http://localhost:8000/home/admin`
2. Click "➕ Add New Tenant"
3. Fill in the tenant details:
   - **Tenant Name**: URL-friendly identifier (e.g., "newclient")
   - **Database Name**: Usually "home"
   - **Database Schema**: Schema name in the database
   - **Admin Email**: Tenant administrator email
   - **Admin Password**: Tenant administrator password

### Via API

```bash
curl -X POST "http://localhost:8000/home/admin/api/tenants" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "newclient",
    "database_name": "home",
    "database_type": "mssql",
    "database_schema": "newclient",
    "admin_user_email": "admin@newclient.com",
    "admin_user_password": "secure_password"
  }'
```

### Automatic Endpoint Creation

🎉 **No additional setup needed!** Once a tenant is created:
- ALL existing endpoints automatically work at `/{tenant_name}/api/*`
- No code changes required
- No manual endpoint configuration

### Database Schema Setup

After creating a tenant, you need to create the database schema and tables:

1. **Create the schema**:
   ```bash
   cd deployment
   python create_schema.py newclient
   ```

2. **Create tables** (run these for the new schema):
   ```bash
   # Update the scripts to use the new schema, then run:
   python create_users_table.py
   python create_events_table.py
   python create_rooms_table.py
   # ... and other table creation scripts
   ```

3. **Instant API Access**:
   ```
   http://localhost:8000/newclient/api/events
   http://localhost:8000/newclient/api/users
   http://localhost:8000/newclient/web
   ```

## Database Structure

### Admin Database (`home_admin`)
```
home_admin/
└── home/
    └── home (table)
        ├── id (int, primary key)
        ├── name (string, unique)
        ├── database_name (string)
        ├── database_type (string)
        ├── database_schema (string)
        ├── admin_user_email (string)
        ├── admin_user_password (string)
        ├── created_at (datetime)
        └── updated_at (datetime)
```

### Tenant Database (`home`)
```
home/
├── beresheet/ (schema)
│   ├── users
│   ├── events
│   ├── rooms
│   └── ... (all other tables)
└── demo/ (schema)
    ├── users
    ├── events
    ├── rooms
    └── ... (all other tables)
```

## Migration from Single-Tenant

If you're migrating from the old single-tenant setup:

### 1. Backup Data
Make sure to backup your existing data before migration.

### 2. Update Client Applications
Update API calls from:
```
http://localhost:8000/api/events
```
To:
```
http://localhost:8000/beresheet/api/events
```

### 3. Update Web Application URLs
Update web app URLs from:
```
http://localhost:8000/web
```
To:
```
http://localhost:8000/beresheet/web
```

### 4. Headers Requirements
**Important**: Headers are still required and validated:
```javascript
// OLD (no longer works)
fetch('/api/events', {
  headers: {
    'homeID': '1',
    'userId': 'user123'
  }
})

// NEW (required format)
fetch('/beresheet/api/events', {
  headers: {
    'homeID': '1',        // Must match tenant ID (beresheet = 1)
    'userId': 'user123'   // Still required for user-specific endpoints
  }
})
```

**Header Validation Rules**:
- `homeID` header must match the tenant's database ID
- `beresheet` tenant expects `homeID: 1`
- `demo` tenant expects `homeID: 2`
- Mismatched headers result in 400 error

## Architecture Benefits

### 1. **True Multi-Tenancy**
- Each tenant has isolated data in separate database schemas
- No data leakage between tenants
- Schema-level security

### 2. **Automatic Endpoint Generation**
- **Zero code changes** to add tenant support
- ALL existing endpoints automatically work with tenant URLs
- New endpoints automatically get tenant support

### 3. **Scalability**
- Easy to add new tenants without code changes
- Database-driven configuration
- Horizontal scaling support

### 4. **Security**
- Tenant isolation at database level
- URL tenant name must match homeID header
- Admin interface separated from tenant data

### 5. **Maintainability**
- Clean separation of concerns
- Centralized tenant management
- RESTful URL structure
- Single codebase serves all tenants

## Troubleshooting

### Common Issues

1. **"Tenant not found" errors**
   - Check if tenant exists in admin interface
   - Verify tenant name spelling in URL
   - Check database connectivity

2. **Database connection errors**
   - Verify SQL Server is running
   - Check connection strings in tenant configuration
   - Ensure database schemas exist

3. **Admin interface not loading**
   - Check if `admin_web.html` exists in `api_service` directory
   - Verify admin database is set up correctly
   - Check server logs for errors

### Debugging

Enable SQL debugging in [`database_utils.py`](api_service/database_utils.py):
```python
SQL_DEBUG = True  # Change to True for SQL query logging
```

### Testing

Run the comprehensive test suite:
```bash
cd api_service
python test_multi_tenant.py
```

## API Documentation

With the server running, visit:
- **Swagger UI**: `http://localhost:8000/docs`
- **ReDoc**: `http://localhost:8000/redoc`

## Support

For issues or questions:
1. Check the server logs
2. Run the test suite
3. Verify database setup
4. Review the architecture plan in [`MULTI_TENANT_ARCHITECTURE_PLAN.md`](MULTI_TENANT_ARCHITECTURE_PLAN.md)

## Next Steps

After setup, you can:
1. Customize tenant configurations
2. Add custom tenant-specific logic
3. Implement tenant-specific themes
4. Set up monitoring and analytics per tenant
5. Configure backup strategies per tenant