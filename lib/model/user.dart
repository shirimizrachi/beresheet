class UserModel {
  final String uniqueId;
  final String fullName;
  final String phoneNumber;
  final String role;
  final DateTime birthday;
  final String apartmentNumber;
  final String maritalStatus;
  final String gender;
  final String religious;
  final String nativeLanguage;
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
      if (photo != null) 'photo': photo,
    };
  }

  // Legacy method for backward compatibility
  factory UserModel.fromFirestore(Map<String, dynamic> doc) {
    return UserModel(
      uniqueId: doc['uid'] as String,
      fullName: doc['fullName'] as String,
      phoneNumber: doc['phoneNumber'] as String,
      role: doc['role'] as String? ?? 'resident',
      birthday: doc['birthday'] != null
          ? DateTime.parse(doc['birthday'] as String)
          : DateTime.now().subtract(const Duration(days: 365 * 30)), // Default to 30 years ago
      apartmentNumber: doc['apartmentNumber'] as String? ?? '',
      maritalStatus: doc['maritalStatus'] as String? ?? '',
      gender: doc['gender'] as String? ?? '',
      religious: doc['religious'] as String? ?? '',
      nativeLanguage: doc['nativeLanguage'] as String? ?? '',
      photo: doc['photo'] as String?,
    );
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
      photo: photo ?? this.photo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
