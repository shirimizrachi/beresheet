import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:beresheet_app/config/app_config.dart';

/// Modern localization service that works with Flutter's official i18n
class ModernLocalizationService {
  static AppLocalizations? _localizations;
  
  /// Initialize the service with a context
  static void initialize(BuildContext context) {
    _localizations = AppLocalizations.of(context);
  }
  
  /// Get the current localizations
  static AppLocalizations get current {
    if (_localizations == null) {
      throw Exception('ModernLocalizationService not initialized. Call initialize(context) first.');
    }
    return _localizations!;
  }
  
  /// Check if current language is Hebrew (default is Hebrew)
  static bool get isHebrew => AppConfig.defaultLanguage == 'he';
  
  /// Check if current language is English
  static bool get isEnglish => AppConfig.defaultLanguage == 'en';
  
  /// Get current language code (always Hebrew by default)
  static String get currentLanguage => AppConfig.defaultLanguage;
  
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

/// Extension to make accessing localizations easier
extension BuildContextLocalization on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}

/// Modern strings class that uses the generated localizations
class ModernAppStrings {
  final AppLocalizations _l10n;
  
  ModernAppStrings(this._l10n);
  
  // Factory constructor to create from context
  factory ModernAppStrings.of(BuildContext context) {
    return ModernAppStrings(AppLocalizations.of(context)!);
  }
  
  // App info
  String get appTitle => _l10n.appTitle;
  String get appName => _l10n.appName;
  String get communitySubtitle => _l10n.communitySubtitle;
  String get homePageTitle => _l10n.appTitle; // Use appTitle as fallback

  // Navigation
  String get profile => _l10n.profile;
  String get myRegisteredEvents => _l10n.myRegisteredEvents;
  String get manageEvents => _l10n.manageEvents;
  String get logOut => _l10n.logOut;
  String get back => _l10n.back;
  String get home => _l10n.home;

  // Auth
  String get login => _l10n.login;
  String get logout => _l10n.logout;
  String get register => _l10n.register;
  String get email => _l10n.email;
  String get password => _l10n.password;
  String get forgotPassword => _l10n.forgotPassword;
  String get createAccount => _l10n.createAccount;
  String get alreadyHaveAccount => _l10n.alreadyHaveAccount;
  String get dontHaveAccount => _l10n.dontHaveAccount;

  // Profile
  String get fullName => _l10n.fullName;
  String get phone => _l10n.phone;
  String get apartmentNumber => _l10n.apartmentNumber;
  String get editProfile => _l10n.editProfile;
  String get personalInformation => _l10n.personalInformation;
  String get contactInformation => _l10n.contactInformation;
  String get birthday => _l10n.birthday;
  String get age => _l10n.age;
  String get role => _l10n.role;
  String get maritalStatus => _l10n.maritalStatus;
  String get gender => _l10n.gender;
  String get religious => _l10n.religious;
  String get nativeLanguage => _l10n.nativeLanguage;
  String get profilePhoto => _l10n.profilePhoto;
  String get tapToSelectFromGallery => _l10n.tapToSelectFromGallery;
  String get pressHereToTakePhoto => _l10n.pressHereToTakePhoto;
  String get errorTakingPhoto => _l10n.errorTakingPhoto;
  String get selectBirthday => _l10n.selectBirthday;
  String get pleaseSelectBirthday => _l10n.pleaseSelectBirthday;
  String get createProfile => _l10n.createProfile;
  String get updateProfile => _l10n.updateProfile;
  String get profileCreatedSuccessfully => _l10n.profileCreatedSuccessfully;
  String get profileUpdatedSuccessfully => _l10n.profileUpdatedSuccessfully;
  String get errorSavingProfile => _l10n.errorSavingProfile;
  String get pleaseEnterFullName => _l10n.pleaseEnterFullName;
  String get pleaseEnterPhoneNumber => _l10n.pleaseEnterPhoneNumber;
  String get pleaseEnterApartmentNumber => _l10n.pleaseEnterApartmentNumber;

