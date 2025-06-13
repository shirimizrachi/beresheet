import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../config/app_config.dart';

/// Utility class for getting localized display names for various enums and constants
class DisplayNameUtils {
  
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
  
  /// Get display name for event type using localization
  static String getEventTypeDisplayName(String type, BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    switch (type) {
      case AppConfig.eventTypeClass:
        return localizations.eventTypeClass;
      case AppConfig.eventTypePerformance:
        return localizations.eventTypePerformance;
      case AppConfig.eventTypeCultural:
        return localizations.eventTypeCultural;
      case AppConfig.eventTypeLeisure:
        return localizations.eventTypeLeisure;
      case AppConfig.eventTypeWorkshop:
        return localizations.eventTypeWorkshop;
      case AppConfig.eventTypeMeeting:
        return localizations.eventTypeMeeting;
      case AppConfig.eventTypeSport:
        return localizations.eventTypeSport;
      case AppConfig.eventTypeHealth:
        return localizations.eventTypeHealth;
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
      case AppConfig.eventRecurringMonthly:
        return localizations.eventRecurringMonthly;
      default:
        return recurring;
    }
  }
}