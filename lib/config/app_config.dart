import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

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
  
  /// Get the API base URL based on platform
  static String get apiBaseUrl {
    if (kIsWeb) {
      return 'http://localhost:8000';    // Web can use localhost
    } else {
      return 'http://10.0.2.2:8000';    // Android emulator uses 10.0.2.2
    }
  }

  /// Get the API base URL (alias for compatibility)
  static String get baseUrl => apiBaseUrl;
  
  /// Get the web homepage URL
  static String get webHomepageUrl => '$apiBaseUrl/web';
  
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
  static const String eventTypeClass = 'class';
  static const String eventTypePerformance = 'performance';
  static const String eventTypeCultural = 'cultural';
  static const String eventTypeLeisure = 'leisure';
  static const String eventTypeWorkshop = 'workshop';
  static const String eventTypeMeeting = 'meeting';
  static const String eventTypeSport = 'sport';
  static const String eventTypeHealth = 'health';
  
  /// Available event types
  static const List<String> eventTypes = [
    eventTypeClass,
    eventTypePerformance,
    eventTypeCultural,
    eventTypeLeisure,
    eventTypeWorkshop,
    eventTypeMeeting,
    eventTypeSport,
    eventTypeHealth
  ];
  
  /// Event Status Constants
  static const String eventStatusPendingApproval = 'pending-approval';
  static const String eventStatusApproved = 'approved';
  static const String eventStatusRejected = 'rejected';
  static const String eventStatusCancelled = 'cancelled';
  
  /// Available event status options
  static const List<String> eventStatusOptions = [
    eventStatusPendingApproval,
    eventStatusApproved,
    eventStatusRejected,
    eventStatusCancelled
  ];
  
  /// Event Recurring Constants
  static const String eventRecurringNone = 'none';
  static const String eventRecurringDaily = 'daily';
  static const String eventRecurringWeekly = 'weekly';
  static const String eventRecurringMonthly = 'monthly';
  
  /// Available recurring options for events
  static const List<String> eventRecurringOptions = [
    eventRecurringNone,
    eventRecurringDaily,
    eventRecurringWeekly,
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
  

  /// Unsplash API configuration
  /// Replace this with your actual Unsplash API access key
  static const String unsplashAccessKey = 'l4TUVw_DzVoNebjqDrd8x0-dED46kFfQkxuF3-KRQ2k';
  
  /// Get the Unsplash API access key
  static String get unsplashKey => unsplashAccessKey;
}