import 'dart:async';
import 'package:beresheet_app/model/event.dart';
import 'package:beresheet_app/screen/app/events/eventdetail.dart';
import 'package:beresheet_app/screen/app/events/event_vote_review_screen.dart';
import 'package:beresheet_app/services/event_service.dart';
import 'package:beresheet_app/services/modern_localization_service.dart';
import 'package:beresheet_app/utils/direction_utils.dart';
import 'package:beresheet_app/utils/display_name_utils.dart';
import 'package:flutter/material.dart';

class RegisteredEventsScreen extends StatefulWidget {
  const RegisteredEventsScreen({Key? key}) : super(key: key);

  @override
  State<RegisteredEventsScreen> createState() => _RegisteredEventsScreenState();
}

class _RegisteredEventsScreenState extends State<RegisteredEventsScreen> {
  List<Event> registeredEvents = [];
  bool isLoading = true;
  bool _disposed = false;
  Completer<void>? _loadingCompleter;

  @override
  void initState() {
    super.initState();
    loadRegisteredEvents();
  }

  @override
  void dispose() {
    _disposed = true;
    _loadingCompleter?.complete();
    super.dispose();
  }

  Future<void> loadRegisteredEvents() async {
    // Cancel any previous loading operation
    _loadingCompleter?.complete();
    _loadingCompleter = Completer<void>();
    
    try {
      // Load events (will use cache if valid, or refresh if expired)
      await EventService.loadEventsForHome();
      
      // Check if widget is still mounted and not disposed
      if (_disposed || !mounted) return;
      
      // Get registered events from cache
      final cachedEvents = EventService.getCachedRegisteredEvents();
      
      // Final check before setState
      if (_disposed || !mounted) return;
      
      setState(() {
        registeredEvents = cachedEvents;
        isLoading = false;
      });
      
      print('RegisteredEventsScreen: Loaded ${cachedEvents.length} registered events from cache');
    } catch (e) {
      print('Error loading registered events: $e');
      // Fallback to old method
      try {
        // Check if still mounted before fallback
        if (_disposed || !mounted) return;
        
        final events = await EventService.getRegisteredEvents();
        
        // Check again before setState
        if (_disposed || !mounted) return;
        
        setState(() {
          registeredEvents = events;
          isLoading = false;
        });
      } catch (e2) {
        // Final check before error setState
        if (_disposed || !mounted) return;
        
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshEvents() async {
    if (_disposed || !mounted) return;
    await loadRegisteredEvents();
  }

  Future<void> _unregisterFromEvent(Event event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.unregister),
        content: Text('${context.l10n.unregisterConfirmation} "${event.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.unregister),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final success = await EventService.unregisterFromEvent(event.id);
        if (success) {
          await loadRegisteredEvents();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Unregistered from ${event.name}'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.operationFailed),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'class':
        return Colors.blue;
      case 'performance':
        return Colors.purple;
      case 'cultural':
        return Colors.orange;
      case 'leisure':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'class':
        return Icons.school;
      case 'performance':
        return Icons.theater_comedy;
      case 'cultural':
        return Icons.palette;
      case 'leisure':
        return Icons.nature_people;
      default:
        return Icons.event;
    }
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.myRegisteredEvents),
        backgroundColor: theme.colorScheme.primary,
        titleTextStyle: TextStyle(
          color: theme.colorScheme.onPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: theme.colorScheme.onPrimary),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : registeredEvents.isEmpty
              ? RefreshIndicator(
                  onRefresh: _refreshEvents,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: SizedBox(
                      height: 400,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.event_busy,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No registered events',
                              style: const TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Register for events from the home page',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _refreshEvents,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: registeredEvents.length,
                    itemBuilder: (context, index) {
                      final event = registeredEvents[index];
                      final typeColor = _getTypeColor(event.type);
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    // Event Type Badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: typeColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: typeColor),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _getTypeIcon(event.type),
                                            size: 14,
                                            color: typeColor,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            DisplayNameUtils.getEventTypeDisplayName(event.type, context).toUpperCase(),
                                            style: TextStyle(
                                              color: typeColor,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Spacer(),
                                    // Status Badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green[100],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.check_circle,
                                            size: 14,
                                            color: Colors.green[700],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            context.l10n.registered.toUpperCase(),
                                            style: TextStyle(
                                              color: Colors.green[700],
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                
                                const SizedBox(height: 12),
                                
                                // Event Name
                                Text(
                                  event.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                
                                const SizedBox(height: 8),
                                
                                // Date and Time
                                Row(
                                  children: [
                                    Icon(
                                      Icons.access_time,
                                      size: 16,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${DisplayNameUtils.getLocalizedFormattedDate(event.dateTime, context)} at ${event.formattedTime}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                                
                                const SizedBox(height: 4),
                                
                                // Location
                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      size: 16,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        event.location,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                
                                const SizedBox(height: 12),
                                
                                // Description
                                Text(
                                  event.description,
                                  style: const TextStyle(fontSize: 14),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                
                                const SizedBox(height: 12),
                                
                                // Action Buttons
                                Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton(
                                            onPressed: () => _unregisterFromEvent(event),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.orange[700],
                                              side: BorderSide(color: Colors.orange[300]!),
                                            ),
                                            child: Text(context.l10n.unregister),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: ElevatedButton(
                                            onPressed: () async {
                                              try {
                                                // Validate event data before navigation
                                                if (event.id.isEmpty || event.name.isEmpty) {
                                                  throw Exception('Invalid event data');
                                                }
                                                
                                                print('Navigating to event details for: ${event.name} (ID: ${event.id})');
                                                
                                                if (!mounted) return;
                                                
                                                await Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => EventDetailPage(event: event),
                                                  ),
                                                );
                                              } catch (e) {
                                                print('Error navigating to event details: $e');
                                                if (mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text('Error opening event details: $e'),
                                                      backgroundColor: Colors.red,
                                                    ),
                                                  );
                                                }
                                              }
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: theme.colorScheme.primary,
                                              foregroundColor: Colors.white,
                                            ),
                                            child: Text(context.l10n.viewDetails),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: () async {
                                          try {
                                            // Validate event data before navigation
                                            if (event.id.isEmpty || event.name.isEmpty) {
                                              throw Exception('Invalid event data');
                                            }
                                            
                                            print('Navigating to vote & review for: ${event.name} (ID: ${event.id})');
                                            
                                            if (!mounted) return;
                                            
                                            await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => EventVoteReviewScreen(
                                                  eventRegistrationId: event.id, // Using event ID as placeholder
                                                  eventId: event.id,
                                                  eventName: event.name,
                                                ),
                                              ),
                                            );
                                          } catch (e) {
                                            print('Error navigating to vote & review: $e');
                                            if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('Error opening vote & review: $e'),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            }
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue,
                                          foregroundColor: Colors.white,
                                        ),
                                        icon: const Icon(Icons.rate_review, size: 18),
                                        label: Text(context.l10n.voteAndReview),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                      );
                    },
                  ),
                ),
    );
  }
}