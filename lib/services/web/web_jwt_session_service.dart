import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import '../../model/web/web_jwt_user.dart';
import '../../config/app_config.dart';
// Import dart:html only for web platform
import 'dart:html' as html show document;

/// Web JWT Session Service - completely separate from admin session service
/// Manages JWT tokens and session data for web users
class WebJwtSessionService {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      preferencesKeyPrefix: 'web_jwt_',
    ),
    iOptions: IOSOptions(
      groupId: 'group.com.beresheet.web.jwt',
      accountName: 'WebJwtSession',
    ),
  );

  // Storage keys - prefixed to avoid conflicts with admin system
  static const String _webJwtSessionKey = 'web_jwt_session';
  static const String _webJwtTokenKey = 'web_jwt_token';
  static const String _webJwtRefreshTokenKey = 'web_jwt_refresh_token';
  static const String _webJwtUserKey = 'web_jwt_user';
  static const String _webJwtHomeNameKey = 'web_jwt_home_name';

  // In-memory cache for current session
  static WebJwtSession? _currentSession;

  /// Store JWT session securely
  static Future<void> storeSession(WebJwtSession session) async {
    try {
      _currentSession = session;

      // Store session data securely
      await _secureStorage.write(
        key: _webJwtSessionKey,
        value: jsonEncode(session.toJson()),
      );

      // Store individual tokens for easy access
      await _secureStorage.write(
        key: _webJwtTokenKey,
        value: session.token,
      );

      await _secureStorage.write(
        key: _webJwtRefreshTokenKey,
        value: session.refreshToken,
      );

      await _secureStorage.write(
        key: _webJwtUserKey,
        value: jsonEncode(session.user.toJson()),
      );

      print('Web JWT session stored successfully for user: ${session.user.fullName}');
    } catch (e) {
      print('Error storing web JWT session: $e');
      throw Exception('Failed to store web JWT session');
    }
  }

  /// Get JWT token from browser cookies (web only)
  static String? _getJwtTokenFromCookie() {
    if (kIsWeb) {
      try {
        final cookies = html.document.cookie!;
        print('All browser cookies: $cookies');
        final cookiePairs = cookies.split(';');
        
        for (final cookiePair in cookiePairs) {
          final parts = cookiePair.trim().split('=');
          if (parts.length == 2 && parts[0] == 'web_jwt_token') {
            print('Found web_jwt_token cookie: ${parts[1].substring(0, 20)}...');
            return parts[1];
          }
        }
        print('web_jwt_token cookie not found');
      } catch (e) {
        print('Error reading web_jwt_token cookie: $e');
      }
    }
    return null;
  }

  /// Get current JWT token
  static Future<String?> getJwtToken() async {
    try {
      // Return cached token if available and valid
      if (_currentSession != null && _currentSession!.isValid) {
        return _currentSession!.token;
      }

      // For web, try to get token from cookie first (since cookies persist across page refreshes)
      if (kIsWeb) {
        final cookieToken = _getJwtTokenFromCookie();
        if (cookieToken != null) {
          print('Found JWT token in cookie');
          return cookieToken;
        }
      }

      // Try to load from secure storage
      return await _secureStorage.read(key: _webJwtTokenKey);
    } catch (e) {
      print('Error getting web JWT token: $e');
      return null;
    }
  }

  /// Get current refresh token
  static Future<String?> getRefreshToken() async {
    try {
      // Return cached refresh token if available
      if (_currentSession != null && _currentSession!.canRefresh) {
        return _currentSession!.refreshToken;
      }

      // Try to load from secure storage
      return await _secureStorage.read(key: _webJwtRefreshTokenKey);
    } catch (e) {
      print('Error getting web JWT refresh token: $e');
      return null;
    }
  }

  /// Get full JWT session
  static Future<WebJwtSession?> getSession() async {
    try {
      // Return cached session if available and valid
      if (_currentSession != null && _currentSession!.isValid) {
        return _currentSession;
      }

      // Try to load from secure storage
      final sessionJson = await _secureStorage.read(key: _webJwtSessionKey);
      if (sessionJson == null) return null;

      final sessionData = jsonDecode(sessionJson) as Map<String, dynamic>;
      final session = WebJwtSession.fromJson(sessionData);

      print('Session loaded - Now: ${DateTime.now()}, ExpiresAt: ${session.expiresAt}');
      print('Session isValid: ${session.isValid}, timeUntilExpiration: ${session.timeUntilExpiration}');

      // Check if session is still valid
      if (session.isValid) {
        _currentSession = session;
        return session;
      } else {
        // Session expired, clear it
        print('Session expired immediately - clearing session');
        await clearSession(reason: 'Session expired');
        return null;
      }
    } catch (e) {
      print('Error getting web JWT session: $e');
      return null;
    }
  }

  /// Check if there's a valid JWT session
  static Future<bool> hasValidSession() async {
    try {
      final session = await getSession();
      return session != null && session.isValid;
    } catch (e) {
      print('Error checking web JWT session validity: $e');
      return false;
    }
  }

  /// Get current user from session
  static Future<WebJwtUser?> getCurrentUser() async {
    try {
      final session = await getSession();
      return session?.user;
    } catch (e) {
      print('Error getting current web JWT user: $e');
      return null;
    }
  }

  /// Store home name for tenant routing
  static Future<void> storeHomeName(String homeName) async {
    try {
      await _secureStorage.write(
        key: _webJwtHomeNameKey,
        value: homeName,
      );
      print('Web JWT home name stored: $homeName');
    } catch (e) {
      print('Error storing web JWT home name: $e');
    }
  }

  /// Get stored home name
  static Future<String?> getHomeName() async {
    try {
      return await _secureStorage.read(key: _webJwtHomeNameKey);
    } catch (e) {
      print('Error getting web JWT home name: $e');
      return null;
    }
  }

  /// Clear JWT session
  static Future<void> clearSession({String? reason}) async {
    try {
      _currentSession = null;

      // Clear all stored session data
      await Future.wait([
        _secureStorage.delete(key: _webJwtSessionKey),
        _secureStorage.delete(key: _webJwtTokenKey),
        _secureStorage.delete(key: _webJwtRefreshTokenKey),
        _secureStorage.delete(key: _webJwtUserKey),
        _secureStorage.delete(key: _webJwtHomeNameKey),
      ]);

      print('Web JWT session cleared${reason != null ? ' - Reason: $reason' : ''}');
    } catch (e) {
      print('Error clearing web JWT session: $e');
    }
  }

  /// Update session with new JWT tokens (for token refresh)
  static Future<void> updateSession(WebJwtSession newSession) async {
    await storeSession(newSession);
  }

  /// Check if token needs refresh
  static Future<bool> needsRefresh() async {
    try {
      final session = await getSession();
      return session?.needsRefresh ?? false;
    } catch (e) {
      print('Error checking if web JWT needs refresh: $e');
      return false;
    }
  }

  /// Get session remaining time
  static Future<Duration?> getSessionRemainingTime() async {
    try {
      final session = await getSession();
      if (session == null) return null;

      return session.timeUntilExpiration;
    } catch (e) {
      print('Error getting web JWT session remaining time: $e');
      return null;
    }
  }

  /// Check if error is a network error
  static bool isNetworkError(dynamic error) {
    final errorMessage = error.toString().toLowerCase();
    return errorMessage.contains('socketexception') ||
        errorMessage.contains('handshakeexception') ||
        errorMessage.contains('timeout') ||
        errorMessage.contains('network') ||
        errorMessage.contains('connection');
  }

  /// Check if error is an authentication error
  static bool isAuthenticationError(dynamic error) {
    final errorMessage = error.toString().toLowerCase();
    return errorMessage.contains('401') ||
        errorMessage.contains('unauthorized') ||
        errorMessage.contains('invalid token') ||
        errorMessage.contains('jwt') ||
        errorMessage.contains('expired');
  }

  /// Validate session format
  static bool _isValidSessionFormat(Map<String, dynamic> sessionData) {
    return sessionData.containsKey('token') &&
        sessionData.containsKey('refreshToken') &&
        sessionData.containsKey('user') &&
        sessionData.containsKey('expiresAt') &&
        sessionData.containsKey('refreshExpiresAt') &&
        sessionData.containsKey('createdAt');
  }

  /// Get session debug info (for development)
  static Future<Map<String, dynamic>> getSessionDebugInfo() async {
    try {
      final session = await getSession();
      final token = await getJwtToken();
      final refreshToken = await getRefreshToken();
      final user = session?.user;

      return {
        'hasSession': session != null,
        'sessionValid': session?.isValid ?? false,
        'canRefresh': session?.canRefresh ?? false,
        'needsRefresh': session?.needsRefresh ?? false,
        'hasToken': token != null,
        'hasRefreshToken': refreshToken != null,
        'tokenLength': token?.length ?? 0,
        'userPhoneNumber': user?.phoneNumber,
        'userFullName': user?.fullName,
        'userRole': user?.role,
        'homeId': user?.homeId,
        'expiresAt': session?.expiresAt.toIso8601String(),
        'refreshExpiresAt': session?.refreshExpiresAt.toIso8601String(),
        'timeUntilExpiration': session?.timeUntilExpiration.toString(),
        'sessionInMemory': _currentSession != null,
      };
    } catch (e) {
      return {
        'error': e.toString(),
      };
    }
  }

  /// Get headers for authenticated API calls
  static Future<Map<String, String>> getAuthHeaders() async {
    final token = await getJwtToken();
    final user = await getCurrentUser();
    
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    
    if (user != null) {
      headers['homeID'] = user.homeId.toString();
      headers['currentUserId'] = user.id;
    }
    
    return headers;
  }

  /// Check if user has manager role
  static Future<bool> isManager() async {
    try {
      final user = await getCurrentUser();
      return user?.role == 'manager';
    } catch (e) {
      print('Error checking if user is manager: $e');
      return false;
    }
  }

  /// Check if user is logged in
  static Future<bool> isLoggedIn() async {
    return await hasValidSession();
  }
}