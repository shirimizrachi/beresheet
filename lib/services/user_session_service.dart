import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:html' as html;
import '../model/user.dart';
import 'api_user_service.dart';

class UserSessionService {
  static const String _residentIdKey = 'user_resident_id';
  static const String _roleKey = 'user_role';
  static const String _userIdKey = 'user_id';
  
  static int? _cachedResidentId;
  static String? _cachedRole;
  static String? _cachedUserId;

  /// Initialize user session by fetching profile data
  static Future<void> initializeSession() async {
    try {
      final user = await ApiUserService.getCurrentUserProfile();
      if (user != null) {
        await setResidentId(user.residentId);
        await setRole(user.role);
        await setUserId(user.userId);
      }
    } catch (e) {
      print('Error initializing user session: $e');
    }
  }

  /// Store residentId based on platform
  static Future<void> setResidentId(int residentId) async {
    _cachedResidentId = residentId;
    
    if (kIsWeb) {
      // Store in cookie for web
      html.document.cookie = '$_residentIdKey=$residentId; path=/';
    } else {
      // Store in SharedPreferences for mobile
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_residentIdKey, residentId);
    }
  }

  /// Get residentId based on platform
  static Future<int?> getResidentId() async {
    if (_cachedResidentId != null) {
      return _cachedResidentId;
    }

    if (kIsWeb) {
      // Get from cookie for web
      final cookies = html.document.cookie?.split(';') ?? [];
      for (final cookie in cookies) {
        final parts = cookie.trim().split('=');
        if (parts.length == 2 && parts[0] == _residentIdKey) {
          _cachedResidentId = int.tryParse(parts[1]);
          return _cachedResidentId;
        }
      }
    } else {
      // Get from SharedPreferences for mobile
      final prefs = await SharedPreferences.getInstance();
      _cachedResidentId = prefs.getInt(_residentIdKey);
      return _cachedResidentId;
    }
    
    return null;
  }

  /// Store role based on platform
  static Future<void> setRole(String role) async {
    _cachedRole = role;
    
    if (kIsWeb) {
      // Store in cookie for web
      html.document.cookie = '$_roleKey=$role; path=/';
    } else {
      // Store in SharedPreferences for mobile
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_roleKey, role);
    }
  }

  /// Get role based on platform
  static Future<String?> getRole() async {
    if (_cachedRole != null) {
      return _cachedRole;
    }

    if (kIsWeb) {
      // Get from cookie for web
      final cookies = html.document.cookie?.split(';') ?? [];
      for (final cookie in cookies) {
        final parts = cookie.trim().split('=');
        if (parts.length == 2 && parts[0] == _roleKey) {
          _cachedRole = parts[1];
          return _cachedRole;
        }
      }
    } else {
      // Get from SharedPreferences for mobile
      final prefs = await SharedPreferences.getInstance();
      _cachedRole = prefs.getString(_roleKey);
      return _cachedRole;
    }
    
    return null;
  }

  /// Store userId based on platform
  static Future<void> setUserId(String userId) async {
    _cachedUserId = userId;
    
    if (kIsWeb) {
      // Store in cookie for web
      html.document.cookie = '$_userIdKey=$userId; path=/';
    } else {
      // Store in SharedPreferences for mobile
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userIdKey, userId);
    }
  }

  /// Get userId based on platform
  static Future<String?> getUserId() async {
    if (_cachedUserId != null) {
      return _cachedUserId;
    }

    if (kIsWeb) {
      // Get from cookie for web
      final cookies = html.document.cookie?.split(';') ?? [];
      for (final cookie in cookies) {
        final parts = cookie.trim().split('=');
        if (parts.length == 2 && parts[0] == _userIdKey) {
          _cachedUserId = parts[1];
          return _cachedUserId;
        }
      }
    } else {
      // Get from SharedPreferences for mobile
      final prefs = await SharedPreferences.getInstance();
      _cachedUserId = prefs.getString(_userIdKey);
      return _cachedUserId;
    }
    
    return null;
  }

  /// Clear session data
  static Future<void> clearSession() async {
    _cachedResidentId = null;
    _cachedRole = null;
    _cachedUserId = null;
    
    if (kIsWeb) {
      // Clear cookies for web
      html.document.cookie = '$_residentIdKey=; expires=Thu, 01 Jan 1970 00:00:00 UTC; path=/;';
      html.document.cookie = '$_roleKey=; expires=Thu, 01 Jan 1970 00:00:00 UTC; path=/;';
      html.document.cookie = '$_userIdKey=; expires=Thu, 01 Jan 1970 00:00:00 UTC; path=/;';
    } else {
      // Clear SharedPreferences for mobile
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_residentIdKey);
      await prefs.remove(_roleKey);
      await prefs.remove(_userIdKey);
    }
  }

  /// Check if user has manager role
  static Future<bool> isManager() async {
    final role = await getRole();
    return role == 'manager';
  }

  /// Get headers with residentID, Firebase token, and userId for API requests
  static Future<Map<String, String>> getApiHeaders() async {
    final residentId = await getResidentId();
    final userId = await getUserId();
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    
    if (residentId != null) {
      headers['residentID'] = residentId.toString();
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