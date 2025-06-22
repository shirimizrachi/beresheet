/// Admin user model for the independent admin panel system
/// This represents a user from the home table in the home schema
class AdminUser {
  final int id;
  final String name;
  final String databaseName;
  final String databaseType;
  final String databaseSchema;
  final String adminUserEmail;
  final String adminUserPassword;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AdminUser({
    required this.id,
    required this.name,
    required this.databaseName,
    required this.databaseType,
    required this.databaseSchema,
    required this.adminUserEmail,
    required this.adminUserPassword,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create AdminUser from JSON response
  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: json['id'] as int,
      name: json['name'] as String,
      databaseName: json['database_name'] as String,
      databaseType: json['database_type'] as String,
      databaseSchema: json['database_schema'] as String,
      adminUserEmail: json['admin_user_email'] as String,
      adminUserPassword: json['admin_user_password'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Convert AdminUser to JSON for API requests
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'database_name': databaseName,
      'database_type': databaseType,
      'database_schema': databaseSchema,
      'admin_user_email': adminUserEmail,
      'admin_user_password': adminUserPassword,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Create a copy of AdminUser with some updated fields
  AdminUser copyWith({
    int? id,
    String? name,
    String? databaseName,
    String? databaseType,
    String? databaseSchema,
    String? adminUserEmail,
    String? adminUserPassword,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AdminUser(
      id: id ?? this.id,
      name: name ?? this.name,
      databaseName: databaseName ?? this.databaseName,
      databaseType: databaseType ?? this.databaseType,
      databaseSchema: databaseSchema ?? this.databaseSchema,
      adminUserEmail: adminUserEmail ?? this.adminUserEmail,
      adminUserPassword: adminUserPassword ?? this.adminUserPassword,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AdminUser &&
        other.id == id &&
        other.name == name &&
        other.databaseName == databaseName &&
        other.databaseType == databaseType &&
        other.databaseSchema == databaseSchema &&
        other.adminUserEmail == adminUserEmail &&
        other.adminUserPassword == adminUserPassword &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      name,
      databaseName,
      databaseType,
      databaseSchema,
      adminUserEmail,
      adminUserPassword,
      createdAt,
      updatedAt,
    );
  }

  @override
  String toString() {
    return 'AdminUser(id: $id, name: $name, email: $adminUserEmail, schema: $databaseSchema)';
  }
}

/// Admin login credentials model
class AdminCredentials {
  final String email;
  final String password;

  const AdminCredentials({
    required this.email,
    required this.password,
  });

  /// Convert to JSON for API requests
  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'password': password,
    };
  }

  @override
  String toString() {
    return 'AdminCredentials(email: $email, password: [HIDDEN])';
  }
}

/// Admin session model
class AdminSession {
  final String token;
  final AdminUser user;
  final DateTime expiresAt;
  final DateTime createdAt;

  const AdminSession({
    required this.token,
    required this.user,
    required this.expiresAt,
    required this.createdAt,
  });

  /// Create AdminSession from JSON response
  factory AdminSession.fromJson(Map<String, dynamic> json) {
    return AdminSession(
      token: json['token'] as String,
      user: AdminUser.fromJson(json['user'] as Map<String, dynamic>),
      expiresAt: DateTime.parse(json['expires_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Convert AdminSession to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'user': user.toJson(),
      'expires_at': expiresAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Check if the session is still valid
  bool get isValid {
    return DateTime.now().isBefore(expiresAt);
  }

  /// Get time remaining until expiration
  Duration get timeUntilExpiration {
    return expiresAt.difference(DateTime.now());
  }

  @override
  String toString() {
    return 'AdminSession(user: ${user.name}, valid: $isValid, expires: $expiresAt)';
  }
}