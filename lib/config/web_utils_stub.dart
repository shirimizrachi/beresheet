/// Mobile/Desktop stub for WebUtils
/// This file provides the same interface as web_utils.dart but for non-web platforms
class WebUtils {
  /// Default API prefix for fallback
  static const String _defaultApiPrefix = 'beresheet';
  
  /// Default home ID for fallback
  static const int _defaultHomeId = 1;
  
  /// Get the API prefix from tenant_info cookie for web requests
  /// On mobile platforms, this always returns the default prefix
  static String getTenantPrefixFromCookie() {
    // On mobile platforms, always return the default prefix
    return _defaultApiPrefix;
  }
  
  /// Get the tenant home ID from tenant_info cookie for web requests
  /// On mobile platforms, this always returns the default home ID
  static int getTenantHomeIdFromCookie() {
    // On mobile platforms, always return the default home ID
    return _defaultHomeId;
  }
}