import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:beresheet_app/services/web/web_jwt_session_service.dart';
import 'package:beresheet_app/model/user.dart';
import 'package:beresheet_app/config/app_config.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:beresheet_app/utils/display_name_utils.dart';
import 'package:beresheet_app/model/service_provider_type.dart';
import 'package:beresheet_app/services/service_provider_type_service.dart';
import 'package:file_picker/file_picker.dart';

class EditUserWeb extends StatefulWidget {
  final UserModel user;
  
  const EditUserWeb({Key? key, required this.user}) : super(key: key);

  @override
  State<EditUserWeb> createState() => _EditUserWebState();
}

class _EditUserWebState extends State<EditUserWeb> {
  final _formKey = GlobalKey<FormState>();
  
  // Form controllers
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _apartmentController = TextEditingController();
  
  // Form variables
  String _selectedRole = 'resident';
  String _selectedMaritalStatus = 'single';
  String _selectedGender = 'male';
  String _selectedReligious = 'secular';
  String _selectedLanguage = 'hebrew';
  DateTime? _selectedBirthday;
  int? _selectedServiceProviderTypeId;
  
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  
  // Service provider types
  List<ServiceProviderType> _serviceProviderTypes = [];
  bool _loadingServiceProviderTypes = false;
  
  // Photo upload variables
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  String? _currentPhotoUrl;

  // Dropdown options
  final List<String> _roleOptions = ['resident', 'staff', 'instructor', 'service', 'caregiver', 'manager'];
  final List<String> _maritalStatusOptions = ['single', 'married', 'divorced', 'widowed'];
  final List<String> _genderOptions = ['male', 'female', 'other'];
  final List<String> _religiousOptions = ['secular', 'orthodox', 'traditional'];
  final List<String> _languageOptions = ['hebrew', 'english', 'arabic', 'russian', 'french', 'spanish'];

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  void _checkPermissions() async {
    final user = await WebJwtSessionService.getCurrentUser();
    final userRole = user?.role ?? '';
    if (userRole != 'manager') {
      setState(() {
        _errorMessage = 'Access denied: Manager role required to edit users';
        _isLoading = false;
      });
      return;
    }
    _initializeForm();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _apartmentController.dispose();
    super.dispose();
  }

  void _initializeForm() {
    _fullNameController.text = widget.user.fullName;
    _phoneController.text = widget.user.phoneNumber;
    _apartmentController.text = widget.user.apartmentNumber;
    _selectedRole = widget.user.role;
    _selectedMaritalStatus = widget.user.maritalStatus;
    _selectedGender = widget.user.gender.isNotEmpty ? widget.user.gender : 'male';
    _selectedReligious = widget.user.religious.isNotEmpty ? widget.user.religious : 'secular';
    _selectedLanguage = widget.user.nativeLanguage;
    _selectedBirthday = widget.user.birthday;
    _selectedServiceProviderTypeId = widget.user.serviceProviderTypeId;
    _currentPhotoUrl = widget.user.photo;
    
    // Load service provider types if role is service
    if (_selectedRole == 'service') {
      _loadServiceProviderTypes();
    }
  }

