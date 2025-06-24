import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:beresheet_app/screen/app/homepage.dart';
import 'package:beresheet_app/screen/app/loginscreen.dart';
import 'package:beresheet_app/screen/app/otpscreen.dart';
import 'package:beresheet_app/screen/app/users/new_profilepage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/api_user_service.dart';
import '../services/user_session_service.dart';
import '../config/app_config.dart';

class AuthRepo {
  static String verId = "";
  static final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static void verifyPhoneNumber(BuildContext context, String number) async {
    try {
      await _firebaseAuth.verifyPhoneNumber(
        phoneNumber: '+972$number',
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            await signInWithPhoneNumber(
                context, credential.verificationId!, credential.smsCode!);
          } catch (e) {
            print('Error in verification completed: $e');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Auto-verification failed: $e')),
            );
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          print('Verification failed: ${e.code} - ${e.message}');
          String errorMessage = 'Verification failed. ';
          if (e.code == 'invalid-phone-number') {
            errorMessage += 'The provided phone number is not valid.';
          } else if (e.code == 'too-many-requests') {
            errorMessage += 'Too many requests. Please try again later.';
          } else {
            errorMessage += e.message ?? 'Unknown error occurred.';
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage)),
          );
        },
        codeSent: (String verificationId, int? resendToken) {
          verId = verificationId;
          print("verficationId $verId");
          Navigator.push(context, MaterialPageRoute(builder: (ctx) {
            return OtpScreen(number: number);
          }));
          print("code sent");
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          print("Auto retrieval timeout for verification ID: $verificationId");
        },
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      print('Error signing in with phone number: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  // Logout functionality removed as requested
  // Users will need to delete the app to logout (which clears session data)

  static void submitOtp(BuildContext context, String otp) {
    signInWithPhoneNumber(context, verId, otp);
  }

  static Future<void> signInWithPhoneNumber(
      BuildContext context, String verificationId, String smsCode) async {
    try {
      final AuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      final UserCredential userCredential =
          await _firebaseAuth.signInWithCredential(credential);

      if (userCredential.user != null) {
        await _handleUserAuthentication(context, userCredential);
      } else {
        throw Exception('Authentication failed: User is null');
      }
    } catch (e) {
      print('Error signing in with phone number: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sign in failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Handle user authentication after Firebase OTP verification
  static Future<void> _handleUserAuthentication(BuildContext context, UserCredential userCredential) async {
    try {
      // Check if we have a valid session (for returning users)
      final hasValidSession = await UserSessionService.hasValidSession();
      
      if (hasValidSession) {
        final existingUserId = await UserSessionService.getUserId();
        final existingHomeId = await UserSessionService.gethomeID();
        
        if (existingUserId != null && existingHomeId != null) {
          try {
            // Returning user - verify they still exist in database
            final existingUser = await ApiUserService.getUserProfile(existingUserId);
            if (existingUser != null) {
              // User exists, redirect to home
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const HomePage())
              );
              return;
            } else {
              // User was deleted from database, clear session and treat as new user
              await UserSessionService.clearSession(reason: 'User deleted from database');
            }
          } catch (e) {
            if (UserSessionService.isNetworkError(e)) {
              print('Network error checking existing user, proceeding with session: $e');
              // On network error, trust existing session
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const HomePage())
              );
              return;
            } else if (UserSessionService.isAuthenticationError(e)) {
              print('Authentication error, clearing session: $e');
              await UserSessionService.clearSession(reason: 'Authentication error');
            } else {
              print('Unknown error checking existing user: $e');
              // For unknown errors, still try to proceed
            }
          }
        }
      }

      // First time or user not found - try to discover user's home and get profile
      final phoneNumber = userCredential.user!.phoneNumber;
      if (phoneNumber != null) {
        // Remove country code (+972) to get local number
        String localPhoneNumber = phoneNumber;
        if (phoneNumber.startsWith('+972')) {
          localPhoneNumber = phoneNumber.substring(4);
        }

        try {
          // First, try to get user's home information using the global endpoint
          final homeInfo = await ApiUserService.getUserHomeInfo(localPhoneNumber);
          
          if (homeInfo != null) {
            // Store home info in session for subsequent requests
            await UserSessionService.sethomeID(homeInfo['home_id']);
            await UserSessionService.setTenantName(homeInfo['home_name']);
            
            // Now try to get the user profile using the correct home ID
            final existingProfile = await ApiUserService.getUserProfileByPhone(localPhoneNumber, homeInfo['home_id']);
            
            if (existingProfile != null) {
              // Profile found, user session is already set by ApiUserService.getUserProfileByPhone
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const HomePage())
              );
            } else {
              // User's home was found but profile doesn't exist in that home's database
              // This shouldn't happen if home_index is properly maintained
              await _firebaseAuth.signOut();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Profile inconsistency detected. Please contact the administrator.'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 5),
                ),
              );
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
                (route) => false,
              );
            }
          } else {
            // No home found for this phone number - user doesn't exist in any home
            await _firebaseAuth.signOut();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Your profile was not found in the system. Please contact the administrator to create your profile first.'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 5),
              ),
            );
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const LoginPage()),
              (route) => false,
            );
          }
        } catch (e) {
          if (UserSessionService.isNetworkError(e)) {
            print('Network error during phone lookup: $e');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Network error. Please check your connection and try again.'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 5),
              ),
            );
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const LoginPage()),
              (route) => false,
            );
          } else {
            // Other errors, show generic message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error during authentication: $e'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const LoginPage()),
              (route) => false,
            );
          }
        }
      } else {
        // No phone number available (shouldn't happen with phone auth)
        await _firebaseAuth.signOut();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Phone number not available. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    } catch (e) {
      print('Error handling user authentication: $e');
      
      // Enhanced error handling
      if (UserSessionService.isNetworkError(e)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Network error during authentication. Please try again.'),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      } else {
        // On other errors, navigate to profile page to be safe
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) {
            return NewProfilePage(userCredential: userCredential);
          })
        );
      }
    }
  }

  /// Check authentication status on app start
  static Future<bool> checkAuthenticationStatus() async {
    try {
      final currentUser = _firebaseAuth.currentUser;
      if (currentUser == null) {
        return false; // Not authenticated with Firebase
      }

      // Check if we have a valid session
      final hasValidSession = await UserSessionService.hasValidSession();
      if (!hasValidSession) {
        return false; // No session data
      }

      // Get session data
      final existingUserId = await UserSessionService.getUserId();
      final existingHomeId = await UserSessionService.gethomeID();
      
      if (existingUserId != null && existingHomeId != null) {
        try {
          // Verify user still exists in database
          final existingUser = await ApiUserService.getUserProfile(existingUserId);
          return existingUser != null;
        } catch (e) {
          if (UserSessionService.isNetworkError(e)) {
            print('Network error checking authentication, assuming valid: $e');
            // On network errors, trust the local session
            return true;
          } else if (UserSessionService.isAuthenticationError(e)) {
            print('Authentication error in checkAuthenticationStatus: $e');
            // Clear session on auth errors
            await UserSessionService.clearSession(reason: 'Auth error in checkAuthenticationStatus');
            return false;
          } else {
            print('Unknown error checking authentication status: $e');
            // For unknown errors, trust local session temporarily
            return true;
          }
        }
      }
      
      return false; // No user session data
    } catch (e) {
      print('Error checking authentication status: $e');
      
      // Enhanced error handling
      if (UserSessionService.isNetworkError(e)) {
        // On network errors, check if we have local session data
        final hasValidSession = await UserSessionService.hasValidSession();
        return hasValidSession;
      }
      
      return false;
    }
  }
}
