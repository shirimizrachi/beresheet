import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'web_utils.dart' if (dart.library.io) 'web_utils_stub.dart';
import '../services/user_session_service.dart';

/// Application configuration constants
class AppConfig {
  /// Default language for the application - Hebrew
  static const String defaultLanguage = 'he';
  
  /// Fallback language if default fails to load - English
  static const String fallbackLanguage = 'en';
  
  /// List of supported languages
  static const List<String> supportedLanguages = ['he', 'en'];
  
  /// Default text direction - RTL for Hebrew-first app
  static const TextDirection textDirection = TextDirection.rtl;
  
  /// Check if the app is using RTL direction
  static bool get isRTL => textDirection == TextDirection.rtl;
  
  /// Check if the app is using LTR direction
  static bool get isLTR => textDirection == TextDirection.ltr;
  
  /// Get the text direction as a string
  static String get directionString => isRTL ? 'RTL' : 'LTR';
  
  /// Default locale - Hebrew (Israel)
  static const Locale appLocale = Locale('he', 'IL');
  
  /// English locale for fallback
  static const Locale englishLocale = Locale('en', 'US');
  
  /// Get supported locales
  static List<Locale> get supportedLocales => [
    appLocale,      // Hebrew first (default)
    englishLocale,  // English as fallback
  ];
  
  /// Get locale from language code
  static Locale getLocale(String languageCode) {
    switch (languageCode) {
      case 'he':
        return appLocale;
      case 'en':
        return englishLocale;
      default:
        return appLocale; // Default to Hebrew
    }
  }
  
  /// Get text direction from language code
  static TextDirection getTextDirection(String languageCode) {
    switch (languageCode) {
      case 'he':
        return TextDirection.rtl;
      case 'en':
        return TextDirection.ltr;
      default:
        return TextDirection.rtl; // Default to RTL
    }
  }
  
  /// Default home ID for user authentication
  /// This should be configured based on the specific deployment
  static const int defaultHomeId = 1;
  
  /// Get the default home ID
  static int get homeId => defaultHomeId;
  
  /// API base URL for backend services
  /// This should be configured based on the deployment environment
  ///
  /// For development:
  /// - Web: 'http://localhost:8000'
  /// - Android emulator: 'http://10.0.2.2:8000'
  /// For production: 'https://your-production-api.com'
  /// For staging: 'https://your-staging-api.com'
  
  /// API prefix for tenant routing
  /// This prefix will be prepended to all API calls
  /// Default value is 'beresheet' - can be configured per deployment
  static const String apiPrefix = 'beresheet';
  
  /// Cached tenant prefix from session (for performance)
  static String? _cachedTenantPrefix;
  
  /// Get the API prefix for mobile apps (static)
  static String get prefix => apiPrefix;
  
  
  /// Get the API base URL based on platform (without prefix)
  static String get apiBaseUrl {
    // Check for production build
    const String environment = String.fromEnvironment('ENVIRONMENT', defaultValue: 'development');
    
    if (environment == 'production') {
      // For production: use production domain for all platforms
      return 'https://www.residentsapp.com';
    }
    
    // Development/local configuration
    if (kIsWeb) {
      return 'http://localhost:8000';    // Web can use localhost
    } else {
      return 'http://10.0.2.2:8000';    // Android emulator uses 10.0.2.2
    }
  }

  
  /// Get the API prefix from user session for authenticated requests
  static Future<String> getApiPrefixFromSession() async {
    try {
      // Get tenant name from session storage
      final tenantName = await UserSessionService.getTenantName();
      return tenantName ?? apiPrefix; // Fallback to static prefix if no session
    } catch (e) {
      return apiPrefix; // Fallback to static prefix on error
    }
  }

  /// Get the full API URL with session-based prefix for authenticated calls
  static Future<String> getApiUrlWithSessionPrefix() async {
    final prefix = await getApiPrefixFromSession();
    return '$apiBaseUrl/$prefix';
  }
  
  /// Get the full API URL with prefix for API calls
  /// For web: uses tenant_info cookie, for mobile: uses cached tenant prefix
  /// This method constructs URLs like: http://localhost:8000/tenant_name/api/...
  static String get apiUrlWithPrefix {
    if (kIsWeb) {
      return '$apiBaseUrl/${WebUtils.getTenantPrefixFromCookie()}';
    } else {
      // Use cached tenant prefix for mobile, fallback to static prefix
      final tenantPrefix = _cachedTenantPrefix ?? apiPrefix;
      return '$apiBaseUrl/$tenantPrefix';
    }
  }
  
