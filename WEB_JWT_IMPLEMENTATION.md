# Web JWT Authentication Implementation

This document describes the implementation of JWT-based authentication for the Flutter web application, completely separate from the admin JWT system.

## Overview

The web JWT authentication system provides secure, token-based authentication for web users with automatic token refresh and secure storage. It's designed to be completely independent from the existing admin JWT authentication system.

## Architecture

### Frontend Components

#### 1. JWT Models (`lib/model/web/`)
- **`WebJwtUser`**: User model for JWT-authenticated web users
- **`WebJwtSession`**: JWT session with access and refresh tokens
- **`WebJwtCredentials`**: Login credentials structure
- **`WebJwtLoginResult`**: Login response structure

#### 2. JWT Services (`lib/services/web/`)
- **`WebJwtSessionService`**: Manages JWT tokens and session data
  - Secure token storage using FlutterSecureStorage
  - Token validation and expiration handling
  - Session management and debugging utilities

- **`WebJwtAuthService`**: Handles authentication operations
  - Login with phone number and password
  - Token validation and refresh
  - Logout and session cleanup
  - Automatic token refresh

- **`WebJwtApiService`**: JWT-aware API client
  - Automatic JWT token inclusion in requests
  - Token refresh before API calls
  - Authentication error handling

#### 3. JWT UI Components (`lib/screen/web/`)
- **`WebJwtLoginScreen`**: Modern login screen for JWT authentication
- **`WebJwtAuthWrapper`**: Authentication wrapper with role-based access
- **`WebJwtAuthenticatedPage`**: Convenience wrapper for authenticated pages
- **`WebJwtManagerPage`**: Convenience wrapper for manager-only pages
- **`WebJwtStaffPage`**: Convenience wrapper for staff-level pages

### Backend Components

#### 1. JWT Authentication API (`api_service/web_jwt_auth.py`)
- **`/api/web-auth/login`**: JWT login endpoint
- **`/api/web-auth/validate`**: Token validation endpoint
- **`/api/web-auth/refresh`**: Token refresh endpoint
- **`/api/web-auth/logout`**: Logout endpoint
- **`/api/web-auth/me`**: Get current user endpoint

#### 2. JWT Configuration
- **Access Token**: 1 hour expiration
- **Refresh Token**: 30 days expiration
- **Algorithm**: HS256
- **Issuer**: "web" (to distinguish from admin tokens)

## Security Features

### 1. Token Security
- **Secure Storage**: Tokens stored using FlutterSecureStorage with encryption
- **Separate Keys**: Different storage keys from admin system
- **Token Validation**: Issuer validation to prevent admin/web token confusion
- **Automatic Refresh**: Tokens refreshed before expiration

### 2. Role-Based Access Control
- **Manager**: Full access to management features
- **Staff**: Access to staff-level features
- **Service**: Access to service provider features
- **Resident**: Basic authenticated access

### 3. API Security
- **Bearer Token**: Standard Authorization header format
- **Error Handling**: Proper 401 handling and token cleanup
- **Request Validation**: User validation on each protected request

## Usage Examples

### 1. Basic Authentication Check
```dart
// Check if user is authenticated
final isAuth = await WebJwtAuthService.isAuthenticated();
if (isAuth) {
  final user = await WebJwtAuthService.getCurrentUser();
  print('Logged in as: ${user?.fullName}');
}
```

### 2. Protected Page Wrapper
```dart
// Require authentication for any role
WebJwtAuthenticatedPage(
  child: MyHomePage(),
)

// Require manager role
WebJwtManagerPage(
  child: AdminPanel(),
)

// Custom role requirement
WebJwtAuthWrapper(
  requiredRole: 'staff',
  child: StaffPanel(),
)
```

### 3. API Calls with JWT
```dart
// Automatic JWT token inclusion
final events = await WebJwtApiService.getEvents();

// Create event (manager only)
await WebJwtApiService.createEvent({
  'name': 'New Event',
  'description': 'Event description',
  // ... other fields
});
```