  // Events
  String get events => _l10n.events;
  String get event => _l10n.event;
  String get eventDetails => _l10n.eventDetails;
  String get upcomingEvents => _l10n.upcomingEvents;
  String get registeredEvents => _l10n.registeredEvents;
  String get myEvents => _l10n.myEvents;
  String get noEventsFound => _l10n.noEventsFound;
  String get registerEvent => _l10n.registerEvent;
  String get unregister => _l10n.unregister;
  String get registered => _l10n.registered;
  String get eventFull => _l10n.eventFull;
  String get availableSpots => _l10n.availableSpots;
  String get participants => _l10n.participants;
  String get location => _l10n.location;
  String get dateTime => _l10n.dateTime;
  String get description => _l10n.description;
  String get eventName => _l10n.eventName;
  String get eventType => _l10n.eventType;
  String get createEvent => _l10n.createEvent;
  String get editEvent => _l10n.editEvent;
  String get deleteEvent => _l10n.deleteEvent;
  String get maxParticipants => _l10n.maxParticipants;
  String get currentParticipants => _l10n.currentParticipants;
  String get imageUrl => _l10n.imageUrl;
  String get eventCreated => _l10n.eventCreated;
  String get eventUpdated => _l10n.eventUpdated;
  String get eventDeleted => _l10n.eventDeleted;
  String get registrationSuccessful => _l10n.registrationSuccessful;
  String get unregistrationSuccessful => _l10n.unregistrationSuccessful;
  String get viewDetails => _l10n.viewDetails;
  String get retry => _l10n.retry;

  // Event Types
  String get eventTypeCultural => _l10n.eventTypeCultural;
  String get eventTypeSport => _l10n.eventTypeSport;

  // Common
  String get yes => _l10n.yes;
  String get no => _l10n.no;
  String get ok => _l10n.ok;
  String get cancel => _l10n.cancel;
  String get save => _l10n.save;
  String get edit => _l10n.edit;
  String get delete => _l10n.delete;
  String get add => _l10n.add;
  String get loading => _l10n.loading;
  String get error => _l10n.error;
  String get success => _l10n.success;
  String get warning => _l10n.warning;
  String get refresh => _l10n.refresh;
  String get tryAgain => _l10n.tryAgain;
  String get required => _l10n.required;
  String get optional => _l10n.optional;

  // Messages
  String get welcome => _l10n.welcome;
  String get somethingWentWrong => _l10n.somethingWentWrong;
  String get pleaseWait => _l10n.pleaseWait;
  String get operationSuccessful => _l10n.operationSuccessful;
  String get operationFailed => _l10n.operationFailed;
  String get areYouSure => _l10n.areYouSure;
  String get confirmDelete => _l10n.confirmDelete;
  String get fieldRequired => _l10n.fieldRequired;
  
  // Profile screen
  String get profileInformation => _l10n.profileInformation;
  String get favoriteActivities => _l10n.favoriteActivities;

  // Roles
  String get roleResident => _l10n.roleResident;
  String get roleStaff => _l10n.roleStaff;
  String get roleInstructor => _l10n.roleInstructor;
  String get roleService => _l10n.roleService;
  String get roleCaregiver => _l10n.roleCaregiver;

  // Marital Status
  String get maritalStatusSingle => _l10n.maritalStatusSingle;
  String get maritalStatusMarried => _l10n.maritalStatusMarried;
  String get maritalStatusDivorced => _l10n.maritalStatusDivorced;
  String get maritalStatusWidowed => _l10n.maritalStatusWidowed;

  // Gender
  String get genderMale => _l10n.genderMale;
  String get genderFemale => _l10n.genderFemale;
  String get genderOther => _l10n.genderOther;

  // Religious
  String get religiousSecular => _l10n.religiousSecular;
  String get religiousOrthodox => _l10n.religiousOrthodox;
  String get religiousTraditional => _l10n.religiousTraditional;

