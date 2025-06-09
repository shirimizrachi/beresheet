import 'package:beresheet_app/model/event.dart';
import 'package:beresheet_app/screen/app/events/event_form_screen.dart';
import 'package:beresheet_app/services/event_service.dart';
import 'package:beresheet_app/services/localization_service.dart';
import 'package:beresheet_app/theme/app_theme.dart';
import 'package:flutter/material.dart';

class EventsManagementScreen extends StatefulWidget {
  const EventsManagementScreen({Key? key}) : super(key: key);

  @override
  State<EventsManagementScreen> createState() => _EventsManagementScreenState();
}

class _EventsManagementScreenState extends State<EventsManagementScreen> {
  List<Event> events = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadEvents();
  }

  Future<void> loadEvents() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final loadedEvents = await EventService.loadEvents();
      setState(() {
        events = loadedEvents;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = '${'events.failed_to_load_events'.tr}: $e';
        isLoading = false;
      });
    }
  }

  Future<void> deleteEvent(String eventId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('events.delete_event'.tr),
          content: Text('events.delete_event_confirmation'.tr),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('common.cancel'.tr),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text('common.delete'.tr),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      final success = await EventService.deleteEvent(eventId);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('events.event_deleted'.tr),
            backgroundColor: Colors.green,
          ),
        );
        loadEvents(); // Refresh the list
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('events.failed_to_delete_event'.tr),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> navigateToEventForm({Event? event}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventFormScreen(event: event),
      ),
    );

    if (result == true) {
      loadEvents(); // Refresh the list
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text(
          'navigation.manage_events'.tr,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: Colors.white,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => navigateToEventForm(),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red[300],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        errorMessage!,
                        style: AppTextStyles.bodyMedium.copyWith(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      ElevatedButton(
                        onPressed: loadEvents,
                        child: Text('events.retry'.tr),
                      ),
                    ],
                  ),
                )
              : events.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.event_busy,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'events.no_events_found'.tr,
                            style: AppTextStyles.heading4.copyWith(color: Colors.grey[600]),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'events.create_first_event'.tr,
                            style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: loadEvents,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: events.length,
                        itemBuilder: (context, index) {
                          final event = events[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: AppSpacing.md),
                            child: ListTile(
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  event.imageUrl,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      width: 60,
                                      height: 60,
                                      color: Colors.grey[300],
                                      child: const Icon(Icons.image_not_supported),
                                    );
                                  },
                                ),
                              ),
                              title: Text(
                                event.name,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    event.type.toUpperCase(),
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${event.formattedDate} at ${event.formattedTime}',
                                    style: AppTextStyles.bodySmall,
                                  ),
                                  Text(
                                    '${event.currentParticipants}/${event.maxParticipants} participants',
                                    style: AppTextStyles.bodySmall,
                                  ),
                                ],
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  switch (value) {
                                    case 'edit':
                                      navigateToEventForm(event: event);
                                      break;
                                    case 'delete':
                                      deleteEvent(event.id);
                                      break;
                                  }
                                },
                                itemBuilder: (BuildContext context) => [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: ListTile(
                                      leading: const Icon(Icons.edit),
                                      title: Text('common.edit'.tr),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: ListTile(
                                      leading: const Icon(Icons.delete, color: Colors.red),
                                      title: Text('common.delete'.tr, style: const TextStyle(color: Colors.red)),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ],
                              ),
                              onTap: () => navigateToEventForm(event: event),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}