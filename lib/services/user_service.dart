import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  static const String _usersKey = 'users_data';

  static Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final usersJson = prefs.getString(_usersKey);
      
      if (usersJson != null) {
        final List<dynamic> users = json.decode(usersJson);
        for (var user in users) {
          if (user['uid'] == userId) {
            return Map<String, dynamic>.from(user);
          }
        }
      }
      return null;
    } catch (e) {
      print('Error loading user profile: $e');
      return null;
    }
  }

  static Future<bool> saveUserProfile(Map<String, dynamic> userProfile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final usersJson = prefs.getString(_usersKey);
      
      List<dynamic> users = [];
      if (usersJson != null) {
        users = json.decode(usersJson);
      }

      // Remove existing user profile if it exists
      users.removeWhere((user) => user['uid'] == userProfile['uid']);
      
      // Add updated profile
      users.add(userProfile);
      
      // Save back to SharedPreferences
      await prefs.setString(_usersKey, json.encode(users));
      
      // Mark user as having completed profile setup
      await prefs.setBool('user_profile_complete_${userProfile['uid']}', true);
      
      return true;
    } catch (e) {
      print('Error saving user profile: $e');
      return false;
    }
  }

  static Future<bool> isUserProfileComplete(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('user_profile_complete_$userId') ?? false;
    } catch (e) {
      print('Error checking profile completion: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> createBasicUserProfile(User user) async {
    try {
      final basicProfile = {
        'uid': user.uid,
        'phoneNumber': user.phoneNumber ?? '',
        'fullName': '',
        'address': '',
        'favoriteActivities': <String>[],
        'lastUpdated': DateTime.now().toIso8601String(),
        'isComplete': false,
      };
      
      final success = await saveUserProfile(basicProfile);
      if (success) {
        return basicProfile;
      }
      return null;
    } catch (e) {
      print('Error creating basic profile: $e');
      return null;
    }
  }

  static Future<List<String>> getAllActivityTypes() async {
    try {
      final String response = await rootBundle.loadString('assets/data/events.json');
      final List<dynamic> events = json.decode(response);
      
      Set<String> activityTypes = {};
      for (var event in events) {
        if (event['type'] != null) {
          activityTypes.add(event['type'].toString().toLowerCase());
        }
      }
      
      return activityTypes.toList()..sort();
    } catch (e) {
      print('Error loading activity types: $e');
      return ['class', 'performance', 'cultural', 'leisure'];
    }
  }

  static String getActivityDisplayName(String type) {
    switch (type.toLowerCase()) {
      case 'class':
        return 'Classes';
      case 'performance':
        return 'Performances';
      case 'cultural':
        return 'Cultural';
      case 'leisure':
        return 'Leisure';
      default:
        return type.toUpperCase();
    }
  }

  static Map<String, String> getActivityDetails(String type) {
    switch (type.toLowerCase()) {
      case 'class':
        return {
          'icon': 'school',
          'color': 'blue',
          'description': 'Educational classes and workshops'
        };
      case 'performance':
        return {
          'icon': 'theater_comedy',
          'color': 'purple', 
          'description': 'Live shows and entertainment'
        };
      case 'cultural':
        return {
          'icon': 'palette',
          'color': 'orange',
          'description': 'Cultural activities and arts'
        };
      case 'leisure':
        return {
          'icon': 'nature_people',
          'color': 'green',
          'description': 'Relaxing and recreational activities'
        };
      default:
        return {
          'icon': 'event',
          'color': 'grey',
          'description': 'Various activities'
        };
    }
  }
}