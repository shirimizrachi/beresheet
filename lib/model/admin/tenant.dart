/// Tenant model for the admin panel system
/// Represents a tenant configuration that maps to the home table structure
class Tenant {
  final int id;
  final String name;
  final String databaseName;
  final String databaseType;
  final String databaseSchema;
  final String adminUserEmail;
  final String adminUserPassword;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Tenant({
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

  /// Create Tenant from JSON response
  factory Tenant.fromJson(Map<String, dynamic> json) {
    return Tenant(
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

  /// Convert Tenant to JSON for API requests
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

  /// Create a copy of Tenant with some updated fields
  Tenant copyWith({
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
    return Tenant(
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
    return other is Tenant &&
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
    return 'Tenant(id: $id, name: $name, schema: $databaseSchema, email: $adminUserEmail)';
  }
}

/// Tenant creation model for new tenant requests (simplified - only requires name)
class TenantCreate {
  final String name;

  const TenantCreate({
    required this.name,
  });

  /// Convert to JSON for API requests
  Map<String, dynamic> toJson() {
    return {
      'name': name,
    };
  }

  /// Create from form data or user input
  factory TenantCreate.fromForm({
    required String name,
  }) {
    return TenantCreate(
      name: name.trim(),
    );
  }

  @override
  String toString() {
    return 'TenantCreate(name: $name)';
  }
}

/// Tenant update model for tenant modification requests
class TenantUpdate {
  final String? name;
  final String? databaseName;
  final String? databaseType;
  final String? databaseSchema;
  final String? adminUserEmail;
  final String? adminUserPassword;

  const TenantUpdate({
    this.name,
    this.databaseName,
    this.databaseType,
    this.databaseSchema,
    this.adminUserEmail,
    this.adminUserPassword,
  });

  /// Convert to JSON for API requests (only include non-null fields)
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {};
    
    if (name != null) json['name'] = name;
    if (databaseName != null) json['database_name'] = databaseName;
    if (databaseType != null) json['database_type'] = databaseType;
    if (databaseSchema != null) json['database_schema'] = databaseSchema;
    if (adminUserEmail != null) json['admin_user_email'] = adminUserEmail;
    if (adminUserPassword != null) json['admin_user_password'] = adminUserPassword;
    
    return json;
  }

  /// Check if this update has any fields to update
  bool get hasUpdates {
    return name != null ||
        databaseName != null ||
        databaseType != null ||
        databaseSchema != null ||
        adminUserEmail != null ||
        adminUserPassword != null;
  }

  @override
  String toString() {
    return 'TenantUpdate(hasUpdates: $hasUpdates)';
  }
}