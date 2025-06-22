import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../model/admin/admin_user.dart';
import '../../config/admin_config.dart';

/// Independent session management service for the admin panel
/// Completely separate from the main app's session management
class AdminSessionService {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  static AdminSession? _currentSession;

  /// Store admin session securely
  static Future<void> storeSession(AdminSession session) async {
    try {
      _currentSession = session;
      
      // Store session data securely
      await _secureStorage.write(
        key: AdminConfig.adminSessionKey,
        value: jsonEncode(session.toJson()),
      );
      
      // Store token separately for quick access
      await _secureStorage.write(
        key: AdminConfig.adminTokenKey,
        value: session.token,
      );
      
      // Store user data separately
      await _secureStorage.write(
        key: AdminConfig.adminUserKey,
        value: jsonEncode(session.user.toJson()),
      );
      
      print('Admin session stored successfully for user: ${session.user.name}');
    } catch (e) {
      print('Error storing admin session: $e');
      throw Exception('Failed to store admin session');
    }
  }

  /// Get current admin user
  static Future<AdminUser?> getCurrentUser() async {
    try {
      // Return cached session if available and valid
      if (_currentSession != null && _currentSession!.isValid) {
        return _currentSession!.user;
      }
      
      // Try to load from secure storage
      final userJson = await _secureStorage.read(key: AdminConfig.adminUserKey);
      if (userJson == null) return null;
      
      final userData = jsonDecode(userJson) as Map<String, dynamic>;
      return AdminUser.fromJson(userData);
    } catch (e) {
      print('Error getting current admin user: $e');
      return null;
    }
  }

  /// Get current session token
  static Future<String?> getSessionToken() async {
    try {
      // Return cached token if available and valid
      if (_currentSession != null && _currentSession!.isValid) {
        return _currentSession!.token;
      }
      
      // Try to load from secure storage
      return await _secureStorage.read(key: AdminConfig.adminTokenKey);
    } catch (e) {
      print('Error getting admin session token: $e');
      return null;
    }
  }

  /// Get full admin session
  static Future<AdminSession?> getSession() async {
    try {
      // Return cached session if available and valid
      if (_currentSession != null && _currentSession!.isValid) {
        return _currentSession;
      }
      
      // Try to load from secure storage
      final sessionJson = await _secureStorage.read(key: AdminConfig.adminSessionKey);
      if (sessionJson == null) return null;
      
      final sessionData = jsonDecode(sessionJson) as Map<String, dynamic>;
      final session = AdminSession.fromJson(sessionData);
      
      print('Admin session loaded - Now: ${DateTime.now()}, ExpiresAt: ${session.expiresAt}');
      print('Admin session isValid: ${session.isValid}, timeUntilExpiration: ${session.timeUntilExpiration}');
      
      // Check if session is still valid
      if (session.isValid) {
        _currentSession = session;
        print('Admin session is valid, using cached session');
        return session;
      } else {
        // Session expired, clear it
        print('Admin session expired, clearing session');
        await clearSession();
        return null;
      }
    } catch (e) {
      print('Error getting admin session: $e');
      return null;
    }
  }

  /// Check if there's a valid admin session
  static Future<bool> hasValidSession() async {
    try {
      final session = await getSession();
      return session != null && session.isValid;
    } catch (e) {
      print('Error checking admin session validity: $e');
      return false;
    }
  }

  /// Clear admin session
  static Future<void> clearSession({String? reason}) async {
    try {
      _currentSession = null;
      
      // Clear all stored session data
      await Future.wait([
        _secureStorage.delete(key: AdminConfig.adminSessionKey),
        _secureStorage.delete(key: AdminConfig.adminTokenKey),
        _secureStorage.delete(key: AdminConfig.adminUserKey),
      ]);
      
      print('Admin session cleared${reason != null ? ' - Reason: $reason' : ''}');
    } catch (e) {
      print('Error clearing admin session: $e');
    }
  }

  /// Refresh session if needed
  static Future<bool> refreshSessionIfNeeded() async {
    try {
      final session = await getSession();
      if (session == null) return false;
      
      // Check if session needs refresh (within threshold of expiration)
      final timeUntilExpiration = session.timeUntilExpiration;
      if (timeUntilExpiration <= AdminConfig.sessionRefreshThreshold) {
        // Here you would typically call an API to refresh the token
        // For now, we'll just check if it's still valid
        if (timeUntilExpiration.isNegative) {
          await clearSession(reason: 'Session expired');
          return false;
        }
      }
      
      return true;
    } catch (e) {
      print('Error refreshing admin session: $e');
      return false;
    }
  }

  /// Update session with new data (for token refresh)
  static Future<void> updateSession(AdminSession newSession) async {
    await storeSession(newSession);
  }

  /// Get session remaining time
  static Future<Duration?> getSessionRemainingTime() async {
    try {
      final session = await getSession();
      if (session == null) return null;
      
      return session.timeUntilExpiration;
    } catch (e) {
      print('Error getting session remaining time: $e');
      return null;
    }
  }

  /// Check if error is authentication related
  static bool isAuthenticationError(dynamic error) {
    if (error is Exception) {
      final errorMessage = error.toString().toLowerCase();
      return errorMessage.contains('unauthorized') ||
          errorMessage.contains('authentication') ||
          errorMessage.contains('token') ||
          errorMessage.contains('session') ||
          errorMessage.contains('401');
    }
    return false;
  }

  /// Check if error is network related
  static bool isNetworkError(dynamic error) {
    if (error is Exception) {
      final errorMessage = error.toString().toLowerCase();
      return errorMessage.contains('network') ||
          errorMessage.contains('connection') ||
          errorMessage.contains('timeout') ||
          errorMessage.contains('unreachable') ||
          errorMessage.contains('dns');
    }
    return false;
  }

  /// Validate session format
  static bool _isValidSessionFormat(Map<String, dynamic> sessionData) {
    return sessionData.containsKey('token') &&
        sessionData.containsKey('user') &&
        sessionData.containsKey('expires_at') &&
        sessionData.containsKey('created_at');
  }

  /// Get session debug info (for development)
  static Future<Map<String, dynamic>> getSessionDebugInfo() async {
    try {
      final session = await getSession();
      final token = await getSessionToken();
      final user = await getCurrentUser();
      
      return {
        'hasSession': session != null,
        'sessionValid': session?.isValid ?? false,
        'hasToken': token != null,
        'hasUser': user != null,
        'userName': user?.name,
        'userEmail': user?.adminUserEmail,
        'expiresAt': session?.expiresAt.toIso8601String(),
        'timeUntilExpiration': session?.timeUntilExpiration.toString(),
        'sessionInMemory': _currentSession != null,
      };
    } catch (e) {
      return {
        'error': e.toString(),
      };
    }
  }

  /// Clear all admin-related storage (for development/debugging)
  static Future<void> clearAllAdminStorage() async {
    try {
      await clearSession(reason: 'Manual storage clear');
      
      // Clear any other admin-related keys if they exist
      final allKeys = await _secureStorage.readAll();
      final adminKeys = allKeys.keys.where((key) => key.startsWith('admin_'));
      
      for (final key in adminKeys) {
        await _secureStorage.delete(key: key);
      }
      
      print('All admin storage cleared');
    } catch (e) {
      print('Error clearing admin storage: $e');
    }
  }
}