  Future<void> _pickImage() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        setState(() {
          _selectedImageBytes = result.files.single.bytes!;
          _selectedImageName = result.files.single.name;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error picking image: $e';
      });
    }
  }

  Future<void> _updateUser() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedBirthday == null) {
      setState(() {
        _errorMessage = 'Please select a birthday';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final headers = await WebJwtSessionService.getAuthHeaders();
      
      // Use multipart request if there's an image to upload
      http.Response response;
      
      if (_selectedImageBytes != null) {
        // Create multipart request for image upload
        var request = http.MultipartRequest(
          'PUT',
          Uri.parse('${AppConfig.apiUrlWithPrefix}/api/users/${widget.user.id}'),
        );
        
        // Add headers but remove Content-Type for multipart requests
        final multipartHeaders = Map<String, String>.from(headers);
        multipartHeaders.remove('Content-Type'); // Remove this for multipart requests
        request.headers.addAll(multipartHeaders);
        
        // Add form fields - only send non-null and non-empty values
        if (_fullNameController.text.trim().isNotEmpty) {
          request.fields['full_name'] = _fullNameController.text.trim();
        }
        if (_phoneController.text.trim().isNotEmpty) {
          request.fields['phone_number'] = _phoneController.text.trim();
        }
        if (_selectedRole.isNotEmpty) {
          request.fields['role'] = _selectedRole;
        }
        if (_selectedBirthday != null) {
          request.fields['birthday'] = _selectedBirthday!.toIso8601String(); // Send full ISO string like mobile version
        }
        if (_apartmentController.text.trim().isNotEmpty) {
          request.fields['apartment_number'] = _apartmentController.text.trim();
        }
        if (_selectedMaritalStatus.isNotEmpty) {
          request.fields['marital_status'] = _selectedMaritalStatus;
        }
        if (_selectedGender.isNotEmpty) {
          request.fields['gender'] = _selectedGender;
        }
        if (_selectedReligious.isNotEmpty) {
          request.fields['religious'] = _selectedReligious;
        }
        if (_selectedLanguage.isNotEmpty) {
          request.fields['native_language'] = _selectedLanguage;
        }
        if (_selectedServiceProviderTypeId != null) {
          request.fields['service_provider_type_id'] = _selectedServiceProviderTypeId.toString();
        }
        
        // Add image file with proper content type
        request.files.add(http.MultipartFile.fromBytes(
          'photo',
          _selectedImageBytes!,
          filename: _selectedImageName ?? '${widget.user.id}.jpeg',
          contentType: MediaType.parse('image/jpeg'),
        ));
        
        // Send request and get response
        final streamedResponse = await request.send();
        response = await http.Response.fromStream(streamedResponse);
      } else {
        // Use multipart request even without image for consistency with mobile version
        var request = http.MultipartRequest(
          'PUT',
          Uri.parse('${AppConfig.apiUrlWithPrefix}/api/users/${widget.user.id}'),
        );
        
        // Add headers but remove Content-Type for multipart requests
        final multipartHeaders = Map<String, String>.from(headers);
        multipartHeaders.remove('Content-Type'); // Remove this for multipart requests
        request.headers.addAll(multipartHeaders);
        
        // Add form fields - only send non-null and non-empty values
        if (_fullNameController.text.trim().isNotEmpty) {
          request.fields['full_name'] = _fullNameController.text.trim();
        }
        if (_phoneController.text.trim().isNotEmpty) {
          request.fields['phone_number'] = _phoneController.text.trim();
        }
        if (_selectedRole.isNotEmpty) {
          request.fields['role'] = _selectedRole;
        }
        if (_selectedBirthday != null) {
          request.fields['birthday'] = _selectedBirthday!.toIso8601String(); // Send full ISO string like mobile version
        }
        if (_apartmentController.text.trim().isNotEmpty) {
          request.fields['apartment_number'] = _apartmentController.text.trim();
        }
        if (_selectedMaritalStatus.isNotEmpty) {
          request.fields['marital_status'] = _selectedMaritalStatus;
        }
        if (_selectedGender.isNotEmpty) {
          request.fields['gender'] = _selectedGender;
        }
        if (_selectedReligious.isNotEmpty) {
          request.fields['religious'] = _selectedReligious;
        }
        if (_selectedLanguage.isNotEmpty) {
          request.fields['native_language'] = _selectedLanguage;
        }
        if (_selectedServiceProviderTypeId != null) {
          request.fields['service_provider_type_id'] = _selectedServiceProviderTypeId.toString();
        }
        
        // Send request and get response
        final streamedResponse = await request.send();
        response = await http.Response.fromStream(streamedResponse);
      }

      if (response.statusCode == 200) {
        setState(() {
          _successMessage = 'User updated successfully!';
          _isLoading = false;
          // Clear selected image after successful upload
          _selectedImageBytes = null;
          _selectedImageName = null;
          // Update current photo URL if response contains it
          try {
            final responseData = json.decode(response.body);
            if (responseData['photo'] != null) {
              _currentPhotoUrl = responseData['photo'];
            }
          } catch (e) {
            // Ignore JSON parsing errors
          }
        });
        
        // Navigate back after a short delay
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to update user: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error updating user: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _selectBirthday() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthday ?? DateTime.now().subtract(const Duration(days: 365 * 30)),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
    );
    
    if (picked != null && picked != _selectedBirthday) {
      setState(() {
        _selectedBirthday = picked;
      });
    }
  }

  String _formatRole(String role) {
    return DisplayNameUtils.getUserRoleDisplayName(role, context);
  }

  String _formatMaritalStatus(String status) {
    switch (status) {
      case 'single': return 'Single';
      case 'married': return 'Married';
      case 'divorced': return 'Divorced';
      case 'widowed': return 'Widowed';
      default: return status.toUpperCase();
    }
  }

  String _formatGender(String gender) {
    switch (gender) {
      case 'male': return 'Male';
      case 'female': return 'Female';
      case 'other': return 'Other';
      default: return gender.toUpperCase();
    }
  }

  String _formatReligious(String religious) {
    switch (religious) {
      case 'secular': return 'Secular';
      case 'orthodox': return 'Orthodox';
      case 'traditional': return 'Traditional';
      default: return religious.toUpperCase();
    }
  }

  String _formatLanguage(String language) {
    switch (language) {
      case 'hebrew': return 'Hebrew';
      case 'english': return 'English';
      case 'arabic': return 'Arabic';
      case 'russian': return 'Russian';
      case 'french': return 'French';
      case 'spanish': return 'Spanish';
      default: return language.toUpperCase();
    }
  }

  Future<void> _loadServiceProviderTypes() async {
    setState(() {
      _loadingServiceProviderTypes = true;
    });
    
    try {
      final types = await ServiceProviderTypeService.getServiceProviderTypesWeb();
      setState(() {
        _serviceProviderTypes = types;
        _loadingServiceProviderTypes = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load service provider types: $e';
        _loadingServiceProviderTypes = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Edit User: ${widget.user.fullName.isNotEmpty ? widget.user.fullName : widget.user.phoneNumber}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.blue[700],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Info Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person, color: Colors.blue),
                          const SizedBox(width: 8),
                          const Text(
                            'User Information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'User ID: ${widget.user.id}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Photo Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.photo_camera, color: Colors.blue),
                          const SizedBox(width: 8),
                          const Text(
                            'Profile Photo',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: _pickImage,
                              child: Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.grey[200],
                                  border: Border.all(color: Colors.blue, width: 2),
                                ),
                                child: _selectedImageBytes != null
                                    ? ClipOval(
                                        child: Image.memory(
                                          _selectedImageBytes!,
                                          fit: BoxFit.cover,
                                          width: 120,
                                          height: 120,
                                        ),
                                      )
                                    : (_currentPhotoUrl != null && _currentPhotoUrl!.isNotEmpty)
                                        ? ClipOval(
                                            child: Image.network(
                                              _currentPhotoUrl!,
                                              fit: BoxFit.cover,
                                              width: 120,
                                              height: 120,
                                              errorBuilder: (context, error, stackTrace) {
                                                return const Icon(Icons.person, size: 60, color: Colors.grey);
                                              },
                                            ),
                                          )
                                        : const Icon(Icons.person, size: 60, color: Colors.grey),
                              ),
                            ),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: _pickImage,
                              child: const Text(
                                'Click to select from gallery',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontSize: 12,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Form Fields
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Edit Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Full Name
                      TextFormField(
                        controller: _fullNameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter full name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Phone Number
                      TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter phone number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Role
                      DropdownButtonFormField<String>(
                        value: _selectedRole,
                        decoration: const InputDecoration(
                          labelText: 'Role',
                          border: OutlineInputBorder(),
                        ),
                        items: _roleOptions.map((String role) {
                          return DropdownMenuItem<String>(
                            value: role,
                            child: Text(_formatRole(role)),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedRole = newValue!;
                            // Reset service provider type when role changes
                            if (_selectedRole != 'service') {
                              _selectedServiceProviderTypeId = null;
                            } else {
                              // Load service provider types when role becomes service
                              _loadServiceProviderTypes();
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Service Provider Type (only shown when role is 'service')
                      if (_selectedRole == 'service') ...[
                        _loadingServiceProviderTypes
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            : DropdownButtonFormField<int>(
                                value: _selectedServiceProviderTypeId,
                                decoration: const InputDecoration(
                                  labelText: 'Service Provider Type',
                                  border: OutlineInputBorder(),
                                ),
                                hint: const Text('Select service provider type'),
                                items: _serviceProviderTypes.map((ServiceProviderType type) {
                                  return DropdownMenuItem<int>(
                                    value: type.id,
                                    child: Text(type.name),
                                  );
                                }).toList(),
                                onChanged: (int? newValue) {
                                  setState(() {
                                    _selectedServiceProviderTypeId = newValue;
                                  });
                                },
                                validator: _selectedRole == 'service'
                                    ? (value) {
                                        if (value == null) {
                                          return 'Please select a service provider type';
                                        }
                                        return null;
                                      }
                                    : null,
                              ),
                        const SizedBox(height: 16),
                      ],
                      
                      // Birthday
                      InkWell(
                        onTap: _selectBirthday,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Birthday',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text(
                            _selectedBirthday != null
                                ? '${_selectedBirthday!.day}/${_selectedBirthday!.month}/${_selectedBirthday!.year}'
                                : 'Select birthday',
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Apartment Number
                      TextFormField(
                        controller: _apartmentController,
                        decoration: const InputDecoration(
                          labelText: 'Apartment Number',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter apartment number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Marital Status
                      DropdownButtonFormField<String>(
                        value: _selectedMaritalStatus,
                        decoration: const InputDecoration(
                          labelText: 'Marital Status',
                          border: OutlineInputBorder(),
                        ),
                        items: _maritalStatusOptions.map((String status) {
                          return DropdownMenuItem<String>(
                            value: status,
                            child: Text(_formatMaritalStatus(status)),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedMaritalStatus = newValue!;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Gender
                      DropdownButtonFormField<String>(
                        value: _selectedGender,
                        decoration: const InputDecoration(
                          labelText: 'Gender',
                          border: OutlineInputBorder(),
                        ),
                        items: _genderOptions.map((String gender) {
                          return DropdownMenuItem<String>(
                            value: gender,
                            child: Text(_formatGender(gender)),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedGender = newValue!;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Religious
                      DropdownButtonFormField<String>(
                        value: _selectedReligious,
                        decoration: const InputDecoration(
                          labelText: 'Religious',
                          border: OutlineInputBorder(),
                        ),
                        items: _religiousOptions.map((String religious) {
                          return DropdownMenuItem<String>(
                            value: religious,
                            child: Text(_formatReligious(religious)),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedReligious = newValue!;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Native Language
                      DropdownButtonFormField<String>(
                        value: _selectedLanguage,
                        decoration: const InputDecoration(
                          labelText: 'Native Language',
                          border: OutlineInputBorder(),
                        ),
                        items: _languageOptions.map((String language) {
                          return DropdownMenuItem<String>(
                            value: language,
                            child: Text(_formatLanguage(language)),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedLanguage = newValue!;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Messages
              if (_errorMessage != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    border: Border.all(color: Colors.red[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red[700]),
                    textAlign: TextAlign.center,
                  ),
                ),
              
              if (_successMessage != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    border: Border.all(color: Colors.green[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _successMessage!,
                    style: TextStyle(color: Colors.green[700]),
                    textAlign: TextAlign.center,
                  ),
                ),
              
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _updateUser,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('Update User'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}