import 'package:beresheet_app/model/event.dart';
import 'package:beresheet_app/screen/app/events/eventdetail.dart';
import 'package:beresheet_app/services/image_cache_service.dart';
import 'package:beresheet_app/services/modern_localization_service.dart';
import 'package:beresheet_app/theme/app_theme.dart';
import 'package:beresheet_app/utils/direction_utils.dart';
import 'package:beresheet_app/utils/display_name_utils.dart';
import 'package:beresheet_app/widgets/localized_date_time_widget.dart';
import 'package:flutter/material.dart';

class EventCard extends StatefulWidget {
  const EventCard({Key? key, required this.event, this.onRegistrationChanged, this.isRegistered = false, this.isHorizontalLayout = false}) : super(key: key);
  final Event event;
  final VoidCallback? onRegistrationChanged;
  final bool isRegistered;
  final bool isHorizontalLayout;

  @override
  State<EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<EventCard> {

  Color _getTypeColor(String type) {
    return ActivityTypeHelper.getColor(type);
  }

  IconData _getTypeIcon(String type) {
    return ActivityTypeHelper.getIcon(type);
  }

  @override
  Widget build(BuildContext context) {
    final typeColor = _getTypeColor(widget.event.type);
    final isRTL = DirectionUtils.isRTL;

    return Container(
      height: widget.isHorizontalLayout ? 140 : null, // Fixed height for horizontal layout
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
        child: widget.isHorizontalLayout ? _buildHorizontalLayout(typeColor, isRTL) : _buildVerticalLayout(typeColor),
      ),
    );
  }

  Widget _buildVerticalLayout(Color typeColor) {
    return Column(
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
            child: _buildEventDetails(typeColor, false),
          ),
        ),
      ],
    );
  }

  Widget _buildHorizontalLayout(Color typeColor, bool isRTL) {
    return Row(
      children: [
        // Event Image Section (Left for LTR, Right for RTL)
        Container(
          width: 120,
          height: double.infinity,
          child: ClipRRect(
            borderRadius: BorderRadius.only(
              topLeft: isRTL ? Radius.zero : const Radius.circular(12),
              bottomLeft: isRTL ? Radius.zero : const Radius.circular(12),
              topRight: isRTL ? const Radius.circular(12) : Radius.zero,
              bottomRight: isRTL ? const Radius.circular(12) : Radius.zero,
            ),
            child: ImageCacheService.buildEventImage(
              imageUrl: widget.event.imageUrl,
              width: 120,
              height: double.infinity,
              fit: BoxFit.cover,
              placeholder: Container(
                color: Colors.grey[200],
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              errorWidget: Container(
                color: Colors.grey[300],
                child: Icon(
                  _getTypeIcon(widget.event.type),
                  size: 40,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ),
        ),
        
        // Event Details Section (Right for LTR, Left for RTL)
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: _buildEventDetails(typeColor, true),
          ),
        ),
      ],
    );
  }

  Widget _buildEventDetails(Color typeColor, bool isHorizontalLayout) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Event Type Badge and Registration Status
        Row(
          children: [
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
                    DisplayNameUtils.getEventTypeDisplayName(widget.event.type, context).toUpperCase(),
                    style: TextStyle(
                      color: typeColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            
            // Registration Status Badge
            if (widget.isRegistered) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 10,
                      color: Colors.green[700],
                    ),
                    const SizedBox(width: 2),
                    Text(
                      context.l10n.registered.toUpperCase(),
                      style: TextStyle(
                        color: Colors.green[700],
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        
        const SizedBox(height: 6),
        
        // Event Name
        Flexible(
          child: Text(
            widget.event.name,
            style: TextStyle(
              fontSize: isHorizontalLayout ? 16 : 12,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        
        const SizedBox(height: 4),
        
        // Date and Time
        Row(
          children: [
            Icon(Icons.access_time, size: 12, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Expanded(
              child: LocalizedDateTimeWidget(
                dateTime: widget.event.date_time,
                size: DateTimeDisplaySize.medium,
                textColor: Colors.grey[600],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 2),
        
        // Location
        Row(
          children: [
            Icon(Icons.location_on, size: 12, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                widget.event.location,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 4),
        
        // Participants and Duration Row
        Row(
          children: [
            Icon(Icons.people, size: 12, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              '${widget.event.current_participants}/${widget.event.max_participants}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(width: 12),
            Icon(Icons.timer, size: 12, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              '${widget.event.duration} ${context.l10n.minutesShort}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            if (!widget.event.isAvailable) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'FULL',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.red[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
