import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../model/admin/admin_user.dart';
import '../../config/admin_config.dart';
import 'admin_session_service.dart';

/// Independent authentication service for the admin panel
/// Handles authentication against the home table in home schema
class AdminAuthService {
  
  /// Login with email and password
  static Future<AdminUser?> login(String email, String password) async {
    try {
      print('Attempting admin login for email: $email');
      
      final credentials = AdminCredentials(email: email, password: password);
      
      // Make API call to admin authentication endpoint
      final response = await http.post(
        Uri.parse('${AdminConfig.baseUrl}${AdminConfig.adminAuthLoginEndpoint}'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(credentials.toJson()),
      ).timeout(AdminConfig.apiTimeout);
      
      print('Admin login response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;
        
        print('Raw admin session data from backend: $responseData');
        
        // Create session from response
        final session = AdminSession.fromJson(responseData);
        
        print('Parsed admin session - ExpiresAt: ${session.expiresAt}, CreatedAt: ${session.createdAt}');
        print('Current time: ${DateTime.now()}');
        print('Admin session isValid: ${session.isValid}');
        
        // Store session
        await AdminSessionService.storeSession(session);
        
        print('Admin session stored successfully for user: ${session.user.name}');
        print('Admin login successful for user: ${session.user.name}');
        return session.user;
      } else if (response.statusCode == 401) {
        print('Admin login failed: Invalid credentials');
        throw Exception(AdminConfig.invalidCredentialsMessage);
      } else {
        final errorData = jsonDecode(response.body) as Map<String, dynamic>;
        final errorMessage = errorData['detail'] ?? 'Login failed';
        print('Admin login failed: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('Error during admin login: $e');
      
      if (AdminSessionService.isNetworkError(e)) {
        throw Exception(AdminConfig.networkErrorMessage);
      } else if (e.toString().contains(AdminConfig.invalidCredentialsMessage)) {
        rethrow;
      } else {
        throw Exception(AdminConfig.unknownErrorMessage);
      }
    }
  }
  
  /// Validate current session
  static Future<bool> validateSession() async {
    try {
      final token = await AdminSessionService.getSessionToken();
      if (token == null) {
        print('No admin token found for validation');
        return false;
      }
      
      print('Validating admin session token');
      
      final response = await http.post(
        Uri.parse('${AdminConfig.baseUrl}${AdminConfig.adminAuthValidateEndpoint}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'token': token}),
      ).timeout(AdminConfig.apiTimeout);
      
      print('Admin session validation response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;
        final isValid = responseData['valid'] as bool? ?? false;
        
        if (!isValid) {
          print('Admin session is invalid, clearing session');
          await AdminSessionService.clearSession(reason: 'Invalid session');
        }
        
        return isValid;
      } else if (response.statusCode == 401) {
        print('Admin session validation failed: Unauthorized');
        await AdminSessionService.clearSession(reason: 'Unauthorized');
        return false;
      } else {
        print('Admin session validation failed with status: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Error validating admin session: $e');
      
      if (AdminSessionService.isNetworkError(e)) {
        // On network error, don't clear session - might be temporary
        print('Network error during session validation, keeping session');
        return true; // Assume valid to allow offline usage
      } else {
        await AdminSessionService.clearSession(reason: 'Validation error');
        return false;
      }
    }
  }
  
  /// Logout and clear session
  static Future<void> logout() async {
    try {
      final token = await AdminSessionService.getSessionToken();
      
      if (token != null) {
        print('Logging out admin user');
        
        // Notify server about logout (best effort, don't fail if it doesn't work)
        try {
          await http.post(
            Uri.parse('${AdminConfig.baseUrl}${AdminConfig.adminAuthLogoutEndpoint}'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          ).timeout(AdminConfig.apiTimeout);
          print('Admin logout notification sent to server');
        } catch (e) {
          print('Failed to notify server about logout (continuing anyway): $e');
        }
      }
      
      // Clear local session regardless of server response
      await AdminSessionService.clearSession(reason: 'User logout');
      print('Admin session cleared successfully');
    } catch (e) {
      print('Error during admin logout: $e');
      // Still clear session even if server logout fails
      await AdminSessionService.clearSession(reason: 'Logout error');
    }
  }
  
  /// Check if user is currently authenticated
  static Future<bool> isAuthenticated() async {
    try {
      // First check if we have a valid session locally
      final hasValidSession = await AdminSessionService.hasValidSession();
      if (!hasValidSession) {
        print('No valid admin session found locally');
        return false;
      }
      
      // Optionally validate with server (can be disabled for offline support)
      if (AdminConfig.enableAdvancedLogging) {
        return await validateSession();
      }
      
      return true;
    } catch (e) {
      print('Error checking admin authentication status: $e');
      return false;
    }
  }
  
  /// Refresh authentication token
  static Future<bool> refreshToken() async {
    try {
      final session = await AdminSessionService.getSession();
      if (session == null) {
        print('No admin session to refresh');
        return false;
      }
      
      print('Refreshing admin authentication token');
      
      final response = await http.post(
        Uri.parse('${AdminConfig.baseUrl}${AdminConfig.adminAuthValidateEndpoint}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.token}',
        },
        body: jsonEncode({
          'token': session.token,
          'refresh': true,
        }),
      ).timeout(AdminConfig.apiTimeout);
      
      print('Admin token refresh response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;
        
        if (responseData.containsKey('new_token')) {
          // Create new session with refreshed token
          final newSession = AdminSession(
            token: responseData['new_token'] as String,
            user: session.user,
            expiresAt: DateTime.now().add(AdminConfig.sessionTimeout),
            createdAt: DateTime.now(),
          );
          
          await AdminSessionService.updateSession(newSession);
          print('Admin token refreshed successfully');
          return true;
        }
      }
      
      print('Admin token refresh failed');
      return false;
    } catch (e) {
      print('Error refreshing admin token: $e');
      return false;
    }
  }
  
  /// Get current authenticated admin user
  static Future<AdminUser?> getCurrentUser() async {
    try {
      final isAuth = await isAuthenticated();
      if (!isAuth) return null;
      
      return await AdminSessionService.getCurrentUser();
    } catch (e) {
      print('Error getting current admin user: $e');
      return null;
    }
  }
  
  /// Auto-refresh token if needed
  static Future<void> autoRefreshToken() async {
    try {
      final session = await AdminSessionService.getSession();
      if (session == null) return;
      
      // Check if token needs refresh
      final timeUntilExpiration = session.timeUntilExpiration;
      if (timeUntilExpiration <= AdminConfig.sessionRefreshThreshold) {
        print('Admin token is close to expiration, attempting refresh');
        final refreshSuccess = await refreshToken();
        
        if (!refreshSuccess) {
          print('Admin token refresh failed, user needs to re-login');
          await AdminSessionService.clearSession(reason: 'Token refresh failed');
        }
      }
    } catch (e) {
      print('Error during admin token auto-refresh: $e');
    }
  }
  
  /// Handle authentication errors
  static Future<void> handleAuthError(dynamic error) async {
    print('Handling admin authentication error: $error');
    
    if (AdminSessionService.isAuthenticationError(error)) {
      await AdminSessionService.clearSession(reason: 'Authentication error');
    }
  }
  
  /// Get authentication headers for API requests
  static Future<Map<String, String>> getAuthHeaders() async {
    final token = await AdminSessionService.getSessionToken();
    
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    
    return headers;
  }
  
  /// Check admin authentication status for debugging
  static Future<Map<String, dynamic>> getAuthDebugInfo() async {
    try {
      final sessionInfo = await AdminSessionService.getSessionDebugInfo();
      final isAuth = await isAuthenticated();
      final token = await AdminSessionService.getSessionToken();
      
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