import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../config/app_config.dart';
import '../../../services/web_image_cache_service.dart';
import '../../../services/web/web_jwt_session_service.dart';
import '../../../model/event.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../../utils/display_name_utils.dart';
import 'event_form_web.dart';
import 'event_gallery_web.dart';

class EventsManagementWeb extends StatefulWidget {
  const EventsManagementWeb({Key? key}) : super(key: key);

  @override
  State<EventsManagementWeb> createState() => _EventsManagementWebState();
}

class _EventsManagementWebState extends State<EventsManagementWeb> {
  List<Event> _events = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _filterStatus = 'all'; // all, approved, pending-approval, gallery
  List<Event> _galleryEvents = [];

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
      // Load regular events
      final response = await http.get(
        Uri.parse('${AppConfig.apiUrlWithPrefix}/api/events'),
        headers: await WebJwtSessionService.getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> eventsData = json.decode(response.body);
        _events = eventsData.map((data) => Event.fromJson(data)).toList();
      } else {
        setState(() {
          _errorMessage = 'Failed to load events: ${response.statusCode}';
          _isLoading = false;
        });
        return;
      }

      // Load gallery events
      await _loadGalleryEvents();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading events: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadGalleryEvents() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiUrlWithPrefix}/api/events?include_gallery=true'),
        headers: await WebJwtSessionService.getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> eventsData = json.decode(response.body);
        _galleryEvents = eventsData.map((data) => Event.fromJson(data)).toList();
      } else {
        print('Failed to load gallery events: ${response.statusCode}');
        _galleryEvents = [];
      }
    } catch (e) {
      print('Error loading gallery events: $e');
      _galleryEvents = [];
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

  Future<void> _openGallery(Event event) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EventGalleryWeb(event: event),
      ),
    );
  }

  Future<void> _updateEventStatus(String eventId, String newStatus) async {
    try {
      print('Updating event $eventId status to $newStatus'); // Debug log
      
      final request = http.MultipartRequest(
        'PUT',
        Uri.parse('${AppConfig.apiUrlWithPrefix}/api/events/$eventId'),
      );
      
      // Add headers using WebJwtSessionService method
      final authHeaders = await WebJwtSessionService.getAuthHeaders();
      request.headers.addAll(authHeaders);
      
      // Add form field for status
      request.fields['status'] = newStatus;
      
      print('Request headers: ${request.headers}'); // Debug log
      print('Request fields: ${request.fields}'); // Debug log
      
      final response = await request.send();
      print('Response status code: ${response.statusCode}'); // Debug log

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.eventStatusUpdatedTo(DisplayNameUtils.getEventStatusDisplayName(newStatus, context)))),
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

  String _formatDateTime(DateTime date_time) {
    return '${date_time.day}/${date_time.month}/${date_time.year} ${date_time.hour}:${date_time.minute.toString().padLeft(2, '0')}';
  }

  String _formatEventDateTime(Event event) {
    if (event.recurring == 'none' || event.recurring == null) {
      // One-time event - show next_date_time (which should be same as date_time for non-recurring)
      return _formatDateTime(event.next_date_time);
    } else {
      // Recurring event - show explanation of the recurrence
      return _formatRecurringEventDescription(event);
    }
  }

  String _formatRecurringEventDescription(Event event) {
    try {
      final pattern = event.parsedRecurrencePattern;
      if (pattern == null) {
        return _formatDateTime(event.next_date_time); // Fallback to next occurrence
      }

      final time = pattern.time ?? '${event.date_time.hour}:${event.date_time.minute.toString().padLeft(2, '0')}';
      final startDate = '${event.date_time.day}/${event.date_time.month}/${event.date_time.year}';
      final endDate = '${event.recurringEndDate!.day}/${event.recurringEndDate!.month}/${event.recurringEndDate!.year}';
      final nextEventDate = _formatDateTime(event.next_date_time);

      switch (event.recurring) {
        case 'weekly':
          final dayName = _getDayName(pattern.dayOfWeek ?? 0);
          return '${AppLocalizations.of(context)!.everyWeek} $dayName ${AppLocalizations.of(context)!.at} $time\n${AppLocalizations.of(context)!.start}: $startDate - ${AppLocalizations.of(context)!.until} $endDate\n${AppLocalizations.of(context)!.nextEvent}: $nextEventDate';
        
        case 'bi-weekly':
          final dayName = _getDayName(pattern.dayOfWeek ?? 0);
          return '${AppLocalizations.of(context)!.everyTwoWeeks} $dayName ${AppLocalizations.of(context)!.at} $time\n${AppLocalizations.of(context)!.start}: $startDate - ${AppLocalizations.of(context)!.until} $endDate\n${AppLocalizations.of(context)!.nextEvent}: $nextEventDate';
        
        case 'monthly':
          final dayOfMonth = pattern.dayOfMonth ?? 1;
          return '${AppLocalizations.of(context)!.everyMonth} ${AppLocalizations.of(context)!.onDay} $dayOfMonth ${AppLocalizations.of(context)!.at} $time\n${AppLocalizations.of(context)!.start}: $startDate - ${AppLocalizations.of(context)!.until} $endDate\n${AppLocalizations.of(context)!.nextEvent}: $nextEventDate';
        
        default:
          return _formatDateTime(event.next_date_time); // Fallback
      }
    } catch (e) {
      return _formatDateTime(event.next_date_time); // Fallback on error
    }
  }

  String _getDayName(int dayOfWeek) {
    switch (dayOfWeek) {
      case 0: return AppLocalizations.of(context)!.sunday;
      case 1: return AppLocalizations.of(context)!.monday;
      case 2: return AppLocalizations.of(context)!.tuesday;
      case 3: return AppLocalizations.of(context)!.wednesday;
      case 4: return AppLocalizations.of(context)!.thursday;
      case 5: return AppLocalizations.of(context)!.friday;
      case 6: return AppLocalizations.of(context)!.saturday;
      default: return AppLocalizations.of(context)!.sunday;
    }
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
                IconButton(
                  onPressed: _loadEvents,
                  icon: const Icon(Icons.refresh),
                  tooltip: AppLocalizations.of(context)!.refresh,
                  iconSize: 28,
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
                          : _filterStatus == 'gallery'
                              ? 'No Events with Gallery Images'
                              : 'No ${_filterStatus.toUpperCase()} Events',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(AppLocalizations.of(context)!.eventsWillAppearHere),
          ],
        ),
      );
    }

    // Show gallery carousel view for gallery filter
    if (_filterStatus == 'gallery') {
      return _buildGalleryCarouselView(filteredEvents);
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
                  margin: const EdgeInsets.all(10),
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
                  child: WebImageCacheService.buildEventImage(
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
                                _buildDetailRow(Icons.calendar_today, '', _formatEventDateTime(event)),
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
                                _buildDetailRow(Icons.people, AppLocalizations.of(context)!.participants, '${event.current_participants}/${event.max_participants}'),
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
                        // Gallery Button
                        ElevatedButton.icon(
                          onPressed: () => _openGallery(event),
                          icon: Icon(Icons.photo_library, size: 18),
                          label: Text(AppLocalizations.of(context)!.gallery),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        
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
                        SizedBox(
                          height: 36, // Same height as the buttons
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButton<String>(
                              value: event.status,
                              underline: const SizedBox(),
                              icon: Icon(Icons.arrow_drop_down, color: event.status == AppConfig.eventStatusDone ? Colors.grey.shade400 : Colors.grey),
                              items: AppConfig.userSelectableEventStatusOptions.map((status) {
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

  Widget _buildGalleryCarouselView(List<Event> galleryEvents) {
    return PageView.builder(
      itemCount: galleryEvents.length,
      itemBuilder: (context, index) {
        final event = galleryEvents[index];
        return Card(
          margin: const EdgeInsets.all(16),
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                // Left side - Event Details
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Event Title
                      Text(
                        event.name,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
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
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Event Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDetailRow(Icons.calendar_today, AppLocalizations.of(context)!.date_time, _formatEventDateTime(event)),
                            const SizedBox(height: 12),
                            _buildDetailRow(Icons.category, AppLocalizations.of(context)!.webType, DisplayNameUtils.getEventTypeDisplayName(event.type, context)),
                            const SizedBox(height: 12),
                            _buildDetailRow(Icons.location_on, AppLocalizations.of(context)!.location, event.location),
                            const SizedBox(height: 12),
                            _buildDetailRow(Icons.people, AppLocalizations.of(context)!.participants, '${event.current_participants}/${event.max_participants}'),
                            const SizedBox(height: 24),
                            
                            // Description
                            if (event.description.isNotEmpty) ...[
                              Text(
                                AppLocalizations.of(context)!.description,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: Text(
                                  event.description,
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 14,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],
                            
                            // Action Buttons
                            const Spacer(),
                            Row(
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () => _editEvent(event),
                                  icon: const Icon(Icons.edit, size: 18),
                                  label: Text(AppLocalizations.of(context)!.editButton),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                ElevatedButton.icon(
                                  onPressed: () => _openGallery(event),
                                  icon: const Icon(Icons.photo_library, size: 18),
                                  label: Text(AppLocalizations.of(context)!.gallery),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(width: 32),
                
                // Right side - Gallery Images
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${AppLocalizations.of(context)!.gallery} (${AppLocalizations.of(context)!.photoCount(event.gallery_photos?.length ?? 0)})',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      Expanded(
                        child: event.gallery_photos != null && event.gallery_photos!.isNotEmpty
                            ? Container(
                                height: 280, // Fixed height to accommodate 2 rows with spacing
                                child: GridView.builder(
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    childAspectRatio: 1,
                                  ),
                                  itemCount: event.gallery_photos!.length,
                                  itemBuilder: (context, photoIndex) {
                                  final photo = event.gallery_photos![photoIndex];
                                  return Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.grey.withOpacity(0.2),
                                          spreadRadius: 1,
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: WebImageCacheService.buildEventImage(
                                        imageUrl: photo['thumbnail_url'] ?? photo['image_url'],
                                        fit: BoxFit.cover,
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
                                            size: 32,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            )
                            : Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.photo_library_outlined,
                                      size: 64,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      AppLocalizations.of(context)!.noPhotosYet,
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
