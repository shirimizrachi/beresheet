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
}
