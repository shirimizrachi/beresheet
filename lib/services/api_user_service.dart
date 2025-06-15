import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../model/user.dart';
import 'user_session_service.dart';
import '../config/app_config.dart';
import 'firebase_messaging_service.dart';

class ApiUserService {
  // Use different URLs for web vs mobile platforms
  static String get baseUrl {
    if (kIsWeb) {
      return AppConfig.apiBaseUrl; // Web can use localhost
    } else {
      return 'http://10.0.2.2:8000'; // Android emulator uses 10.0.2.2
    }
  }

  /// Get user profile by user ID
  static Future<UserModel?> getUserProfile(String userId) async {
    try {
      final headers = await UserSessionService.getApiHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/users/$userId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final user = UserModel.fromJson(data);
        // Store user session data after successful fetch
        await UserSessionService.sethomeID(user.homeID);
        await UserSessionService.setRole(user.role);
        await UserSessionService.setUserId(user.id);
        await UserSessionService.setPhoto(user.photo);
        return user;
      } else if (response.statusCode == 404) {
        return null; // User not found
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        print('Authentication error fetching user profile: ${response.statusCode}');
        throw Exception('Authentication error: ${response.statusCode}');
      } else {
        print('Error fetching user profile: ${response.statusCode} - ${response.body}');
        throw Exception('API error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching user profile: $e');
      // Re-throw to allow caller to handle different error types
      rethrow;
    }
  }

  /// Get user profile by phone number
  static Future<UserModel?> getUserProfileByPhone(String phoneNumber, int homeId) async {
    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'homeID': homeId.toString(),
      };
      
