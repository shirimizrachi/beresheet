import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../model/user.dart';

class ApiUserService {
  // Use different URLs for web vs mobile platforms
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8000'; // Web can use localhost
    } else {
      return 'http://10.0.2.2:8000'; // Android emulator uses 10.0.2.2
    }
  }

  /// Get user profile by unique ID
  static Future<UserModel?> getUserProfile(String uniqueId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/users/$uniqueId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return UserModel.fromJson(data);
      } else if (response.statusCode == 404) {
        return null; // User not found
      } else {
        print('Error fetching user profile: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error fetching user profile: $e');
      return null;
    }
  }

  /// Create a new user profile
  static Future<UserModel?> createUserProfile(String uniqueId, UserModel user) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/users/$uniqueId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(user.toJson()),
      );

      if (response.statusCode == 201) {
        final Map<String, dynamic> data = json.decode(response.body);
        return UserModel.fromJson(data);
      } else {
        print('Error creating user profile: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error creating user profile: $e');
      return null;
    }
  }

  /// Update an existing user profile
  static Future<UserModel?> updateUserProfile(String uniqueId, UserModel user) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/users/$uniqueId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(user.toJson()),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return UserModel.fromJson(data);
      } else {
        print('Error updating user profile: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error updating user profile: $e');
      return null;
    }
  }

  /// Delete a user profile
  static Future<bool> deleteUserProfile(String uniqueId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/users/$uniqueId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        print('Error deleting user profile: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error deleting user profile: $e');
      return false;
    }
  }

  /// Get all user profiles
  static Future<List<UserModel>> getAllUsers() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/users'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => UserModel.fromJson(json)).toList();
      } else {
        print('Error fetching all users: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('Error fetching all users: $e');
      return [];
    }
  }

  /// Upload user photo
  static Future<String?> uploadUserPhoto(String uniqueId, File imageFile) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/users/$uniqueId/photo'),
      );

      request.files.add(
        await http.MultipartFile.fromPath(
          'photo',
          imageFile.path,
          filename: '$uniqueId.jpeg',
        ),
      );

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(responseBody);
        return data['photo_url'];
      } else {
        print('Error uploading photo: ${response.statusCode} - $responseBody');
        return null;
      }
    } catch (e) {
      print('Error uploading photo: $e');
      return null;
    }
  }

  /// Upload user photo from bytes
  static Future<String?> uploadUserPhotoFromBytes(String uniqueId, Uint8List imageBytes, String filename) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/users/$uniqueId/photo'),
      );

      request.files.add(
        http.MultipartFile.fromBytes(
          'photo',
          imageBytes,
          filename: filename,
        ),
      );

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(responseBody);
        return data['photo_url'];
      } else {
        print('Error uploading photo: ${response.statusCode} - $responseBody');
        return null;
      }
    } catch (e) {
      print('Error uploading photo: $e');
      return null;
    }
  }

  /// Get user photo URL
  static String getUserPhotoUrl(String uniqueId) {
    return '$baseUrl/api/users/$uniqueId/photo';
  }

  /// Convenience method to get current user's profile
  static Future<UserModel?> getCurrentUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      return await getUserProfile(user.uid);
    }
    return null;
  }

  /// Convenience method to save current user's profile
  static Future<UserModel?> saveCurrentUserProfile(UserModel userProfile) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Check if profile exists
      final existingProfile = await getUserProfile(user.uid);
      if (existingProfile != null) {
        // Update existing profile
        return await updateUserProfile(user.uid, userProfile);
      } else {
        // Create new profile
        return await createUserProfile(user.uid, userProfile);
      }
    }
    return null;
  }

  /// Get role display names
  static String getRoleDisplayName(String role) {
    switch (role.toLowerCase()) {
      case 'resident':
        return 'Resident';
      case 'staff':
        return 'Staff';
      case 'instructor':
        return 'Instructor';
      case 'service':
        return 'Service Provider';
      case 'caregiver':
        return 'Caregiver';
      default:
        return role.toUpperCase();
    }
  }

  /// Get available roles
  static List<String> getAvailableRoles() {
    return ['resident', 'staff', 'instructor', 'service', 'caregiver'];
  }

  /// Get available marital statuses
  static List<String> getAvailableMaritalStatuses() {
    return ['single', 'married', 'divorced', 'widowed'];
  }

  /// Get available genders
  static List<String> getAvailableGenders() {
    return ['male', 'female', 'other'];
  }

  /// Get available languages
  static List<String> getAvailableLanguages() {
    return ['hebrew', 'english', 'arabic', 'russian', 'french', 'spanish', 'other'];
  }
}