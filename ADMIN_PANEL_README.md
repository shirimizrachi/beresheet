# Independent Flutter Web Admin Panel

## Overview

This document describes the independent admin panel system for multi-tenant management, implemented as a completely separate Flutter web application that runs alongside the existing web management system.

## Architecture

### Independence
- **Separate Authentication**: Uses home table in home schema for authentication
- **Independent Session Management**: No shared code with existing web management
- **Isolated Routing**: Uses `/home/admin/*` path prefix
- **No Code Sharing**: Completely separate services, models, and UI components

### Key Components

```
lib/
├── screen/admin/                           # Admin UI components
│   ├── admin_login_screen.dart            # Login page
│   ├── admin_dashboard_screen.dart        # Main dashboard
│   └── widgets/                           # Admin-specific widgets
│       ├── tenant_card_widget.dart        # Tenant display card
│       ├── tenant_form_widget.dart        # Tenant create/edit form
│       └── table_management_widget.dart   # Table operations
├── services/admin/                         # Admin services
│   ├── admin_auth_service.dart            # Authentication
│   ├── admin_session_service.dart         # Session management
│   └── admin_api_service.dart             # API communication
├── model/admin/                           # Admin models
│   ├── admin_user.dart                    # Admin user model
│   ├── tenant.dart                        # Tenant models
│   └── tenant_table.dart                  # Table models
└── config/admin_config.dart               # Admin configuration
```

## Features

### 1. Admin Authentication
- **Login Route**: `/home/admin/login`
- **Credentials**: Email/password from home table in home schema
- **JWT Tokens**: Secure session management with automatic expiration
- **Session Storage**: Encrypted local storage using `flutter_secure_storage`

### 2. Tenant Management
- **Create Tenants**: Full setup including schema and user creation
- **Edit Tenants**: Update tenant configuration
- **Delete Tenants**: Remove tenant configurations
- **View Tenants**: Direct links to tenant applications

### 3. Table Management
- **Schema Tables**: View all tables in each tenant's schema
- **Recreate Tables**: Drop and recreate tables with options
- **Load Demo Data**: Insert demo data for supported tables
- **Real-time Statistics**: Table row counts and column information

### 4. Health Monitoring
- **System Health**: Monitor overall system status
- **Tenant Count**: Track number of configured tenants
- **Connection Status**: Database connectivity checks

## API Endpoints

All admin endpoints are served under `/home/admin/api/`:

### Authentication
- `POST /home/admin/api/auth/login` - Admin login
- `POST /home/admin/api/auth/validate` - Token validation
- `POST /home/admin/api/auth/logout` - Admin logout

### Tenant Management
- `GET /home/admin/api/tenants` - List all tenants
- `POST /home/admin/api/tenants` - Create new tenant
- `PUT /home/admin/api/tenants/{id}` - Update tenant
- `DELETE /home/admin/api/tenants/{id}` - Delete tenant

### Table Operations
- `GET /home/admin/api/tenants/{name}/tables` - Get tenant tables
- `POST /home/admin/api/tenants/{name}/tables/{table}/recreate` - Recreate table
- `POST /home/admin/api/tenants/{name}/tables/{table}/load_data` - Load demo data

### System
- `GET /home/admin/api/health` - System health check

## Usage

### 1. Access Admin Panel
1. Navigate to `/home/admin/login` in your web browser
2. Enter your admin credentials (email/password from home table)
3. Click "Sign In" to authenticate

### 2. Manage Tenants
1. From the dashboard, click "Add New Tenant" to create a new tenant
2. Fill in the tenant form with required information:
   - **Tenant Name**: Alphanumeric with optional hyphens/underscores
   - **Database Name**: Usually "residents"
   - **Database Type**: MSSQL (currently supported)
   - **Database Schema**: Auto-generated from tenant name
   - **Admin Email**: Tenant administrator email
   - **Admin Password**: Secure password for tenant admin

3. Click "Create Tenant" to set up the full tenant environment

### 3. Table Management
1. Click the "Tables" button on any tenant card
2. View all tables in the tenant's schema
3. Use "Recreate" to rebuild tables (with optional drop-first)
4. Use "Load Data" to insert demo data (for supported tables)

### 4. Monitor System
1. Click "Health Check" to verify system status
2. View tenant count and connection status in the app bar
3. Monitor real-time table statistics

## Configuration

### Admin Settings
Configuration is centralized in `lib/config/admin_config.dart`:

```dart
class AdminConfig {
  // Routes
  static const String adminLoginRoute = '/home/admin/login';
  static const String adminDashboardRoute = '/home/admin/dashboard';
  
  // Session settings
  static const Duration sessionTimeout = Duration(hours: 8);
  
  // Validation rules
  static const int minPasswordLength = 8;
  static const int maxTenantNameLength = 50;
  
  // Supported features
  static const bool enableTableManagement = true;
  static const bool enableTenantDeletion = true;
}
```

### Backend Configuration
Backend authentication uses the home table:

```sql
-- Home table structure (already exists)
SELECT admin_user_email, admin_user_password 
FROM home.home 
WHERE admin_user_email = 'admin@example.com'
```

## Security

### Authentication
- **JWT Tokens**: Secure token-based authentication
- **Session Expiration**: Automatic logout after 8 hours
- **Secure Storage**: Encrypted credential storage
- **Password Validation**: Minimum security requirements

### Authorization
- **Admin-Only Access**: Restricted to home table users
- **Independent Sessions**: No cross-contamination with regular users
- **API Protection**: All endpoints require valid JWT tokens

### Data Protection
- **Input Validation**: All forms validate input data
- **SQL Injection Prevention**: Parameterized queries
- **XSS Protection**: Proper data encoding

## Development

### Adding New Features
1. **Models**: Add new models in `lib/model/admin/`
2. **Services**: Extend services in `lib/services/admin/`
3. **UI**: Create widgets in `lib/screen/admin/widgets/`
4. **API**: Add endpoints in `api_service/admin.py`

### Testing
- Unit tests for services and models
- Integration tests for API endpoints
- UI tests for admin workflows

### Deployment
- Admin panel is included in web builds
- No additional deployment steps required
- Uses same backend as main application

## Troubleshooting

### Common Issues

**Login Fails**
- Verify admin credentials exist in home.home table
- Check database connectivity
- Ensure JWT secret is configured

**Tables Not Loading**
- Verify tenant database schema exists
- Check database permissions
- Confirm connection strings are valid

**Session Expires**
- Normal behavior after 8 hours
- Re-login to continue working
- Check system clock synchronization

### Debug Information
Access debug info through browser developer console:
- Session state information
- Authentication status
- API response details

## Future Enhancements

### Planned Features
- **Bulk Operations**: Manage multiple tenants simultaneously
- **Audit Logging**: Track all admin actions
- **Email Notifications**: Alert on system events
- **Advanced Monitoring**: Detailed system metrics
- **Backup Management**: Database backup controls

### Scalability
- **Multi-Admin Support**: Multiple admin users
- **Role-Based Access**: Different permission levels
- **API Rate Limiting**: Prevent abuse
- **Caching**: Improve performance

## Support

For technical support or feature requests:
1. Check logs in browser developer console
2. Verify backend API responses
3. Review admin configuration settings
4. Contact system administrator

---

**Note**: This admin panel is completely independent from the existing web management system and should not interfere with regular application operations.