import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

class WebAuthService {
  static String get _baseUrl => AppConfig.apiUrlWithPrefix;
  
  // SharedPreferences keys
  static const String _sessionIdKey = 'web_session_id';
  static const String _userIdKey = 'web_user_id';
  static const String _homeIdKey = 'web_home_id';
  static const String _userRoleKey = 'web_user_role';
  static const String _userFullNameKey = 'web_user_full_name';
  
  // Session storage
  static String? _sessionId;
  static String? _userId;
  static int? _homeId;
  static String? _userRole;
  static String? _userFullName;

  /// Initialize and restore session from persistent storage
  static Future<void> initializeSession() async {
    final prefs = await SharedPreferences.getInstance();
    _sessionId = prefs.getString(_sessionIdKey);
    _userId = prefs.getString(_userIdKey);
    _homeId = prefs.getInt(_homeIdKey);
    _userRole = prefs.getString(_userRoleKey);
    _userFullName = prefs.getString(_userFullNameKey);
    
    // Validate restored session
    if (_sessionId != null && _homeId != null) {
      final isValid = await validateSession();
      if (!isValid) {
        await clearSession();
      } else if (_userId != null && _userFullName == null) {
        // If we have a valid session but no full name, fetch user profile
        await _fetchUserProfile();
      }
    }
  }

  /// Save session to persistent storage
  static Future<void> _saveSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (_sessionId != null) {
      await prefs.setString(_sessionIdKey, _sessionId!);
    }
    if (_userId != null) {
      await prefs.setString(_userIdKey, _userId!);
    }
    if (_homeId != null) {
      await prefs.setInt(_homeIdKey, _homeId!);
    }
    if (_userRole != null) {
      await prefs.setString(_userRoleKey, _userRole!);
    }
    if (_userFullName != null) {
      await prefs.setString(_userFullNameKey, _userFullName!);
    }
  }

  /// Fetch user profile to get full name
  static Future<void> _fetchUserProfile() async {
    if (_userId == null || _homeId == null) return;
    
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/users/$_userId'),
        headers: getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final userData = jsonDecode(response.body);
        _userFullName = userData['full_name'] ?? 'Unknown User';
        await _saveSession();
      }
    } catch (e) {
      print('Error fetching user profile: $e');
    }
  }

  /// Login with phone number and password
  static Future<LoginResult> login(String phoneNumber, String password, int homeId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/auth/login'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'phone_number': phoneNumber,
          'password': password,
          'home_id': homeId,
        }),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        _sessionId = responseData['session_id'];
        _userId = responseData['user_id'];
        _homeId = responseData['home_id'];
        _userRole = responseData['user_role'];

        // Fetch user profile to get full name
        await _fetchUserProfile();

        // Save session to persistent storage
        await _saveSession();

        return LoginResult(
          success: true,
          message: responseData['message'],
          sessionId: _sessionId,
          userId: _userId,
          homeId: _homeId,
          userRole: _userRole,
        );
      } else {
        return LoginResult(
          success: false,
          message: responseData['message'] ?? 'Login failed',
        );
      }
    } catch (e) {
      return LoginResult(
        success: false,
        message: 'Network error: ${e.toString()}',
      );
    }
  }

  /// Login with phone number and password, including homeId in headers for tenant routing
  static Future<LoginResult> loginWithHomeId(String phoneNumber, String password, int homeId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/auth/login'),
        headers: {
          'Content-Type': 'application/json',
          'homeID': homeId.toString(), // Add homeId to headers for tenant validation
        },
        body: jsonEncode({
          'phone_number': phoneNumber,
          'password': password,
          'home_id': homeId,
        }),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        _sessionId = responseData['session_id'];
        _userId = responseData['user_id'];
        _homeId = responseData['home_id'];
        _userRole = responseData['user_role'];

        // Fetch user profile to get full name
        await _fetchUserProfile();

        // Save session to persistent storage
        await _saveSession();

        return LoginResult(
          success: true,
          message: responseData['message'],
          sessionId: _sessionId,
          userId: _userId,
          homeId: _homeId,
          userRole: _userRole,
        );
      } else {
        return LoginResult(
          success: false,
          message: responseData['message'] ?? 'Login failed',
        );
      }
    } catch (e) {
      return LoginResult(
        success: false,
        message: 'Network error: ${e.toString()}',
      );
    }
  }

  /// Validate current session
  static Future<bool> validateSession() async {
    if (_sessionId == null || _homeId == null) {
      return false;
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/auth/validate-session'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'session_id': _sessionId,
          'home_id': _homeId,
        }),
      );

      final responseData = jsonDecode(response.body);
      return response.statusCode == 200 && responseData['valid'] == true;
    } catch (e) {
      return false;
    }
  }

  /// Logout and clear session
  static Future<bool> logout() async {
    if (_sessionId == null || _homeId == null) {
      return true;
    }

    try {
      await http.post(
        Uri.parse('$_baseUrl/api/auth/logout'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'session_id': _sessionId,
          'home_id': _homeId,
        }),
      );
    } catch (e) {
      // Ignore logout errors, just clear session locally
    }

    await clearSession();
    return true;
  }

  /// Clear session data
  static Future<void> clearSession() async {
    _sessionId = null;
    _userId = null;
    _homeId = null;
    _userRole = null;
    _userFullName = null;
    
    // Clear from persistent storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionIdKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_homeIdKey);
    await prefs.remove(_userRoleKey);
    await prefs.remove(_userFullNameKey);
  }

  /// Check if user is logged in
  static bool get isLoggedIn => _sessionId != null;

  /// Check if user has manager role
  static bool get isManager => _userRole == AppConfig.userRoleManager;

  /// Get current session data
  static String? get sessionId => _sessionId;
  static String? get userId => _userId;
  static int? get homeId => _homeId;
  static String? get userRole => _userRole;
  static String? get userFullName => _userFullName;

  /// Set session data (for manual session management)
  static Future<void> setSession(String sessionId, String userId, int homeId, String userRole, [String? userFullName]) async {
    _sessionId = sessionId;
    _userId = userId;
    _homeId = homeId;
    _userRole = userRole;
    _userFullName = userFullName;
    
    // If no full name provided, fetch it
    if (_userFullName == null) {
      await _fetchUserProfile();
    }
    
    // Save to persistent storage
    await _saveSession();
  }

  /// Get headers for authenticated API calls
  static Map<String, String> getAuthHeaders() {
    final headers = {
      'Content-Type': 'application/json',
    };

    if (_homeId != null) {
      headers['homeID'] = _homeId.toString();
    }

    if (_userId != null) {
      headers['currentUserId'] = _userId!;
    }

    return headers;
  }
}

class LoginResult {
  final bool success;
  final String message;
  final String? sessionId;
  final String? userId;
  final int? homeId;
  final String? userRole;

  LoginResult({
    required this.success,
    required this.message,
    this.sessionId,
    this.userId,
    this.homeId,
    this.userRole,
  });
}