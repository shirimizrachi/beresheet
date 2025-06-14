import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class FirebaseMessagingService {
  static FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  
  /// Initialize Firebase Messaging and request permissions
  static Future<void> initialize() async {
    if (kIsWeb) {
      // Web doesn't support FCM tokens in the same way
      return;
    }
    
    // Request permission for iOS
    await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
  }
  
  /// Get the current FCM token
  static Future<String?> getFcmToken() async {
    try {
      if (kIsWeb) {
        // Web doesn't support FCM tokens in the same way
        return null;
      }
      
      final token = await _messaging.getToken();
      if (kDebugMode) {
        print('FCM Token: $token');
      }
      return token;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting FCM token: $e');
      }
      return null;
    }
  }
  
  /// Check if FCM token has changed and return the new token if different
  static Future<String?> checkForTokenChanges(String? currentToken) async {
    try {
      final newToken = await getFcmToken();
      
      if (newToken != null && newToken != currentToken) {
        if (kDebugMode) {
          print('FCM Token changed from $currentToken to $newToken');
        }
        return newToken;
      }
      
      return null; // No change
    } catch (e) {
      if (kDebugMode) {
        print('Error checking FCM token changes: $e');
      }
      return null;
    }
  }
  
  /// Listen for token refresh events
  static void listenForTokenRefresh(Function(String) onTokenRefresh) {
    if (kIsWeb) {
      return;
    }
    
    _messaging.onTokenRefresh.listen((newToken) {
      if (kDebugMode) {
        print('FCM Token refreshed: $newToken');
      }
      onTokenRefresh(newToken);
    });
  }
}