  // Languages
  String get languageHebrew => _l10n.languageHebrew;
  String get languageEnglish => _l10n.languageEnglish;
  String get languageArabic => _l10n.languageArabic;
  String get languageRussian => _l10n.languageRussian;
  String get languageFrench => _l10n.languageFrench;
  String get languageSpanish => _l10n.languageSpanish;
  
  // Additional strings
  String get noOrdersFound => _l10n.noOrdersFound;
  String get noProductsFound => _l10n.noProductsFound;
  String get addToCart => _l10n.addToCart;
  String get backToOrders => _l10n.backToOrders;
  String get noUserLoggedIn => _l10n.noUserLoggedIn;
  String get errorLoadingOrderDetails => _l10n.errorLoadingOrderDetails;
  String get noOrderFound => _l10n.noOrderFound;
  String get errorPickingImage => _l10n.errorPickingImage;
  String get unregisterConfirmation => _l10n.unregisterConfirmation;
  String get noRegisteredEvents => _l10n.noRegisteredEvents;
  String get registerFromHome => _l10n.registerFromHome;
  String get createFirstEvent => _l10n.createFirstEvent;
  String get failedToLoadEvents => _l10n.failedToLoadEvents;
  String get failedToDeleteEvent => _l10n.failedToDeleteEvent;
  String get failedToUnregister => _l10n.failedToUnregister;
  String get enterEventName => _l10n.enterEventName;
  String get pleaseEnterEventName => _l10n.pleaseEnterEventName;
  String get enterEventDescription => _l10n.enterEventDescription;
  String get pleaseEnterEventDescription => _l10n.pleaseEnterEventDescription;
  String get enterEventLocation => _l10n.enterEventLocation;
  String get pleaseEnterEventLocation => _l10n.pleaseEnterEventLocation;
  String get enterMaximumParticipants => _l10n.enterMaximumParticipants;
  String get pleaseEnterMaximumParticipants => _l10n.pleaseEnterMaximumParticipants;
  String get pleaseEnterValidPositiveNumber => _l10n.pleaseEnterValidPositiveNumber;
  String get enterCurrentParticipants => _l10n.enterCurrentParticipants;
  String get pleaseEnterCurrentParticipants => _l10n.pleaseEnterCurrentParticipants;
  String get pleaseEnterValidNonNegativeNumber => _l10n.pleaseEnterValidNonNegativeNumber;
  String get currentParticipantsCannotExceed => _l10n.currentParticipantsCannotExceed;
  String get enterImageUrl => _l10n.enterImageUrl;
  String get pleaseEnterImageUrl => _l10n.pleaseEnterImageUrl;
  String get imagePreview => _l10n.imagePreview;
  String get invalidImageUrl => _l10n.invalidImageUrl;
  String get createEventButton => _l10n.createEventButton;
  String get updateEventButton => _l10n.updateEventButton;
  String get deleteEventConfirmation => _l10n.deleteEventConfirmation;
  
  // Create User Profile
  String get createNewUserProfile => _l10n.createNewUserProfile;
  String get createNewUserProfileDescription => _l10n.createNewUserProfileDescription;
  String get homeId => _l10n.homeId;
  String get homeIdRequired => _l10n.homeIdRequired;
  String get pleaseEnterValidNumber => _l10n.pleaseEnterValidNumber;
  String get selectHome => _l10n.selectHome;
  String get phoneNumber => _l10n.phoneNumber;
  String get phoneNumberRequired => _l10n.phoneNumberRequired;
  String get pleaseEnterValidPhoneNumber => _l10n.pleaseEnterValidPhoneNumber;
  String get enterPhoneNumber => _l10n.enterPhoneNumber;
  String get createUserProfile => _l10n.createUserProfile;
  String get creating => _l10n.creating;
  String get accessDenied => _l10n.accessDenied;
  String get onlyManagersCanCreateUsers => _l10n.onlyManagersCanCreateUsers;
  String get userProfileCreatedSuccessfully => _l10n.userProfileCreatedSuccessfully;
  String get userId => _l10n.userId;
  String get failedToCreateUserProfile => _l10n.failedToCreateUserProfile;
  String get anErrorOccurred => _l10n.anErrorOccurred;
}