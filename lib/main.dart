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
      // Use the new authentication check from AuthRepo
      final isAuthenticated = await AuthRepo.checkAuthenticationStatus();
      
      if (isAuthenticated) {
        // User is authenticated and has valid session data
        final storedUserId = await UserSessionService.getUserId();
        if (storedUserId != null) {
          final userProfile = await ApiUserService.getUserProfile(storedUserId);
          if (userProfile != null) {
            // Check and update Firebase FCM token if needed
            ApiUserService.checkAndUpdateFcmToken(storedUserId);
            
            // Check if profile data is complete
            if (userProfile.fullName.isEmpty) {
              // Profile exists but is incomplete - direct to profile setup
              return const NewProfilePage();
            } else {
              // User exists and profile is complete
              return const HomePage();
            }
          } else {
            // User profile was deleted from database
            await UserSessionService.clearSession();
            await FirebaseAuth.instance.signOut();
          }
        }
      }
      
      // Not authenticated or no valid session - clear session and show login
      await UserSessionService.clearSession();
      return const LoginPage();
    } catch (e) {
      print('Error checking user status: $e');
      // On error, clear session and show login
      await UserSessionService.clearSession();
      return const LoginPage();
    }
  }
}