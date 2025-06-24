class ServiceProviderType {
  final String id;
  final String name;
  final String? description;

  ServiceProviderType({
    required this.id,
    required this.name,
    this.description,
  });

  factory ServiceProviderType.fromJson(Map<String, dynamic> json) {
    return ServiceProviderType(
      id: json['id'].toString(),
      name: json['name'] as String,
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
    };
  }

  @override
  String toString() {
    return 'ServiceProviderType{id: $id, name: $name, description: $description}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ServiceProviderType &&
        other.id == id &&
        other.name == name &&
        other.description == description;
  }

  @override
  int get hashCode => Object.hash(id, name, description);
}