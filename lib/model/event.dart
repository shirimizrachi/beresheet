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
    required this.dateTime,
    required this.location,
    required this.maxParticipants,
    required this.imageUrl,
    this.currentParticipants = 0,
    this.status = AppConfig.eventStatusPendingApproval,
    this.recurring = AppConfig.eventRecurringNone,
    this.recurringEndDate,
    this.recurringPattern,
    this.isRegistered = false,
  });

  final String id;
  final String name;
  final String type; // "event", "sport", "cultural", "art", "english", "religion"
  final String description;
  final DateTime dateTime; // Initial occurrence date for recurring events
  final String location;
  final int maxParticipants;
  final String imageUrl;
  int currentParticipants;
  final String status; // "pending-approval", "approved", "rejected", "cancelled"
  final String recurring; // "none", "weekly", "monthly", "bi-weekly"
  final DateTime? recurringEndDate;
  final String? recurringPattern; // JSON string with pattern details
  final bool isRegistered; // Whether the current user is registered for this event

  bool get isAvailable => currentParticipants < maxParticipants;
  
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
    return "${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}";
  }

  String get formattedDate {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return "${dateTime.day} ${months[dateTime.month - 1]} ${dateTime.year}";
  }

  String get formattedTime {
    return "${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}";
  }

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'],
      name: json['name'],
      type: json['type'],
      description: json['description'],
      dateTime: DateTime.parse(json['dateTime']),
      location: json['location'],
      maxParticipants: json['maxParticipants'],
      imageUrl: json['image_url'],
      currentParticipants: json['currentParticipants'] ?? 0,
      status: json['status'] ?? AppConfig.eventStatusPendingApproval,
      recurring: json['recurring'] ?? AppConfig.eventRecurringNone,
      recurringEndDate: json['recurring_end_date'] != null
          ? DateTime.parse(json['recurring_end_date'])
          : null,
      recurringPattern: json['recurring_pattern'],
      isRegistered: json['is_registered'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'description': description,
      'dateTime': dateTime.toIso8601String(),
      'location': location,
      'maxParticipants': maxParticipants,
      'image_url': imageUrl,
      'currentParticipants': currentParticipants,
      'status': status,
      'recurring': recurring,
      'recurring_end_date': recurringEndDate?.toIso8601String(),
      'recurring_pattern': recurringPattern,
      'is_registered': isRegistered,
    };
  }

  Event copyWith({
    String? id,
    String? name,
    String? type,
    String? description,
    DateTime? dateTime,
    String? location,
    int? maxParticipants,
    String? imageUrl,
    int? currentParticipants,
    String? status,
    String? recurring,
    DateTime? recurringEndDate,
    String? recurringPattern,
    bool? isRegistered,
  }) {
    return Event(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      description: description ?? this.description,
      dateTime: dateTime ?? this.dateTime,
      location: location ?? this.location,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      imageUrl: imageUrl ?? this.imageUrl,
      currentParticipants: currentParticipants ?? this.currentParticipants,
      status: status ?? this.status,
      recurring: recurring ?? this.recurring,
      recurringEndDate: recurringEndDate ?? this.recurringEndDate,
      recurringPattern: recurringPattern ?? this.recurringPattern,
      isRegistered: isRegistered ?? this.isRegistered,
    );
  }
}