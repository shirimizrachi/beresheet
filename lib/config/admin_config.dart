/// Configuration for the independent admin panel system
/// Contains all admin-specific settings and constants
class AdminConfig {
  /// Admin base URL - independent from main app configuration
  static const String baseUrl = 'http://localhost:8000';
  
  /// Admin panel base routes
  static const String adminLoginRoute = '/home/admin/login';
  static const String adminDashboardRoute = '/home/admin/dashboard';
  
  /// API endpoints
  static const String adminApiBase = '/home/admin/api';
  static const String adminAuthLoginEndpoint = '$adminApiBase/auth/login';
  static const String adminAuthValidateEndpoint = '$adminApiBase/auth/validate';
  static const String adminAuthLogoutEndpoint = '$adminApiBase/auth/logout';
  static const String adminTenantsEndpoint = '$adminApiBase/tenants';
  static const String adminHealthEndpoint = '$adminApiBase/health';
  
  /// Session configuration
  static const String adminSessionKey = 'admin_session';
  static const String adminTokenKey = 'admin_token';
  static const String adminUserKey = 'admin_user';
  static const Duration sessionTimeout = Duration(hours: 8);
  static const Duration sessionRefreshThreshold = Duration(minutes: 30);
  
  /// UI configuration
  static const String adminAppTitle = 'Multi-Tenant Management Admin';
  static const String adminLoginTitle = 'Admin Login';
  static const String adminDashboardTitle = 'Admin Dashboard';
  
  /// Theme colors
  static const int primaryColorValue = 0xFF2C3E50;
  static const int accentColorValue = 0xFF3498DB;
  static const int successColorValue = 0xFF27AE60;
  static const int warningColorValue = 0xFFF39C12;
  static const int errorColorValue = 0xFFE74C3C;
  static const int infoColorValue = 0xFF17A2B8;
  
  /// Grid and layout configuration
  static const double tenantCardMinWidth = 300.0;
  static const double adminPanelMaxWidth = 1200.0;
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  
  /// Animation durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 400);
  static const Duration longAnimation = Duration(milliseconds: 600);
  
  /// Table management
  static const List<String> availableTableNames = [
    'users',
    'service_provider_types',
    'event_instructor',
    'events',
    'rooms',
    'event_gallery',
    'events_registration',
    'home_notification',
    'user_notification',
    'requests',
  ];
  
  static const List<String> tablesWithDemoData = [
    'users',
    'service_provider_types',
    'event_instructor',
    'events',
    'rooms',
    'home_notification',
    'user_notification',
  ];
  
  /// Database types
  static const List<String> supportedDatabaseTypes = [
    'mssql',
  ];
  
  /// Validation rules
  static const int minPasswordLength = 8;
  static const int maxTenantNameLength = 50;
  static const int maxEmailLength = 100;
  
  /// Regular expressions for validation
  static const String tenantNamePattern = r'^[a-zA-Z0-9_-]+$';
  static const String emailPattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
  static const String schemaNamePattern = r'^[a-zA-Z][a-zA-Z0-9_]*$';
  
  /// Error messages
  static const String invalidCredentialsMessage = 'Invalid email or password';
  static const String sessionExpiredMessage = 'Your session has expired. Please log in again.';
  static const String networkErrorMessage = 'Network error. Please check your connection.';
  static const String unknownErrorMessage = 'An unexpected error occurred. Please try again.';
  static const String tenantNotFoundMessage = 'Tenant not found';
  static const String tenantAlreadyExistsMessage = 'A tenant with this name already exists';
  
  /// Success messages
  static const String tenantCreatedMessage = 'Tenant created successfully';
  static const String tenantUpdatedMessage = 'Tenant updated successfully';
  static const String tenantDeletedMessage = 'Tenant deleted successfully';
  static const String tableRecreatedMessage = 'Table recreated successfully';
  static const String dataLoadedMessage = 'Demo data loaded successfully';
  
  /// HTTP timeouts
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration longOperationTimeout = Duration(minutes: 5);
  
  /// Pagination and limits
  static const int defaultPageSize = 20;
  static const int maxTenantsPerPage = 50;
  
  /// Retry configuration
  static const int maxRetryAttempts = 3;
  static const Duration retryDelay = Duration(seconds: 2);
  
  /// Admin panel features flags
  static const bool enableTableManagement = true;
  static const bool enableHealthChecks = true;
  static const bool enableTenantDeletion = true;
  static const bool enableAdvancedLogging = true;
  
  /// Helper methods for validation
  static bool isValidTenantName(String name) {
    if (name.isEmpty || name.length > maxTenantNameLength) return false;
    return RegExp(tenantNamePattern).hasMatch(name);
  }
  
  static bool isValidEmail(String email) {
    if (email.isEmpty || email.length > maxEmailLength) return false;
    return RegExp(emailPattern).hasMatch(email);
  }
  
  static bool isValidSchemaName(String schema) {
    if (schema.isEmpty) return false;
    return RegExp(schemaNamePattern).hasMatch(schema);
  }
  
  static bool isValidPassword(String password) {
    return password.length >= minPasswordLength;
  }
  
  /// Helper method to get API endpoint URLs
  static String getTenantEndpoint(int tenantId) {
    return '$adminTenantsEndpoint/$tenantId';
  }
  
  static String getTenantByNameEndpoint(String tenantName) {
    return '$adminTenantsEndpoint/$tenantName';
  }
  
  static String getTenantTablesEndpoint(String tenantName) {
    return '$adminTenantsEndpoint/$tenantName/tables';
  }
  
  static String getTableRecreateEndpoint(String tenantName, String tableName) {
    return '$adminTenantsEndpoint/$tenantName/tables/$tableName/recreate';
  }
  
  static String getTableLoadDataEndpoint(String tenantName, String tableName) {
    return '$adminTenantsEndpoint/$tenantName/tables/$tableName/load_data';
  }
  
  static String getCreateSchemaEndpoint(String schemaName) {
    return '$adminApiBase/create_schema/$schemaName';
  }
}