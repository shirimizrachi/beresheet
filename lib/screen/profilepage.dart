import 'package:beresheet_app/screen/homepage.dart';
import 'package:beresheet_app/services/user_service.dart';
import 'package:beresheet_app/theme/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, this.userCredential});
  final UserCredential? userCredential;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  String fullName = '';
  String address = '';
  String phoneNumber = '';
  List<String> favoriteActivities = [];
  List<String> availableActivities = [];
  
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      // Load available activity types
      final activities = await UserService.getAllActivityTypes();
      
      // Load user data
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final userData = await UserService.getUserProfile(currentUser.uid);
        
        if (userData != null) {
          setState(() {
            fullName = userData['fullName'] ?? '';
            address = userData['address'] ?? '';
            phoneNumber = userData['phoneNumber'] ?? currentUser.phoneNumber ?? '';
            favoriteActivities = List<String>.from(userData['favoriteActivities'] ?? []);
            availableActivities = activities;
            _fullNameController.text = fullName;
            _addressController.text = address;
            isLoading = false;
          });
        } else {
          setState(() {
            phoneNumber = currentUser.phoneNumber ?? '';
            availableActivities = activities;
            isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _saveUserProfile() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      User? currentUser = FirebaseAuth.instance.currentUser;
      
      if (currentUser != null) {
        String uid = currentUser.uid;
        String userPhone = widget.userCredential?.user?.phoneNumber ?? currentUser.phoneNumber ?? phoneNumber;

        final userProfile = {
          'fullName': fullName,
          'address': address,
          'phoneNumber': userPhone,
          'uid': uid,
          'favoriteActivities': favoriteActivities,
          'lastUpdated': DateTime.now().toIso8601String(),
          'isComplete': true,
        };

        final success = await UserService.saveUserProfile(userProfile);
        
        if (success) {
          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                content: const Text('Profile updated successfully!'),
                actions: <Widget>[
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Close dialog
                      // Always go to homepage after successful profile save
                      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
                    },
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to save profile. Please try again.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    }
  }

  void _toggleActivity(String activity) {
    setState(() {
      if (favoriteActivities.contains(activity)) {
        favoriteActivities.remove(activity);
      } else {
        favoriteActivities.add(activity);
      }
    });
  }

  Color _getActivityColor(String type) {
    return ActivityTypeHelper.getColor(type);
  }

  IconData _getActivityIcon(String type) {
    return ActivityTypeHelper.getIcon(type);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profile Information'),
        backgroundColor: AppColors.primary,
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (phoneNumber.isNotEmpty) ...[
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              const Icon(Icons.phone, color: AppColors.primary),
                              const SizedBox(width: 12),
                              Text(
                                'Phone: $phoneNumber',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16.0),
                    ],
                    
                    TextFormField(
                      controller: _fullNameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your full name';
                        }
                        return null;
                      },
                      onSaved: (value) => fullName = value ?? '',
                    ),
                    
                    const SizedBox(height: 16.0),
                    
                    TextFormField(
                      controller: _addressController,
                      decoration: const InputDecoration(
                        labelText: 'Address',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.home),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your address';
                        }
                        return null;
                      },
                      onSaved: (value) => address = value ?? '',
                    ),
                    
                    const SizedBox(height: 24.0),
                    
                    // Favorite Activities Section
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.favorite, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Text(
                                  'Favorite Activities',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Select the types of activities you enjoy most:',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: availableActivities.map((activity) {
                                final isSelected = favoriteActivities.contains(activity);
                                final activityColor = _getActivityColor(activity);
                                final displayName = UserService.getActivityDisplayName(activity);
                                final details = UserService.getActivityDetails(activity);
                                
                                return InkWell(
                                  onTap: () => _toggleActivity(activity),
                                  borderRadius: BorderRadius.circular(20),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isSelected 
                                          ? activityColor 
                                          : activityColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: activityColor,
                                        width: isSelected ? 2 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _getActivityIcon(activity),
                                          size: 16,
                                          color: isSelected ? Colors.white : activityColor,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          displayName,
                                          style: TextStyle(
                                            color: isSelected ? Colors.white : activityColor,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            if (favoriteActivities.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(
                                'Selected: ${favoriteActivities.map((a) => UserService.getActivityDisplayName(a)).join(', ')}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 32.0),
                    
                    ElevatedButton(
                      onPressed: _saveUserProfile,
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                      ),
                      child: Text(fullName.isEmpty ? 'Create Profile' : 'Update Profile'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
