/// Helper function to parse UTC timestamp to local DateTime
DateTime _parseUtcToLocal(String utcString) {
  // Add 'Z' suffix if not present to ensure UTC parsing
  final utcStringWithZ = utcString.endsWith('Z') ? utcString : '${utcString}Z';
  return DateTime.parse(utcStringWithZ).toLocal();
}

/// Web JWT User model - completely separate from admin user
class WebJwtUser {
  final String id;
  final String phoneNumber;
  final String fullName;
  final String role;
  final int homeId;
  final String? homeName;
  final String? photo;
  final String? apartmentNumber;
  final DateTime createdAt;
  final DateTime updatedAt;

  const WebJwtUser({
    required this.id,
    required this.phoneNumber,
    required this.fullName,
    required this.role,
    required this.homeId,
    this.homeName,
    this.photo,
    this.apartmentNumber,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WebJwtUser.fromJson(Map<String, dynamic> json) {
    return WebJwtUser(
      id: json['id'] as String,
      phoneNumber: json['phoneNumber'] as String,
      fullName: json['fullName'] as String,
      role: json['role'] as String,
      homeId: (json['homeId'] as num).toInt(),
      homeName: json['homeName'] as String?,
      photo: json['photo'] as String?,
      apartmentNumber: json['apartmentNumber'] as String?,
      createdAt: _parseUtcToLocal(json['createdAt'] as String),
      updatedAt: _parseUtcToLocal(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phoneNumber': phoneNumber,
      'fullName': fullName,
      'role': role,
      'homeId': homeId,
      'homeName': homeName,
      'photo': photo,
      'apartmentNumber': apartmentNumber,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    };
  }

  @override
  String toString() => 'WebJwtUser(id: $id, phoneNumber: $phoneNumber, fullName: $fullName, role: $role, homeId: $homeId, homeName: $homeName)';
}

/// Web JWT Session model
class WebJwtSession {
  final String token;
  final String refreshToken;
  final WebJwtUser user;
  final DateTime expiresAt;
  final DateTime refreshExpiresAt;
  final DateTime createdAt;

  const WebJwtSession({
    required this.token,
    required this.refreshToken,
    required this.user,
    required this.expiresAt,
    required this.refreshExpiresAt,
    required this.createdAt,
  });

  factory WebJwtSession.fromJson(Map<String, dynamic> json) {
    return WebJwtSession(
      token: json['token'] as String,
      refreshToken: json['refreshToken'] as String,
      user: WebJwtUser.fromJson(json['user'] as Map<String, dynamic>),
      expiresAt: _parseUtcToLocal(json['expiresAt'] as String),
      refreshExpiresAt: _parseUtcToLocal(json['refreshExpiresAt'] as String),
      createdAt: _parseUtcToLocal(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'refreshToken': refreshToken,
      'user': user.toJson(),
      'expiresAt': expiresAt.toUtc().toIso8601String(),
      'refreshExpiresAt': refreshExpiresAt.toUtc().toIso8601String(),
      'createdAt': createdAt.toUtc().toIso8601String(),
    };
  }

  /// Check if the main token is still valid
  bool get isValid {
    final now = DateTime.now();
    return now.isBefore(expiresAt);
  }

  /// Check if the refresh token is still valid
  bool get canRefresh => DateTime.now().isBefore(refreshExpiresAt);

  /// Get time remaining until token expires
  Duration get timeUntilExpiration => expiresAt.difference(DateTime.now());

  /// Check if token needs refresh (within 5 minutes of expiration)
  bool get needsRefresh => timeUntilExpiration.inMinutes <= 5;

  @override
  String toString() => 'WebJwtSession(user: ${user.fullName}, expiresAt: $expiresAt, isValid: $isValid)';
}

/// Web JWT Credentials for login
class WebJwtCredentials {
  final String phoneNumber;
  final String password;
  final int homeId;

  const WebJwtCredentials({
    required this.phoneNumber,
    required this.password,
    required this.homeId,
  });

  factory WebJwtCredentials.fromJson(Map<String, dynamic> json) {
    return WebJwtCredentials(
      phoneNumber: json['phoneNumber'] as String,
      password: json['password'] as String,
      homeId: (json['homeId'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'phoneNumber': phoneNumber,
      'password': password,
      'homeId': homeId,
    };
  }
}

/// Web JWT Login Result
class WebJwtLoginResult {
  final bool success;
  final String message;
  final WebJwtSession? session;
  final String? error;

  const WebJwtLoginResult({
    required this.success,
    required this.message,
    this.session,
    this.error,
  });

  factory WebJwtLoginResult.fromJson(Map<String, dynamic> json) {
    return WebJwtLoginResult(
      success: json['success'] as bool,
      message: json['message'] as String,
      session: json['session'] == null
          ? null
          : WebJwtSession.fromJson(json['session'] as Map<String, dynamic>),
      error: json['error'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'session': session?.toJson(),
      'error': error,
    };
  }
}