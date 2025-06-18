import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../config/app_config.dart';
import '../../../services/image_cache_service.dart';
import '../../../services/web_auth_service.dart';
import '../../../model/event.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../../utils/display_name_utils.dart';
import 'event_form_web.dart';

class EventsManagementWeb extends StatefulWidget {
  const EventsManagementWeb({Key? key}) : super(key: key);

  @override
  State<EventsManagementWeb> createState() => _EventsManagementWebState();
}

class _EventsManagementWebState extends State<EventsManagementWeb> {
  List<Event> _events = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _filterStatus = 'all'; // all, approved, pending-approval

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Show ALL events for everyone - no user filtering
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/api/events'),
        headers: {
          'Content-Type': 'application/json',
          'homeID': WebAuthService.homeId.toString(),
          'userId': WebAuthService.userId ?? '',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> eventsData = json.decode(response.body);
        setState(() {
          _events = eventsData.map((data) => Event.fromJson(data)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load events: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading events: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _editEvent(Event event) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => EventFormWeb(event: event),
      ),
    );
    
    if (result == true) {
      // Refresh the events list after editing
      await _loadEvents();
    }
  }

  Future<void> _updateEventStatus(String eventId, String newStatus) async {
    try {
      print('Updating event $eventId status to $newStatus'); // Debug log
      
      final request = http.MultipartRequest(
        'PUT',
        Uri.parse('${AppConfig.apiBaseUrl}/api/events/$eventId'),
      );
      
      // Add headers using WebAuthService method
      final authHeaders = WebAuthService.getAuthHeaders();
      authHeaders['userId'] = WebAuthService.userId ?? '';
      request.headers.addAll(authHeaders);
      
      // Add form field for status
      request.fields['status'] = newStatus;
      
      print('Request headers: ${request.headers}'); // Debug log
      print('Request fields: ${request.fields}'); // Debug log
      
      final response = await request.send();
      print('Response status code: ${response.statusCode}'); // Debug log

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.eventStatusUpdatedTo(newStatus))),
        );
        await _loadEvents(); // Refresh the list
      } else {
        final responseBody = await response.stream.bytesToString();
        print('Error response body: $responseBody'); // Debug log
        String errorMessage = AppLocalizations.of(context)!.failedToUpdateEventStatus;
        try {
          final errorData = json.decode(responseBody);
          errorMessage = errorData['detail'] ?? errorMessage;
        } catch (e) {
          // Use default error message
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$errorMessage (Status: ${response.statusCode})')),
        );
      }
    } catch (e) {
      print('Exception updating event status: $e'); // Debug log
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.errorUpdatingEvent(e.toString()))),
      );
    }
  }


  List<Event> _getFilteredEvents() {
    // Apply status filtering based on selected filter
    switch (_filterStatus) {
      case 'approved':
        return _events.where((event) => event.status == AppConfig.eventStatusApproved).toList();
      case 'pending-approval':
        return _events.where((event) => event.status == AppConfig.eventStatusPendingApproval).toList();
      default:
        return _events;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
            fontSize: 14,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 14,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case AppConfig.eventStatusApproved:
        return Colors.green;
      case AppConfig.eventStatusPendingApproval:
        return Colors.orange;
      case AppConfig.eventStatusRejected:
        return Colors.red;
      case AppConfig.eventStatusCancelled:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.event, size: 32, color: Colors.blue),
                const SizedBox(width: 16),
                Text(
                  AppLocalizations.of(context)!.webEventsManagement,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _loadEvents,
                  icon: const Icon(Icons.refresh),
                  label: Text(AppLocalizations.of(context)!.refresh),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Filter Row
            Row(
              children: [
                Text(AppLocalizations.of(context)!.filterLabel, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(width: 16),
                ChoiceChip(
                  label: Text(AppLocalizations.of(context)!.all),
                  selected: _filterStatus == 'all',
                  onSelected: (selected) {
                    if (selected) setState(() => _filterStatus = 'all');
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text(AppLocalizations.of(context)!.approved),
                  selected: _filterStatus == 'approved',
                  onSelected: (selected) {
                    if (selected) setState(() => _filterStatus = 'approved');
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text(AppLocalizations.of(context)!.pendingApproval),
                  selected: _filterStatus == 'pending-approval',
                  onSelected: (selected) {
                    if (selected) setState(() => _filterStatus = 'pending-approval');
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Events List
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${AppLocalizations.of(context)!.events} (${_getFilteredEvents().length})',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: _buildEventsList(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventsList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.errorTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(_errorMessage!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadEvents,
              child: Text(AppLocalizations.of(context)!.retryButton),
            ),
          ],
        ),
      );
    }

    final filteredEvents = _getFilteredEvents();

    if (filteredEvents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.event_busy, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              _filterStatus == 'all'
                  ? AppLocalizations.of(context)!.noEventsFound
                  : _filterStatus == 'pending-approval'
                      ? AppLocalizations.of(context)!.noPendingApprovalEvents
                      : _filterStatus == 'approved'
                          ? AppLocalizations.of(context)!.noApprovedEvents
                          : 'No ${_filterStatus.toUpperCase()} Events',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(AppLocalizations.of(context)!.eventsWillAppearHere),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: filteredEvents.length,
      itemBuilder: (context, index) {
        final event = filteredEvents[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Event Image Preview
                Container(
                  width: 100,
                  height: 100,
                  margin: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: ImageCacheService.buildEventImage(
                    imageUrl: event.imageUrl.isNotEmpty ? event.imageUrl : null,
                    fit: BoxFit.cover,
                    borderRadius: BorderRadius.circular(12),
                    placeholder: Container(
                      color: Colors.grey.shade100,
                      child: const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                    errorWidget: Container(
                      color: Colors.grey.shade100,
                      child: const Icon(
                        Icons.image_not_supported,
                        color: Colors.grey,
                        size: 40,
                      ),
                    ),
                  ),
                ),
                
                // Event Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Event Title
                      Text(
                        event.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      // Event Details Grid
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildDetailRow(Icons.calendar_today, AppLocalizations.of(context)!.webDate, _formatDateTime(event.dateTime)),
                                const SizedBox(height: 4),
                                _buildDetailRow(Icons.category, AppLocalizations.of(context)!.webType, DisplayNameUtils.getEventTypeDisplayName(event.type, context)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildDetailRow(Icons.location_on, AppLocalizations.of(context)!.location, event.location),
                                const SizedBox(height: 4),
                                _buildDetailRow(Icons.people, AppLocalizations.of(context)!.participants, '${event.currentParticipants}/${event.maxParticipants}'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      // Description
                      if (event.description.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Text(
                            event.description,
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Status and Actions Column
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: _getStatusColor(event.status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _getStatusColor(event.status), width: 1.5),
                      ),
                      child: Text(
                        DisplayNameUtils.getEventStatusDisplayName(event.status, context),
                        style: TextStyle(
                          color: _getStatusColor(event.status),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Action Buttons Row
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Edit Button
                        ElevatedButton.icon(
                          onPressed: () => _editEvent(event),
                          icon: Icon(event.status == AppConfig.eventStatusDone ? Icons.visibility : Icons.edit, size: 18),
                          label: Text(event.status == AppConfig.eventStatusDone
                              ? AppLocalizations.of(context)!.viewDetails
                              : AppLocalizations.of(context)!.editButton),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: event.status == AppConfig.eventStatusDone ? Colors.grey : Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        
                        // Status Dropdown
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButton<String>(
                            value: event.status,
                            underline: const SizedBox(),
                            icon: Icon(Icons.arrow_drop_down, color: event.status == AppConfig.eventStatusDone ? Colors.grey.shade400 : Colors.grey),
                            items: AppConfig.eventStatusOptions.map((status) {
                              return DropdownMenuItem(
                                value: status,
                                child: Text(
                                  DisplayNameUtils.getEventStatusDisplayName(status, context),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: event.status == AppConfig.eventStatusDone ? Colors.grey.shade400 : null,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: event.status == AppConfig.eventStatusDone ? null : (newStatus) {
                              if (newStatus != null && newStatus != event.status) {
                                _updateEventStatus(event.id, newStatus);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}