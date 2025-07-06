import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../model/web/web_jwt_user.dart';
import '../../config/app_config.dart';
import 'web_jwt_session_service.dart';

/// Web JWT Authentication Service - completely separate from admin authentication
/// Handles JWT-based authentication for web users with tenant routing support
class WebJwtAuthService {
  static String get _baseUrl => AppConfig.apiUrlWithPrefix;

  /// Get user profile by phone number within current tenant context
  static Future<Map<String, dynamic>?> getUserByPhone(String phoneNumber, int homeId, String homeName) async {
    try {
      print('Getting user by phone number: $phoneNumber for homeId: $homeId');
      
      // Use the tenant-specific by-phone endpoint since we already know the tenant
      final response = await http.post(
        Uri.parse('$_baseUrl/api/users/by-phone'),
        headers: {
          'Content-Type': 'application/json',
          'homeID': homeId.toString(),
        },
        body: jsonEncode({'phone_number': phoneNumber}),
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        print('Found user: ${data['full_name']} (ID: ${data['id']})');
        return {
          'home_id': homeId,
          'home_name': homeName,
          'user': data,
        };
      } else {
        print('User lookup failed: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error getting user by phone: $e');
      return null;
    }
  }

  /// Login with phone number and password for a specific tenant
  static Future<WebJwtLoginResult> loginForTenant(String phoneNumber, String password, int homeId, String homeName) async {
    try {
      // First, check if user exists in this tenant
      final userInfo = await getUserByPhone(phoneNumber, homeId, homeName);
      if (userInfo == null) {
        return const WebJwtLoginResult(
          success: false,
          message: 'User not found in this home. Please contact your administrator.',
          error: 'user_not_found',
        );
      }
      
      // Use the user info for login
      return await login(phoneNumber, password, homeId, homeName);
    } catch (e) {
      print('Error during tenant login: $e');
      return WebJwtLoginResult(
        success: false,
        message: 'Login failed: ${e.toString()}',
        error: 'login_error',
      );
    }
  }

  /// Login with phone number and password
  static Future<WebJwtLoginResult> login(String phoneNumber, String password, int homeId, [String? homeName]) async {
    try {
      print('Attempting web JWT login for phone: $phoneNumber, homeId: $homeId, homeName: $homeName');
      
      final credentials = WebJwtCredentials(
        phoneNumber: phoneNumber,
        password: password,
        homeId: homeId,
      );
      
      // Construct tenant-aware login URL
      if (homeName == null) {
        throw Exception('Home name is required for tenant-aware JWT login');
      }
      
      final loginUrl = '$_baseUrl/api/web-auth/login';
      print('Using tenant-aware login URL: $loginUrl');
      
      // Make API call to web JWT authentication endpoint
      final response = await http.post(
        Uri.parse(loginUrl),
        headers: {
          'Content-Type': 'application/json',
          'homeID': homeId.toString(), // Add homeId to headers for tenant routing
        },
        body: jsonEncode(credentials.toJson()),
      ).timeout(const Duration(seconds: 30));
      
      print('Web JWT login response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;
        
        print('Raw session data from backend: $responseData');
        
        // The API now returns admin-format response: {token, user, expires_at, created_at}
        // We need to convert this to our WebJwtSession format
        final userMap = responseData['user'] as Map<String, dynamic>;
        
        // Create WebJwtUser from the admin-format response
        final user = WebJwtUser(
          id: userMap['id'].toString(),
          phoneNumber: userMap['phoneNumber'] as String? ?? userMap['admin_user_email'] as String,
          fullName: userMap['fullName'] as String? ?? userMap['name'] as String,
          role: userMap['role'] as String? ?? 'resident',
          homeId: userMap['homeId'] as int? ?? 1,
          homeName: userMap['homeName'] as String? ?? userMap['database_schema'] as String?,
          photo: userMap['photo'] as String?,
          apartmentNumber: userMap['apartmentNumber'] as String?,
          createdAt: DateTime.parse(userMap['created_at'] as String),
          updatedAt: DateTime.parse(userMap['updated_at'] as String),
        );
        
        // Create WebJwtSession from the admin-format response
        final session = WebJwtSession(
          token: responseData['token'] as String,
          refreshToken: '', // Will be set by refresh endpoint if needed
          user: user,
          expiresAt: DateTime.parse(responseData['expires_at'] as String),
          refreshExpiresAt: DateTime.parse(responseData['expires_at'] as String).add(Duration(days: 30)), // Default 30 days
          createdAt: DateTime.parse(responseData['created_at'] as String),
        );
        
        print('Parsed session - ExpiresAt: ${session.expiresAt}, RefreshExpiresAt: ${session.refreshExpiresAt}');
        print('Current time: ${DateTime.now()}');
        print('Session isValid: ${session.isValid}');
        
        // Store session
        await WebJwtSessionService.storeSession(session);
        
        // Store home name for tenant routing
        if (homeName != null) {
          await WebJwtSessionService.storeHomeName(homeName);
        }
        
        print('Web JWT login successful for user: ${session.user.fullName}');
        return WebJwtLoginResult(
          success: true,
          message: 'Login successful',
          session: session,
        );
      } else if (response.statusCode == 401) {
        print('Web JWT login failed: Invalid credentials');
        return const WebJwtLoginResult(
          success: false,
          message: 'Invalid phone number or password',
          error: 'invalid_credentials',
        );
      } else {
        final errorData = jsonDecode(response.body) as Map<String, dynamic>;
        final errorMessage = errorData['message'] ?? errorData['detail'] ?? 'Login failed';
        print('Web JWT login failed: $errorMessage');
        return WebJwtLoginResult(
          success: false,
          message: errorMessage,
          error: errorData['error'],
        );
      }
    } catch (e) {
      print('Error during web JWT login: $e');
      
      if (WebJwtSessionService.isNetworkError(e)) {
        return const WebJwtLoginResult(
          success: false,
          message: 'Network error. Please check your connection and try again.',
          error: 'network_error',
        );
      } else {
        return WebJwtLoginResult(
          success: false,
          message: 'Login failed: ${e.toString()}',
          error: 'unknown_error',
        );
      }
    }
  }

  /// Validate current JWT token
  static Future<bool> validateToken() async {
    try {
      final token = await WebJwtSessionService.getJwtToken();
      if (token == null) {
        print('No web JWT token found for validation');
        return false;
      }
      
      print('Validating web JWT token: ${token.substring(0, 20)}...');
      
      final response = await http.post(
        Uri.parse('$_baseUrl/api/web-auth/validate'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 30));
      
      print('Web JWT validation response status: ${response.statusCode}');
      print('Web JWT validation response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;
        final isValid = responseData['valid'] as bool? ?? false;
        
        if (isValid) {
          print('Web JWT token is valid');
          // If valid, try to reconstruct session from user data
          final userData = responseData['user'];
          if (userData != null) {
            print('Reconstructing session from validated token');
            // Note: This is a simplified session reconstruction
            // In a real app, you might want to fetch fresh session data
          }
        } else {
          print('Web JWT token is invalid, clearing session');
          await WebJwtSessionService.clearSession(reason: 'Invalid token');
        }
        
        return isValid;
      } else if (response.statusCode == 401) {
        print('Web JWT validation failed: Unauthorized');
        await WebJwtSessionService.clearSession(reason: 'Unauthorized');
        return false;
      } else {
        print('Web JWT validation failed with status: ${response.statusCode}, body: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error validating web JWT token: $e');
      
      if (WebJwtSessionService.isNetworkError(e)) {
        // On network error, don't clear session - might be temporary
        print('Network error during JWT validation, keeping session');
        return true; // Assume valid to allow offline usage
      } else {
        await WebJwtSessionService.clearSession(reason: 'Validation error');
        return false;
      }
    }
  }

  /// Refresh JWT token using refresh token
  static Future<bool> refreshToken() async {
    try {
      final session = await WebJwtSessionService.getSession();
      final refreshToken = await WebJwtSessionService.getRefreshToken();
      
      if (session == null || refreshToken == null) {
        print('No web JWT session or refresh token to refresh');
        return false;
      }
      
      if (!session.canRefresh) {
        print('Web JWT refresh token expired');
        await WebJwtSessionService.clearSession(reason: 'Refresh token expired');
        return false;
      }
      
      print('Refreshing web JWT token');
      
      final response = await http.post(
        Uri.parse('$_baseUrl/api/web-auth/refresh'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.token}',
        },
        body: jsonEncode({
          'refresh_token': refreshToken,
        }),
      ).timeout(const Duration(seconds: 30));
      
      print('Web JWT refresh response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;
        
        if (responseData['success'] == true) {
          // Create new session with refreshed tokens
          final newSession = WebJwtSession(
            token: responseData['token'] as String,
            refreshToken: responseData['refresh_token'] as String,
            user: session.user,
            expiresAt: DateTime.parse(responseData['expires_at'] as String),
            refreshExpiresAt: DateTime.parse(responseData['refresh_expires_at'] as String),
            createdAt: DateTime.now(),
          );
          
          await WebJwtSessionService.updateSession(newSession);
          print('Web JWT token refreshed successfully');
          return true;
        }
      }
      
      print('Web JWT token refresh failed');
      return false;
    } catch (e) {
      print('Error refreshing web JWT token: $e');
      return false;
    }
  }

  /// Logout and clear session
  static Future<void> logout() async {
    try {
      final token = await WebJwtSessionService.getJwtToken();
      
      if (token != null) {
        print('Logging out web JWT user');
        
        // Notify server about logout (best effort, don't fail if it doesn't work)
        try {
          final headers = await WebJwtSessionService.getAuthHeaders();
          await http.post(
            Uri.parse('$_baseUrl/api/web-auth/logout'),
            headers: headers,
          ).timeout(const Duration(seconds: 30));
          print('Web JWT logout notification sent to server');
        } catch (e) {
          print('Failed to notify server about JWT logout (continuing anyway): $e');
        }
      }
      
      // Clear local session regardless of server response
      await WebJwtSessionService.clearSession(reason: 'User logout');
      print('Web JWT session cleared successfully');
    } catch (e) {
      print('Error during web JWT logout: $e');
      // Still clear session even if server logout fails
      await WebJwtSessionService.clearSession(reason: 'Logout error');
    }
  }

  /// Check if user is currently authenticated
  static Future<bool> isAuthenticated() async {
    try {
      // First check if we have a valid session locally
      final hasValidSession = await WebJwtSessionService.hasValidSession();
      if (hasValidSession) {
        print('Valid web JWT session found locally');
        return true;
      }

      // If no valid session but we have a token (e.g., from cookie), try to load session
      final token = await WebJwtSessionService.getJwtToken();
      if (token != null) {
        print('Found JWT token from cookie but no session, will validate with server later');
        // Instead of validating immediately, let the auth wrapper handle it
        // This mirrors the admin approach of trusting local session data
        return false; // This will trigger the login flow to recreate session
      }
      
      print('No valid web JWT session or token found');
      return false;
    } catch (e) {
      print('Error checking web JWT authentication status: $e');
      return false;
    }
  }

  /// Get current authenticated user
  static Future<WebJwtUser?> getCurrentUser() async {
    try {
      final isAuth = await isAuthenticated();
      if (!isAuth) return null;
      
      return await WebJwtSessionService.getCurrentUser();
    } catch (e) {
      print('Error getting current web JWT user: $e');
      return null;
    }
  }

  /// Auto-refresh token if needed
  static Future<void> autoRefreshToken() async {
    try {
      final needsRefresh = await WebJwtSessionService.needsRefresh();
      if (needsRefresh) {
        print('Web JWT token is close to expiration, attempting refresh');
        final refreshSuccess = await refreshToken();
        
        if (!refreshSuccess) {
          print('Web JWT token refresh failed, user needs to re-login');
          await WebJwtSessionService.clearSession(reason: 'Token refresh failed');
        }
      }
    } catch (e) {
      print('Error during web JWT token auto-refresh: $e');
    }
  }

  /// Handle authentication errors
  static Future<void> handleAuthError(dynamic error) async {
    print('Handling web JWT authentication error: $error');
    
    if (WebJwtSessionService.isAuthenticationError(error)) {
      await WebJwtSessionService.clearSession(reason: 'Authentication error');
    }
  }

  /// Get authentication headers for API requests
  static Future<Map<String, String>> getAuthHeaders() async {
    return await WebJwtSessionService.getAuthHeaders();
  }

  /// Initialize JWT service on app start
  static Future<void> initialize() async {
    try {
      print('Initializing Web JWT Auth Service');
      
      // Check if we have a valid session
      final hasValidSession = await WebJwtSessionService.hasValidSession();
      if (hasValidSession) {
        print('Found valid web JWT session');
        
        // Auto-refresh token if needed
        await autoRefreshToken();
      } else {
        print('No valid web JWT session found');
      }
    } catch (e) {
      print('Error initializing Web JWT Auth Service: $e');
    }
  }

  /// Check authentication status for debugging
  static Future<Map<String, dynamic>> getAuthDebugInfo() async {
    try {
      final sessionInfo = await WebJwtSessionService.getSessionDebugInfo();
      final isAuth = await isAuthenticated();
      final token = await WebJwtSessionService.getJwtToken();
      
      return {
        'isAuthenticated': isAuth,
        'hasToken': token != null,
        'tokenLength': token?.length ?? 0,
        'session': sessionInfo,
      };
    } catch (e) {
      return {
        'error': e.toString(),
      };
    }
  }
}