  /// Update the cached tenant prefix from session
  /// This should be called when user logs in or tenant changes
  static Future<void> updateTenantPrefixCache() async {
    try {
      _cachedTenantPrefix = await getApiPrefixFromSession();
    } catch (e) {
      print('Error updating tenant prefix cache: $e');
      _cachedTenantPrefix = apiPrefix; // Fallback to static prefix
    }
  }
  
  /// Clear the cached tenant prefix
  /// This should be called when user logs out
  static void clearTenantPrefixCache() {
    _cachedTenantPrefix = null;
  }
  
  /// Get the web homepage URL (uses cookie-based prefix for web)
  static String get webHomepageUrl {
    return '$apiBaseUrl/${WebUtils.getTenantPrefixFromCookie()}/web';
  }
  
  /// Environment-specific configuration
  /// You can also use this approach for different environments:
  ///
  /// static String get apiBaseUrl {
  ///   const String environment = String.fromEnvironment('ENVIRONMENT', defaultValue: 'development');
  ///   switch (environment) {
  ///     case 'production':
  ///       return 'https://your-production-api.com';
  ///     case 'staging':
  ///       return 'https://your-staging-api.com';
  ///     case 'development':
  ///     default:
  ///       return 'http://localhost:8000';
  ///   }
  /// }

  /// Event Configuration Constants
  /// These are shared across the app to ensure consistency
  
  /// Event Type Constants
  static const String eventTypeEvent = 'event';
  static const String eventTypeSport = 'sport';
  static const String eventTypeCultural = 'cultural';
  static const String eventTypeArt = 'art';
  static const String eventTypeEnglish = 'english';
  static const String eventTypeReligion = 'religion';
  
  /// Available event types
  static const List<String> eventTypes = [
    eventTypeEvent,
    eventTypeSport,
    eventTypeCultural,
    eventTypeArt,
    eventTypeEnglish,
    eventTypeReligion
  ];
  
  /// Event Status Constants
  static const String eventStatusPendingApproval = 'pending-approval';
  static const String eventStatusApproved = 'approved';
  static const String eventStatusRejected = 'rejected';
  static const String eventStatusCancelled = 'cancelled';
  static const String eventStatusDone = 'done';
  
  /// Available event status options (all statuses)
  static const List<String> eventStatusOptions = [
    eventStatusPendingApproval,
    eventStatusApproved,
    eventStatusRejected,
    eventStatusCancelled,
    eventStatusDone
  ];
  
  /// User-selectable event status options (excludes 'done' as it's internal only)
  static const List<String> userSelectableEventStatusOptions = [
    eventStatusPendingApproval,
    eventStatusApproved,
    eventStatusRejected,
    eventStatusCancelled
  ];
  
  /// Event Recurring Constants
  static const String eventRecurringNone = 'none';
  static const String eventRecurringDaily = 'daily';
  static const String eventRecurringWeekly = 'weekly';
  static const String eventRecurringBiWeekly = 'bi-weekly';
  static const String eventRecurringMonthly = 'monthly';
  
  /// Available recurring options for events
  static const List<String> eventRecurringOptions = [
    eventRecurringNone,
    eventRecurringWeekly,
    eventRecurringBiWeekly,
    eventRecurringMonthly,
  ];
  
  /// User Role Constants
  static const String userRoleManager = 'manager';
  static const String userRoleStaff = 'staff';
  static const String userRoleInstructor = 'instructor';
  static const String userRoleResident = 'resident';
  static const String userRoleCaregiver = 'caregiver';
  static const String userRoleService = 'service';
  
  /// Available user roles
  static const List<String> userRoles = [
    userRoleManager,
    userRoleStaff,
    userRoleInstructor,
    userRoleResident,
    userRoleCaregiver,
    userRoleService
  ];
  
  /// Notification Status Constants
  static const String notificationStatusPendingApproval = 'pending-approval';
  static const String notificationStatusApproved = 'approved';
  static const String notificationStatusCanceled = 'canceled';
  static const String notificationStatusSent = 'sent';
  
  /// Available notification status options
  static const List<String> notificationStatusOptions = [
    notificationStatusPendingApproval,
    notificationStatusApproved,
    notificationStatusCanceled,
    notificationStatusSent
  ];
  

  /// Unsplash API configuration
  /// Replace this with your actual Unsplash API access key
  static const String unsplashAccessKey = 'l4TUVw_DzVoNebjqDrd8x0-dED46kFfQkxuF3-KRQ2k';
  
  /// Get the Unsplash API access key
  static String get unsplashKey => unsplashAccessKey;
}
