import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import 'web_jwt_session_service.dart';
import 'web_jwt_auth_service.dart';

/// Web JWT API Service - handles authenticated API calls with JWT tokens
/// Completely separate from admin API service with tenant routing support
class WebJwtApiService {
  static String get _baseUrl => AppConfig.apiUrlWithPrefix;
  
  /// Get the tenant-specific API base URL
  static Future<String> _getTenantApiUrl() async {
    try {
      // First try to get stored home name
      String? homeName = await WebJwtSessionService.getHomeName();
      
      if (homeName == null) {
        // If no stored home name, try to discover it
        final user = await WebJwtSessionService.getCurrentUser();
        if (user == null) {
          throw Exception('No authenticated user found');
        }
        
        final homeInfo = await WebJwtAuthService.discoverUserHome(user.phoneNumber);
        if (homeInfo == null) {
          throw Exception('Could not discover home for user ${user.phoneNumber}');
        }
        
        homeName = homeInfo['home_name'] as String;
        // Store for future use
        await WebJwtSessionService.storeHomeName(homeName);
      }
      
      return '$_baseUrl/$homeName/api';
    } catch (e) {
      print('Error getting tenant API URL: $e');
      throw Exception('Failed to get tenant API URL: $e');
    }
  }

  /// Make an authenticated GET request
  static Future<http.Response> get(String endpoint, {Map<String, String>? additionalHeaders}) async {
    return await _makeAuthenticatedRequest(
      'GET',
      endpoint,
      additionalHeaders: additionalHeaders,
    );
  }

