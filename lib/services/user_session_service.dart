import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../model/user.dart';
import '../config/app_config.dart';
import 'api_user_service.dart';

class UserSessionService {
  static const String _homeIDKey = 'user_home_id';
  static const String _roleKey = 'user_role';
  static const String _userIdKey = 'user_id';
  static const String _photoKey = 'user_photo';
  
  static int? _cachedhomeID;
  static String? _cachedRole;
  static String? _cachedUserId;
  static String? _cachedPhoto;

  /// Initialize user session by restoring from SharedPreferences first, then optionally fetching fresh data
  static Future<void> initializeSession({bool fetchFreshData = false}) async {
    try {
      // First, restore cached session data from SharedPreferences
      await _restoreSessionFromStorage();
      
      // Optionally fetch fresh data from API if requested
      if (fetchFreshData) {
        final user = await ApiUserService.getCurrentUserProfile();
        if (user != null) {
          await sethomeID(user.homeID);
          await setRole(user.role);
          await setUserId(user.id);
          await setPhoto(user.photo);
        }
      }
    } catch (e) {
      print('Error initializing user session: $e');
      // Don't clear session on initialization errors - keep existing cached data
    }
  }

  /// Restore session data from SharedPreferences to static cache
  static Future<void> _restoreSessionFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedhomeID = prefs.getInt(_homeIDKey);
      _cachedRole = prefs.getString(_roleKey);
      _cachedUserId = prefs.getString(_userIdKey);
      _cachedPhoto = prefs.getString(_photoKey);
      
      print('Session restored from storage: userId=$_cachedUserId, homeID=$_cachedhomeID, role=$_cachedRole');
    } catch (e) {
      print('Error restoring session from storage: $e');
    }
  }

  /// Check if session data exists (either in cache or storage)
  static Future<bool> hasValidSession() async {
    try {
      // First check cache
      if (_cachedUserId != null && _cachedhomeID != null) {
        return true;
      }
      
      // Check SharedPreferences if cache is empty
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString(_userIdKey);
      final homeID = prefs.getInt(_homeIDKey);
      
      return userId != null && homeID != null;
    } catch (e) {
      print('Error checking session validity: $e');
      return false;
    }
  }

  /// Store homeID using SharedPreferences (works on all platforms)
  static Future<void> sethomeID(int homeID) async {
    _cachedhomeID = homeID;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_homeIDKey, homeID);
  }

  /// Get homeID using SharedPreferences
  static Future<int?> gethomeID() async {
    if (_cachedhomeID != null) {
      return _cachedhomeID;
    }

    final prefs = await SharedPreferences.getInstance();
    _cachedhomeID = prefs.getInt(_homeIDKey);
    return _cachedhomeID;
  }

  /// Store role using SharedPreferences
  static Future<void> setRole(String role) async {
    _cachedRole = role;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_roleKey, role);
  }

  /// Get role using SharedPreferences
  static Future<String?> getRole() async {
    if (_cachedRole != null) {
      return _cachedRole;
    }

    final prefs = await SharedPreferences.getInstance();
    _cachedRole = prefs.getString(_roleKey);
    return _cachedRole;
  }

  /// Store userId using SharedPreferences
  static Future<void> setUserId(String userId) async {
    _cachedUserId = userId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, userId);
  }

  /// Get userId using SharedPreferences
  static Future<String?> getUserId() async {
    if (_cachedUserId != null) {
      return _cachedUserId;
    }

    final prefs = await SharedPreferences.getInstance();
    _cachedUserId = prefs.getString(_userIdKey);
    return _cachedUserId;
  }

  /// Store photo URL using SharedPreferences
  static Future<void> setPhoto(String? photoUrl) async {
    _cachedPhoto = photoUrl;
    final prefs = await SharedPreferences.getInstance();
    if (photoUrl != null) {
      await prefs.setString(_photoKey, photoUrl);
    } else {
      await prefs.remove(_photoKey);
    }
  }

  /// Get photo URL using SharedPreferences
  static Future<String?> getPhoto() async {
    if (_cachedPhoto != null) {
      return _cachedPhoto;
    }

    final prefs = await SharedPreferences.getInstance();
    _cachedPhoto = prefs.getString(_photoKey);
    return _cachedPhoto;
  }


  /// Check if user has manager role
  static Future<bool> isManager() async {
    final role = await getRole();
    return role == AppConfig.userRoleManager;
  }

  /// Get headers with homeID, Firebase token, and userId for API requests
  static Future<Map<String, String>> getApiHeaders() async {
    final homeID = await gethomeID();
    final userId = await getUserId();
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    
    if (homeID != null) {
      headers['homeID'] = homeID.toString();
    }
    
    if (userId != null) {
      headers['userId'] = userId;
    }
    
    // Add Firebase token with refresh handling
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final token = await user.getIdToken(true); // Force refresh if needed
        if (token != null) {
          headers['firebaseToken'] = token;
        }
      }
    } catch (e) {
      print('Error getting Firebase token: $e');
    }
    
    return headers;
  }

  /// Setup Firebase Auth state listener for automatic session management
  static void setupFirebaseAuthListener() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      if (user == null) {
        // User signed out - clear session
        print('Firebase user signed out - clearing session');
        await clearSession();
      } else {
        // User signed in - refresh session if we have stored data
        print('Firebase user state changed - user signed in');
        final hasSession = await hasValidSession();
        if (hasSession) {
          // Refresh session data periodically
          await _refreshSessionIfNeeded();
        }
      }
    });

    // Also listen for token refresh events
    FirebaseAuth.instance.idTokenChanges().listen((User? user) async {
      if (user != null) {
        print('Firebase token refreshed');
        // Token was refreshed, update any cached data if needed
      }
    });
  }

  /// Refresh session data if it's been a while since last update
  static Future<void> _refreshSessionIfNeeded() async {
    try {
      final userId = await getUserId();
      if (userId != null) {
        // Fetch fresh user data to update session
        final user = await ApiUserService.getUserProfile(userId);
        if (user != null) {
          await sethomeID(user.homeID);
          await setRole(user.role);
          await setUserId(user.id);
          await setPhoto(user.photo);
          print('Session data refreshed successfully');
        }
      }
    } catch (e) {
      print('Error refreshing session: $e');
      // Don't clear session on refresh errors - keep existing data
    }
  }

  /// Clear session with optional reason logging
  static Future<void> clearSession({String? reason}) async {
    print('Clearing session${reason != null ? ' - Reason: $reason' : ''}');
    _cachedhomeID = null;
    _cachedRole = null;
    _cachedUserId = null;
    _cachedPhoto = null;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_homeIDKey);
    await prefs.remove(_roleKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_photoKey);
  }

  /// Enhanced error handling for API calls
  static bool isNetworkError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('socketexception') ||
           errorString.contains('timeout') ||
           errorString.contains('network') ||
           errorString.contains('connection') ||
           errorString.contains('unreachable');
  }

  /// Enhanced error handling for authentication errors
  static bool isAuthenticationError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('unauthorized') ||
           errorString.contains('403') ||
           errorString.contains('401') ||
           errorString.contains('token') ||
           errorString.contains('authentication');
  }
}