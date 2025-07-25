import '../config/app_config.dart';
import 'dart:convert';

class RecurrencePattern {
  final int? dayOfWeek; // 0=Sunday, 1=Monday, ..., 6=Saturday
  final int? dayOfMonth; // 1-31 for monthly events
  final String? time; // "14:00" format
  final int? interval; // For bi-weekly (interval=2), etc.

  RecurrencePattern({
    this.dayOfWeek,
    this.dayOfMonth,
    this.time,
    this.interval,
  });

  factory RecurrencePattern.fromJson(Map<String, dynamic> json) {
    return RecurrencePattern(
      dayOfWeek: json['dayOfWeek'],
      dayOfMonth: json['dayOfMonth'],
      time: json['time'],
      interval: json['interval'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (dayOfWeek != null) 'dayOfWeek': dayOfWeek,
      if (dayOfMonth != null) 'dayOfMonth': dayOfMonth,
      if (time != null) 'time': time,
      if (interval != null) 'interval': interval,
    };
  }

  factory RecurrencePattern.fromJsonString(String jsonString) {
    try {
      final json = jsonDecode(jsonString);
      return RecurrencePattern.fromJson(json);
    } catch (e) {
      return RecurrencePattern();
    }
  }

  String toJsonString() {
    return jsonEncode(toJson());
  }
}

class Event {
  Event({
    required this.id,
    required this.name,
    required this.type,
    required this.description,
    required this.date_time,
    required this.next_date_time,
    required this.location,
    required this.max_participants,
    required this.imageUrl,
    this.duration = 60,
    this.current_participants = 0,
    this.status = AppConfig.eventStatusPendingApproval,
    this.recurring = AppConfig.eventRecurringNone,
    this.recurringEndDate,
    this.recurringPattern,
    this.instructorName,
    this.instructorDesc,
    this.instructorPhoto,
    this.isRegistered = false,
    this.reviews = const [],
    this.gallery_photos = const [],
  });

  final String id;
  final String name;
  final String type; // "event", "sport", "cultural", "art", "english", "religion"
  final String description;
  final DateTime date_time; // Initial occurrence date for recurring events
  final DateTime next_date_time; // Calculated next occurrence for recurring events
  final String location;
  final int max_participants;
  final String imageUrl;
  final int duration; // Duration in minutes
  int current_participants;
  final String status; // "pending-approval", "approved", "rejected", "cancelled", "done"
  final String recurring; // "none", "weekly", "monthly", "bi-weekly"
  final DateTime? recurringEndDate;
  final String? recurringPattern; // JSON string with pattern details
  final String? instructorName;
  final String? instructorDesc;
  final String? instructorPhoto;
  final bool isRegistered; // Whether the current user is registered for this event
  final List<Map<String, dynamic>> reviews; // Event reviews for completed events
  final List<Map<String, dynamic>> gallery_photos; // Gallery photos for completed events

  bool get isAvailable => current_participants < max_participants;
  
  /// Get parsed recurrence pattern
  RecurrencePattern? get parsedRecurrencePattern {
    if (recurringPattern == null || recurringPattern!.isEmpty) {
      return null;
    }
    return RecurrencePattern.fromJsonString(recurringPattern!);
  }
  
  /// Check if this is a recurring event
  bool get isRecurring => recurring != AppConfig.eventRecurringNone;
  
  String get formattedDateTime {
    return "${next_date_time.day}/${next_date_time.month}/${next_date_time.year} at ${next_date_time.hour}:${next_date_time.minute.toString().padLeft(2, '0')}";
  }

  String get formattedDate {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return "${next_date_time.day} ${months[next_date_time.month - 1]} ${next_date_time.year}";
  }

  String get formattedTime {
    return "${next_date_time.hour}:${next_date_time.minute.toString().padLeft(2, '0')}";
  }

