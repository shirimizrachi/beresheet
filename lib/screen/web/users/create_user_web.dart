import 'package:beresheet_app/services/api_user_service.dart';
import 'package:beresheet_app/services/web/web_jwt_session_service.dart';
import 'package:beresheet_app/services/modern_localization_service.dart';
import 'package:beresheet_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:html' as html;
import 'package:beresheet_app/config/app_config.dart';

class CreateUserWeb extends StatefulWidget {
  const CreateUserWeb({Key? key}) : super(key: key);

  @override
  State<CreateUserWeb> createState() => _CreateUserWebState();
}

class _CreateUserWebState extends State<CreateUserWeb> {
  final _formKey = GlobalKey<FormState>();
  final _phoneNumberController = TextEditingController();
  bool _isCreating = false;
  String? _currentUserHomeId;
  bool _isLoadingUserData = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserData();
  }

  @override
  void dispose() {
    _phoneNumberController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUserData() async {
    try {
      final user = await WebJwtSessionService.getCurrentUser();
      if (user != null && user.homeId.toString().isNotEmpty) {
        setState(() {
          _currentUserHomeId = user.homeId.toString();
          _isLoadingUserData = false;
        });
      } else {
        setState(() {
          _isLoadingUserData = false;
        });
        print('Error: No user or homeID found');
      }
    } catch (e) {
      setState(() {
        _isLoadingUserData = false;
      });
      print('Error loading user data: $e');
    }
  }

  Future<void> _createUser() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      // Check if user has manager role
      final user = await WebJwtSessionService.getCurrentUser();
      if (user?.role != 'manager') {
        final strings = ModernAppStrings.of(context);
        _showErrorDialog(strings.accessDenied, strings.onlyManagersCanCreateUsers);
        return;
      }

      // Make API call directly with proper web auth headers
      final headers = await WebJwtSessionService.getAuthHeaders();
      
      final minimalData = {
        'home_id': _currentUserHomeId!,
        'phone_number': _phoneNumberController.text.trim(),
      };
      
      final response = await http.post(
        Uri.parse('${AppConfig.apiUrlWithPrefix}/api/users'),
        headers: headers,
        body: json.encode(minimalData),
      );

      if (response.statusCode == 201) {
        final strings = ModernAppStrings.of(context);
        final responseData = json.decode(response.body);
        final userId = responseData['id'] ?? 'Unknown';
        _showSuccessDialog(strings.success, '${strings.userProfileCreatedSuccessfully}\n${strings.userId}: $userId');
        _clearForm();
      } else {
        final strings = ModernAppStrings.of(context);
        String errorMessage = strings.failedToCreateUserProfile;
        
        // Try to get more specific error message from response
        try {
          final responseData = json.decode(response.body);
          if (responseData['detail'] != null) {
            final detail = responseData['detail'].toString();
            // Check if it's a phone number already exists error
            if (detail.toLowerCase().contains('phone number') && detail.toLowerCase().contains('already exists')) {
              errorMessage = strings.phoneNumberAlreadyExists;
            } else {
              errorMessage = detail;
            }
          }
        } catch (e) {
          // If we can't parse the response, use the default error message
        }
        
        _showErrorDialog(strings.error, 'Error ${response.statusCode}: $errorMessage');
      }
    } catch (e) {
      final strings = ModernAppStrings.of(context);
      _showErrorDialog(strings.error, '${strings.anErrorOccurred}: $e');
    } finally {
      setState(() {
        _isCreating = false;
      });
    }
  }

  void _clearForm() {
    _phoneNumberController.clear();
  }

  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(color: Colors.green)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(ModernAppStrings.of(context).ok),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(color: Colors.red)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(ModernAppStrings.of(context).ok),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          ModernAppStrings.of(context).createNewUserProfile,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.primary,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppBorderRadius.large),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: _isLoadingUserData
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Loading user data...'),
                        ],
                      ),
                    )
                  : _currentUserHomeId == null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error, size: 64, color: Colors.red),
                              const SizedBox(height: 16),
                              const Text(
                                'Error: Unable to get user home information',
                                style: TextStyle(color: Colors.red),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Go Back'),
                              ),
                            ],
                          ),
                        )
                      : Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                    // Header
                    Icon(
                      Icons.person_add,
                      size: 64,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      ModernAppStrings.of(context).createNewUserProfile,
                      style: AppTextStyles.heading1.copyWith(
                        fontSize: 28,
                        color: AppColors.primary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      ModernAppStrings.of(context).createNewUserProfileDescription,
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // Phone Number Field
                    Builder(
                      builder: (context) {
                        final strings = ModernAppStrings.of(context);
                        return TextFormField(
                          controller: _phoneNumberController,
                          decoration: InputDecoration(
                            labelText: '${strings.phoneNumber} *',
                            hintText: strings.enterPhoneNumber,
                            prefixIcon: const Icon(Icons.phone),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          keyboardType: TextInputType.phone,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return strings.phoneNumberRequired;
                            }
                            if (value.trim().length < 10) {
                              return strings.pleaseEnterValidPhoneNumber;
                            }
                            return null;
                          },
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // Create Button
                    ElevatedButton(
                      onPressed: _isCreating ? null : _createUser,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                        ),
                        elevation: 4,
                      ),
                      child: _isCreating
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Text(ModernAppStrings.of(context).creating),
                              ],
                            )
                          : Text(
                              ModernAppStrings.of(context).createUserProfile,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Cancel Button
                    TextButton(
                      onPressed: _isCreating ? null : () => Navigator.of(context).pop(),
                      child: Text(ModernAppStrings.of(context).cancel),
                            ),
                          ],
                        ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}