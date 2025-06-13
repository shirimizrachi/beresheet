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
  
  static int? _cachedhomeID;
  static String? _cachedRole;
  static String? _cachedUserId;

  /// Initialize user session by fetching profile data
  static Future<void> initializeSession() async {
    try {
      final user = await ApiUserService.getCurrentUserProfile();
      if (user != null) {
        await sethomeID(user.homeID);
        await setRole(user.role);
        await setUserId(user.id);
      }
    } catch (e) {
      print('Error initializing user session: $e');
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

  /// Clear session data
  static Future<void> clearSession() async {
    _cachedhomeID = null;
    _cachedRole = null;
    _cachedUserId = null;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_homeIDKey);
    await prefs.remove(_roleKey);
    await prefs.remove(_userIdKey);
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
    
    // Add Firebase token
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final token = await user.getIdToken();
        if (token != null) {
          headers['firebaseToken'] = token;
        }
      }
    } catch (e) {
      print('Error getting Firebase token: $e');
    }
    
    return headers;
  }
}