  /// Make an authenticated POST request
  static Future<http.Response> post(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? additionalHeaders,
  }) async {
    return await _makeAuthenticatedRequest(
      'POST',
      endpoint,
      body: body,
      additionalHeaders: additionalHeaders,
    );
  }

  /// Make an authenticated PUT request
  static Future<http.Response> put(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? additionalHeaders,
  }) async {
    return await _makeAuthenticatedRequest(
      'PUT',
      endpoint,
      body: body,
      additionalHeaders: additionalHeaders,
    );
  }

  /// Make an authenticated DELETE request
  static Future<http.Response> delete(String endpoint, {Map<String, String>? additionalHeaders}) async {
    return await _makeAuthenticatedRequest(
      'DELETE',
      endpoint,
      additionalHeaders: additionalHeaders,
    );
  }

  /// Make an authenticated multipart request (for file uploads)
  static Future<http.StreamedResponse> multipart(
    String method,
    String endpoint,
    Map<String, String> fields, {
    Map<String, http.MultipartFile>? files,
    Map<String, String>? additionalHeaders,
  }) async {
    await _ensureValidToken();
    
    final headers = await WebJwtSessionService.getAuthHeaders();
    if (additionalHeaders != null) {
      headers.addAll(additionalHeaders);
    }
    
    final tenantBaseUrl = await _getTenantApiUrl();
    final uri = Uri.parse('$tenantBaseUrl$endpoint');
    final request = http.MultipartRequest(method, uri);
    
    request.headers.addAll(headers);
    request.fields.addAll(fields);
    
    if (files != null) {
      request.files.addAll(files.values);
    }
    
    try {
      return await request.send();
    } catch (e) {
      print('Error in multipart request: $e');
      rethrow;
    }
  }

  /// Make an authenticated request with automatic token refresh
  static Future<http.Response> _makeAuthenticatedRequest(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? additionalHeaders,
  }) async {
    await _ensureValidToken();
    
    final headers = await WebJwtSessionService.getAuthHeaders();
    if (additionalHeaders != null) {
      headers.addAll(additionalHeaders);
    }
    
    final tenantBaseUrl = await _getTenantApiUrl();
    final uri = Uri.parse('$tenantBaseUrl$endpoint');
    
    try {
      http.Response response;
      
      switch (method.toUpperCase()) {
        case 'GET':
          response = await http.get(uri, headers: headers);
          break;
        case 'POST':
          response = await http.post(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          );
          break;
        case 'PUT':
          response = await http.put(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          );
          break;
        case 'DELETE':
          response = await http.delete(uri, headers: headers);
          break;
        default:
          throw UnsupportedError('HTTP method $method not supported');
      }
      
      // Handle authentication errors
      if (response.statusCode == 401) {
        print('JWT API request returned 401, handling auth error');
        await WebJwtAuthService.handleAuthError('401 Unauthorized');
        throw Exception('Authentication failed - please login again');
      }
      
      return response;
    } catch (e) {
      print('Error in JWT API request: $e');
      
      // Handle authentication errors
      if (WebJwtSessionService.isAuthenticationError(e)) {
        await WebJwtAuthService.handleAuthError(e);
      }
      
      rethrow;
    }
  }

  /// Ensure we have a valid token, refresh if needed
  static Future<void> _ensureValidToken() async {
    final needsRefresh = await WebJwtSessionService.needsRefresh();
    if (needsRefresh) {
      print('JWT token needs refresh before API call');
      final refreshSuccess = await WebJwtAuthService.refreshToken();
      if (!refreshSuccess) {
        throw Exception('Token refresh failed - please login again');
      }
    }
    
    final hasValidSession = await WebJwtSessionService.hasValidSession();
    if (!hasValidSession) {
      throw Exception('No valid JWT session - please login');
    }
  }

  /// Get events with JWT authentication
  static Future<List<Map<String, dynamic>>> getEvents({
    String? type,
    bool? upcoming,
    bool? approvedOnly,
  }) async {
    String endpoint = '/api/events';
    final queryParams = <String>[];
    
    if (type != null) queryParams.add('type=$type');
    if (upcoming == true) queryParams.add('upcoming=true');
    if (approvedOnly == true) queryParams.add('approved_only=true');
    
    if (queryParams.isNotEmpty) {
      endpoint += '?${queryParams.join('&')}';
    }
    
    final response = await get(endpoint);
    
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Failed to load events: ${response.statusCode}');
    }
  }

  /// Get user profile with JWT authentication
  static Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    final response = await get('/api/users/$userId');
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else if (response.statusCode == 404) {
      return null;
    } else {
      throw Exception('Failed to load user profile: ${response.statusCode}');
    }
  }

  /// Create event with JWT authentication
  static Future<Map<String, dynamic>> createEvent(Map<String, dynamic> eventData) async {
    final response = await post('/api/events', body: eventData);
    
    if (response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception('Failed to create event: ${errorData['detail'] ?? 'Unknown error'}');
    }
  }

  /// Update event with JWT authentication
  static Future<Map<String, dynamic>> updateEvent(String eventId, Map<String, dynamic> eventData) async {
    final response = await put('/api/events/$eventId', body: eventData);
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception('Failed to update event: ${errorData['detail'] ?? 'Unknown error'}');
    }
  }

  /// Delete event with JWT authentication
  static Future<void> deleteEvent(String eventId) async {
    final response = await delete('/api/events/$eventId');
    
    if (response.statusCode != 200) {
      final errorData = jsonDecode(response.body);
      throw Exception('Failed to delete event: ${errorData['detail'] ?? 'Unknown error'}');
    }
  }

  /// Register for event with JWT authentication
  static Future<void> registerForEvent(String eventId) async {
    final response = await post('/api/events/$eventId/register');
    
    if (response.statusCode != 200) {
      final errorData = jsonDecode(response.body);
      throw Exception('Failed to register for event: ${errorData['detail'] ?? 'Unknown error'}');
    }
  }

  /// Unregister from event with JWT authentication
  static Future<void> unregisterFromEvent(String eventId) async {
    final response = await post('/api/events/$eventId/unregister');
    
    if (response.statusCode != 200) {
      final errorData = jsonDecode(response.body);
      throw Exception('Failed to unregister from event: ${errorData['detail'] ?? 'Unknown error'}');
    }
  }

  /// Get all users with JWT authentication (manager only)
  static Future<List<Map<String, dynamic>>> getAllUsers() async {
    final response = await get('/api/users');
    
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Failed to load users: ${response.statusCode}');
    }
  }

  /// Create user with JWT authentication (manager only)
  static Future<Map<String, dynamic>> createUser(Map<String, dynamic> userData) async {
    final response = await post('/api/users', body: userData);
    
    if (response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception('Failed to create user: ${errorData['detail'] ?? 'Unknown error'}');
    }
  }

  /// Update user with JWT authentication
  static Future<Map<String, dynamic>> updateUser(String userId, Map<String, dynamic> userData) async {
    final response = await put('/api/users/$userId', body: userData);
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception('Failed to update user: ${errorData['detail'] ?? 'Unknown error'}');
    }
  }

  /// Test JWT authentication
  static Future<Map<String, dynamic>> testAuth() async {
    final response = await get('/api/web-auth/me');
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('JWT auth test failed: ${response.statusCode}');
    }
  }
}