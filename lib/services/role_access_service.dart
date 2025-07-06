import '../services/user_session_service.dart';
import '../services/web/web_jwt_auth_service.dart';
import '../config/app_config.dart';
import 'package:flutter/foundation.dart';

/// Service to handle role-based access control across the application
class RoleAccessService {
  
  /// Check if current user has manager or staff role (for mobile app)
  static Future<bool> canEditEvents() async {
    try {
      final role = await UserSessionService.getRole();
      return role == AppConfig.userRoleManager || role == AppConfig.userRoleStaff;
    } catch (e) {
      print('Error checking edit events permission: $e');
      return false;
    }
  }
  
  /// Check if current user has manager or staff role for web tenant management access
  static Future<bool> canAccessTenantManagement() async {
    try {
      if (kIsWeb) {
        final user = await WebJwtAuthService.getCurrentUser();
        return user?.role == AppConfig.userRoleManager || user?.role == AppConfig.userRoleStaff;
      } else {
        final role = await UserSessionService.getRole();
        return role == AppConfig.userRoleManager || role == AppConfig.userRoleStaff;
      }
    } catch (e) {
      print('Error checking tenant management access: $e');
      return false;
    }
  }
  
  /// Check if current user has manager or staff role for web general access
  static Future<bool> canAccessWebFeatures() async {
    try {
      if (kIsWeb) {
        final user = await WebJwtAuthService.getCurrentUser();
        return user?.role == AppConfig.userRoleManager || user?.role == AppConfig.userRoleStaff;
      } else {
        final role = await UserSessionService.getRole();
        return role == AppConfig.userRoleManager || role == AppConfig.userRoleStaff;
      }
    } catch (e) {
      print('Error checking web features access: $e');
      return false;
    }
  }
  
  /// Check if current user is a manager (highest privilege level)
  static Future<bool> isManager() async {
    try {
      if (kIsWeb) {
        final user = await WebJwtAuthService.getCurrentUser();
        return user?.role == AppConfig.userRoleManager;
      } else {
        final role = await UserSessionService.getRole();
        return role == AppConfig.userRoleManager;
      }
    } catch (e) {
      print('Error checking manager role: $e');
      return false;
    }
  }
  
  /// Check if current user is staff (manager or staff)
  static Future<bool> isStaff() async {
    try {
      if (kIsWeb) {
        final user = await WebJwtAuthService.getCurrentUser();
        return user?.role == AppConfig.userRoleManager || user?.role == AppConfig.userRoleStaff;
      } else {
        final role = await UserSessionService.getRole();
        return role == AppConfig.userRoleManager || role == AppConfig.userRoleStaff;
      }
    } catch (e) {
      print('Error checking staff role: $e');
      return false;
    }
  }
  
  /// Get current user role for debugging/display purposes
  static Future<String?> getCurrentRole() async {
    try {
      if (kIsWeb) {
        final user = await WebJwtAuthService.getCurrentUser();
        return user?.role;
      } else {
        return await UserSessionService.getRole();
      }
    } catch (e) {
      print('Error getting current role: $e');
      return null;
    }
  }
}