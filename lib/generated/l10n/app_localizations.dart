import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_he.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('he')
  ];

  /// The title of the application
  ///
  /// In en, this message translates to:
  /// **'Beresheet - Residential Community'**
  String get appTitle;

  /// The name of the application
  ///
  /// In en, this message translates to:
  /// **'Beresheet'**
  String get appName;

  /// Subtitle for the community
  ///
  /// In en, this message translates to:
  /// **'Residential Community'**
  String get communitySubtitle;

  /// Profile navigation
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// My registered events navigation
  ///
  /// In en, this message translates to:
  /// **'My Registered Events'**
  String get myRegisteredEvents;

  /// Manage events navigation
  ///
  /// In en, this message translates to:
  /// **'Manage Events'**
  String get manageEvents;

  /// Log out navigation
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get logOut;

  /// Back navigation
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// Home navigation
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// Login button
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// Logout button
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// Register button
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// Email field
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// Password field
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// Forgot password link
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// Create account button
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// Already have account text
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get alreadyHaveAccount;

  /// Don't have account text
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get dontHaveAccount;

  /// Full name field
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// Phone field
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// Apartment number field
  ///
  /// In en, this message translates to:
  /// **'Apartment Number'**
  String get apartmentNumber;

  /// Edit profile button
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// Personal information section
  ///
  /// In en, this message translates to:
  /// **'Personal Information'**
  String get personalInformation;

  /// Contact information section
  ///
  /// In en, this message translates to:
  /// **'Contact Information'**
  String get contactInformation;

  /// Birthday field
  ///
  /// In en, this message translates to:
  /// **'Birthday'**
  String get birthday;

  /// Age field
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get age;

  /// Role field
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get role;

  /// Marital status field
  ///
  /// In en, this message translates to:
  /// **'Marital Status'**
  String get maritalStatus;

  /// Gender field
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get gender;

  /// Religious field
  ///
  /// In en, this message translates to:
  /// **'Religious'**
  String get religious;

  /// Native language field
  ///
  /// In en, this message translates to:
  /// **'Native Language'**
  String get nativeLanguage;

  /// Profile photo field
  ///
  /// In en, this message translates to:
  /// **'Profile Photo'**
  String get profilePhoto;

  /// Tap to take photo instruction
  ///
  /// In en, this message translates to:
  /// **'Tap to take photo'**
  String get tapToTakePhoto;

  /// Select birthday instruction
  ///
  /// In en, this message translates to:
  /// **'Select Birthday'**
  String get selectBirthday;

  /// Please select birthday message
  ///
  /// In en, this message translates to:
  /// **'Please select your birthday'**
  String get pleaseSelectBirthday;

  /// Create profile button
  ///
  /// In en, this message translates to:
  /// **'Create Profile'**
  String get createProfile;

  /// Update profile button
  ///
  /// In en, this message translates to:
  /// **'Update Profile'**
  String get updateProfile;

  /// Profile created success message
  ///
  /// In en, this message translates to:
  /// **'Profile created successfully!'**
  String get profileCreatedSuccessfully;

  /// Profile updated success message
  ///
  /// In en, this message translates to:
  /// **'Profile updated successfully!'**
  String get profileUpdatedSuccessfully;

  /// Error saving profile message
  ///
  /// In en, this message translates to:
  /// **'Error saving profile'**
  String get errorSavingProfile;

  /// Please enter full name validation
  ///
  /// In en, this message translates to:
  /// **'Please enter your full name'**
  String get pleaseEnterFullName;

  /// Please enter phone number validation
  ///
  /// In en, this message translates to:
  /// **'Please enter your phone number'**
  String get pleaseEnterPhoneNumber;

  /// Please enter apartment number validation
  ///
  /// In en, this message translates to:
  /// **'Please enter your apartment number'**
  String get pleaseEnterApartmentNumber;

  /// Address field
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

  /// Please enter address validation
  ///
  /// In en, this message translates to:
  /// **'Please enter your address'**
  String get pleaseEnterAddress;

  /// Events label
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get events;

  /// Event label
  ///
  /// In en, this message translates to:
  /// **'Event'**
  String get event;

  /// Event details label
  ///
  /// In en, this message translates to:
  /// **'Event Details'**
  String get eventDetails;

  /// Upcoming events label
  ///
  /// In en, this message translates to:
  /// **'Upcoming Events'**
  String get upcomingEvents;

  /// Registered events label
  ///
  /// In en, this message translates to:
  /// **'Registered Events'**
  String get registeredEvents;

  /// My events label
  ///
  /// In en, this message translates to:
  /// **'My Events'**
  String get myEvents;

  /// No events found message
  ///
  /// In en, this message translates to:
  /// **'No events found'**
  String get noEventsFound;

  /// Register for event button
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get registerEvent;

  /// Unregister from event button
  ///
  /// In en, this message translates to:
  /// **'Unregister'**
  String get unregister;

  /// Registered status
  ///
  /// In en, this message translates to:
  /// **'Registered'**
  String get registered;

  /// Event full status
  ///
  /// In en, this message translates to:
  /// **'Event Full'**
  String get eventFull;

  /// Available spots label
  ///
  /// In en, this message translates to:
  /// **'Available Spots'**
  String get availableSpots;

  /// Participants label
  ///
  /// In en, this message translates to:
  /// **'Participants'**
  String get participants;

  /// Location label
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// Date and time label
  ///
  /// In en, this message translates to:
  /// **'Date & Time'**
  String get dateTime;

  /// Description label
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// Event name label
  ///
  /// In en, this message translates to:
  /// **'Event Name'**
  String get eventName;

  /// Event type label
  ///
  /// In en, this message translates to:
  /// **'Event Type'**
  String get eventType;

  /// Create event button
  ///
  /// In en, this message translates to:
  /// **'Create Event'**
  String get createEvent;

  /// Edit event button
  ///
  /// In en, this message translates to:
  /// **'Edit Event'**
  String get editEvent;

  /// Delete event button
  ///
  /// In en, this message translates to:
  /// **'Delete Event'**
  String get deleteEvent;

  /// Maximum participants label
  ///
  /// In en, this message translates to:
  /// **'Max Participants'**
  String get maxParticipants;

  /// Current participants label
  ///
  /// In en, this message translates to:
  /// **'Current Participants'**
  String get currentParticipants;

  /// Image URL label
  ///
  /// In en, this message translates to:
  /// **'Image URL'**
  String get imageUrl;

  /// Event created success message
  ///
  /// In en, this message translates to:
  /// **'Event created successfully'**
  String get eventCreated;

  /// Event updated success message
  ///
  /// In en, this message translates to:
  /// **'Event updated successfully'**
  String get eventUpdated;

  /// Event deleted success message
  ///
  /// In en, this message translates to:
  /// **'Event deleted successfully'**
  String get eventDeleted;

  /// Registration successful message
  ///
  /// In en, this message translates to:
  /// **'Registration successful'**
  String get registrationSuccessful;

  /// Unregistration successful message
  ///
  /// In en, this message translates to:
  /// **'Unregistration successful'**
  String get unregistrationSuccessful;

  /// View details button
  ///
  /// In en, this message translates to:
  /// **'View Details'**
  String get viewDetails;

  /// Retry button
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Class event type
  ///
  /// In en, this message translates to:
  /// **'Class'**
  String get eventTypeClass;

  /// Performance event type
  ///
  /// In en, this message translates to:
  /// **'Performance'**
  String get eventTypePerformance;

  /// Cultural event type
  ///
  /// In en, this message translates to:
  /// **'Cultural'**
  String get eventTypeCultural;

  /// Leisure event type
  ///
  /// In en, this message translates to:
  /// **'Leisure'**
  String get eventTypeLeisure;

  /// Workshop event type
  ///
  /// In en, this message translates to:
  /// **'Workshop'**
  String get eventTypeWorkshop;

  /// Meeting event type
  ///
  /// In en, this message translates to:
  /// **'Meeting'**
  String get eventTypeMeeting;

  /// Sport event type
  ///
  /// In en, this message translates to:
  /// **'Sport'**
  String get eventTypeSport;

  /// Health event type
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get eventTypeHealth;

  /// Yes button
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No button
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// OK button
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// Cancel button
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Save button
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Edit button
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// Delete button
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Add button
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// Loading message
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// Error message
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// Success message
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// Warning message
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get warning;

  /// Refresh button
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// Try again button
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get tryAgain;

  /// Required field indicator
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// Optional field indicator
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get optional;

  /// Welcome message
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get welcome;

  /// Something went wrong message
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get somethingWentWrong;

  /// Please wait message
  ///
  /// In en, this message translates to:
  /// **'Please wait'**
  String get pleaseWait;

  /// Operation successful message
  ///
  /// In en, this message translates to:
  /// **'Operation successful'**
  String get operationSuccessful;

  /// Operation failed message
  ///
  /// In en, this message translates to:
  /// **'Operation failed'**
  String get operationFailed;

  /// Are you sure confirmation
  ///
  /// In en, this message translates to:
  /// **'Are you sure?'**
  String get areYouSure;

  /// Confirm delete message
  ///
  /// In en, this message translates to:
  /// **'Confirm Delete'**
  String get confirmDelete;

  /// Field required validation
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get fieldRequired;

  /// Profile information label
  ///
  /// In en, this message translates to:
  /// **'Profile Information'**
  String get profileInformation;

  /// Favorite activities label
  ///
  /// In en, this message translates to:
  /// **'Favorite Activities'**
  String get favoriteActivities;

  /// Resident role
  ///
  /// In en, this message translates to:
  /// **'Resident'**
  String get roleResident;

  /// Staff role
  ///
  /// In en, this message translates to:
  /// **'Staff'**
  String get roleStaff;

  /// Instructor role
  ///
  /// In en, this message translates to:
  /// **'Instructor'**
  String get roleInstructor;

  /// Service provider role
  ///
  /// In en, this message translates to:
  /// **'Service Provider'**
  String get roleService;

  /// Caregiver role
  ///
  /// In en, this message translates to:
  /// **'Caregiver'**
  String get roleCaregiver;

  /// Single marital status
  ///
  /// In en, this message translates to:
  /// **'Single'**
  String get maritalStatusSingle;

  /// Married marital status
  ///
  /// In en, this message translates to:
  /// **'Married'**
  String get maritalStatusMarried;

  /// Divorced marital status
  ///
  /// In en, this message translates to:
  /// **'Divorced'**
  String get maritalStatusDivorced;

  /// Widowed marital status
  ///
  /// In en, this message translates to:
  /// **'Widowed'**
  String get maritalStatusWidowed;

  /// Male gender
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get genderMale;

  /// Female gender
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get genderFemale;

  /// Other gender
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get genderOther;

  /// Secular religious status
  ///
  /// In en, this message translates to:
  /// **'Secular'**
  String get religiousSecular;

  /// Orthodox religious status
  ///
  /// In en, this message translates to:
  /// **'Orthodox'**
  String get religiousOrthodox;

  /// Traditional religious status
  ///
  /// In en, this message translates to:
  /// **'Traditional'**
  String get religiousTraditional;

  /// Hebrew language
  ///
  /// In en, this message translates to:
  /// **'Hebrew'**
  String get languageHebrew;

  /// English language
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// Arabic language
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get languageArabic;

  /// Russian language
  ///
  /// In en, this message translates to:
  /// **'Russian'**
  String get languageRussian;

  /// French language
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get languageFrench;

  /// Spanish language
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get languageSpanish;

  /// No orders found message
  ///
  /// In en, this message translates to:
  /// **'No orders found'**
  String get noOrdersFound;

  /// No products found message
  ///
  /// In en, this message translates to:
  /// **'No products found'**
  String get noProductsFound;

  /// Add to cart button
  ///
  /// In en, this message translates to:
  /// **'Add to Cart'**
  String get addToCart;

  /// Back to orders button
  ///
  /// In en, this message translates to:
  /// **'Back to Orders'**
  String get backToOrders;

  /// No user logged in message
  ///
  /// In en, this message translates to:
  /// **'No user logged in'**
  String get noUserLoggedIn;

  /// Error loading order details
  ///
  /// In en, this message translates to:
  /// **'Error loading order details'**
  String get errorLoadingOrderDetails;

  /// No order found message
  ///
  /// In en, this message translates to:
  /// **'No order found'**
  String get noOrderFound;

  /// Error picking image message
  ///
  /// In en, this message translates to:
  /// **'Error picking image'**
  String get errorPickingImage;

  /// Unregister confirmation message
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to unregister from'**
  String get unregisterConfirmation;

  /// No registered events message
  ///
  /// In en, this message translates to:
  /// **'No registered events'**
  String get noRegisteredEvents;

  /// Register from home message
  ///
  /// In en, this message translates to:
  /// **'Register for events from the home page'**
  String get registerFromHome;

  /// Create first event instruction
  ///
  /// In en, this message translates to:
  /// **'Tap the + button to create your first event'**
  String get createFirstEvent;

  /// Failed to load events error
  ///
  /// In en, this message translates to:
  /// **'Failed to load events'**
  String get failedToLoadEvents;

  /// Failed to delete event error
  ///
  /// In en, this message translates to:
  /// **'Failed to delete event'**
  String get failedToDeleteEvent;

  /// Failed to unregister error
  ///
  /// In en, this message translates to:
  /// **'Failed to unregister'**
  String get failedToUnregister;

  /// Enter event name hint
  ///
  /// In en, this message translates to:
  /// **'Enter event name'**
  String get enterEventName;

  /// Please enter event name validation
  ///
  /// In en, this message translates to:
  /// **'Please enter event name'**
  String get pleaseEnterEventName;

  /// Enter event description hint
  ///
  /// In en, this message translates to:
  /// **'Enter event description'**
  String get enterEventDescription;

  /// Please enter event description validation
  ///
  /// In en, this message translates to:
  /// **'Please enter event description'**
  String get pleaseEnterEventDescription;

  /// Enter event location hint
  ///
  /// In en, this message translates to:
  /// **'Enter event location'**
  String get enterEventLocation;

  /// Please enter event location validation
  ///
  /// In en, this message translates to:
  /// **'Please enter event location'**
  String get pleaseEnterEventLocation;

  /// Enter maximum participants hint
  ///
  /// In en, this message translates to:
  /// **'Enter maximum participants'**
  String get enterMaximumParticipants;

  /// Please enter maximum participants validation
  ///
  /// In en, this message translates to:
  /// **'Please enter maximum participants'**
  String get pleaseEnterMaximumParticipants;

  /// Please enter valid positive number validation
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid positive number'**
  String get pleaseEnterValidPositiveNumber;

  /// Enter current participants hint
  ///
  /// In en, this message translates to:
  /// **'Enter current participants'**
  String get enterCurrentParticipants;

  /// Please enter current participants validation
  ///
  /// In en, this message translates to:
  /// **'Please enter current participants'**
  String get pleaseEnterCurrentParticipants;

  /// Please enter valid non-negative number validation
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid non-negative number'**
  String get pleaseEnterValidNonNegativeNumber;

  /// Current participants validation
  ///
  /// In en, this message translates to:
  /// **'Current participants cannot exceed maximum'**
  String get currentParticipantsCannotExceed;

  /// Enter image URL hint
  ///
  /// In en, this message translates to:
  /// **'Enter image URL'**
  String get enterImageUrl;

  /// Please enter image URL validation
  ///
  /// In en, this message translates to:
  /// **'Please enter image URL'**
  String get pleaseEnterImageUrl;

  /// Image preview label
  ///
  /// In en, this message translates to:
  /// **'Image Preview'**
  String get imagePreview;

  /// Invalid image URL message
  ///
  /// In en, this message translates to:
  /// **'Invalid image URL'**
  String get invalidImageUrl;

  /// Create event button text
  ///
  /// In en, this message translates to:
  /// **'CREATE EVENT'**
  String get createEventButton;

  /// Update event button text
  ///
  /// In en, this message translates to:
  /// **'UPDATE EVENT'**
  String get updateEventButton;

  /// Delete event confirmation message
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this event? This action cannot be undone.'**
  String get deleteEventConfirmation;

  /// Management panel label
  ///
  /// In en, this message translates to:
  /// **'Management Panel'**
  String get managementPanel;

  /// Welcome message to Beresheet community
  ///
  /// In en, this message translates to:
  /// **'Welcome to Beresheet Community'**
  String get welcomeToBeresheet;

  /// Discover events description
  ///
  /// In en, this message translates to:
  /// **'Discover amazing events and activities in our community'**
  String get discoverEvents;

  /// Featured events label
  ///
  /// In en, this message translates to:
  /// **'Featured Events'**
  String get featuredEvents;

  /// No events available message
  ///
  /// In en, this message translates to:
  /// **'No events available'**
  String get noEventsAvailable;

  /// Beresheet community name
  ///
  /// In en, this message translates to:
  /// **'Beresheet Community'**
  String get beresheetCommunity;

  /// Building stronger community slogan
  ///
  /// In en, this message translates to:
  /// **'Building a stronger community together'**
  String get buildingStrongerCommunity;

  /// Refresh events button
  ///
  /// In en, this message translates to:
  /// **'Refresh Events'**
  String get refreshEvents;

  /// Management panel title with community name
  ///
  /// In en, this message translates to:
  /// **'Management Panel - Beresheet Community'**
  String get managementPanelTitle;

  /// Manage all aspects description
  ///
  /// In en, this message translates to:
  /// **'Manage all aspects of the Beresheet community'**
  String get manageAllAspects;

  /// Management tools label
  ///
  /// In en, this message translates to:
  /// **'Management Tools'**
  String get managementTools;

  /// Events management label
  ///
  /// In en, this message translates to:
  /// **'Events Management'**
  String get eventsManagement;

  /// Create edit manage events description
  ///
  /// In en, this message translates to:
  /// **'Create, edit, and manage community events'**
  String get createEditManageEvents;

  /// Users management label
  ///
  /// In en, this message translates to:
  /// **'Users Management'**
  String get usersManagement;

  /// Manage members and permissions description
  ///
  /// In en, this message translates to:
  /// **'Manage community members and permissions'**
  String get manageMembersPermissions;

  /// Announcements label
  ///
  /// In en, this message translates to:
  /// **'Announcements'**
  String get announcements;

  /// Create and manage announcements description
  ///
  /// In en, this message translates to:
  /// **'Create and manage community announcements'**
  String get createManageAnnouncements;

  /// Facilities label
  ///
  /// In en, this message translates to:
  /// **'Facilities'**
  String get facilities;

  /// Manage facilities and bookings description
  ///
  /// In en, this message translates to:
  /// **'Manage community facilities and bookings'**
  String get manageFacilitiesBookings;

  /// Reports and analytics label
  ///
  /// In en, this message translates to:
  /// **'Reports & Analytics'**
  String get reportsAnalytics;

  /// View statistics and reports description
  ///
  /// In en, this message translates to:
  /// **'View community statistics and reports'**
  String get viewStatisticsReports;

  /// System settings label
  ///
  /// In en, this message translates to:
  /// **'System Settings'**
  String get systemSettings;

  /// Configure system settings description
  ///
  /// In en, this message translates to:
  /// **'Configure system settings and preferences'**
  String get configureSystemSettings;

  /// Soon label
  ///
  /// In en, this message translates to:
  /// **'Soon'**
  String get soon;

  /// Coming soon label
  ///
  /// In en, this message translates to:
  /// **'Coming Soon'**
  String get comingSoon;

  /// Feature under development message
  ///
  /// In en, this message translates to:
  /// **'is currently under development and will be available in a future update.'**
  String get featureUnderDevelopment;

  /// Create new user profile title
  ///
  /// In en, this message translates to:
  /// **'Create New User Profile'**
  String get createNewUserProfile;

  /// Create new user profile description
  ///
  /// In en, this message translates to:
  /// **'Enter the basic information to create a new user profile. Additional details can be updated later.'**
  String get createNewUserProfileDescription;

  /// Home field label
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeId;

  /// Home selection required validation
  ///
  /// In en, this message translates to:
  /// **'Home selection is required'**
  String get homeIdRequired;

  /// Please enter valid number validation
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid number'**
  String get pleaseEnterValidNumber;

  /// Select home hint
  ///
  /// In en, this message translates to:
  /// **'Select a home'**
  String get selectHome;

  /// Phone number field label
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumber;

  /// Phone number required validation
  ///
  /// In en, this message translates to:
  /// **'Phone number is required'**
  String get phoneNumberRequired;

  /// Please enter valid phone number validation
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid phone number'**
  String get pleaseEnterValidPhoneNumber;

  /// Enter phone number hint
  ///
  /// In en, this message translates to:
  /// **'Enter phone number'**
  String get enterPhoneNumber;

  /// Create user profile button
  ///
  /// In en, this message translates to:
  /// **'Create User Profile'**
  String get createUserProfile;

  /// Creating status text
  ///
  /// In en, this message translates to:
  /// **'Creating...'**
  String get creating;

  /// Access denied dialog title
  ///
  /// In en, this message translates to:
  /// **'Access Denied'**
  String get accessDenied;

  /// Only managers can create users message
  ///
  /// In en, this message translates to:
  /// **'Only managers can create new user profiles.'**
  String get onlyManagersCanCreateUsers;

  /// User profile created successfully message
  ///
  /// In en, this message translates to:
  /// **'User profile created successfully!'**
  String get userProfileCreatedSuccessfully;

  /// User ID label
  ///
  /// In en, this message translates to:
  /// **'User ID'**
  String get userId;

  /// Failed to create user profile message
  ///
  /// In en, this message translates to:
  /// **'Failed to create user profile. Please try again.'**
  String get failedToCreateUserProfile;

  /// An error occurred message
  ///
  /// In en, this message translates to:
  /// **'An error occurred'**
  String get anErrorOccurred;

  /// Web management panel title
  ///
  /// In en, this message translates to:
  /// **'Management Panel'**
  String get webManagementPanel;

  /// Web homepage link
  ///
  /// In en, this message translates to:
  /// **'Homepage'**
  String get webHomepage;

  /// Web create event navigation
  ///
  /// In en, this message translates to:
  /// **'Create Event'**
  String get webCreateEvent;

  /// Web events list navigation
  ///
  /// In en, this message translates to:
  /// **'Events List'**
  String get webEventsList;

  /// Web event registrations navigation
  ///
  /// In en, this message translates to:
  /// **'Event Registrations'**
  String get webEventRegistrations;

  /// Web create user navigation
  ///
  /// In en, this message translates to:
  /// **'Create User'**
  String get webCreateUser;

  /// Web user list navigation
  ///
  /// In en, this message translates to:
  /// **'User List'**
  String get webUserList;

  /// Web rooms navigation
  ///
  /// In en, this message translates to:
  /// **'Rooms'**
  String get webRooms;

  /// Web events management title
  ///
  /// In en, this message translates to:
  /// **'Events Management'**
  String get webEventsManagement;

  /// Web filter label
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get webFilter;

  /// Web all filter option
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get webAll;

  /// Web approved filter option
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get webApproved;

  /// Web pending approval filter option
  ///
  /// In en, this message translates to:
  /// **'Pending Approval'**
  String get webPendingApproval;

  /// Web date label
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get webDate;

  /// Web type label
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get webType;

  /// Web status label
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get webStatus;

  /// Web update event button
  ///
  /// In en, this message translates to:
  /// **'Update Event'**
  String get webUpdateEvent;

  /// Web delete event button
  ///
  /// In en, this message translates to:
  /// **'Delete Event'**
  String get webDeleteEvent;

  /// Web clear form button
  ///
  /// In en, this message translates to:
  /// **'Clear Form'**
  String get webClearForm;

  /// Web confirm delete dialog title
  ///
  /// In en, this message translates to:
  /// **'Confirm Delete'**
  String get webConfirmDelete;

  /// Web final confirmation dialog title
  ///
  /// In en, this message translates to:
  /// **'Final Confirmation'**
  String get webFinalConfirmation;

  /// Web delete confirmation message
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete the event \"{eventName}\"?\n\nThis action cannot be undone.'**
  String webDeleteConfirmMessage(String eventName);

  /// Web final confirmation message
  ///
  /// In en, this message translates to:
  /// **'You approve removing the event from all users?\n\nThis will permanently delete all registrations and cannot be undone.'**
  String get webFinalConfirmMessage;

  /// Web yes remove from all users button
  ///
  /// In en, this message translates to:
  /// **'Yes, Remove from All Users'**
  String get webYesRemoveFromAllUsers;

  /// Web event form title
  ///
  /// In en, this message translates to:
  /// **'Event Form'**
  String get webEventForm;

  /// Web basic information section
  ///
  /// In en, this message translates to:
  /// **'Basic Information'**
  String get webBasicInformation;

  /// Web event image section
  ///
  /// In en, this message translates to:
  /// **'Event Image'**
  String get webEventImage;

  /// Web image source label
  ///
  /// In en, this message translates to:
  /// **'Image Source'**
  String get webImageSource;

  /// Web direct URL option
  ///
  /// In en, this message translates to:
  /// **'Direct URL'**
  String get webDirectUrl;

  /// Web Unsplash option
  ///
  /// In en, this message translates to:
  /// **'Unsplash'**
  String get webUnsplash;

  /// Web upload option
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get webUpload;

  /// Web enter image URL placeholder
  ///
  /// In en, this message translates to:
  /// **'Enter image URL'**
  String get webEnterImageUrl;

  /// Web search Unsplash placeholder
  ///
  /// In en, this message translates to:
  /// **'Search on Unsplash'**
  String get webSearchUnsplash;

  /// Web upload image button
  ///
  /// In en, this message translates to:
  /// **'Upload Image'**
  String get webUploadImage;

  /// Web participants settings section
  ///
  /// In en, this message translates to:
  /// **'Participants Settings'**
  String get webParticipantsSettings;

  /// Web recurring settings section
  ///
  /// In en, this message translates to:
  /// **'Recurring Settings'**
  String get webRecurringSettings;

  /// Web recurrence label
  ///
  /// In en, this message translates to:
  /// **'Recurrence'**
  String get webRecurrence;

  /// Web no recurrence option
  ///
  /// In en, this message translates to:
  /// **'No Recurrence'**
  String get webNoRecurrence;

  /// Web daily recurrence option
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get webDaily;

  /// Web weekly recurrence option
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get webWeekly;

  /// Web monthly recurrence option
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get webMonthly;

  /// Web yearly recurrence option
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get webYearly;

  /// Web custom pattern recurrence option
  ///
  /// In en, this message translates to:
  /// **'Custom Pattern'**
  String get webCustomPattern;

  /// Web recurring end date label
  ///
  /// In en, this message translates to:
  /// **'Recurring End Date'**
  String get webRecurringEndDate;

  /// Web select date button
  ///
  /// In en, this message translates to:
  /// **'Select Date'**
  String get webSelectDate;

  /// Web select time button
  ///
  /// In en, this message translates to:
  /// **'Select Time'**
  String get webSelectTime;

  /// Web select room placeholder
  ///
  /// In en, this message translates to:
  /// **'Select a room'**
  String get webSelectRoom;

  /// Web no rooms available message
  ///
  /// In en, this message translates to:
  /// **'No rooms available'**
  String get webNoRoomsAvailable;

  /// Web failed to load rooms message
  ///
  /// In en, this message translates to:
  /// **'Failed to load rooms'**
  String get webFailedToLoadRooms;

  /// Web event creation requires role message
  ///
  /// In en, this message translates to:
  /// **'Event creation requires manager, staff, or instructor role.'**
  String get webEventCreationRequiresRole;

  /// Web access denied title
  ///
  /// In en, this message translates to:
  /// **'Access Denied'**
  String get webAccessDenied;

  /// Web return to home button
  ///
  /// In en, this message translates to:
  /// **'Return to Home'**
  String get webReturnToHome;

  /// Event status: pending approval
  ///
  /// In en, this message translates to:
  /// **'Pending Approval'**
  String get eventStatusPendingApproval;

  /// Event status: approved
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get eventStatusApproved;

  /// Event status: rejected
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get eventStatusRejected;

  /// Event status: cancelled
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get eventStatusCancelled;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'he'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'he': return AppLocalizationsHe();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
