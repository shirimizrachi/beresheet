# Dual Web Architecture - Flutter Multi-Tenant System

## Overview

This document describes the implementation of a dual Flutter web build system that separates tenant user functionality from admin functionality into two independent web applications.

## Architecture

### Before (Single Build)
```
flutter build web --target lib/main_web.dart
    ↓
build/web/
    ↓
API serves from:
├── /{tenant_name}/web (tenant + admin)
└── /home/admin (admin only)
```

### After (Dual Build)
```
flutter build web --target lib/main_web.dart --output build/web-tenant
flutter build web --target lib/main_admin.dart --output build/web-admin
    ↓
build/
├── web-tenant/    (tenant-only functionality)
└── web-admin/     (admin-only functionality)
    ↓
API serves from:
├── /{tenant_name}/web → build/web-tenant
└── /home/admin → build/web-admin
```

## File Structure

### Flutter Entry Points
- **`lib/main_web.dart`** - Tenant-only web application
  - Web login and authentication
  - Tenant user management
  - Events management
  - Home page with events carousel
  - Removed all admin functionality

- **`lib/main_admin.dart`** - Admin-only web application
  - Admin login and authentication
  - Tenant management dashboard
  - Independent routing system
  - No tenant-specific functionality

### Build Scripts
- **`build_dual_web.sh/.bat`** - Builds both web applications
- **`build_and_serve_dual.sh/.bat`** - Complete build and serve pipeline

### API Service Updates
- **`api_service/main.py`** - Updated to serve dual builds
- **`api_service/tenant_auto_router.py`** - Serves tenant build
- **`api_service/admin.py`** - Serves admin build

## URL Routing

### Tenant Routes (Multi-tenant with validation)
```
/{tenant_name}/web              → build/web-tenant/index.html
/{tenant_name}/web/*            → build/web-tenant/assets
/{tenant_name}/login            → build/web-tenant/index.html (login page)
/{tenant_name}/api/*            → API with tenant validation
```

### Admin Routes (No tenant validation)
```
/home/admin                     → build/web-admin/index.html
/home/admin/*                   → build/web-admin/assets
/home/admin/api/*               → Admin API (no tenant prefix)
```

## Authentication Flow

### Tenant Authentication
1. User visits `/{tenant_name}/web`
2. System checks for valid session
3. If no session → redirect to `/{tenant_name}/login`
4. Login form authenticates via `/{tenant_name}/api/auth/login`
5. Success → redirect to `/{tenant_name}/web`

### Admin Authentication
1. User visits `/home/admin`
2. System checks for admin session
3. If no session → show admin login
4. Login form authenticates via `/home/admin/api/auth/login`
5. Success → show admin dashboard

## Build and Deployment

### Development
```bash
# Build both applications
./build_dual_web.sh

# Build and serve with hot reload
./build_and_serve_dual.sh
```

### Windows
```cmd
# Build both applications
build_dual_web.bat

# Build and serve
build_and_serve_dual.bat
```

### Manual Build
```bash
# Tenant build
flutter build web --target lib/main_web.dart --output build/web-tenant

# Admin build
flutter build web --target lib/main_admin.dart --output build/web-admin
```

## Benefits

### 1. Security
- Admin functionality not exposed to tenant users
- Separate authentication systems
- Reduced attack surface for tenant apps

### 2. Performance
- Smaller bundle sizes for each use case
- Tenant app: ~2MB (no admin code)
- Admin app: ~1.5MB (no tenant features)

### 3. Maintainability
- Clear separation of concerns
- Independent development cycles
- Easier debugging and testing

### 4. Deployment Flexibility
- Can deploy admin and tenant apps separately
- Different update schedules
- Better caching strategies

## Testing

### Tenant Application
1. Build: `flutter build web --target lib/main_web.dart --output build/web-tenant`
2. Test URL: `http://localhost:8000/{tenant_name}/web`
3. Features: Login, events, user management

### Admin Application
1. Build: `flutter build web --target lib/main_admin.dart --output build/web-admin`
2. Test URL: `http://localhost:8000/home/admin`
3. Features: Admin login, tenant management

## Migration Guide

### From Single Build to Dual Build

1. **Replace build script:**
   ```bash
   # OLD
   flutter build web --target lib/main_web.dart
   
   # NEW
   ./build_dual_web.sh
   ```

2. **Update deployment script:**
   ```bash
   # OLD
   ./build_and_serve.sh
   
   # NEW
   ./build_and_serve_dual.sh
   ```

3. **Verify endpoints:**
   - Tenant: `/{tenant_name}/web`
   - Admin: `/home/admin`

## Troubleshooting

### Build Issues
```bash
# Clean builds
rm -rf build/
./build_dual_web.sh
```

### Missing Admin Route
- Ensure `build/web-admin/` exists
- Check `api_service/admin.py` web_build_path

### Missing Tenant Route
- Ensure `build/web-tenant/` exists
- Check `api_service/tenant_auto_router.py` web_build_path

## Development Workflow

### Adding Tenant Features
1. Edit `lib/main_web.dart` or tenant screens
2. Build: `flutter build web --target lib/main_web.dart --output build/web-tenant`
3. Test: `/{tenant_name}/web`

### Adding Admin Features
1. Edit `lib/main_admin.dart` or admin screens
2. Build: `flutter build web --target lib/main_admin.dart --output build/web-admin`
3. Test: `/home/admin`

## Configuration

### Tenant Config (`lib/config/app_config.dart`)
- Tenant-specific API endpoints
- Multi-tenant settings
- User authentication

### Admin Config (`lib/config/admin_config.dart`)
- Admin-specific API endpoints
- Tenant management settings
- Admin authentication

## API Endpoints Summary

```
GET  /                                    # Root info with tenant links
GET  /{tenant_name}/web                   # Tenant web app
GET  /{tenant_name}/api/*                 # Tenant API (with validation)
POST /{tenant_name}/api/auth/login        # Tenant login
GET  /home/admin                          # Admin web app
GET  /home/admin/api/*                    # Admin API (no tenant validation)
POST /home/admin/api/auth/login           # Admin login
GET  /docs                                # API documentation
```

This dual web architecture provides complete separation between tenant and admin functionality while maintaining the existing multi-tenant routing system.