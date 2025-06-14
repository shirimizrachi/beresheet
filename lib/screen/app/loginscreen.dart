import 'package:beresheet_app/auth/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:beresheet_app/services/modern_localization_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  TextEditingController phoneController = TextEditingController();
  bool isgettingOTP = false; // State to manage button enable/disable


  @override
  void dispose() {
    phoneController.dispose();
    super.dispose();
  }



  void getOTP() {
    String phoneNumber = phoneController.text;
    if (RegExp(r'^[0-9]{9}$').hasMatch(phoneNumber)) {
      setState(() {
        isgettingOTP =true;
      });
      AuthRepo.verifyPhoneNumber(context, phoneNumber);
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    context.l10n.mobileNumber,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: TextField(
                    controller: phoneController,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(15)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: const BorderRadius.all(Radius.circular(15)),
                        borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: const BorderRadius.all(Radius.circular(15)),
                        borderSide: BorderSide(color: theme.colorScheme.secondary, width: 2),
                      ),
                      prefix: const Text(
                        "+972  |  ",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      counterText: "",
                    ),
                    maxLength: 9,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
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
