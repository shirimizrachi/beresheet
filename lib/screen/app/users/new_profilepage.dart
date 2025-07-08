import 'dart:io';
import 'package:beresheet_app/screen/app/homepage.dart';
import 'package:beresheet_app/services/api_user_service.dart';
import 'package:beresheet_app/services/image_cache_service.dart';
import 'package:beresheet_app/services/modern_localization_service.dart';
import 'package:beresheet_app/services/user_session_service.dart';
import 'package:beresheet_app/theme/app_theme.dart';
import 'package:beresheet_app/model/user.dart';
import 'package:beresheet_app/utils/direction_utils.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:beresheet_app/utils/display_name_utils.dart';
import 'package:beresheet_app/config/app_config.dart';

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
    _apartmentController.dispose();
    super.dispose();
  }

  // Helper method to validate dropdown values
  String _validateDropdownValue(String? value, List<String> validOptions, String defaultValue) {
    if (value != null && validOptions.contains(value)) {
      return value;
    }
    return defaultValue;
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get userId from session
      final userId = await UserSessionService.getUserId();
      if (userId == null) return;

      final userData = await ApiUserService.getUserProfile(userId);
      if (userData != null) {
        setState(() {
          _currentUser = userData;
          _fullNameController.text = userData.fullName ?? '';
          _phoneController.text = userData.phoneNumber ?? '';
          _apartmentController.text = userData.apartmentNumber ?? '';
          // Ensure the loaded values are in the valid options list
          _selectedRole = _validateDropdownValue(userData.role, AppConfig.userRoles, 'resident');
          _selectedMaritalStatus = _validateDropdownValue(userData.maritalStatus, DisplayNameUtils.maritalStatusOptions, 'single');
          _selectedGender = _validateDropdownValue(userData.gender, DisplayNameUtils.genderOptions, 'male');
          _selectedReligious = _validateDropdownValue(userData.religious, DisplayNameUtils.religiousOptions, 'secular');
          _selectedLanguage = _validateDropdownValue(userData.nativeLanguage, DisplayNameUtils.languageOptions, 'hebrew');
          _selectedBirthday = userData.birthday;
          _photoUrl = userData.photo;
        });
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
        source: ImageSource.gallery,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 75,
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
            content: Text('${context.l10n.errorPickingImage}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 75,
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
            content: Text('${context.l10n.errorTakingPhoto}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    final l10n = context.l10n;
    
    // Validate birthday separately since it's not a form field
    if (_selectedBirthday == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.pleaseSelectBirthday),
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
      // Only allow updates if current user exists
      if (_currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile not found. Please contact administrator to create your profile.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final userModel = UserModel(
        firebaseID: user.uid,
        fullName: _fullNameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        role: _selectedRole,
        birthday: _selectedBirthday ?? DateTime.now().subtract(const Duration(days: 365 * 30)),
        apartmentNumber: _apartmentController.text.trim(),
        maritalStatus: _selectedMaritalStatus,
        gender: _selectedGender,
        religious: _selectedReligious,
        nativeLanguage: _selectedLanguage,
        homeID: _currentUser!.homeID, // Keep existing homeID
        id: _currentUser!.id, // Keep existing id
        photo: _photoUrl,
      );

      // Update existing profile with optional image upload
      UserModel? savedUser = await ApiUserService.updateUserProfile(
        _currentUser!.id,
        userModel,
        imageFile: _selectedImage, // Only upload if user selected a new image
      );

      if (savedUser == null) {
        throw Exception('Failed to save user profile');
      }

      // Update local state with the saved user data
      setState(() {
        _currentUser = savedUser;
        _photoUrl = savedUser.photo;
        _selectedImage = null; // Clear selected image after successful save
      });

      // Photo upload is now handled by updateUserProfile above
      // No need for separate upload call

      // Show success message and navigate
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.success),
            content: Text(_currentUser != null
              ? l10n.profileUpdatedSuccessfully
              : l10n.profileCreatedSuccessfully),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const HomePage()),
                  );
                },
                child: Text(l10n.ok),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.errorSavingProfile}: $e'),
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
    final l10n = context.l10n;
    
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
                  l10n.profilePhoto,
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
                      : ImageCacheService.buildCircularUserImage(
                          imageUrl: _photoUrl,
                          radius: 60,
                          errorWidget: const Icon(Icons.person, size: 60),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickImage,
              child: Text(
                l10n.tapToSelectFromGallery,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _takePhoto,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primary, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.camera_alt, size: 16, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      l10n.pressHereToTakePhoto,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownField(String label, String value, List<String> options, Function(String?) onChanged) {
    final l10n = context.l10n;
    
    // Ensure the value exists in the options list to prevent assertion errors
    String safeValue = options.contains(value) ? value : options.first;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: DropdownButtonFormField<String>(
        value: safeValue,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        items: options.map((String option) {
          return DropdownMenuItem<String>(
            value: option,
            child: Text(_getDisplayValue(option, label)),
          );
        }).toList(),
        onChanged: onChanged,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return _getValidationMessage(label, l10n);
          }
          return null;
        },
      ),
    );
  }

  String _getValidationMessage(String label, dynamic l10n) {
    // Since we can't easily check the label content with l10n, we'll use a general message
    return l10n.fieldRequired;
  }

  String _getDisplayValue(String value, String category) {
    final l10n = context.l10n;
    
    // Map values to localized strings based on the localized category label
    if (category == l10n.role) {
      switch (value) {
        case 'resident': return l10n.roleResident;
        case 'staff': return l10n.roleStaff;
        case 'instructor': return l10n.roleInstructor;
        case 'service': return l10n.roleService;
        case 'caregiver': return l10n.roleCaregiver;
        default: return value;
      }
    } else if (category == l10n.maritalStatus) {
      switch (value) {
        case 'single': return l10n.maritalStatusSingle;
        case 'married': return l10n.maritalStatusMarried;
        case 'divorced': return l10n.maritalStatusDivorced;
        case 'widowed': return l10n.maritalStatusWidowed;
        default: return value;
      }
    } else if (category == l10n.gender) {
      return DisplayNameUtils.getGenderDisplayName(value, context);
    } else if (category == l10n.religious) {
      switch (value) {
        case 'secular': return l10n.religiousSecular;
        case 'orthodox': return l10n.religiousOrthodox;
        case 'traditional': return l10n.religiousTraditional;
        default: return value;
      }
    } else if (category == l10n.nativeLanguage) {
      switch (value) {
        case 'hebrew': return l10n.languageHebrew;
        case 'english': return l10n.languageEnglish;
        case 'arabic': return l10n.languageArabic;
        case 'russian': return l10n.languageRussian;
        case 'french': return l10n.languageFrench;
        case 'spanish': return l10n.languageSpanish;
        default: return value;
      }
    }
    
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_currentUser != null ? l10n.editProfile : l10n.createProfile),
          leading: IconButton(
            icon: Icon(DirectionUtils.backIcon),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentUser != null ? l10n.editProfile : l10n.createProfile),
        leading: IconButton(
          icon: Icon(DirectionUtils.backIcon),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildPhotoSection(),
            const SizedBox(height: 16),
            
            // Personal Information
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: DirectionUtils.crossAxisAlignmentStart,
                  children: [
                    Align(
                      alignment: DirectionUtils.startAlignment,
                      child: Text(
                        l10n.personalInformation,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _fullNameController,
                      decoration: InputDecoration(
                        labelText: l10n.fullName,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return l10n.pleaseEnterFullName;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _phoneController,
                      decoration: InputDecoration(
                        labelText: l10n.phone,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return l10n.pleaseEnterPhoneNumber;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    _buildDropdownField(
                      l10n.role,
                      _selectedRole,
                      ['resident', 'staff', 'instructor', 'service', 'caregiver'],
                      (value) => setState(() => _selectedRole = value!),
                    ),
                    
                    // Birthday field
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _selectedBirthday ?? DateTime.now().subtract(const Duration(days: 365 * 25)),
                            firstDate: DateTime(1900),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            setState(() {
                              _selectedBirthday = date;
                            });
                          }
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: l10n.birthday,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            suffixIcon: const Icon(Icons.calendar_today),
                          ),
                          child: Text(
                            _selectedBirthday != null 
                                ? '${_selectedBirthday!.day}/${_selectedBirthday!.month}/${_selectedBirthday!.year}'
                                : l10n.selectBirthday,
                            style: TextStyle(
                              color: _selectedBirthday != null ? null : Colors.grey[600],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Contact Information
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: DirectionUtils.crossAxisAlignmentStart,
                  children: [
                    Align(
                      alignment: DirectionUtils.startAlignment,
                      child: Text(
                        l10n.contactInformation,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _apartmentController,
                      decoration: InputDecoration(
                        labelText: l10n.apartmentNumber,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return l10n.pleaseEnterApartmentNumber;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    _buildDropdownField(
                      l10n.maritalStatus,
                      _selectedMaritalStatus,
                      DisplayNameUtils.maritalStatusOptions,
                      (value) => setState(() => _selectedMaritalStatus = value!),
                    ),
                    
                    _buildDropdownField(
                      l10n.gender,
                      _selectedGender,
                      DisplayNameUtils.genderOptions,
                      (value) => setState(() => _selectedGender = value!),
                    ),
                    
                    _buildDropdownField(
                      l10n.religious,
                      _selectedReligious,
                      DisplayNameUtils.religiousOptions,
                      (value) => setState(() => _selectedReligious = value!),
                    ),
                    
                    _buildDropdownField(
                      l10n.nativeLanguage,
                      _selectedLanguage,
                      DisplayNameUtils.languageOptions,
                      (value) => setState(() => _selectedLanguage = value!),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Save button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(_currentUser != null ? l10n.updateProfile : l10n.createProfile),
              ),
            ),
          ],
        ),
      ),
    );
  }
}