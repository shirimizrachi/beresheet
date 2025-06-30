# Multi-Tenant Home Indexing System - Implementation Plan

## Overview

This document outlines the implementation plan for a multi-tenant home indexing system that enables users to be automatically routed to their correct home/tenant database after Firebase authentication.

## Current Architecture

- **Database**: SQL Server with multi-tenant architecture using schemas
- **Authentication**: Firebase Authentication for phone verification + API service for user profiles
- **API**: FastAPI service with tenant-specific schema routing
- **Frontend**: Flutter app with web and mobile support
- **Configuration**: Tenant configs stored in `home.home` table, routing via `tenant_config.py`

## Requirements Summary

1. Add `home_index` schema and table during database setup
2. Create `home_index` database user with limited permissions
3. Add home_index functions to API service (create, update, view - only view exposed)
4. Modify user creation to create matching row in home_index table
5. Add `get_user_home` endpoint using home_index connection
6. Update Flutter app to use `get_user_home` after Firebase auth
7. Store home_id and home_name in user session
8. Make apiPrefix dynamic from session instead of static config

## Implementation Plan

### Phase 1: Database Schema Extension

#### 1.1 Modify `setup_residents_database.py`

**File**: `api_service/deployment/admin/setup_residents_database.py`

**Changes**:
- Add `home_index_name = "home_index"`
- Add `home_index_user_name = "home_index"`
- Add `home_index_user_password = "home_index2025!"`
- Add method `create_home_index()`
- Add method `create_home_index_user_and_permissions()`
- Add method `create_home_index_table()`
- Update main execution flow to include home_index setup

**Home Index Table Schema**:
```sql
CREATE TABLE [home_index].[home_index] (
    [phone_number] NVARCHAR(20) PRIMARY KEY,
    [home_id] INT NOT NULL,
    [home_name] NVARCHAR(50) NOT NULL,
    [created_at] DATETIME2 DEFAULT GETDATE(),
    [updated_at] DATETIME2 DEFAULT GETDATE()
);
```

**Home Index User Permissions**:
- Schema: home_index (full access to schema)
- Table: home_index.home_index (SELECT, INSERT, UPDATE only)

#### 1.2 Update `residents_db_config.py`

**File**: `api_service/residents_db_config.py`

**Changes**:
- Add home_index connection configuration
- Add helper functions for home_index connections

**New Configuration**:
```python
# Home Index Configuration
home_index_NAME = "home_index"
HOME_INDEX_USER_NAME = "home_index"
HOME_INDEX_USER_PASSWORD = "home_index2025!"

# Connection strings
LOCAL_HOME_INDEX_CONNECTION_STRING = f"mssql+pyodbc://{HOME_INDEX_USER_NAME}:{HOME_INDEX_USER_PASSWORD}@{LOCAL_SERVER}/{DATABASE_NAME}?driver=ODBC+Driver+17+for+SQL+Server&TrustServerCertificate=yes"
AZURE_HOME_INDEX_CONNECTION_STRING = f"mssql+pyodbc://{HOME_INDEX_USER_NAME}:{HOME_INDEX_USER_PASSWORD}@{AZURE_SERVER}/{DATABASE_NAME}?driver=ODBC+Driver+17+for+SQL+Server&TrustServerCertificate=yes"

def get_home_index_connection_string():
    """Get the home index connection string based on DATABASE_TYPE"""
    if DATABASE_TYPE == "azure":
        return AZURE_HOME_INDEX_CONNECTION_STRING
    else:
        return LOCAL_HOME_INDEX_CONNECTION_STRING
```

### Phase 2: API Service Enhancements

#### 2.1 Create Home Index Service

**New File**: `api_service/home_index.py`

**Features**:
- HomeIndexDatabase class with CRUD operations
- Uses dedicated home_index connection
- Methods: create_home_entry(), update_home_entry(), get_home_by_phone()
- Only `get_home_by_phone()` exposed as public endpoint

