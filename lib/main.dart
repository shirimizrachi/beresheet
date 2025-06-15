import 'package:beresheet_app/screen/app/homepage.dart';
import 'package:beresheet_app/screen/app/loginscreen.dart';
import 'package:beresheet_app/screen/app/users/new_profilepage.dart';
import 'package:beresheet_app/services/user_service.dart';
import 'package:beresheet_app/services/api_user_service.dart';
import 'package:beresheet_app/services/user_session_service.dart';
import 'package:beresheet_app/auth/auth_service.dart';
import 'package:beresheet_app/theme/app_theme.dart';
import 'package:beresheet_app/config/app_config.dart';
import 'package:beresheet_app/services/firebase_messaging_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // for kDebugMode
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'firebase_options.dart';

void setupFirebaseAuth() {
  if (kDebugMode) {
    FirebaseAuth.instance.setSettings(appVerificationDisabledForTesting: true);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // Setup Firebase Auth for debug mode
  setupFirebaseAuth();
  
  // Initialize Firebase Messaging
  await FirebaseMessagingService.initialize();

  // Initialize user session and setup Firebase Auth listener
  await UserSessionService.initializeSession();
  UserSessionService.setupFirebaseAuthListener();

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Beresheet',
      theme: AppTheme.theme,
      
      // Flutter's official internationalization setup
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppConfig.supportedLocales,
      locale: AppConfig.appLocale,
      
      // Locale resolution callback
      localeResolutionCallback: (locale, supportedLocales) {
        // Check if the current device locale is supported
        for (var supportedLocale in supportedLocales) {
          if (supportedLocale.languageCode == locale?.languageCode) {
            return supportedLocale;
          }
        }
        // If not supported, return the first supported locale (Hebrew)
        return supportedLocales.first;
      },
      
      builder: (context, child) {
        return Directionality(
          textDirection: AppConfig.textDirection,
          child: child ?? const SizedBox(),
        );
      },
      home: Scaffold(
        body: FutureBuilder(
          future: _getUserStatus(),
          builder: (context, AsyncSnapshot<Widget> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            return snapshot.data ?? const LoginPage();
          },
        ),
      ),
    );
  }

  // Function to determine which page to navigate to based on user status
  Future<Widget> _getUserStatus() async {
    try {
      // First check if we have a valid session in cache/storage
      final hasValidSession = await UserSessionService.hasValidSession();
      
      if (hasValidSession) {
        // Try to use cached session data first
        final storedUserId = await UserSessionService.getUserId();
        if (storedUserId != null) {
          try {
            // Try to fetch user profile with existing session
            final userProfile = await ApiUserService.getUserProfile(storedUserId);
            if (userProfile != null) {
              // Check and update Firebase FCM token if needed (non-blocking)
              ApiUserService.checkAndUpdateFcmToken(storedUserId).catchError((e) {
                print('Non-critical error updating FCM token: $e');
              });
              
              // Check if profile data is complete
              if (userProfile.fullName?.isEmpty ?? true) {
                // Profile exists but is incomplete - direct to profile setup
                return const NewProfilePage();
              } else {
                // User exists and profile is complete
                return const HomePage();
              }
            } else {
              // User profile not found - could be network issue or deleted user
              // Don't immediately clear session, let authentication check handle it
            }
          } catch (e) {
            if (UserSessionService.isNetworkError(e)) {
              print('Network error fetching user profile, using cached session: $e');
              // On network error, still allow user to continue with cached data
              return const HomePage();
            } else if (UserSessionService.isAuthenticationError(e)) {
              print('Authentication error, clearing session: $e');
              await UserSessionService.clearSession(reason: 'Authentication error');
              await FirebaseAuth.instance.signOut();
            } else {
              print('Unknown error fetching user profile: $e');
              // For unknown errors, don't immediately clear session
              return const HomePage();
            }
          }
        }
      }
      
      // Use the authentication check from AuthRepo as fallback
      final isAuthenticated = await AuthRepo.checkAuthenticationStatus();
      
      if (isAuthenticated) {
        // User is authenticated but session might be corrupted, try to rebuild
        final storedUserId = await UserSessionService.getUserId();
        if (storedUserId != null) {
          try {
            final userProfile = await ApiUserService.getUserProfile(storedUserId);
            if (userProfile != null) {
              // Rebuild session
              await UserSessionService.initializeSession(fetchFreshData: true);
              
              if (userProfile.fullName?.isEmpty ?? true) {
                return const NewProfilePage();
              } else {
                return const HomePage();
              }
            }
          } catch (e) {
            if (UserSessionService.isNetworkError(e)) {
              print('Network error during session rebuild, showing login: $e');
              // On network error during rebuild, show login but don't clear session
              return const LoginPage();
            }
          }
        }
        
        // Authentication exists but no user profile - clear session
        await UserSessionService.clearSession(reason: 'No user profile found');
        await FirebaseAuth.instance.signOut();
      }
      
      // Not authenticated or session rebuild failed - show login
      return const LoginPage();
    } catch (e) {
      print('Error checking user status: $e');
      
      // Enhanced error handling - don't always clear session
      if (UserSessionService.isNetworkError(e)) {
        print('Network error in _getUserStatus, trying to use cached session');
        // Try to use cached session on network errors
        final hasValidSession = await UserSessionService.hasValidSession();
        if (hasValidSession) {
          return const HomePage();
        }
      } else if (UserSessionService.isAuthenticationError(e)) {
        print('Authentication error in _getUserStatus, clearing session');
        await UserSessionService.clearSession(reason: 'Authentication error in _getUserStatus');
      }
      
      // Fallback to login page
      return const LoginPage();
    }
  }
}