import 'package:beresheet_app/screen/app/homepage.dart';
import 'package:beresheet_app/screen/app/loginscreen.dart';
import 'package:beresheet_app/screen/app/new_profilepage.dart';
import 'package:beresheet_app/services/user_service.dart';
import 'package:beresheet_app/services/api_user_service.dart';
import 'package:beresheet_app/services/user_session_service.dart';
import 'package:beresheet_app/theme/app_theme.dart';
import 'package:beresheet_app/config/app_config.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

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
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // Clear session if no user
      await UserSessionService.clearSession();
      return const LoginPage();
    } else {
      // Check if the user exists in the API
      final userProfile = await ApiUserService.getUserProfile(user.uid);
      if (userProfile == null) {
        // User is authenticated but profile doesn't exist - only allow updates in mobile app
        // Clear any existing session
        await UserSessionService.clearSession();
        return const NewProfilePage();
      } else {
        // Initialize session with user data
        await UserSessionService.setResidentId(userProfile.residentId);
        await UserSessionService.setRole(userProfile.role);
        await UserSessionService.setUserId(userProfile.userId);
        
        // Check if profile data is complete
        if (userProfile.fullName.isEmpty) {
          // Profile exists but is incomplete - direct to profile setup
          return const NewProfilePage();
        } else {
          // User exists and profile is complete
          return const HomePage();
        }
      }
    }
  }
}