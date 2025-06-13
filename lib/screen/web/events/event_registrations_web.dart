import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:beresheet_app/services/web_auth_service.dart';
import 'package:beresheet_app/config/app_config.dart';

class EventRegistrationsWeb extends StatefulWidget {
  const EventRegistrationsWeb({Key? key}) : super(key: key);

  @override
  State<EventRegistrationsWeb> createState() => _EventRegistrationsWebState();
}

class _EventRegistrationsWebState extends State<EventRegistrationsWeb> {
  List<Map<String, dynamic>> _events = [];
  List<Map<String, dynamic>> _registrations = [];
  String? _selectedEventId;
  String? _selectedEventTitle;
  bool _isLoadingEvents = true;
  bool _isLoadingRegistrations = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  void _checkPermissions() {
    final userRole = WebAuthService.userRole ?? '';
    if (userRole != 'manager' && userRole != 'staff') {
      setState(() {
        _errorMessage = 'Access denied: Manager or Staff role required to view event registrations';
        _isLoadingEvents = false;
      });
      return;
    }
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _isLoadingEvents = true;
      _errorMessage = null;
    });

    try {
      final headers = WebAuthService.getAuthHeaders();
      
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/api/events'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> eventsJson = json.decode(response.body);
        setState(() {
          _events = eventsJson.cast<Map<String, dynamic>>();
          _isLoadingEvents = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load events: ${response.statusCode}';
          _isLoadingEvents = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading events: $e';
        _isLoadingEvents = false;
      });
    }
  }

  Future<void> _loadEventRegistrations(String eventId, String eventTitle) async {
    setState(() {
      _isLoadingRegistrations = true;
      _selectedEventId = eventId;
      _selectedEventTitle = eventTitle;
      _registrations = [];
    });

    try {
      final headers = WebAuthService.getAuthHeaders();
      
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/api/registrations/event/$eventId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> registrationsJson = json.decode(response.body);
        setState(() {
          _registrations = registrationsJson.cast<Map<String, dynamic>>();
          _isLoadingRegistrations = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load registrations: ${response.statusCode}';
          _isLoadingRegistrations = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading registrations: $e';
        _isLoadingRegistrations = false;
      });
    }
  }

  Future<void> _removeRegistration(String eventId, String userId, String userName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Removal'),
        content: Text('Remove $userName from this event?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final headers = WebAuthService.getAuthHeaders();
      
      final response = await http.delete(
        Uri.parse('${AppConfig.apiBaseUrl}/api/registrations/admin/$eventId/$userId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        // Reload registrations for the current event
        if (_selectedEventId != null && _selectedEventTitle != null) {
          _loadEventRegistrations(_selectedEventId!, _selectedEventTitle!);
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$userName removed from event successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove registration: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error removing registration: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  String _formatEventType(String type) {
    switch (type) {
      case 'activity': return 'Activity';
      case 'course': return 'Course';
      case 'workshop': return 'Workshop';
      case 'seminar': return 'Seminar';
      case 'social': return 'Social';
      case 'sports': return 'Sports';
      case 'cultural': return 'Cultural';
      case 'educational': return 'Educational';
      default: return type.toUpperCase();
    }
  }

  Color _getEventTypeColor(String type) {
    switch (type) {
      case 'activity': return Colors.blue;
      case 'course': return Colors.green;
      case 'workshop': return Colors.orange;
      case 'seminar': return Colors.purple;
      case 'social': return Colors.pink;
      case 'sports': return Colors.red;
      case 'cultural': return Colors.indigo;
      case 'educational': return Colors.teal;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check permissions first
    final userRole = WebAuthService.userRole ?? '';
    if (userRole != 'manager' && userRole != 'staff') {
      return _buildAccessDeniedPage();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Event Registrations',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.blue[700],
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadEvents,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoadingEvents) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorPage();
    }

    return Row(
      children: [
        // Events List (Left Side)
        Expanded(
          flex: 2,
          child: _buildEventsList(),
        ),
        
        const VerticalDivider(width: 1),
        
        // Registrations List (Right Side)
        Expanded(
          flex: 3,
          child: _buildRegistrationsList(),
        ),
      ],
    );
  }

  Widget _buildEventsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16.0),
          color: Colors.grey[100],
          child: Row(
            children: [
              const Icon(Icons.event, color: Colors.blue),
              const SizedBox(width: 8),
              Text(
                'Events (${_events.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        
        Expanded(
          child: _events.isEmpty
              ? const Center(
                  child: Text(
                    'No events found',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: _events.length,
                  itemBuilder: (context, index) {
                    final event = _events[index];
                    final isSelected = _selectedEventId == event['id'];
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      color: isSelected ? Colors.blue[50] : null,
                      child: ListTile(
                        title: Text(
                          event['title'] ?? 'Untitled Event',
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getEventTypeColor(event['type'] ?? ''),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _formatEventType(event['type'] ?? ''),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(_formatDate(event['date_time'])),
                            Text('${event['current_participants'] ?? 0}/${event['max_participants'] ?? 0} participants'),
                          ],
                        ),
                        onTap: () => _loadEventRegistrations(
                          event['id'],
                          event['title'] ?? 'Untitled Event',
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.arrow_forward_ios, color: Colors.blue)
                            : null,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildRegistrationsList() {
    if (_selectedEventId == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.arrow_back,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'Select an event to view registrations',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16.0),
          color: Colors.grey[100],
          child: Row(
            children: [
              const Icon(Icons.people, color: Colors.green),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Registrations for: $_selectedEventTitle',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${_registrations.length} participants',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        Expanded(
          child: _isLoadingRegistrations
              ? const Center(child: CircularProgressIndicator())
              : _registrations.isEmpty
                  ? const Center(
                      child: Text(
                        'No registrations found for this event',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _registrations.length,
                      itemBuilder: (context, index) {
                        final registration = _registrations[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.blue,
                              child: Text(
                                (registration['user_name'] ?? 'U')[0].toUpperCase(),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(registration['user_name'] ?? 'Unknown User'),
                            subtitle: Text(
                              'Registered: ${_formatDate(registration['registration_date'])}',
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.remove_circle, color: Colors.red),
                              onPressed: () => _removeRegistration(
                                registration['event_id'],
                                registration['user_id'],
                                registration['user_name'] ?? 'Unknown User',
                              ),
                              tooltip: 'Remove from event',
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildErrorPage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red[400],
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            style: const TextStyle(
              fontSize: 18,
              color: Colors.red,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadEvents,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessDeniedPage() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Registrations'),
        backgroundColor: Colors.red[700],
      ),
      body: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Access Denied',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Event registration management requires Manager or Staff role.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}