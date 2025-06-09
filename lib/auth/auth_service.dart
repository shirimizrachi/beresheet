import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:beresheet_app/screen/app/homepage.dart';
import 'package:beresheet_app/screen/app/loginscreen.dart';
import 'package:beresheet_app/screen/app/otpscreen.dart';
import 'package:beresheet_app/screen/app/profilepage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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

  static void logoutApp(BuildContext context) async {
    await _firebaseAuth.signOut();
    // ignore: use_build_context_synchronously
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => const LoginPage(),
      ),
    );
  }

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
        // Check if the user already exists in Firestore
        DocumentSnapshot userSnapshot = await _firestore
            .collection('users')
            .doc(userCredential.user!.uid)
            .get();

        if (userSnapshot.exists) {
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (context) => const HomePage()));
        } else {
          // User does not exist, navigate to ProfilePage to complete profile
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) {
            return ProfilePage(userCredential: userCredential);
          }));
        }
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
}
