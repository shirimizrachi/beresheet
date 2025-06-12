import 'package:beresheet_app/services/api_user_service.dart';
import 'package:beresheet_app/services/web_auth_service.dart';
import 'package:beresheet_app/services/modern_localization_service.dart';
import 'package:beresheet_app/services/home_service.dart';
import 'package:beresheet_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:html' as html;

class CreateUserWeb extends StatefulWidget {
  const CreateUserWeb({Key? key}) : super(key: key);

  @override
  State<CreateUserWeb> createState() => _CreateUserWebState();
}

class _CreateUserWebState extends State<CreateUserWeb> {
  final _formKey = GlobalKey<FormState>();
  final _phoneNumberController = TextEditingController();
  bool _isCreating = false;
  List<Home> _availableHomes = [];
  Home? _selectedHome;
  bool _isLoadingHomes = true;

  @override
  void initState() {
    super.initState();
    _loadAvailableHomes();
  }

  @override
  void dispose() {
    _phoneNumberController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableHomes() async {
    try {
      final homes = await HomeService.getAvailableHomes();
      setState(() {
        _availableHomes = homes;
        _isLoadingHomes = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingHomes = false;
      });
      print('Error loading homes: $e');
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
      if (!WebAuthService.isManager) {
        final strings = ModernAppStrings.of(context);
        _showErrorDialog(strings.accessDenied, strings.onlyManagersCanCreateUsers);
        return;
      }

      // Create a temporary unique ID (could be phone number or random)
      final tempfirebaseID = 'temp_${DateTime.now().millisecondsSinceEpoch}';
      
      // Make API call directly with proper web auth headers
      final headers = WebAuthService.getAuthHeaders();
      headers['currentUserId'] = WebAuthService.userId ?? 'current_manager_id';
      headers['firebaseId'] = tempfirebaseID;
      
      final minimalData = {
        'home_id': _selectedHome!.id,
        'phone_number': _phoneNumberController.text.trim(),
      };
      
      final response = await http.post(
        Uri.parse('http://localhost:8000/api/users'),
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
        _showErrorDialog(strings.error, strings.failedToCreateUserProfile);
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
    setState(() {
      _selectedHome = null;
    });
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
              child: Form(
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

                    // Home Selection Field
                    Builder(
                      builder: (context) {
                        final strings = ModernAppStrings.of(context);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_isLoadingHomes)
                              Container(
                                height: 60,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                                  color: Colors.grey[50],
                                ),
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            else
                              DropdownButtonFormField<Home>(
                                value: _selectedHome,
                                decoration: InputDecoration(
                                  labelText: '${strings.homeId} *',
                                  hintText: strings.selectHome,
                                  prefixIcon: const Icon(Icons.home),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                ),
                                items: _availableHomes.map((Home home) {
                                  return DropdownMenuItem<Home>(
                                    value: home,
                                    child: Text(home.name),
                                  );
                                }).toList(),
                                onChanged: (Home? newValue) {
                                  setState(() {
                                    _selectedHome = newValue;
                                  });
                                },
                                validator: (value) {
                                  if (value == null) {
                                    return strings.homeIdRequired;
                                  }
                                  return null;
                                },
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),

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