**Key Methods**:
```python
class HomeIndexDatabase:
    def create_home_entry(self, phone_number: str, home_id: int, home_name: str) -> bool
    def update_home_entry(self, phone_number: str, home_id: int = None, home_name: str = None) -> bool
    def get_home_by_phone(self, phone_number: str) -> Optional[Dict[str, any]]
```

#### 2.2 Modify User Service

**File**: `api_service/users.py`

**Changes**:

1. **Import home_index service**:
```python
from home_index import home_index_db
```

2. **Modify `create_user_profile()` method**:
- After creating user in tenant schema, create matching entry in home_index table
- Use home_index connection for this operation
- Handle failures gracefully (rollback user creation if home_index fails)

3. **Add new endpoint `get_user_home`**:
```python
@app.get("/api/users/get_user_home")
async def get_user_home(phone_number: str = Query(...)):
    """Get user's home information by phone number"""
    try:
        home_info = home_index_db.get_home_by_phone(phone_number)
        if not home_info:
            raise HTTPException(
                status_code=404, 
                detail="User not found. Please contact support to set up your account."
            )
        return home_info
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
```

**Error Handling Strategy**:
- If user not found in home_index: Return 404 with support contact message
- No fallback to default home_id - users must be properly registered
- Clear error messages directing users to contact support

#### 2.3 Update Main API Router

**File**: `api_service/main.py`

**Changes**:
- Import home_index router
- Register home_index endpoints (only GET endpoint exposed)

### Phase 3: Flutter Application Updates

#### 3.1 Update Authentication Flow

**File**: `lib/auth/auth_service.dart`

**Changes**:
1. After successful Firebase authentication
2. Call `get_user_home` API endpoint with phone number
3. Handle response:
   - Success: Store home_id and home_name in secure storage
   - Error 404: Show user-friendly error message with support contact
   - Other errors: Show generic error message

**Authentication Flow**:
```dart
// After Firebase auth success
try {
  final homeInfo = await _apiService.getUserHome(phoneNumber);
  await _secureStorage.write(key: 'user_home_id', value: homeInfo.homeId.toString());
  await _secureStorage.write(key: 'user_home_name', value: homeInfo.homeName);
  await _secureStorage.write(key: 'user_api_prefix', value: homeInfo.homeName);
  // Continue with normal flow
} catch (e) {
  if (e is NotFoundException) {
    // Show support contact message
    _showSupportContactDialog();
  } else {
    // Show generic error
    _showErrorDialog(e.message);
  }
}
```

#### 3.2 Update App Configuration

**File**: `lib/config/app_config.dart`

**Changes**:

1. **Add session-based API prefix method**:
```dart
/// Get the API prefix from user session for authenticated requests
static Future<String> getApiPrefixFromSession() async {
  try {
    final secureStorage = FlutterSecureStorage();
    final sessionPrefix = await secureStorage.read(key: 'user_api_prefix');
    return sessionPrefix ?? apiPrefix; // Fallback to static prefix
  } catch (e) {
    return apiPrefix; // Fallback to static prefix
  }
}

/// Get the full API URL with session-based prefix for authenticated calls
static Future<String> getApiUrlWithSessionPrefix() async {
  final prefix = await getApiPrefixFromSession();
  return '$apiBaseUrl/$prefix';
}
```

2. **Update existing methods to support both static and session-based routing**:
- Keep existing methods for backward compatibility
- Add new session-aware methods for authenticated requests

#### 3.3 Update API Service Calls

**All API service calls after authentication**:
- Use `AppConfig.getApiUrlWithSessionPrefix()` instead of `AppConfig.apiUrlWithPrefix`
- Handle session-based routing dynamically

### Phase 4: Error Handling and User Experience

#### 4.1 User Not Found Handling

