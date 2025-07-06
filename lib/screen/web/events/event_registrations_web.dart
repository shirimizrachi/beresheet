import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:beresheet_app/services/web/web_jwt_auth_service.dart';
import 'package:beresheet_app/config/app_config.dart';
import 'package:beresheet_app/utils/display_name_utils.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

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

  void _checkPermissions() async {
    final user = await WebJwtAuthService.getCurrentUser();
    final userRole = user?.role ?? '';
    if (userRole != 'manager' && userRole != 'staff') {
      setState(() {
        _errorMessage = AppLocalizations.of(context)?.eventRegistrationsManagementRequiresRole ??
                       'Access denied: Manager or Staff role required to view event registrations';
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
      final headers = await WebJwtAuthService.getAuthHeaders();
      
      final response = await http.get(
        Uri.parse('${AppConfig.apiUrlWithPrefix}/api/events'),
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
          _errorMessage = '${AppLocalizations.of(context)?.failedToLoadEvents ?? 'Failed to load events'}: ${response.statusCode}';
          _isLoadingEvents = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '${AppLocalizations.of(context)?.error ?? 'Error'} loading events: $e';
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
      final headers = await WebJwtAuthService.getAuthHeaders();
      
      final response = await http.get(
        Uri.parse('${AppConfig.apiUrlWithPrefix}/api/registrations/event/$eventId'),
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
          _errorMessage = '${AppLocalizations.of(context)?.operationFailed ?? 'Failed to load registrations'}: ${response.statusCode}';
          _isLoadingRegistrations = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '${AppLocalizations.of(context)?.error ?? 'Error'} loading registrations: $e';
        _isLoadingRegistrations = false;
      });
    }
  }

  Future<void> _removeRegistration(String eventId, String userId, String userName) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.unregisterUser),
        content: Text(l10n.areYouSureUnregisterUser(userName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.unregister),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final headers = await WebJwtAuthService.getAuthHeaders();
      
      final response = await http.delete(
        Uri.parse('${AppConfig.apiUrlWithPrefix}/api/registrations/admin/$eventId/$userId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        // Reload registrations for the current event
        if (_selectedEventId != null && _selectedEventTitle != null) {
          _loadEventRegistrations(_selectedEventId!, _selectedEventTitle!);
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.userUnregisteredSuccessfully),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.operationFailed}: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.errorMessage(e.toString())),
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
    return DisplayNameUtils.getEventTypeDisplayName(type, context);
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.eventRegistrations,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.blue[700],
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadEvents,
            tooltip: AppLocalizations.of(context)!.refresh,
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
                '${AppLocalizations.of(context)!.events} (${_events.length})',
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
              ? Center(
                  child: Text(
                    AppLocalizations.of(context)!.noEventsFound,
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
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
                          event['name'] ?? event['title'] ?? AppLocalizations.of(context)!.unknownEvent,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
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
                            Row(
                              children: [
                                const Icon(Icons.access_time, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(_formatDate(event['date_time'] ?? event['dateTime'])),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(Icons.location_on, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    event['location'] ?? AppLocalizations.of(context)!.notAvailable,
                                    style: const TextStyle(fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(Icons.people, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  '${event['current_participants'] ?? 0}/${event['max_participants'] ?? 0} ${AppLocalizations.of(context)!.participants.toLowerCase()}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                        onTap: () => _loadEventRegistrations(
                          event['id'],
                          event['name'] ?? event['title'] ?? AppLocalizations.of(context)!.unknownEvent,
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.arrow_back,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.eventRegistrations,
              style: const TextStyle(fontSize: 18, color: Colors.grey),
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
                      '${AppLocalizations.of(context)!.eventRegistrations}: $_selectedEventTitle',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      AppLocalizations.of(context)!.totalRegistrations(_registrations.length),
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
                  ? Center(
                      child: Text(
                        AppLocalizations.of(context)!.noRegistrationsFound,
                        style: const TextStyle(fontSize: 16, color: Colors.grey),
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
                            title: Text(registration['user_name'] ?? AppLocalizations.of(context)!.unknownUser),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${AppLocalizations.of(context)!.registered}: ${_formatDate(registration['registration_date'])}',
                                ),
                                if (registration['phone'] != null)
                                  Text(
                                    '${AppLocalizations.of(context)!.phone}: ${registration['phone']}',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.remove_circle, color: Colors.red),
                              onPressed: () => _removeRegistration(
                                registration['event_id'],
                                registration['user_id'],
                                registration['user_name'] ?? AppLocalizations.of(context)!.unknownUser,
                              ),
                              tooltip: AppLocalizations.of(context)!.unregisterTooltip,
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
            child: Text(AppLocalizations.of(context)!.retry),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessDeniedPage() {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.eventRegistrations),
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
                Text(
                  AppLocalizations.of(context)!.accessDenied,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context)!.eventRegistrationsManagementRequiresRole,
                  style: const TextStyle(
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