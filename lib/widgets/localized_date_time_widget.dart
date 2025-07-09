import 'package:flutter/material.dart';
import 'package:beresheet_app/services/modern_localization_service.dart';
import 'package:beresheet_app/utils/display_name_utils.dart';

enum DateTimeDisplaySize {
  small,   // 9px - for event cards
  medium,  // 12px - for homepage cards 
  large,   // 14px - for event details
}

class LocalizedDateTimeWidget extends StatelessWidget {
  final DateTime dateTime;
  final DateTimeDisplaySize size;
  final Color? textColor;
  final FontWeight? fontWeight;
  final int? maxLines;
  final TextOverflow? overflow;

  const LocalizedDateTimeWidget({
    Key? key,
    required this.dateTime,
    this.size = DateTimeDisplaySize.medium,
    this.textColor,
    this.fontWeight,
    this.maxLines,
    this.overflow,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    
    // Get localized day of week
    final dayOfWeek = _getLocalizedDayOfWeek(dateTime, l10n);
    
    // Get formatted date (with conditional year display)
    final formattedDate = _getFormattedDateWithConditionalYear(dateTime, context);
    
    // Get formatted time
    final formattedTime = _getFormattedTime(dateTime);
    
    // Combine into full format: "Day of Week, Date at Time"
    final fullDateTimeString = '$dayOfWeek, $formattedDate ${l10n.at} $formattedTime';
    
    // Get font size based on display size
    final fontSize = _getFontSize(size);
    
    return Text(
      fullDateTimeString,
      style: TextStyle(
        fontSize: fontSize,
        color: textColor,
        fontWeight: fontWeight,
      ),
      maxLines: maxLines,
      overflow: overflow,
    );
  }

  String _getLocalizedDayOfWeek(DateTime dateTime, dynamic l10n) {
    switch (dateTime.weekday) {
      case DateTime.monday:
        return l10n.monday;
      case DateTime.tuesday:
        return l10n.tuesday;
      case DateTime.wednesday:
        return l10n.wednesday;
      case DateTime.thursday:
        return l10n.thursday;
      case DateTime.friday:
        return l10n.friday;
      case DateTime.saturday:
        return l10n.saturday;
      case DateTime.sunday:
        return l10n.sunday;
      default:
        return '';
    }
  }

  String _getFormattedDateWithConditionalYear(DateTime dateTime, BuildContext context) {
    final now = DateTime.now();
    final currentYear = now.year;
    final eventYear = dateTime.year;
    
    // If the event is in the same year, use DisplayNameUtils but without year
    // If different year, include the year
    if (eventYear == currentYear) {
      // Use the existing method and try to remove year pattern
      String fullDate = DisplayNameUtils.getLocalizedFormattedDate(dateTime, context);
      
      // Try to remove common year patterns (e.g., "2025", " 2025", ", 2025")
      final yearString = eventYear.toString();
      fullDate = fullDate.replaceAll(RegExp(r',?\s*' + yearString + r'\b'), '');
      fullDate = fullDate.replaceAll(RegExp(r'\b' + yearString + r'\s*,?'), '');
      
      return fullDate.trim();
    } else {
      // Different year - show full date with year
      return DisplayNameUtils.getLocalizedFormattedDate(dateTime, context);
    }
  }

  String _getFormattedTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  double _getFontSize(DateTimeDisplaySize size) {
    switch (size) {
      case DateTimeDisplaySize.small:
        return 9.0;
      case DateTimeDisplaySize.medium:
        return 12.0;
      case DateTimeDisplaySize.large:
        return 14.0;
    }
  }
}