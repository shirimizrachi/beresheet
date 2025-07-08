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
    required this.location,
    required this.max_participants,
    required this.imageUrl,
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
    this.galleryPhotos = const [],
  });

  final String id;
  final String name;
  final String type; // "event", "sport", "cultural", "art", "english", "religion"
  final String description;
  final DateTime date_time; // Initial occurrence date for recurring events
  final String location;
  final int max_participants;
  final String imageUrl;
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
  final List<Map<String, dynamic>> galleryPhotos; // Gallery photos for completed events

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
    return "${date_time.day}/${date_time.month}/${date_time.year} at ${date_time.hour}:${date_time.minute.toString().padLeft(2, '0')}";
  }

  String get formattedDate {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return "${date_time.day} ${months[date_time.month - 1]} ${date_time.year}";
  }

  String get formattedTime {
    return "${date_time.hour}:${date_time.minute.toString().padLeft(2, '0')}";
  }

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'],
      name: json['name'],
      type: json['type'],
      description: json['description'],
      date_time: DateTime.parse(json['date_time']),
      location: json['location'],
      max_participants: json['max_participants'],
      imageUrl: json['image_url'],
      current_participants: json['current_participants'] ?? 0,
      status: json['status'] ?? AppConfig.eventStatusPendingApproval,
      recurring: json['recurring'] ?? AppConfig.eventRecurringNone,
      recurringEndDate: json['recurring_end_date'] != null
          ? DateTime.parse(json['recurring_end_date'])
          : null,
      recurringPattern: json['recurring_pattern'],
      instructorName: json['instructor_name'],
      instructorDesc: json['instructor_desc'],
      instructorPhoto: json['instructor_photo'],
      isRegistered: json['is_registered'] ?? false,
      reviews: json['reviews'] != null
          ? List<Map<String, dynamic>>.from(json['reviews'])
          : const [],
      galleryPhotos: json['gallery_photos'] != null
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
      'location': location,
      'max_participants': max_participants,
      'image_url': imageUrl,
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
      'gallery_photos': galleryPhotos,
    };
  }

  Event copyWith({
    String? id,
    String? name,
    String? type,
    String? description,
    DateTime? date_time,
    String? location,
    int? max_participants,
    String? imageUrl,
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
    List<Map<String, dynamic>>? galleryPhotos,
  }) {
    return Event(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      description: description ?? this.description,
      date_time: date_time ?? this.date_time,
      location: location ?? this.location,
      max_participants: max_participants ?? this.max_participants,
      imageUrl: imageUrl ?? this.imageUrl,
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
      galleryPhotos: galleryPhotos ?? this.galleryPhotos,
    );
  }
}