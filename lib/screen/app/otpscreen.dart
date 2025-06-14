import 'package:beresheet_app/auth/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:beresheet_app/services/modern_localization_service.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key, required this.number});
  final String number;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  TextEditingController otpController = TextEditingController();
  bool isVerifying = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // Accessing theme data
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.primary,
        title: Text(
          context.l10n.otpTitle,
          style: theme.textTheme.titleLarge?.copyWith(
            // Adjusting the style to match the theme
            color:
                theme.colorScheme.surface, // Use the primary color for the text
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
              context.l10n.verifyWithOTPSentTo('0${widget.number}'),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                keyboardType: TextInputType.number,
                controller: otpController,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(15)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: const BorderRadius.all(Radius.circular(15)),
                    borderSide:
                        BorderSide(color: theme.colorScheme.primary, width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: const BorderRadius.all(Radius.circular(15)),
                    borderSide: BorderSide(
                        color: theme.colorScheme.secondary, width: 2),
                  ),
                  labelText: context.l10n.enterOTP,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        theme.colorScheme.primary, // Button background color
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    foregroundColor:
                        theme.colorScheme.onPrimary, // Text color on the button
                  ),
                  onPressed: () {
                    setState(() {
                      isVerifying = true;
                    });
                    AuthRepo.submitOtp(context, otpController.text);
                  },
                  child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: !isVerifying
                          ? Text(
                              context.l10n.continueButton,
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            )
                          : const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            )),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