      // Add Firebase token if available
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final token = await user.getIdToken();
          if (token != null) {
            headers['firebaseToken'] = token;
          }
        }
      } catch (e) {
        print('Error getting Firebase token: $e');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/users/by-phone'),
        headers: headers,
        body: json.encode({'phone_number': phoneNumber}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final user = UserModel.fromJson(data);
        // Store user session data after successful fetch
        await UserSessionService.sethomeID(user.homeID);
        await UserSessionService.setRole(user.role);
        await UserSessionService.setUserId(user.id);
        await UserSessionService.setPhoto(user.photo);
        return user;
      } else if (response.statusCode == 404) {
        return null; // User not found
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        print('Authentication error fetching user profile by phone: ${response.statusCode}');
        throw Exception('Authentication error: ${response.statusCode}');
      } else {
        print('Error fetching user profile by phone: ${response.statusCode} - ${response.body}');
        throw Exception('API error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching user profile by phone: $e');
      // Re-throw to allow caller to handle different error types
      rethrow;
    }
  }

  /// Create a new user profile (requires manager role and homeID header)
  static Future<UserModel?> createUserProfile(UserModel user, String currentUserId, {String? firebaseId}) async {
    try {
      final headers = await UserSessionService.getApiHeaders();
      headers['currentUserId'] = currentUserId; // Add current user ID for role validation
      if (firebaseId != null) {
        headers['firebaseId'] = firebaseId; // Optional firebase ID for linking
      }
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/users'),
        headers: headers,
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

  /// Create a new user profile with minimal data (homeID and phone only)
  static Future<UserModel?> createUserProfileMinimal(int homeID, String phoneNumber, String currentUserId, {String? firebaseId}) async {
    try {
      final headers = await UserSessionService.getApiHeaders();
      headers['currentUserId'] = currentUserId; // Add current user ID for role validation
      if (firebaseId != null) {
        headers['firebaseId'] = firebaseId; // Optional firebase ID for linking
      }
      
      final minimalData = {
        'home_id': homeID,
        'phone_number': phoneNumber,
      };
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/users'),
        headers: headers,
        body: json.encode(minimalData),
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

  /// Update an existing user profile with optional image upload
  static Future<UserModel?> updateUserProfile(String userId, UserModel user, {File? imageFile}) async {
    try {
      // Always use multipart request for consistency with API
      var request = http.MultipartRequest(
        'PUT',
        Uri.parse('$baseUrl/api/users/$userId'),
      );

      // Add headers including homeID
      final headers = await UserSessionService.getApiHeaders();
      request.headers.addAll(headers);

      // Add form fields - only send non-null and non-empty values
      if (user.fullName != null && user.fullName!.isNotEmpty) {
        request.fields['full_name'] = user.fullName!;
      }
      if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
        request.fields['phone_number'] = user.phoneNumber!;
      }
      if (user.role != null && user.role!.isNotEmpty) {
        request.fields['role'] = user.role!;
      }
      if (user.apartmentNumber != null && user.apartmentNumber!.isNotEmpty) {
        request.fields['apartment_number'] = user.apartmentNumber!;
      }
      if (user.maritalStatus != null && user.maritalStatus!.isNotEmpty) {
        request.fields['marital_status'] = user.maritalStatus!;
      }
      if (user.gender != null && user.gender!.isNotEmpty) {
        request.fields['gender'] = user.gender!;
      }
      if (user.religious != null && user.religious!.isNotEmpty) {
        request.fields['religious'] = user.religious!;
      }
      if (user.nativeLanguage != null && user.nativeLanguage!.isNotEmpty) {
        request.fields['native_language'] = user.nativeLanguage!;
      }
      
      if (user.birthday != null) {
        request.fields['birthday'] = user.birthday!.toIso8601String();
      }

      // Add image file if provided
      if (imageFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'photo',
            imageFile.path,
            filename: '$userId.jpeg',
            contentType: MediaType.parse('image/jpeg'),
          ),
        );
      }

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(responseBody);
        final updatedUser = UserModel.fromJson(data);
        // Update session with latest data
        await UserSessionService.sethomeID(updatedUser.homeID);
        await UserSessionService.setRole(updatedUser.role);
        await UserSessionService.setUserId(updatedUser.id);
        await UserSessionService.setPhoto(updatedUser.photo);
        return updatedUser;
      } else {
        print('Error updating user profile with image: ${response.statusCode} - $responseBody');
        return null;
      }
    } catch (e) {
      print('Error updating user profile: $e');
      return null;
    }
  }

  /// Update only the Firebase FCM token for a user
  static Future<bool> updateFirebaseFcmToken(String userId, String fcmToken) async {
    try {
      final headers = await UserSessionService.getApiHeaders();
      final response = await http.patch(
        Uri.parse('$baseUrl/api/users/$userId/fcm-token'),
        headers: headers,
        body: json.encode({'firebase_fcm_token': fcmToken}),
      );

      if (response.statusCode == 200) {
        print('FCM token updated successfully for user $userId');
        return true;
      } else {
        print('Error updating FCM token: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error updating FCM token: $e');
      return false;
    }
  }

  /// Check and update Firebase FCM token if needed
  static Future<void> checkAndUpdateFcmToken(String userId) async {
    try {
      // Get the current FCM token
      final currentToken = await FirebaseMessagingService.getFcmToken();
      
      if (currentToken != null) {
        // Get the user profile to check existing token
        final userProfile = await getUserProfile(userId);
        
        if (userProfile != null) {
          // Check if the token is different or missing
          if (userProfile.firebaseFcmToken != currentToken) {
            print('Updating FCM token for user $userId');
            await updateFirebaseFcmToken(userId, currentToken);
          }
        }
      }
    } catch (e) {
      print('Error checking and updating FCM token: $e');
    }
  }

  /// Delete a user profile
  static Future<bool> deleteUserProfile(String userId) async {
    try {
      final headers = await UserSessionService.getApiHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/api/users/$userId'),
        headers: headers,
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
      final headers = await UserSessionService.getApiHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/users'),
        headers: headers,
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
  static Future<String?> uploadUserPhoto(String userId, File imageFile) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/users/$userId/photo'),
      );

      // Add headers including homeID
      final headers = await UserSessionService.getApiHeaders();
      request.headers.addAll(headers);

      request.files.add(
        await http.MultipartFile.fromPath(
          'photo',
          imageFile.path,
          filename: '$userId.jpeg',
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
  static Future<String?> uploadUserPhotoFromBytes(String userId, Uint8List imageBytes, String filename) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/users/$userId/photo'),
      );

      // Add headers including homeID
      final headers = await UserSessionService.getApiHeaders();
      request.headers.addAll(headers);

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
  static String getUserPhotoUrl(String userId) {
    return '$baseUrl/api/users/$userId/photo';
  }

  /// Convenience method to get current user's profile
  static Future<UserModel?> getCurrentUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // First try to get from session
      final userId = await UserSessionService.getUserId();
      if (userId != null) {
        return await getUserProfile(userId);
      }
      // Fallback: search by firebase ID (this might need to be handled differently)
      // For now, return null and let the app handle user creation
      return null;
    }
    return null;
  }

  /// Convenience method to save current user's profile
  static Future<UserModel?> saveCurrentUserProfile(UserModel userProfile) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Check if profile exists using stored userId
      final userId = await UserSessionService.getUserId();
      if (userId != null) {
        final existingProfile = await getUserProfile(userId);
        if (existingProfile != null) {
          // Update existing profile
          return await updateUserProfile(userId, userProfile);
        }
      }
      // Create new profile (requires manager role) with firebase ID for linking
      return await createUserProfile(userProfile, user.uid, firebaseId: user.uid);
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
      case 'manager':
        return 'Manager';
      default:
        return role.toUpperCase();
    }
  }

  /// Get available roles
  static List<String> getAvailableRoles() {
    return ['resident', 'staff', 'instructor', 'service', 'caregiver', 'manager'];
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