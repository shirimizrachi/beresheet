import 'package:beresheet_app/model/event.dart';
import 'package:beresheet_app/services/event_service.dart';
import 'package:beresheet_app/services/image_cache_service.dart';
import 'package:beresheet_app/services/modern_localization_service.dart';
import 'package:beresheet_app/utils/direction_utils.dart';
import 'package:beresheet_app/utils/display_name_utils.dart';
import 'package:flutter/material.dart';
import 'package:beresheet_app/widgets/localized_date_time_widget.dart';
import 'event_gallery_screen.dart';

class EventDetailPage extends StatefulWidget {
  const EventDetailPage({Key? key, required this.event}) : super(key: key);
  final Event event;

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  bool isRegistering = false;
  bool isRegistered = false;

  @override
  void initState() {
    super.initState();
    _checkRegistrationStatus();
  }

  Future<void> _checkRegistrationStatus() async {
    final registered = await EventService.isRegisteredForEvent(widget.event.id);
    if (mounted) {
      setState(() {
        isRegistered = registered;
      });
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

  Future<void> _handleRegistration() async {
    if (isRegistering) return;

    setState(() {
      isRegistering = true;
    });

    try {
      if (isRegistered) {
        // Unregister
        final success = await EventService.unregisterFromEvent(widget.event.id);
        if (success) {
          setState(() {
            isRegistered = false;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${context.l10n.unregister} ${widget.event.name}'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } else {
        // Register
        if (!widget.event.isAvailable) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.l10n.eventFull),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        final success = await EventService.registerForEvent(widget.event);
        if (success) {
          setState(() {
            isRegistered = true;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${context.l10n.registrationSuccessful} ${widget.event.name}!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      }
    } catch (e) {
      print('Registration error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.operationFailed),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isRegistering = false;
        });
      }
    }
  }

  void _openGallery() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EventGalleryScreen(event: widget.event),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    final typeColor = _getTypeColor(widget.event.type);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.event.name),
        backgroundColor: theme.colorScheme.primary,
        titleTextStyle: TextStyle(
          color: theme.colorScheme.onPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: theme.colorScheme.onPrimary),
        actions: [
          IconButton(
            onPressed: _openGallery,
            icon: Icon(Icons.photo_library),
            tooltip: 'View Gallery',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event Image
            ImageCacheService.buildEventImage(
              imageUrl: widget.event.imageUrl,
              height: 250,
              width: double.infinity,
              fit: BoxFit.cover,
              errorWidget: Container(
                height: 250,
                color: Colors.grey[300],
                child: Icon(
                  _getTypeIcon(widget.event.type),
                  size: 80,
                  color: Colors.grey[600],
                ),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Event Type Badge with Instructor Photo
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Event Type Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: typeColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: typeColor, width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getTypeIcon(widget.event.type),
                              size: 18,
                              color: typeColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              DisplayNameUtils.getEventTypeDisplayName(widget.event.type, context).toUpperCase(),
                              style: TextStyle(
                                color: typeColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Instructor Photo (if available)
                      if (widget.event.instructorName != null &&
                          widget.event.instructorName!.isNotEmpty &&
                          widget.event.instructorPhoto != null &&
                          widget.event.instructorPhoto!.isNotEmpty)
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2),
                          ),
                          child: ImageCacheService.buildCircularUserImage(
                            imageUrl: widget.event.instructorPhoto!,
                            radius: 30,
                            errorWidget: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.person,
                                color: Colors.grey[600],
                                size: 30,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Event Name
                  Text(
                    widget.event.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Description first
                  Text(
                    context.l10n.description,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.event.description,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Event Details Cards
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.access_time, size: 20, color: Colors.grey[600]),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      context.l10n.date_time,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    LocalizedDateTimeWidget(
                                      dateTime: widget.event.date_time,
                                      size: DateTimeDisplaySize.large,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(),
                          _buildDetailRow(
                            Icons.location_on,
                            context.l10n.location,
                            widget.event.location,
                          ),
                          const Divider(),
                          _buildDetailRow(
                            Icons.people,
                            context.l10n.participants,
                            '${widget.event.current_participants} / ${widget.event.max_participants}',
                          ),
                          // Add instructor details if available
                          if (widget.event.instructorName != null && widget.event.instructorName!.isNotEmpty) ...[
                            const Divider(),
                            _buildInstructorDetailRow(),
                          ],
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Availability Status
                  if (!widget.event.isAvailable)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info, color: Colors.red[700]),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'This event is full. You can still register to be added to the waiting list.',
                              style: TextStyle(
                                color: Colors.red[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // Registration Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isRegistering || (!widget.event.isAvailable && !isRegistered) ? null : _handleRegistration,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: !widget.event.isAvailable && !isRegistered
                            ? Colors.grey
                            : isRegistered
                                ? Colors.orange
                                : theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: isRegistering
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              !widget.event.isAvailable && !isRegistered
                                  ? 'EVENT FULL'
                                  : isRegistered
                                      ? context.l10n.unregister
                                      : context.l10n.registerEvent,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
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
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInstructorDetailRow() {
    return Row(
      children: [
        Icon(Icons.person, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.eventInstructor,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.event.instructorName ?? '',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (widget.event.instructorDesc != null && widget.event.instructorDesc!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  widget.event.instructorDesc!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}