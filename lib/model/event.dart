import '../config/app_config.dart';

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
  final String type; // "class", "performance", "cultural", "leisure"
  final String description;
  final DateTime dateTime;
  final String location;
  final int maxParticipants;
  final String imageUrl;
  int currentParticipants;
  final String status; // "active", "canceled", "suspended", "pending-approval"
  final String recurring; // "none", "daily", "weekly", "monthly", "yearly", "custom"
  final DateTime? recurringEndDate;
  final String? recurringPattern; // JSON string with custom pattern details
  final bool isRegistered; // Whether the current user is registered for this event

  bool get isAvailable => currentParticipants < maxParticipants;
  
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