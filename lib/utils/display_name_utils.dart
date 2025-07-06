import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../config/app_config.dart';

/// Utility class for getting localized display names for various enums and constants
class DisplayNameUtils {
  
  /// Get localized formatted date
  static String getLocalizedFormattedDate(DateTime dateTime, BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    
    final months = [
      localizations.january,
      localizations.february,
      localizations.march,
      localizations.april,
      localizations.may,
      localizations.june,
      localizations.july,
      localizations.august,
      localizations.september,
      localizations.october,
      localizations.november,
      localizations.december,
    ];
    
    return "${dateTime.day} ${months[dateTime.month - 1]} ${dateTime.year}";
  }
  
  /// Get display name for user role using localization
  static String getUserRoleDisplayName(String role, BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    switch (role) {
      case AppConfig.userRoleManager:
        return localizations.userRoleManager;
      case AppConfig.userRoleStaff:
        return localizations.userRoleStaff;
      case AppConfig.userRoleInstructor:
        return localizations.userRoleInstructor;
      case AppConfig.userRoleResident:
        return localizations.userRoleResident;
      case AppConfig.userRoleCaregiver:
        return localizations.userRoleCaregiver;
      case AppConfig.userRoleService:
        return localizations.userRoleService;
      default:
        return role.toUpperCase();
    }
  }
  
  /// Format role display name (alias for getUserRoleDisplayName)
  static String formatRoleDisplayName(String role, BuildContext context) {
    return getUserRoleDisplayName(role, context);
  }
  
  /// Get display name for event type using localization
  static String getEventTypeDisplayName(String type, BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    switch (type) {
      case AppConfig.eventTypeEvent:
        return localizations.eventTypeEvent;
      case AppConfig.eventTypeSport:
        return localizations.eventTypeSport;
      case AppConfig.eventTypeCultural:
        return localizations.eventTypeCultural;
      case AppConfig.eventTypeArt:
        return localizations.eventTypeArt;
      case AppConfig.eventTypeEnglish:
        return localizations.eventTypeEnglish;
      case AppConfig.eventTypeReligion:
        return localizations.eventTypeReligion;
      default:
        return type;
    }
  }
  
  /// Get display name for event status using localization
  static String getEventStatusDisplayName(String status, BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    switch (status) {
      case AppConfig.eventStatusPendingApproval:
        return localizations.eventStatusPendingApproval;
      case AppConfig.eventStatusApproved:
        return localizations.eventStatusApproved;
      case AppConfig.eventStatusRejected:
        return localizations.eventStatusRejected;
      case AppConfig.eventStatusCancelled:
        return localizations.eventStatusCancelled;
      case AppConfig.eventStatusDone:
        return localizations.eventStatusDone;
      default:
        return status;
    }
  }
  
  /// Get display name for recurring option using localization
  static String getRecurringDisplayName(String recurring, BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    switch (recurring) {
      case AppConfig.eventRecurringNone:
        return localizations.eventRecurringNone;
      case AppConfig.eventRecurringDaily:
        return localizations.eventRecurringDaily;
      case AppConfig.eventRecurringWeekly:
        return localizations.eventRecurringWeekly;
      case AppConfig.eventRecurringBiWeekly:
        return localizations.eventRecurringBiWeekly;
      case AppConfig.eventRecurringMonthly:
        return localizations.eventRecurringMonthly;
      default:
        return recurring;
    }
  }
  
  /// Get display name for gender using localization
  static String getGenderDisplayName(String gender, BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    switch (gender.toLowerCase()) {
      case 'male':
        return localizations.genderMale;
      case 'female':
        return localizations.genderFemale;
      default:
        return gender;
    }
  }
  
  /// Get display name for notification status using localization
  static String getNotificationStatusDisplayName(String status, BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    switch (status) {
      case AppConfig.notificationStatusPendingApproval:
        return localizations.pendingApproval;
      case AppConfig.notificationStatusApproved:
        return localizations.approved;
      case AppConfig.notificationStatusCanceled:
        return localizations.canceled;
      case AppConfig.notificationStatusSent:
        return localizations.sent;
      default:
        return status;
    }
  }
  
  /// Available gender options
  static const List<String> genderOptions = ['male', 'female'];
  
  /// Available marital status options
  static const List<String> maritalStatusOptions = ['single', 'married', 'divorced', 'widowed'];
  
  /// Available religious options
  static const List<String> religiousOptions = ['secular', 'orthodox', 'traditional'];
  
  /// Available language options
  static const List<String> languageOptions = ['hebrew', 'english', 'arabic', 'russian', 'french', 'spanish'];
  
  /// Get display name for marital status using localization
  static String getMaritalStatusDisplayName(String status, BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    switch (status.toLowerCase()) {
      case 'single':
        return localizations.maritalStatusSingle;
      case 'married':
        return localizations.maritalStatusMarried;
      case 'divorced':
        return localizations.maritalStatusDivorced;
      case 'widowed':
        return localizations.maritalStatusWidowed;
      default:
        return status;
    }
  }
  
  /// Get display name for religious status using localization
  static String getReligiousDisplayName(String religious, BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    switch (religious.toLowerCase()) {
      case 'secular':
        return localizations.religiousSecular;
      case 'orthodox':
        return localizations.religiousOrthodox;
      case 'traditional':
        return localizations.religiousTraditional;
      default:
        return religious;
    }
  }
  
  /// Get display name for language using localization
  static String getLanguageDisplayName(String language, BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    switch (language.toLowerCase()) {
      case 'hebrew':
        return localizations.languageHebrew;
      case 'english':
        return localizations.languageEnglish;
      case 'arabic':
        return localizations.languageArabic;
      case 'russian':
        return localizations.languageRussian;
      case 'french':
        return localizations.languageFrench;
      case 'spanish':
        return localizations.languageSpanish;
      default:
        return language;
    }
  }
}
