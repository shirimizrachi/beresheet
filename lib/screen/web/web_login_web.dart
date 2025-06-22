// REPLACED WITH JWT AUTHENTICATION
// This file now redirects to the new JWT login screen

import 'package:flutter/material.dart';
import 'web_jwt_login_screen.dart';

class WebLoginWeb extends StatelessWidget {
  const WebLoginWeb({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Simply delegate to the new JWT login screen
    return const WebJwtLoginScreen();
  }
}

// Legacy class for compatibility - now delegates to JWT
class WebSessionManager {
  // All methods deprecated - use WebJwtAuthService and WebJwtSessionService instead
  
  Future<void> setSession(String sessionId, String userId, int homeId, String userRole, [String? userFullName]) async {
    print('Warning: WebSessionManager.setSession is deprecated. Use WebJwtAuthService instead.');
  }

  Future<void> clearSession() async {
    print('Warning: WebSessionManager.clearSession is deprecated. Use WebJwtAuthService.logout() instead.');
  }

  bool get isLoggedIn => false;
  String? get sessionId => null;
  String? get userId => null;
  int? get homeId => null;
  String? get userRole => null;
  String? get userFullName => null;
  bool get isManager => false;
}