### 4. Manual Login
```dart
final result = await WebJwtAuthService.login(
  phoneNumber: '0501234567',
  password: 'userPassword',
  homeId: 1,
);

if (result.success) {
  print('Login successful: ${result.session?.user.fullName}');
} else {
  print('Login failed: ${result.message}');
}
```

## Configuration

### Environment Variables (Backend)
```bash
WEB_JWT_SECRET_KEY=your-secret-key-here
WEB_JWT_ACCESS_TOKEN_EXPIRE_MINUTES=60
WEB_JWT_REFRESH_TOKEN_EXPIRE_DAYS=30
```

### App Configuration (Frontend)
The JWT system uses the existing `AppConfig.homeId` for tenant-specific authentication.

## Separation from Admin System

### 1. Storage Separation
- **Admin**: Uses `admin_jwt_*` prefixed keys
- **Web**: Uses `web_jwt_*` prefixed keys
- **Different Containers**: Separate secure storage containers

### 2. API Endpoints Separation
- **Admin**: `/api/admin-auth/*` endpoints
- **Web**: `/api/web-auth/*` endpoints
- **Different Routers**: Completely separate FastAPI routers

### 3. Token Issuer Validation
- **Admin**: Tokens have `"iss": "admin"`
- **Web**: Tokens have `"iss": "web"`
- **Cross-Validation**: Admin tokens cannot be used for web auth and vice versa

### 4. Service Layer Separation
- **Admin**: `AdminAuthService`, `AdminSessionService`, `AdminApiService`
- **Web**: `WebJwtAuthService`, `WebJwtSessionService`, `WebJwtApiService`
- **No Shared State**: Completely independent service implementations

## Migration from Session-Based Auth

The new JWT system replaces the old session-based `WebAuthService`. Key differences:

### Old System (Session-Based)
- Session IDs stored in SharedPreferences
- Session validation on server
- Single session endpoint

### New System (JWT-Based)
- JWT tokens stored in secure storage
- Client-side token validation
- Automatic token refresh
- Role-based access control

## Testing

### Backend Testing
```bash
# Test login
curl -X POST http://localhost:8000/{tenant}/api/web-auth/login \
  -H "Content-Type: application/json" \
  -d '{"phoneNumber": "0501234567", "password": "password", "homeId": 1}'

# Test token validation
curl -X POST http://localhost:8000/{tenant}/api/web-auth/validate \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

### Frontend Testing
Use the debug methods in `WebJwtAuthService.getAuthDebugInfo()` to inspect authentication state.

## Dependencies

### Frontend
- `flutter_secure_storage: ^9.0.0` - Secure token storage
- `json_annotation: ^4.8.1` - JSON serialization
- `http: ^1.1.0` - HTTP requests

### Backend
- `pyjwt==2.8.0` - JWT token handling
- `bcrypt==4.1.2` - Password hashing
- `fastapi==0.104.1` - Web framework

## Best Practices

### 1. Token Handling
- Always check token expiration before API calls
- Implement automatic refresh logic
- Clear tokens on logout or authentication errors

### 2. Security
- Use HTTPS in production
- Implement proper CORS policies
- Validate tokens on every protected endpoint

### 3. Error Handling
- Handle network errors gracefully
- Provide clear error messages to users
- Log authentication events for debugging

### 4. Role Management
- Use role-based wrappers for UI components
- Validate roles on both client and server
- Implement principle of least privilege

## Troubleshooting

### Common Issues

1. **Token Expired**: Implement automatic refresh or redirect to login
2. **Network Errors**: Check API endpoint URLs and connectivity
3. **Storage Issues**: Ensure secure storage permissions on device
4. **Role Access**: Verify user roles match required permissions

### Debug Commands

```bash
# Generate code for JWT models
flutter packages pub run build_runner build

# Install dependencies
flutter pub get
cd api_service && pip install -r requirements.txt
```

## Future Enhancements

1. **Token Blacklisting**: Implement server-side token revocation
2. **Multi-Device Support**: Handle multiple device logins
3. **Biometric Authentication**: Add fingerprint/face ID support
4. **Single Sign-On**: Integrate with external identity providers