import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../config/app_config.dart';
import '../../../services/web/web_jwt_auth_service.dart';
import '../../../model/event.dart';

class EventsSummaryWeb extends StatefulWidget {
  const EventsSummaryWeb({Key? key}) : super(key: key);

  @override
  State<EventsSummaryWeb> createState() => _EventsSummaryWebState();
}

class _EventsSummaryWebState extends State<EventsSummaryWeb> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Event> _allEvents = [];
  List<Map<String, dynamic>> _homeEvents = [];
  final Map<String, int> _statusBreakdown = {};
  final Map<String, int> _recurringBreakdown = {};

  @override
  void initState() {
    super.initState();
    _loadEventsSummary();
  }

  Future<void> _loadEventsSummary() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _loadAllEvents();
      await _loadHomeEvents();
      _calculateBreakdowns();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading events summary: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadAllEvents() async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiUrlWithPrefix}/api/events'),
      headers: await WebJwtAuthService.getAuthHeaders(),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      _allEvents = data.map((json) => Event.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load all events: ${response.statusCode}');
    }
  }

  Future<void> _loadHomeEvents() async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiUrlWithPrefix}/api/events/home'),
      headers: await WebJwtAuthService.getAuthHeaders(),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      _homeEvents = data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Failed to load home events: ${response.statusCode}');
    }
  }

  void _calculateBreakdowns() {
    // Status breakdown
    _statusBreakdown.clear();
    for (final event in _allEvents) {
      _statusBreakdown[event.status] = (_statusBreakdown[event.status] ?? 0) + 1;
    }

    // Recurring breakdown
    _recurringBreakdown.clear();
    for (final event in _allEvents) {
      _recurringBreakdown[event.recurring] = (_recurringBreakdown[event.recurring] ?? 0) + 1;
    }
  }

  String _formatRecurringPattern(Event event) {
    if (event.recurring == 'none') {
      return 'One-time event';
    }

    if (event.recurringPattern == null || event.recurringPattern!.isEmpty) {
      return 'Invalid pattern';
    }

    try {
      final pattern = json.decode(event.recurringPattern!);
      
      if (pattern['dayOfWeek'] != null) {
        final days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
        final dayName = days[pattern['dayOfWeek']];
        final time = pattern['time'] ?? '??:??';
        final interval = pattern['interval'] ?? 1;
        
        if (interval == 2) {
          return 'Every 2nd $dayName $time';
        } else {
          return 'Every $dayName $time';
        }
      } else if (pattern['dayOfMonth'] != null) {
        final day = pattern['dayOfMonth'];
        final time = pattern['time'] ?? '??:??';
        return 'Monthly ${day}th $time';
      }
    } catch (e) {
      return 'Invalid pattern';
    }

    return 'Unknown pattern';
  }

  String _formatHomeRecurringPattern(Map<String, dynamic> eventData) {
    if (eventData['recurring'] == 'none') {
      return 'One-time';
    }

    if (eventData['recurring_pattern'] == null || eventData['recurring_pattern'].isEmpty) {
      return 'Invalid pattern';
    }

    try {
      final pattern = json.decode(eventData['recurring_pattern']);
      
      if (pattern['dayOfWeek'] != null) {
        final days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
        final dayName = days[pattern['dayOfWeek']];
        final time = pattern['time'] ?? '??:??';
        final interval = pattern['interval'] ?? 1;
        
        if (interval == 2) {
          return '2nd $dayName $time';
        } else {
          return '$dayName $time';
        }
      } else if (pattern['dayOfMonth'] != null) {
        final day = pattern['dayOfMonth'];
        final time = pattern['time'] ?? '??:??';
        return 'Monthly ${day}th $time';
      }
    } catch (e) {
      return 'Invalid pattern';
    }

    return 'Unknown';
  }

  Widget _buildAllEventsTable() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📊 ALL EVENTS IN DATABASE (${_allEvents.length} events)',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Name')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Recurring')),
                  DataColumn(label: Text('Original DateTime')),
                  DataColumn(label: Text('Pattern')),
                ],
                rows: _allEvents.map((event) {
                  return DataRow(
                    cells: [
                      DataCell(
                        SizedBox(
                          width: 200,
                          child: Text(
                            event.name.length > 25 ? '${event.name.substring(0, 22)}...' : event.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(Text(event.status)),
                      DataCell(Text(event.recurring)),
                      DataCell(
                        Text(
                          event.date_time != null 
                            ? '${event.date_time!.month.toString().padLeft(2, '0')}-${event.date_time!.day.toString().padLeft(2, '0')} ${event.date_time!.hour.toString().padLeft(2, '0')}:${event.date_time!.minute.toString().padLeft(2, '0')}'
                            : 'None'
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 200,
                          child: Text(
                            _formatRecurringPattern(event),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeEventsTable() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🏠 LOAD_EVENTS_FOR_HOME RESULTS (${_homeEvents.length} events)',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '⏰ Current time: ${DateTime.now().toString().substring(0, 19)}',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Name')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Next Event')),
                  DataColumn(label: Text('Pattern')),
                  DataColumn(label: Text('Start Date')),
                  DataColumn(label: Text('End Date')),
                  DataColumn(label: Text('Override')),
                ],
                rows: _homeEvents.map((eventData) {
                  // Find original event for comparison
                  Event? originalEvent;
                  try {
                    originalEvent = _allEvents.firstWhere((e) => e.id == eventData['id']);
                  } catch (e) {
                    // Event not found in all events
                  }

                  // Format dates
                  DateTime? displayDateTime;
                  try {
                    displayDateTime = DateTime.parse(eventData['date_time'].toString().replaceAll('Z', ''));
                  } catch (e) {
                    // Invalid date format
                  }

                  final displayDateStr = displayDateTime != null 
                    ? '${displayDateTime.month.toString().padLeft(2, '0')}-${displayDateTime.day.toString().padLeft(2, '0')} ${displayDateTime.hour.toString().padLeft(2, '0')}:${displayDateTime.minute.toString().padLeft(2, '0')}'
                    : 'N/A';

                  // Format start and end dates for recurring events
                  String startDateStr = 'N/A';
                  String endDateStr = 'N/A';
                  
                  if (eventData['recurring'] != 'none' && originalEvent != null) {
                    if (originalEvent.date_time != null) {
                      startDateStr = '${originalEvent.date_time!.month.toString().padLeft(2, '0')}-${originalEvent.date_time!.day.toString().padLeft(2, '0')}';
                    }
                    if (originalEvent.recurringEndDate != null) {
                      endDateStr = '${originalEvent.recurringEndDate!.month.toString().padLeft(2, '0')}-${originalEvent.recurringEndDate!.day.toString().padLeft(2, '0')}';
                    }
                  }

                  // Check if overridden
                  bool isOverridden = false;
                  if (eventData['recurring'] != 'none' && originalEvent?.date_time != null) {
                    isOverridden = eventData['date_time'] != originalEvent!.date_time!.toIso8601String();
                  }

                  return DataRow(
                    cells: [
                      DataCell(
                        SizedBox(
                          width: 200,
                          child: Text(
                            eventData['name'].toString().length > 25 
                              ? '${eventData['name'].toString().substring(0, 22)}...' 
                              : eventData['name'].toString(),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(Text(eventData['status'].toString())),
                      DataCell(Text(displayDateStr)),
                      DataCell(
                        SizedBox(
                          width: 150,
                          child: Text(
                            _formatHomeRecurringPattern(eventData),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(Text(startDateStr)),
                      DataCell(Text(endDateStr)),
                      DataCell(
                        Text(
                          isOverridden ? '✅ YES' : '⭕ NO',
                          style: TextStyle(
                            color: isOverridden ? Colors.green : Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryTable() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📈 SUMMARY',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'General Metrics',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildMetricRow('Total events in database:', _allEvents.length.toString()),
                      _buildMetricRow('Events returned by API:', _homeEvents.length.toString()),
                      const SizedBox(height: 16),
                      const Text(
                        'Status Breakdown',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._statusBreakdown.entries.map((entry) => 
                        _buildMetricRow('  ${entry.key}:', entry.value.toString())
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 32),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Recurring Type Breakdown',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._recurringBreakdown.entries.map((entry) => 
                        _buildMetricRow('  ${entry.key}:', entry.value.toString())
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Validation Results',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildValidationRow('Correct chronological ordering:', _isChronologicallyOrdered().toString()),
                      _buildValidationRow('All events are in future:', _areAllEventsInFuture().toString()),
                      _buildValidationRow('DateTime override working:', '${_getOverrideCount()} recurring events'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          SizedBox(
            width: 200,
            child: Text(label),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildValidationRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          const Text('✅ '),
          SizedBox(
            width: 180,
            child: Text(label),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  bool _isChronologicallyOrdered() {
    if (_homeEvents.length <= 1) return true;
    
    for (int i = 0; i < _homeEvents.length - 1; i++) {
      try {
        final current = DateTime.parse(_homeEvents[i]['date_time'].toString().replaceAll('Z', ''));
        final next = DateTime.parse(_homeEvents[i + 1]['date_time'].toString().replaceAll('Z', ''));
        if (current.isAfter(next)) {
          return false;
        }
      } catch (e) {
        return false;
      }
    }
    return true;
  }

  bool _areAllEventsInFuture() {
    final now = DateTime.now();
    for (final eventData in _homeEvents) {
      try {
        final eventDateTime = DateTime.parse(eventData['date_time'].toString().replaceAll('Z', ''));
        if (eventDateTime.isBefore(now)) {
          return false;
        }
      } catch (e) {
        return false;
      }
    }
    return true;
  }

  int _getOverrideCount() {
    int count = 0;
    for (final eventData in _homeEvents) {
      if (eventData['recurring'] != 'none') {
        // Find original event
        try {
          final originalEvent = _allEvents.firstWhere((e) => e.id == eventData['id']);
          if (originalEvent.date_time != null) {
            if (eventData['date_time'] != originalEvent.date_time!.toIso8601String()) {
              count++;
            }
          }
        } catch (e) {
          // Event not found
        }
      }
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Error',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(_errorMessage!),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadEventsSummary,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.analytics,
                            size: 32,
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Events Summary',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          ElevatedButton.icon(
                            onPressed: _loadEventsSummary,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Refresh'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildAllEventsTable(),
                      const SizedBox(height: 24),
                      _buildHomeEventsTable(),
                      const SizedBox(height: 24),
                      _buildSummaryTable(),
                    ],
                  ),
                ),
    );
  }
}