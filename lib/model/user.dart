class UserModel {
  final String firebaseID;
  final String fullName;
  final String phoneNumber;
  final String role; // "resident", "staff", "instructor", "service", "caregiver", "manager"
  final DateTime birthday;
  final String apartmentNumber;
  final String maritalStatus;
  final String gender;
  final String religious;
  final String nativeLanguage;
  final int homeID; // Not displayed in profile page, used for internal operations
  final String id; // Unique user identifier (primary key)
  final String? photo;
  final String? firebaseFcmToken;
  final int? serviceProviderTypeId;
  final String? serviceProviderType;
  final String? createdAt;
  final String? updatedAt;

  UserModel({
    required this.firebaseID,
    required this.fullName,
    required this.phoneNumber,
    required this.role,
    required this.birthday,
    required this.apartmentNumber,
    required this.maritalStatus,
    required this.gender,
    required this.religious,
    required this.nativeLanguage,
    required this.homeID,
    required this.id,
    this.photo,
    this.firebaseFcmToken,
    this.serviceProviderTypeId,
    this.serviceProviderType,
    this.createdAt,
    this.updatedAt,
  });

  // Converts API response to UserModel
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      firebaseID: json['firebase_id'] as String,
      fullName: json['full_name'] as String,
      phoneNumber: json['phone_number'] as String,
      role: json['role'] as String,
      birthday: DateTime.parse(json['birthday'] as String),
      apartmentNumber: json['apartment_number'] as String,
      maritalStatus: json['marital_status'] as String,
      gender: json['gender'] as String,
      religious: json['religious'] as String,
      nativeLanguage: json['native_language'] as String,
      homeID: json['home_id'] as int,
      id: json['id'] as String,
      photo: json['photo'] as String?,
      firebaseFcmToken: json['firebase_fcm_token'] as String?,
      serviceProviderTypeId: json['service_provider_type_id'] as int?,
      serviceProviderType: json['service_provider_type'] as String?,
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
      'home_id': homeID,
      'id': id,
      if (photo != null) 'photo': photo,
      if (firebaseFcmToken != null) 'firebase_fcm_token': firebaseFcmToken,
      if (serviceProviderTypeId != null) 'service_provider_type_id': serviceProviderTypeId,
      if (serviceProviderType != null) 'service_provider_type': serviceProviderType,
    };
  }

  // Legacy method for backward compatibility
  Map<String, dynamic> toMap() {
    return toJson();
  }

  UserModel copyWith({
    String? firebaseID,
    String? fullName,
    String? phoneNumber,
    String? role,
    DateTime? birthday,
    String? apartmentNumber,
    String? maritalStatus,
    String? gender,
    String? religious,
    String? nativeLanguage,
    int? homeID,
    String? id,
    String? photo,
    String? firebaseFcmToken,
    int? serviceProviderTypeId,
    String? serviceProviderType,
    String? createdAt,
    String? updatedAt,
  }) {
    return UserModel(
      firebaseID: firebaseID ?? this.firebaseID,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      role: role ?? this.role,
      birthday: birthday ?? this.birthday,
      apartmentNumber: apartmentNumber ?? this.apartmentNumber,
      maritalStatus: maritalStatus ?? this.maritalStatus,
      gender: gender ?? this.gender,
      religious: religious ?? this.religious,
      nativeLanguage: nativeLanguage ?? this.nativeLanguage,
      homeID: homeID ?? this.homeID,
      id: id ?? this.id,
      photo: photo ?? this.photo,
      firebaseFcmToken: firebaseFcmToken ?? this.firebaseFcmToken,
      serviceProviderTypeId: serviceProviderTypeId ?? this.serviceProviderTypeId,
      serviceProviderType: serviceProviderType ?? this.serviceProviderType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
