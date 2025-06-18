import 'package:beresheet_app/services/event_service.dart';
import 'package:beresheet_app/services/modern_localization_service.dart';
import 'package:beresheet_app/services/web_auth_service.dart';
import 'package:beresheet_app/config/app_config.dart';
import 'package:beresheet_app/theme/app_theme.dart';
import 'package:beresheet_app/utils/direction_utils.dart';
import 'package:beresheet_app/screen/web/events/event_vote_review_web.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

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
        errorMessage = AppLocalizations.of(context)!.errorMessage(e.toString());
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
        title: Text(AppLocalizations.of(context)!.unregisterUser),
        content: Text(AppLocalizations.of(context)!.areYouSureUnregisterUser(userName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(AppLocalizations.of(context)!.unregister),
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
              content: Text(AppLocalizations.of(context)!.userUnregisteredSuccessfully),
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
            content: Text(AppLocalizations.of(context)!.errorMessage(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDateTime(String? dateTimeString) {
    if (dateTimeString == null) return AppLocalizations.of(context)!.notAvailable;
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
          AppLocalizations.of(context)!.eventRegistrationsManagementTitle,
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
            tooltip: AppLocalizations.of(context)!.refreshTooltip,
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
                        child: Text(AppLocalizations.of(context)!.retryButton),
                      ),
                    ],
                  ),
                )
              : registrations.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.event_busy, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            AppLocalizations.of(context)!.noRegistrationsFound,
                            style: const TextStyle(
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
                                      AppLocalizations.of(context)!.totalRegistrations(registrations.length),
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
                                columns: [
                                  DataColumn(label: Text(AppLocalizations.of(context)!.eventColumn)),
                                  DataColumn(label: Text(AppLocalizations.of(context)!.userNameColumn)),
                                  DataColumn(label: Text(AppLocalizations.of(context)!.phoneColumn)),
                                  DataColumn(label: Text(AppLocalizations.of(context)!.registrationDateColumn)),
                                  DataColumn(label: Text(AppLocalizations.of(context)!.statusColumn)),
                                  DataColumn(label: Text('Vote')),
                                  DataColumn(label: Text('Reviews')),
                                  DataColumn(label: Text(AppLocalizations.of(context)!.actionsColumn)),
                                ],
                                rows: registrations.map((registration) {
                                  final eventName = eventNames[registration['event_id']] ?? AppLocalizations.of(context)!.unknownEvent;
                                  final userName = registration['user_name'] ?? AppLocalizations.of(context)!.unknownUser;
                                  final userPhone = registration['user_phone'] ?? AppLocalizations.of(context)!.notAvailable;
                                  final registrationDate = _formatDateTime(registration['registration_date']);
                                  final status = registration['status'] ?? 'unknown';
                                  final vote = registration['vote'];
                                  final reviews = registration['reviews'];
                                  
                                  // Parse reviews to count them
                                  int reviewCount = 0;
                                  if (reviews != null && reviews.toString().isNotEmpty) {
                                    try {
                                      final reviewsList = json.decode(reviews.toString());
                                      if (reviewsList is List) {
                                        reviewCount = reviewsList.length;
                                      }
                                    } catch (e) {
                                      // Ignore parsing errors
                                    }
                                  }
                                  
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
                                        vote != null
                                            ? Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: List.generate(5, (index) {
                                                  return Icon(
                                                    index < vote ? Icons.star : Icons.star_border,
                                                    size: 16,
                                                    color: index < vote ? Colors.amber : Colors.grey,
                                                  );
                                                }),
                                              )
                                            : Text('No vote', style: TextStyle(color: Colors.grey[600])),
                                      ),
                                      DataCell(
                                        reviewCount > 0
                                            ? Text('$reviewCount review${reviewCount > 1 ? 's' : ''}')
                                            : Text('No reviews', style: TextStyle(color: Colors.grey[600])),
                                      ),
                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.rate_review, color: Colors.blue),
                                              tooltip: 'Vote & Review',
                                              onPressed: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => EventVoteReviewWeb(
                                                      eventRegistrationId: registration['id'],
                                                      eventId: registration['event_id'],
                                                      eventName: eventName,
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
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