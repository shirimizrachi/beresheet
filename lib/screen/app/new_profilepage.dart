import 'dart:io';
import 'package:beresheet_app/screen/app/homepage.dart';
import 'package:beresheet_app/services/api_user_service.dart';
import 'package:beresheet_app/services/modern_localization_service.dart';
import 'package:beresheet_app/theme/app_theme.dart';
import 'package:beresheet_app/model/user.dart';
import 'package:beresheet_app/utils/direction_utils.dart';
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
    _apartmentController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userData = await ApiUserService.getUserProfile(user.uid);
      if (userData != null) {
        setState(() {
          _currentUser = userData;
          _fullNameController.text = userData.fullName ?? '';
          _phoneController.text = userData.phoneNumber ?? '';
          _apartmentController.text = userData.apartmentNumber ?? '';
          _selectedRole = userData.role ?? 'resident';
          _selectedMaritalStatus = userData.maritalStatus ?? 'single';
          _selectedGender = userData.gender ?? 'male';
          _selectedReligious = userData.religious ?? 'secular';
          _selectedLanguage = userData.nativeLanguage ?? 'hebrew';
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
        residentId: _currentUser!.residentId, // Keep existing residentId
        userId: _currentUser!.userId, // Keep existing userId
        photo: _photoUrl,
      );

      // Update existing profile only (creation should be done via web interface)
      UserModel? savedUser = await ApiUserService.updateUserProfile(user.uid, userModel);

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
                      : _photoUrl != null
                          ? ClipOval(
                              child: Image.network(
                                ApiUserService.getUserPhotoUrl(FirebaseAuth.instance.currentUser!.uid),
                                fit: BoxFit.cover,
                                width: 120,
                                height: 120,
                                errorBuilder: (context, error, stackTrace) => 
                                    const Icon(Icons.person, size: 60),
                              ),
                            )
                          : const Icon(Icons.person, size: 60),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.tapToTakePhoto,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownField(String label, String value, List<String> options, Function(String?) onChanged) {
    final l10n = context.l10n;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: DropdownButtonFormField<String>(
        value: value,
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
    
    // Map values to localized strings
    switch (category) {
      case 'Role': // This will need to be updated when we localize the category labels
        switch (value) {
          case 'resident': return l10n.roleResident;
          case 'staff': return l10n.roleStaff;
          case 'instructor': return l10n.roleInstructor;
          case 'service': return l10n.roleService;
          case 'caregiver': return l10n.roleCaregiver;
          default: return value;
        }
      case 'Marital Status':
        switch (value) {
          case 'single': return l10n.maritalStatusSingle;
          case 'married': return l10n.maritalStatusMarried;
          case 'divorced': return l10n.maritalStatusDivorced;
          case 'widowed': return l10n.maritalStatusWidowed;
          default: return value;
        }
      case 'Gender':
        switch (value) {
          case 'male': return l10n.genderMale;
          case 'female': return l10n.genderFemale;
          case 'other': return l10n.genderOther;
          default: return value;
        }
      case 'Religious':
        switch (value) {
          case 'secular': return l10n.religiousSecular;
          case 'orthodox': return l10n.religiousOrthodox;
          case 'traditional': return l10n.religiousTraditional;
          default: return value;
        }
      case 'Language':
        switch (value) {
          case 'hebrew': return l10n.languageHebrew;
          case 'english': return l10n.languageEnglish;
          case 'arabic': return l10n.languageArabic;
          case 'russian': return l10n.languageRussian;
          case 'french': return l10n.languageFrench;
          case 'spanish': return l10n.languageSpanish;
          default: return value;
        }
      default:
        return value;
    }
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
                    Text(
                      l10n.personalInformation,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
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
                    Text(
                      l10n.contactInformation,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
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
                      ['single', 'married', 'divorced', 'widowed'],
                      (value) => setState(() => _selectedMaritalStatus = value!),
                    ),
                    
                    _buildDropdownField(
                      l10n.gender,
                      _selectedGender,
                      ['male', 'female', 'other'],
                      (value) => setState(() => _selectedGender = value!),
                    ),
                    
                    _buildDropdownField(
                      l10n.religious,
                      _selectedReligious,
                      ['secular', 'orthodox', 'traditional'],
                      (value) => setState(() => _selectedReligious = value!),
                    ),
                    
                    _buildDropdownField(
                      l10n.nativeLanguage,
                      _selectedLanguage,
                      ['hebrew', 'english', 'arabic', 'russian', 'french', 'spanish'],
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