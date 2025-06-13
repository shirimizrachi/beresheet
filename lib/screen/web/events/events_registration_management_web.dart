import 'package:beresheet_app/services/event_service.dart';
import 'package:beresheet_app/services/modern_localization_service.dart';
import 'package:beresheet_app/services/web_auth_service.dart';
import 'package:beresheet_app/config/app_config.dart';
import 'package:beresheet_app/theme/app_theme.dart';
import 'package:beresheet_app/utils/direction_utils.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class EventsRegistrationManagementWeb extends StatefulWidget {
  const EventsRegistrationManagementWeb({Key? key}) : super(key: key);

  @override
  State<EventsRegistrationManagementWeb> createState() => _EventsRegistrationManagementWebState();
}

class _EventsRegistrationManagementWebState extends State<EventsRegistrationManagementWeb> {
  List<Map<String, dynamic>> registrations = [];
  bool isLoading = true;
  String? errorMessage;
  Map<String, String> eventNames = {}; // Cache event names

  @override
  void initState() {
    super.initState();
    _loadRegistrations();
  }

  Future<void> _loadRegistrations() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // Get all registrations
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/api/registrations/all'),
        headers: {
          'Content-Type': 'application/json',
          'homeID': WebAuthService.homeId.toString(),
          'currentUserId': WebAuthService.userId ?? '',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        registrations = data.map((item) => item as Map<String, dynamic>).toList();
        
        // Load event names for display
        await _loadEventNames();
        
        setState(() {
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load registrations: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Error loading registrations: $e';
      });
    }
  }

  Future<void> _loadEventNames() async {
    try {
      // Load all events for managers to get event names
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/api/events'),
        headers: {
          'Content-Type': 'application/json',
          'homeID': WebAuthService.homeId.toString(),
          'userId': WebAuthService.userId ?? '',
        },
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final Map<String, String> names = {};
        for (final eventData in data) {
          names[eventData['id']] = eventData['name'];
        }
        setState(() {
          eventNames = names;
        });
      }
    } catch (e) {
      print('Error loading event names: $e');
    }
  }

  Future<void> _unregisterUser(String eventId, String userId, String userName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Unregister User'),
        content: Text('Are you sure you want to unregister $userName from this event?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Unregister'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final response = await http.delete(
          Uri.parse('${AppConfig.apiBaseUrl}/api/registrations/admin/$eventId/$userId'),
          headers: {
            'Content-Type': 'application/json',
            'homeID': WebAuthService.homeId.toString(),
            'currentUserId': WebAuthService.userId ?? '',
          },
        );

        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('User unregistered successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _loadRegistrations(); // Refresh the list
        } else {
          throw Exception('Failed to unregister user: ${response.statusCode}');
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDateTime(String? dateTimeString) {
    if (dateTimeString == null) return 'N/A';
    try {
      final dateTime = DateTime.parse(dateTimeString);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTimeString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Event Registrations Management',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRegistrations,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadRegistrations,
                        child: Text('Retry'),
                      ),
                    ],
                  ),
                )
              : registrations.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_busy, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No registrations found',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Icon(Icons.info, color: AppColors.primary),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Total Registrations: ${registrations.length}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Card(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                columns: const [
                                  DataColumn(label: Text('Event')),
                                  DataColumn(label: Text('User Name')),
                                  DataColumn(label: Text('Phone')),
                                  DataColumn(label: Text('Registration Date')),
                                  DataColumn(label: Text('Status')),
                                  DataColumn(label: Text('Actions')),
                                ],
                                rows: registrations.map((registration) {
                                  final eventName = eventNames[registration['event_id']] ?? 'Unknown Event';
                                  final userName = registration['user_name'] ?? 'Unknown User';
                                  final userPhone = registration['user_phone'] ?? 'N/A';
                                  final registrationDate = _formatDateTime(registration['registration_date']);
                                  final status = registration['status'] ?? 'unknown';
                                  
                                  return DataRow(
                                    cells: [
                                      DataCell(
                                        Container(
                                          constraints: const BoxConstraints(maxWidth: 200),
                                          child: Text(
                                            eventName,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                      DataCell(Text(userName)),
                                      DataCell(Text(userPhone)),
                                      DataCell(Text(registrationDate)),
                                      DataCell(
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: status == 'registered' ? Colors.green[100] : Colors.orange[100],
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            status.toUpperCase(),
                                            style: TextStyle(
                                              color: status == 'registered' ? Colors.green[700] : Colors.orange[700],
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (status == 'registered')
                                              IconButton(
                                                icon: const Icon(Icons.remove_circle, color: Colors.red),
                                                tooltip: 'Unregister',
                                                onPressed: () => _unregisterUser(
                                                  registration['event_id'],
                                                  registration['user_id'],
                                                  userName,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }
}