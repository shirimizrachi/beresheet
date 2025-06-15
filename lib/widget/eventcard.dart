import 'package:beresheet_app/model/event.dart';
import 'package:beresheet_app/screen/app/events/eventdetail.dart';
import 'package:beresheet_app/services/event_service.dart';
import 'package:beresheet_app/services/image_cache_service.dart';
import 'package:beresheet_app/services/modern_localization_service.dart';
import 'package:beresheet_app/theme/app_theme.dart';
import 'package:beresheet_app/utils/direction_utils.dart';
import 'package:flutter/material.dart';

class EventCard extends StatefulWidget {
  const EventCard({Key? key, required this.event}) : super(key: key);
  final Event event;

  @override
  State<EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<EventCard> {
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
    return ActivityTypeHelper.getColor(type);
  }

  IconData _getTypeIcon(String type) {
    return ActivityTypeHelper.getIcon(type);
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

  @override
  Widget build(BuildContext context) {
    final typeColor = _getTypeColor(widget.event.type);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppBorderRadius.medium),
        boxShadow: [AppShadows.cardShadow],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EventDetailPage(event: widget.event),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event Image
            Flexible(
              flex: 3,
              child: ImageCacheService.buildEventImage(
                imageUrl: widget.event.imageUrl,
                width: double.infinity,
                fit: BoxFit.cover,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                placeholder: Container(
                  width: double.infinity,
                  color: Colors.grey[200],
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: Container(
                  width: double.infinity,
                  color: Colors.grey[300],
                  child: Icon(
                    _getTypeIcon(widget.event.type),
                    size: 40,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ),
            
            Flexible(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Event Type Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: typeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: typeColor, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getTypeIcon(widget.event.type),
                            size: 12,
                            color: typeColor,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            widget.event.type.toUpperCase(),
                            style: TextStyle(
                              color: typeColor,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 4),
                    
                    // Event Name
                    Flexible(
                      child: Text(
                        widget.event.name,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    
                    const SizedBox(height: 2),
                    
                    // Date and Time
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 10, color: Colors.grey[600]),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            widget.event.formattedDate,
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 1),
                    
                    // Location
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 10, color: Colors.grey[600]),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            widget.event.location,
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 4),
                    
                    // Participants Info and Register Button Row
                    Row(
                      children: [
                        Icon(Icons.people, size: 10, color: Colors.grey[600]),
                        const SizedBox(width: 2),
                        Text(
                          '${widget.event.currentParticipants}/${widget.event.maxParticipants}',
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (!widget.event.isAvailable) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.red[100],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'FULL',
                              style: TextStyle(
                                fontSize: 7,
                                color: Colors.red[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        // Compact Register Button
                        Expanded(
                          child: SizedBox(
                            height: 24,
                            child: ElevatedButton(
                              onPressed: isRegistering ? null : _handleRegistration,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isRegistered
                                    ? AppColors.accent
                                    : AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                minimumSize: Size.zero,
                              ),
                              child: isRegistering
                                  ? const SizedBox(
                                      height: 12,
                                      width: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : Text(
                                      isRegistered ? context.l10n.unregister : context.l10n.registerEvent,
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}