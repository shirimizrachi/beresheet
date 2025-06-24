import 'package:flutter/foundation.dart';
import 'dart:html' as html;

/// Web-specific utility functions for tenant management
class WebUtils {
  /// Default API prefix for fallback
  static const String _defaultApiPrefix = 'beresheet';
  
  /// Default home ID for fallback
  static const int _defaultHomeId = 1;
  
  /// Get the API prefix from tenant_info cookie for web requests
  /// Cookie format: "tenant_name:tenant_id" (e.g., "demo:2")
  /// Returns the tenant_name part before the colon
  static String getTenantPrefixFromCookie() {
    if (kIsWeb) {
      try {
        final cookies = html.document.cookie!;
        final cookiePairs = cookies.split(';');
        
        for (final cookiePair in cookiePairs) {
          final parts = cookiePair.trim().split('=');
          if (parts.length == 2 && parts[0] == 'tenant_info') {
            final tenantInfo = parts[1];
            // Extract tenant name before the colon
            final colonIndex = tenantInfo.indexOf(':');
            if (colonIndex > 0) {
              return tenantInfo.substring(0, colonIndex);
            }
            // If no colon found, return the whole value
            return tenantInfo;
          }
        }
      } catch (e) {
        print('Error reading tenant_info cookie: $e');
      }
    }
    // Fallback to static prefix for mobile or if cookie not found
    return _defaultApiPrefix;
  }
  
  /// Get the tenant home ID from tenant_info cookie for web requests
  /// Cookie format: "tenant_name:tenant_id" (e.g., "demo:2")
  /// Returns the tenant_id part after the colon
  static int getTenantHomeIdFromCookie() {
    if (kIsWeb) {
      try {
        final cookies = html.document.cookie!;
        final cookiePairs = cookies.split(';');
        
        for (final cookiePair in cookiePairs) {
          final parts = cookiePair.trim().split('=');
          if (parts.length == 2 && parts[0] == 'tenant_info') {
            final tenantInfo = parts[1];
            // Extract tenant ID after the colon
            final colonIndex = tenantInfo.indexOf(':');
            if (colonIndex > 0 && colonIndex < tenantInfo.length - 1) {
              final homeIdStr = tenantInfo.substring(colonIndex + 1);
              return int.tryParse(homeIdStr) ?? _defaultHomeId;
            }
          }
        }
      } catch (e) {
        print('Error reading tenant_info cookie for home ID: $e');
      }
    }
    // Fallback to static home ID for mobile or if cookie not found
    return _defaultHomeId;
  }
}