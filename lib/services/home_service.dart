import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

/// Model for Home data
class Home {
  final int id;
  final String name;
  final String schema;

  Home({
    required this.id,
    required this.name,
    required this.schema,
  });

  factory Home.fromJson(Map<String, dynamic> json) {
    return Home(
      id: json['id'] as int,
      name: json['name'] as String,
      schema: json['schema'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'schema': schema,
    };
  }
}

class HomeService {
  static const String baseUrl = AppConfig.apiBaseUrl;

  /// Get all available homes
  static Future<List<Home>> getAvailableHomes() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/homes'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Home.fromJson(json)).toList();
      } else {
        print('Failed to get available homes: ${response.statusCode}');
        print('Response body: ${response.body}');
        return [];
      }
    } catch (e) {
      print('Error getting available homes: $e');
      return [];
    }
  }
}