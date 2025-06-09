import 'dart:io';
import 'package:beresheet_app/screen/app/homepage.dart';
import 'package:beresheet_app/services/api_user_service.dart';
import 'package:beresheet_app/services/localization_service.dart';
import 'package:beresheet_app/theme/app_theme.dart';
import 'package:beresheet_app/model/user.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class NewProfilePage extends StatefulWidget {
  const NewProfilePage({super.key, this.userCredential});
  final UserCredential? userCredential;

  @override
  State<NewProfilePage> createState() => _NewProfilePageState();
}

class _NewProfilePageState extends State<NewProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  
  // Form controllers
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  DateTime? _selectedBirthday;
  final TextEditingController _apartmentController = TextEditingController();
  
  // Form variables
  String _selectedRole = 'resident';
  String _selectedMaritalStatus = 'single';
  String _selectedGender = 'male';
  String _selectedReligious = 'secular';
  String _selectedLanguage = 'hebrew';
  
  // User data
  UserModel? _currentUser;
  String? _photoUrl;
  File? _selectedImage;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    // Birthday is managed as a DateTime variable, no controller to dispose
    _apartmentController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userData = await ApiUserService.getUserProfile(user.uid);
        
        if (userData != null) {
          setState(() {
            _currentUser = userData;
            _fullNameController.text = userData.fullName;
            _phoneController.text = userData.phoneNumber;
            _selectedBirthday = userData.birthday;
            _apartmentController.text = userData.apartmentNumber;
            _selectedRole = userData.role;
            _selectedMaritalStatus = userData.maritalStatus;
            _selectedGender = userData.gender;
            _selectedReligious = userData.religious;
            _selectedLanguage = userData.nativeLanguage;
            _photoUrl = userData.photo;
          });
        } else {
          // Set phone number from Firebase if available
          _phoneController.text = user.phoneNumber ?? '';
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Validate birthday separately since it's not a form field
    if (_selectedBirthday == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('profile.please_select_birthday'.tr),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No authenticated user found');
      }

      // Create user model
      final userModel = UserModel(
        uniqueId: user.uid,
        fullName: _fullNameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        role: _selectedRole,
        birthday: _selectedBirthday ?? DateTime.now().subtract(const Duration(days: 365 * 30)),
        apartmentNumber: _apartmentController.text.trim(),
        maritalStatus: _selectedMaritalStatus,
        gender: _selectedGender,
        religious: _selectedReligious,
        nativeLanguage: _selectedLanguage,
        photo: _photoUrl,
      );

      // Save or update user profile
      UserModel? savedUser;
      if (_currentUser != null) {
        // Update existing profile
        savedUser = await ApiUserService.updateUserProfile(user.uid, userModel);
      } else {
        // Create new profile
        savedUser = await ApiUserService.createUserProfile(user.uid, userModel);
      }

      if (savedUser == null) {
        throw Exception('Failed to save user profile');
      }

      // Upload photo if selected
      if (_selectedImage != null) {
        final photoUrl = await ApiUserService.uploadUserPhoto(user.uid, _selectedImage!);
        if (photoUrl != null) {
          setState(() {
            _photoUrl = photoUrl;
          });
        }
      }

      // Show success message and navigate
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Success'),
            content: Text(_currentUser != null
              ? 'profile.profile_updated_successfully'.tr
              : 'profile.profile_created_successfully'.tr),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const HomePage()),
                  );
                },
                child: Text('common.ok'.tr),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${'profile.error_saving_profile'.tr}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Widget _buildPhotoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.photo_camera, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'profile.profile_photo'.tr,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey[200],
                    border: Border.all(color: AppColors.primary, width: 2),
                  ),
                  child: _selectedImage != null
                      ? ClipOval(
                          child: Image.file(
                            _selectedImage!,
                            fit: BoxFit.cover,
                            width: 120,
                            height: 120,
                          ),
                        )
                      : _photoUrl != null
                          ? ClipOval(
                              child: Image.network(
                                ApiUserService.getUserPhotoUrl(FirebaseAuth.instance.currentUser!.uid),
                                fit: BoxFit.cover,
                                width: 120,
                                height: 120,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(
                                    Icons.camera_alt,
                                    size: 40,
                                    color: AppColors.primary,
                                  );
                                },
                              ),
                            )
                          : const Icon(
                              Icons.camera_alt,
                              size: 40,
                              color: AppColors.primary,
                            ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'profile.tap_to_take_photo'.tr,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownField(
    String label,
    String value,
    List<String> options,
    ValueChanged<String?> onChanged,
  ) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: _getFieldIcon(label),
      ),
      items: options.map((String option) {
        return DropdownMenuItem<String>(
          value: option,
          child: Text(_getDisplayName(option)),
        );
      }).toList(),
      onChanged: onChanged,
      validator: (value) {
        if (value == null || value.isEmpty) {
          // Generate appropriate validation message based on label
          if (label.contains('profile.role'.tr)) {
            return 'profile.please_select_role'.tr;
          } else if (label.contains('profile.marital_status'.tr)) {
            return 'profile.please_select_marital_status'.tr;
          } else if (label.contains('profile.gender'.tr)) {
            return 'profile.please_select_gender'.tr;
          } else if (label.contains('profile.religious'.tr)) {
            return 'profile.please_select_religious'.tr;
          } else if (label.contains('profile.native_language'.tr)) {
            return 'profile.please_select_native_language'.tr;
          } else {
            return 'Please select $label';
          }
        }
        return null;
      },
    );
  }

  Icon _getFieldIcon(String label) {
    switch (label) {
      case 'Role':
        return const Icon(Icons.work);
      case 'Marital Status':
        return const Icon(Icons.favorite);
      case 'Gender':
        return const Icon(Icons.person);
      case 'Religious':
        return const Icon(Icons.place);
      case 'Native Language':
        return const Icon(Icons.language);
      default:
        return const Icon(Icons.info);
    }
  }

  String _getDisplayName(String value) {
    // Check different categories for translation keys
    if (['resident', 'staff', 'instructor', 'service', 'caregiver'].contains(value)) {
      return 'roles.$value'.tr;
    } else if (['single', 'married', 'divorced', 'widowed'].contains(value)) {
      return 'marital_status.$value'.tr;
    } else if (['male', 'female', 'other'].contains(value)) {
      return 'gender.$value'.tr;
    } else if (['secular', 'orthodox', 'traditional'].contains(value)) {
      return 'religious.$value'.tr;
    } else if (['hebrew', 'english', 'arabic', 'russian', 'french', 'spanish'].contains(value)) {
      return 'languages.$value'.tr;
    } else {
      return value.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_currentUser != null ? 'profile.edit_profile'.tr : 'profile.create_profile'.tr),
        backgroundColor: AppColors.primary,
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Photo section
                    _buildPhotoSection(),
                    const SizedBox(height: 24),

                    // Full Name
                    TextFormField(
                      controller: _fullNameController,
                      decoration: InputDecoration(
                        labelText: 'profile.full_name'.tr,
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.person),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'profile.please_enter_full_name'.tr;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Phone Number
                    TextFormField(
                      controller: _phoneController,
                      decoration: InputDecoration(
                        labelText: 'profile.phone'.tr,
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.phone),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'profile.please_enter_phone_number'.tr;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Role
                    _buildDropdownField(
                      'profile.role'.tr,
                      _selectedRole,
                      ApiUserService.getAvailableRoles(),
                      (value) => setState(() => _selectedRole = value!),
                    ),
                    const SizedBox(height: 16),

                    // Birthday
                    GestureDetector(
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedBirthday ?? DateTime.now().subtract(const Duration(days: 365 * 30)),
                          firstDate: DateTime.now().subtract(const Duration(days: 365 * 120)),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null && picked != _selectedBirthday) {
                          setState(() {
                            _selectedBirthday = picked;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.cake, color: Colors.grey),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _selectedBirthday != null
                                    ? '${_selectedBirthday!.day}/${_selectedBirthday!.month}/${_selectedBirthday!.year}'
                                    : 'Select Birthday',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: _selectedBirthday != null ? Colors.black : Colors.grey[600],
                                ),
                              ),
                            ),
                            const Icon(Icons.calendar_today, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Apartment Number
                    TextFormField(
                      controller: _apartmentController,
                      decoration: InputDecoration(
                        labelText: 'profile.apartment_number'.tr,
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.home),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'profile.please_enter_apartment_number'.tr;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Marital Status
                    _buildDropdownField(
                      'profile.marital_status'.tr,
                      _selectedMaritalStatus,
                      ApiUserService.getAvailableMaritalStatuses(),
                      (value) => setState(() => _selectedMaritalStatus = value!),
                    ),
                    const SizedBox(height: 16),

                    // Gender
                    _buildDropdownField(
                      'profile.gender'.tr,
                      _selectedGender,
                      ApiUserService.getAvailableGenders(),
                      (value) => setState(() => _selectedGender = value!),
                    ),
                    const SizedBox(height: 16),

                    // Religious
                    _buildDropdownField(
                      'profile.religious'.tr,
                      _selectedReligious,
                      ['secular', 'orthodox', 'traditional'],
                      (value) => setState(() => _selectedReligious = value!),
                    ),
                    const SizedBox(height: 16),

                    // Native Language
                    _buildDropdownField(
                      'profile.native_language'.tr,
                      _selectedLanguage,
                      ApiUserService.getAvailableLanguages(),
                      (value) => setState(() => _selectedLanguage = value!),
                    ),
                    const SizedBox(height: 32),

                    // Save Button
                    ElevatedButton(
                      onPressed: _isSaving ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        disabledBackgroundColor: Colors.grey,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(_currentUser != null ? 'profile.update_profile'.tr : 'profile.create_profile'.tr),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}