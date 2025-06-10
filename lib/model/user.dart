class UserModel {
  final String uniqueId;
  final String fullName;
  final String phoneNumber;
  final String role; // "resident", "staff", "instructor", "service", "caregiver", "manager"
  final DateTime birthday;
  final String apartmentNumber;
  final String maritalStatus;
  final String gender;
  final String religious;
  final String nativeLanguage;
  final int residentId; // Not displayed in profile page, used for internal operations
  final String userId; // Unique user identifier generated on creation
  final String? photo;
  final String? createdAt;
  final String? updatedAt;

  UserModel({
    required this.uniqueId,
    required this.fullName,
    required this.phoneNumber,
    required this.role,
    required this.birthday,
    required this.apartmentNumber,
    required this.maritalStatus,
    required this.gender,
    required this.religious,
    required this.nativeLanguage,
    required this.residentId,
    required this.userId,
    this.photo,
    this.createdAt,
    this.updatedAt,
  });

  // Converts API response to UserModel
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uniqueId: json['unique_id'] as String,
      fullName: json['full_name'] as String,
      phoneNumber: json['phone_number'] as String,
      role: json['role'] as String,
      birthday: DateTime.parse(json['birthday'] as String),
      apartmentNumber: json['apartment_number'] as String,
      maritalStatus: json['marital_status'] as String,
      gender: json['gender'] as String,
      religious: json['religious'] as String,
      nativeLanguage: json['native_language'] as String,
      residentId: json['resident_id'] as int,
      userId: json['user_id'] as String,
      photo: json['photo'] as String?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  // Converts UserModel to JSON for API requests
  Map<String, dynamic> toJson() {
    return {
      'full_name': fullName,
      'phone_number': phoneNumber,
      'role': role,
      'birthday': birthday.toIso8601String().split('T')[0], // Send only date part (YYYY-MM-DD)
      'apartment_number': apartmentNumber,
      'marital_status': maritalStatus,
      'gender': gender,
      'religious': religious,
      'native_language': nativeLanguage,
      'resident_id': residentId,
      'user_id': userId,
      if (photo != null) 'photo': photo,
    };
  }

  // Legacy method for backward compatibility
  Map<String, dynamic> toMap() {
    return toJson();
  }

  UserModel copyWith({
    String? uniqueId,
    String? fullName,
    String? phoneNumber,
    String? role,
    DateTime? birthday,
    String? apartmentNumber,
    String? maritalStatus,
    String? gender,
    String? religious,
    String? nativeLanguage,
    int? residentId,
    String? userId,
    String? photo,
    String? createdAt,
    String? updatedAt,
  }) {
    return UserModel(
      uniqueId: uniqueId ?? this.uniqueId,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      role: role ?? this.role,
      birthday: birthday ?? this.birthday,
      apartmentNumber: apartmentNumber ?? this.apartmentNumber,
      maritalStatus: maritalStatus ?? this.maritalStatus,
      gender: gender ?? this.gender,
      religious: religious ?? this.religious,
      nativeLanguage: nativeLanguage ?? this.nativeLanguage,
      residentId: residentId ?? this.residentId,
      userId: userId ?? this.userId,
      photo: photo ?? this.photo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
