import 'package:beresheet_app/auth/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:beresheet_app/services/modern_localization_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  List<TextEditingController> phoneControllers = List.generate(10, (index) => TextEditingController());
  List<FocusNode> focusNodes = List.generate(10, (index) => FocusNode());
  bool isgettingOTP = false; // State to manage button enable/disable


  @override
  void dispose() {
    for (var controller in phoneControllers) {
      controller.dispose();
    }
    for (var focusNode in focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  String getFullPhoneNumber() {
    return phoneControllers.map((controller) => controller.text).join();
  }

  String getPhoneNumberForFirebase() {
    String fullNumber = getFullPhoneNumber();
    // Remove leading zero and add country code for Firebase
    if (fullNumber.startsWith('0') && fullNumber.length == 10) {
      return '972${fullNumber.substring(1)}'; // Remove 0, add 972
    }
    return fullNumber;
  }

  void onDigitChanged(String value, int index) {
    if (value.isNotEmpty && index < 9) {
      // Move to next field
      FocusScope.of(context).requestFocus(focusNodes[index + 1]);
    } else if (value.isEmpty && index > 0) {
      // Move to previous field on backspace
      FocusScope.of(context).requestFocus(focusNodes[index - 1]);
    }
  }

  void getOTP() {
    String phoneNumber = getFullPhoneNumber();
    if (RegExp(r'^0[0-9]{9}$').hasMatch(phoneNumber)) {
      setState(() {
        isgettingOTP = true;
      });
      String firebasePhoneNumber = getPhoneNumberForFirebase();
      AuthRepo.verifyPhoneNumber(context, firebasePhoneNumber);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.pleaseEnterValidPhoneNumber),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // Accessing theme data
    return Scaffold(
      backgroundColor: theme.colorScheme.background, // Using background color from theme
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: theme.colorScheme.primary, // Using primary color from theme
        title: Text(
          context.l10n.loginTitle,
          style: theme.textTheme.titleLarge?.copyWith(
            color: theme.colorScheme.onPrimary, // Ensuring text color is readable on primary color
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.bold,
            shadows: const [
              Shadow(
                color: Colors.black45,
                offset: Offset(1, 2),
              ),
            ],
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 50),
            Text(
              context.l10n.enterMobileNumberForOTP,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 40),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(10, (index) {
                  return Container(
                    width: 40,
                    height: 50,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: theme.colorScheme.primary,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: TextField(
                      controller: phoneControllers[index],
                      focusNode: focusNodes[index],
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        counterText: "",
                      ),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      onChanged: (value) {
                        if (value.length == 1 && RegExp(r'[0-9]').hasMatch(value)) {
                          onDigitChanged(value, index);
                        } else if (value.isEmpty) {
                          onDigitChanged(value, index);
                        } else {
                          // Clear invalid input
                          phoneControllers[index].clear();
                        }
                      },
                      onTap: () {
                        // Clear field when tapped
                        phoneControllers[index].clear();
                      },
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  foregroundColor: theme.colorScheme.onPrimary,
                ),
                onPressed: getOTP ,  // Enable the button only if isButtonEnabled is true
                child:  Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: !isgettingOTP?  Text(
                    context.l10n.sendOTP,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ) : const Center(child: CircularProgressIndicator(color: Colors.white,),),
                ),
              ),
            ),
            const SizedBox(height: 20,),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(context.l10n.termsAndConditionsAcceptance),
            ),
          ],
        ),
      ),
    );
  }
}
