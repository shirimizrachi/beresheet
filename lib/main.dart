import 'package:beresheet_app/screen/app/homepage.dart';
import 'package:beresheet_app/screen/app/loginscreen.dart';
import 'package:beresheet_app/screen/app/profilepage.dart';
import 'package:beresheet_app/services/user_service.dart';
import 'package:beresheet_app/services/localization_service.dart';
import 'package:beresheet_app/theme/app_theme.dart';
import 'package:beresheet_app/config/app_config.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // Initialize localization service
  await LocalizationService.initialize();

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: LocalizationService.getString('app_title', fallback: 'Beresheet'),
      theme: AppTheme.theme,
      locale: AppConfig.appLocale,
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
      return const LoginPage();
    } else {
      // Check if the user exists in the JSON users storage
      final userProfile = await UserService.getUserProfile(user.uid);
      if (userProfile == null) {
        // User is authenticated but not in JSON users storage - create basic profile and direct to profile setup
        await UserService.createBasicUserProfile(user);
        return const ProfilePage();
      } else {
        // Check if profile is complete
        final isComplete = userProfile['isComplete'] ?? false;
        if (!isComplete || userProfile['fullName']?.isEmpty == true) {
          // Profile exists but is incomplete - direct to profile setup
          return const ProfilePage();
        } else {
          // User exists and profile is complete
          return const HomePage();
        }
      }
    }
  }
}