  factory Event.fromJson(Map<String, dynamic> json) {
    // Parse date_time with null safety
    DateTime parsedDateTime;
    try {
      if (json['date_time'] == null) {
        throw Exception('date_time is null');
      }
      parsedDateTime = DateTime.parse(json['date_time']);
    } catch (e) {
      print('Error parsing date_time for event ${json['id']}: $e');
      // Use current time as fallback
      parsedDateTime = DateTime.now();
    }

    // Parse next_date_time with null safety
    DateTime parsedNextDateTime;
    try {
      if (json['next_date_time'] == null) {
        // Fall back to date_time if next_date_time is missing
        parsedNextDateTime = parsedDateTime;
      } else {
        parsedNextDateTime = DateTime.parse(json['next_date_time']);
      }
    } catch (e) {
      print('Error parsing next_date_time for event ${json['id']}: $e');
      // Use date_time as fallback
      parsedNextDateTime = parsedDateTime;
    }

    return Event(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      type: json['type'] ?? 'event',
      description: json['description'] ?? '',
      date_time: parsedDateTime,
      next_date_time: parsedNextDateTime,
      location: json['location'] ?? '',
      max_participants: json['max_participants'] ?? 0,
      imageUrl: json['image_url'] ?? '',
      duration: json['duration'],
      current_participants: json['current_participants'] ?? 0,
      status: json['status'] ?? AppConfig.eventStatusPendingApproval,
      recurring: json['recurring'] ?? AppConfig.eventRecurringNone,
      recurringEndDate: json['recurring_end_date'] != null
          ? DateTime.tryParse(json['recurring_end_date'])
          : null,
      recurringPattern: json['recurring_pattern'],
      instructorName: json['instructor_name'],
      instructorDesc: json['instructor_desc'],
      instructorPhoto: json['instructor_photo'],
      isRegistered: json['is_registered'] ?? false,
      reviews: json['reviews'] != null
          ? List<Map<String, dynamic>>.from(json['reviews'])
          : const [],
      gallery_photos: json['gallery_photos'] != null
          ? List<Map<String, dynamic>>.from(json['gallery_photos'])
          : const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'description': description,
      'date_time': date_time.toIso8601String(),
      'next_date_time': next_date_time.toIso8601String(),
      'location': location,
      'max_participants': max_participants,
      'image_url': imageUrl,
      'duration': duration,
      'current_participants': current_participants,
      'status': status,
      'recurring': recurring,
      'recurring_end_date': recurringEndDate?.toIso8601String(),
      'recurring_pattern': recurringPattern,
      'instructor_name': instructorName,
      'instructor_desc': instructorDesc,
      'instructor_photo': instructorPhoto,
      'is_registered': isRegistered,
      'reviews': reviews,
      'gallery_photos': gallery_photos,
    };
  }

  Event copyWith({
    String? id,
    String? name,
    String? type,
    String? description,
    DateTime? date_time,
    DateTime? next_date_time,
    String? location,
    int? max_participants,
    String? imageUrl,
    int? duration,
    int? current_participants,
    String? status,
    String? recurring,
    DateTime? recurringEndDate,
    String? recurringPattern,
    String? instructorName,
    String? instructorDesc,
    String? instructorPhoto,
    bool? isRegistered,
    List<Map<String, dynamic>>? reviews,
    List<Map<String, dynamic>>? gallery_photos,
  }) {
    return Event(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      description: description ?? this.description,
      date_time: date_time ?? this.date_time,
      next_date_time: next_date_time ?? this.next_date_time,
      location: location ?? this.location,
      max_participants: max_participants ?? this.max_participants,
      imageUrl: imageUrl ?? this.imageUrl,
      duration: duration ?? this.duration,
      current_participants: current_participants ?? this.current_participants,
      status: status ?? this.status,
      recurring: recurring ?? this.recurring,
      recurringEndDate: recurringEndDate ?? this.recurringEndDate,
      recurringPattern: recurringPattern ?? this.recurringPattern,
      instructorName: instructorName ?? this.instructorName,
      instructorDesc: instructorDesc ?? this.instructorDesc,
      instructorPhoto: instructorPhoto ?? this.instructorPhoto,
      isRegistered: isRegistered ?? this.isRegistered,
      reviews: reviews ?? this.reviews,
      gallery_photos: gallery_photos ?? this.gallery_photos,
    );
  }
}

