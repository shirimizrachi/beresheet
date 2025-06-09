import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:beresheet_app/config/app_config.dart';

/// Service for managing localization strings
class LocalizationService {
  static Map<String, dynamic>? _localizedStrings;
  static String _currentLanguage = AppConfig.defaultLanguage;

  /// Initialize the localization service
  static Future<void> initialize() async {
    await loadLanguage(_currentLanguage);
  }

  /// Load language strings from assets
  static Future<void> loadLanguage(String languageCode) async {
    try {
      final String jsonString = await rootBundle.loadString('assets/strings/$languageCode.json');
      final Map<String, dynamic> jsonMap = json.decode(jsonString);
      _localizedStrings = jsonMap;
      _currentLanguage = languageCode;
      print('Loaded language: $languageCode');
    } catch (e) {
      print('Error loading language $languageCode: $e');
      // Fallback to default language if loading fails
      if (languageCode != AppConfig.fallbackLanguage) {
        await loadLanguage(AppConfig.fallbackLanguage);
      }
    }
  }

  /// Get localized string by key
  static String getString(String key, {String? fallback}) {
    if (_localizedStrings == null) {
      return fallback ?? key;
    }

    // Split the key by dots to access nested objects
    List<String> keys = key.split('.');
    dynamic current = _localizedStrings;

    for (String k in keys) {
      if (current is Map<String, dynamic> && current.containsKey(k)) {
        current = current[k];
      } else {
        // Key not found, return fallback or key itself
        return fallback ?? key;
      }
    }

    return current?.toString() ?? fallback ?? key;
  }

  /// Get current language code
  static String get currentLanguage => _currentLanguage;

  /// Check if current language is Hebrew
  static bool get isHebrew => _currentLanguage == 'he';

  /// Check if current language is English
  static bool get isEnglish => _currentLanguage == 'en';

  /// Change language
  static Future<void> changeLanguage(String languageCode) async {
    await loadLanguage(languageCode);
  }

  /// Get available languages
  static List<String> get availableLanguages => AppConfig.supportedLanguages;

  /// Get language display name
  static String getLanguageDisplayName(String languageCode) {
    switch (languageCode) {
      case 'he':
        return 'עברית';
      case 'en':
        return 'English';
      default:
        return languageCode;
    }
  }
}

/// Extension to make string access easier
extension LocalizedString on String {
  /// Get localized string using this string as key
  String get tr => LocalizationService.getString(this);
  
  /// Get localized string with fallback
  String trOr(String fallback) => LocalizationService.getString(this, fallback: fallback);
}

/// Common text strings shortcuts
class AppStrings {
  // App info
  static String get appTitle => 'app_title'.tr;
  static String get appName => 'app_name'.tr;
  static String get communitySubtitle => 'community_subtitle'.tr;

  // Navigation
  static String get profile => 'navigation.profile'.tr;
  static String get myRegisteredEvents => 'navigation.my_registered_events'.tr;
  static String get manageEvents => 'navigation.manage_events'.tr;
  static String get logOut => 'navigation.log_out'.tr;
  static String get back => 'navigation.back'.tr;
  static String get home => 'navigation.home'.tr;

  // Auth
  static String get login => 'auth.login'.tr;
  static String get logout => 'auth.logout'.tr;
  static String get register => 'auth.register'.tr;
  static String get email => 'auth.email'.tr;
  static String get password => 'auth.password'.tr;
  static String get forgotPassword => 'auth.forgot_password'.tr;
  static String get createAccount => 'auth.create_account'.tr;
  static String get alreadyHaveAccount => 'auth.already_have_account'.tr;
  static String get dontHaveAccount => 'auth.dont_have_account'.tr;

  // Profile
  static String get fullName => 'profile.full_name'.tr;
  static String get phone => 'profile.phone'.tr;
  static String get apartmentNumber => 'profile.apartment_number'.tr;
  static String get editProfile => 'profile.edit_profile'.tr;
  static String get personalInformation => 'profile.personal_information'.tr;
  static String get contactInformation => 'profile.contact_information'.tr;

  // Events
  static String get events => 'events.events'.tr;
  static String get event => 'events.event'.tr;
  static String get eventDetails => 'events.event_details'.tr;
  static String get upcomingEvents => 'events.upcoming_events'.tr;
  static String get registeredEvents => 'events.registered_events'.tr;
  static String get myEvents => 'events.my_events'.tr;
  static String get noEventsFound => 'events.no_events_found'.tr;
  static String get registerEvent => 'events.register'.tr;
  static String get unregister => 'events.unregister'.tr;
  static String get registered => 'events.registered'.tr;
  static String get eventFull => 'events.event_full'.tr;
  static String get availableSpots => 'events.available_spots'.tr;
  static String get participants => 'events.participants'.tr;
  static String get location => 'events.location'.tr;
  static String get dateTime => 'events.date_time'.tr;
  static String get description => 'events.description'.tr;
  static String get eventName => 'events.event_name'.tr;
  static String get eventType => 'events.event_type'.tr;
  static String get createEvent => 'events.create_event'.tr;
  static String get editEvent => 'events.edit_event'.tr;
  static String get deleteEvent => 'events.delete_event'.tr;
  static String get maxParticipants => 'events.max_participants'.tr;
  static String get currentParticipants => 'events.current_participants'.tr;
  static String get imageUrl => 'events.image_url'.tr;
  static String get unregisterFromEvent => 'events.unregister_from_event'.tr;
  static String get registerForEvent => 'events.register_for_event'.tr;
  static String get eventCreated => 'events.event_created'.tr;
  static String get eventUpdated => 'events.event_updated'.tr;
  static String get eventDeleted => 'events.event_deleted'.tr;
  static String get registrationSuccessful => 'events.registration_successful'.tr;
  static String get unregistrationSuccessful => 'events.unregistration_successful'.tr;
  static String get viewDetails => 'events.view_details'.tr;
  static String get retry => 'events.retry'.tr;

  // Event Types
  static String getEventType(String type) => 'event_types.$type'.tr;

  // Common
  static String get yes => 'common.yes'.tr;
  static String get no => 'common.no'.tr;
  static String get ok => 'common.ok'.tr;
  static String get cancel => 'common.cancel'.tr;
  static String get save => 'common.save'.tr;
  static String get edit => 'common.edit'.tr;
  static String get delete => 'common.delete'.tr;
  static String get add => 'common.add'.tr;
  static String get loading => 'common.loading'.tr;
  static String get error => 'common.error'.tr;
  static String get success => 'common.success'.tr;
  static String get warning => 'common.warning'.tr;
  static String get refresh => 'common.refresh'.tr;
  static String get tryAgain => 'common.try_again'.tr;
  static String get required => 'common.required'.tr;
  static String get optional => 'common.optional'.tr;

  // Messages
  static String get welcome => 'messages.welcome'.tr;
  static String get somethingWentWrong => 'messages.something_went_wrong'.tr;
  static String get pleaseWait => 'messages.please_wait'.tr;
  static String get operationSuccessful => 'messages.operation_successful'.tr;
  static String get operationFailed => 'messages.operation_failed'.tr;
  static String get areYouSure => 'messages.are_you_sure'.tr;
  static String get confirmDelete => 'messages.confirm_delete'.tr;
  static String get fieldRequired => 'messages.field_required'.tr;
  
  // Profile
  static String get profileInformation => 'profile_screen.profile_information'.tr;
  static String get favoriteActivities => 'profile_screen.favorite_activities'.tr;
  static String get createProfile => 'profile_screen.create_profile'.tr;
  static String get updateProfile => 'profile_screen.update_profile'.tr;
}