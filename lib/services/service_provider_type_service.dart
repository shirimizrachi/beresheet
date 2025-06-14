import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:beresheet_app/model/service_provider_type.dart';
import 'package:beresheet_app/config/app_config.dart';
import 'package:beresheet_app/services/web_auth_service.dart';

class ServiceProviderTypeService {
  static const String _baseUrl = '${AppConfig.apiBaseUrl}/api/service-provider-types';

  /// Get all service provider types
  static Future<List<ServiceProviderType>> getServiceProviderTypes({
    required int homeId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'homeID': homeId.toString(),
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => ServiceProviderType.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load service provider types: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading service provider types: $e');
    }
  }

  /// Get a specific service provider type by ID
  static Future<ServiceProviderType?> getServiceProviderType({
    required int typeId,
    required int homeId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/$typeId'),
        headers: {
          'Content-Type': 'application/json',
          'homeID': homeId.toString(),
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return ServiceProviderType.fromJson(data);
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw Exception('Failed to load service provider type: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading service provider type: $e');
    }
  }

  /// Create a new service provider type (Manager role required)
  static Future<ServiceProviderType?> createServiceProviderType({
    required String name,
    String? description,
    required int homeId,
    required String currentUserId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'homeID': homeId.toString(),
          'currentUserId': currentUserId,
        },
        body: json.encode({
          'name': name,
          'description': description,
        }),
      );

      if (response.statusCode == 201) {
        final Map<String, dynamic> data = json.decode(response.body);
        return ServiceProviderType.fromJson(data);
      } else {
        throw Exception('Failed to create service provider type: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error creating service provider type: $e');
    }
  }

  /// Update a service provider type (only description can be updated, Manager role required)
  static Future<ServiceProviderType?> updateServiceProviderType({
    required int typeId,
    String? description,
    required int homeId,
    required String currentUserId,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/$typeId'),
        headers: {
          'Content-Type': 'application/json',
          'homeID': homeId.toString(),
          'currentUserId': currentUserId,
        },
        body: json.encode({
          'description': description,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return ServiceProviderType.fromJson(data);
      } else {
        throw Exception('Failed to update service provider type: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error updating service provider type: $e');
    }
  }

  /// Delete a service provider type (Manager role required)
  static Future<bool> deleteServiceProviderType({
    required int typeId,
    required int homeId,
    required String currentUserId,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/$typeId'),
        headers: {
          'Content-Type': 'application/json',
          'homeID': homeId.toString(),
          'currentUserId': currentUserId,
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Error deleting service provider type: $e');
    }
  }

  /// Get all service provider types using WebAuthService for web authentication
  static Future<List<ServiceProviderType>> getServiceProviderTypesWeb() async {
    try {
      final headers = WebAuthService.getAuthHeaders();
      
      final response = await http.get(
        Uri.parse(_baseUrl),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => ServiceProviderType.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load service provider types: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading service provider types: $e');
    }
  }

  /// Create a new service provider type using WebAuthService for web authentication
  static Future<ServiceProviderType?> createServiceProviderTypeWeb({
    required String name,
    String? description,
  }) async {
    try {
      final headers = WebAuthService.getAuthHeaders();
      headers['currentUserId'] = WebAuthService.userId ?? '';
      
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: headers,
        body: json.encode({
          'name': name,
          'description': description,
        }),
      );

      if (response.statusCode == 201) {
        final Map<String, dynamic> data = json.decode(response.body);
        return ServiceProviderType.fromJson(data);
      } else {
        throw Exception('Failed to create service provider type: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error creating service provider type: $e');
    }
  }

  /// Update a service provider type using WebAuthService for web authentication
  static Future<ServiceProviderType?> updateServiceProviderTypeWeb({
    required int typeId,
    String? description,
  }) async {
    try {
      final headers = WebAuthService.getAuthHeaders();
      headers['currentUserId'] = WebAuthService.userId ?? '';
      
      final response = await http.put(
        Uri.parse('$_baseUrl/$typeId'),
        headers: headers,
        body: json.encode({
          'description': description,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return ServiceProviderType.fromJson(data);
      } else {
        throw Exception('Failed to update service provider type: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error updating service provider type: $e');
    }
  }

  /// Delete a service provider type using WebAuthService for web authentication
  static Future<bool> deleteServiceProviderTypeWeb({
    required int typeId,
  }) async {
    try {
      final headers = WebAuthService.getAuthHeaders();
      headers['currentUserId'] = WebAuthService.userId ?? '';
      
      final response = await http.delete(
        Uri.parse('$_baseUrl/$typeId'),
        headers: headers,
      );

      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Error deleting service provider type: $e');
    }
  }
}