import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:beresheet_app/config/app_config.dart';
import 'package:beresheet_app/services/user_session_service.dart';
import 'package:beresheet_app/services/modern_localization_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final headers = await UserSessionService.getApiHeaders();
      final userId = await UserSessionService.getUserId();
      
      if (userId == null) {
        throw Exception('User not logged in');
      }

      final response = await http.get(
        Uri.parse('${AppConfig.apiUrlWithPrefix}/api/user-notifications'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _notifications = data.cast<Map<String, dynamic>>();
        });
      } else {
        throw Exception('Failed to load notifications: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _markNotificationAsRead(String notificationId) async {
    try {
      final headers = await UserSessionService.getApiHeaders();
      
      // Create a PATCH request to mark notification as read
      final response = await http.patch(
        Uri.parse('${AppConfig.apiUrlWithPrefix}/api/user-notifications/$notificationId/read'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        // Reload notifications to reflect the change
        _loadNotifications();
      } else {
        print('Failed to mark notification as read: ${response.statusCode}');
      }
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? const Center(
                  child: Text('No notifications found'),
                )
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      final notification = _notifications[index];
                      return Card(
                        child: ListTile(
                          title: Text(notification['notification_sender_user_name'] ?? 'Unknown Sender'),
                          subtitle: Text(notification['notification_message'] ?? 'No message'),
                          trailing: notification['user_read_date'] != null
                              ? const Icon(Icons.check, color: Colors.green)
                              : const Icon(Icons.circle, color: Colors.blue),
                          leading: CircleAvatar(
                            child: Text(
                              (notification['notification_sender_user_name'] ?? 'U')[0].toUpperCase(),
                            ),
                          ),
                          onTap: () {
                            // Mark as read when tapped
                            _markNotificationAsRead(notification['id'].toString());
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