**Error Message Strategy**:
```
"Account Setup Required

Your phone number is not registered with any home community. Please contact support to complete your account setup.

Support Contact:
Email: support@beresheet.com
Phone: +972-XX-XXXXXXX

Error Code: USER_NOT_FOUND"
```

#### 4.2 Migration Strategy for Existing Users

**Manual Migration Process**:
1. Export all existing users from all tenant schemas
2. Create migration script to populate home_index table
3. Validate data consistency
4. Deploy new system
5. Test with sample users before full rollout

**Migration Script Structure**:
```python
# migration_populate_home_index.py
def migrate_existing_users():
    # Get all tenants
    # For each tenant, get all users
    # Create home_index entries
    # Validate consistency
```

### Phase 5: Security Considerations

#### 5.1 Database Security

- **Isolated Schema**: home_index schema completely separate from tenant data
- **Limited Permissions**: home_index user can only access home_index table
- **No Cross-Schema Access**: home_index user cannot access tenant schemas
- **Read-Only for API**: Only SELECT, INSERT, UPDATE permissions (no DELETE)

#### 5.2 API Security

- **Phone Number Validation**: Ensure phone number format consistency
- **Rate Limiting**: Implement rate limiting on get_user_home endpoint
- **Audit Logging**: Log all home_index access attempts
- **Input Sanitization**: Validate all input parameters

#### 5.3 Session Security

- **Secure Storage**: Use Flutter secure storage for sensitive data
- **Session Timeout**: Implement session expiration
- **Data Encryption**: Encrypt stored session data

### Phase 6: Testing Strategy

#### 6.1 Database Testing

- Test home_index schema creation
- Verify user permissions
- Test table operations (CRUD)
- Validate data integrity constraints

#### 6.2 API Testing

- Test home_index CRUD operations
- Test get_user_home endpoint with various scenarios
- Test error handling (user not found, database errors)
- Test integration with user creation flow

#### 6.3 Flutter App Testing

- Test authentication flow with home lookup
- Test error handling scenarios
- Test session management
- Test API prefix switching

#### 6.4 Integration Testing

- End-to-end user registration flow
- Multi-tenant routing verification
- Error recovery scenarios
- Performance testing with multiple homes

## Implementation Order

1. **Database Layer** (Phase 1)
   - Extend setup_residents_database.py
   - Update residents_db_config.py
   - Test database setup

2. **API Service Layer** (Phase 2)
   - Create home_index.py
   - Modify users.py
   - Update main.py
   - Test API endpoints

3. **Flutter App Layer** (Phase 3)
   - Update auth service
   - Modify app_config.dart
   - Update API service calls
   - Test authentication flow

4. **Integration & Testing** (Phase 4-6)
   - End-to-end testing
   - Error handling validation
   - Performance testing
   - Security audit

## Rollback Plan

If implementation fails:

1. **Database Rollback**:
   - Drop home_index schema
   - Remove home_index user
   - Restore original setup script

2. **API Rollback**:
   - Remove home_index.py
   - Restore original users.py
   - Remove new endpoints

3. **Flutter Rollback**:
   - Restore original auth flow
   - Revert app_config.dart changes
   - Use static API prefix

## Success Criteria

- ✅ New users can be created with home_index entries
- ✅ Existing authentication flow continues to work
- ✅ Users are properly routed to their home tenants
- ✅ Error handling works correctly for unregistered users
- ✅ Session-based API prefix works correctly
- ✅ Multi-tenant isolation is maintained
- ✅ Performance is not degraded
- ✅ Security requirements are met

## Risk Mitigation

1. **Data Loss Risk**: Full database backup before deployment
2. **User Lockout Risk**: Thorough testing with sample users
3. **Performance Risk**: Database indexing and connection pooling
4. **Security Risk**: Comprehensive security audit
5. **Rollback Risk**: Detailed rollback procedures documented

This implementation plan ensures a secure, scalable, and maintainable multi-tenant home indexing system while maintaining backward compatibility and providing clear error handling for edge cases.