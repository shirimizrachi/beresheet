/// Tenant table model for the admin panel system
/// Represents a database table within a tenant's schema
class TenantTable {
  final String tableName;
  final String tableType;
  final int columnCount;
  final int rowCount;

  const TenantTable({
    required this.tableName,
    required this.tableType,
    required this.columnCount,
    required this.rowCount,
  });

  /// Create TenantTable from JSON response
  factory TenantTable.fromJson(Map<String, dynamic> json) {
    return TenantTable(
      tableName: json['table_name'] as String,
      tableType: json['table_type'] as String,
      columnCount: json['column_count'] as int,
      rowCount: json['row_count'] as int,
    );
  }

  /// Convert TenantTable to JSON
  Map<String, dynamic> toJson() {
    return {
      'table_name': tableName,
      'table_type': tableType,
      'column_count': columnCount,
      'row_count': rowCount,
    };
  }

  /// Check if this table has demo data available
  bool get hasDemoData {
    const tablesWithDemoData = [
      'users',
      'service_provider_types',
      'event_instructor',
      'events',
      'rooms',
      'home_notification',
      'user_notification'
    ];
    return tablesWithDemoData.contains(tableName.toLowerCase());
  }

  /// Get a display-friendly table name
  String get displayName {
    return tableName
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  /// Get table statistics summary
  String get statisticsSummary {
    return '$columnCount columns • $rowCount rows';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TenantTable &&
        other.tableName == tableName &&
        other.tableType == tableType &&
        other.columnCount == columnCount &&
        other.rowCount == rowCount;
  }

  @override
  int get hashCode {
    return Object.hash(tableName, tableType, columnCount, rowCount);
  }

  @override
  String toString() {
    return 'TenantTable(name: $tableName, type: $tableType, columns: $columnCount, rows: $rowCount)';
  }
}

/// Tenant tables response wrapper
class TenantTablesResponse {
  final String tenantName;
  final String schema;
  final List<TenantTable> tables;
  final int totalTables;

  const TenantTablesResponse({
    required this.tenantName,
    required this.schema,
    required this.tables,
    required this.totalTables,
  });

  /// Create TenantTablesResponse from JSON response
  factory TenantTablesResponse.fromJson(Map<String, dynamic> json) {
    final tablesList = json['tables'] as List<dynamic>;
    final tables = tablesList
        .map((tableJson) => TenantTable.fromJson(tableJson as Map<String, dynamic>))
        .toList();

    return TenantTablesResponse(
      tenantName: json['tenant_name'] as String,
      schema: json['schema'] as String,
      tables: tables,
      totalTables: json['total_tables'] as int,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'tenant_name': tenantName,
      'schema': schema,
      'tables': tables.map((table) => table.toJson()).toList(),
      'total_tables': totalTables,
    };
  }

  /// Get tables that have demo data available
  List<TenantTable> get tablesWithDemoData {
    return tables.where((table) => table.hasDemoData).toList();
  }

  /// Get tables without demo data
  List<TenantTable> get tablesWithoutDemoData {
    return tables.where((table) => !table.hasDemoData).toList();
  }

  @override
  String toString() {
    return 'TenantTablesResponse(tenant: $tenantName, schema: $schema, tables: ${tables.length})';
  }
}

/// Table operation response
class TableOperationResponse {
  final String status;
  final String message;
  final String tenantName;
  final String tableName;
  final String schema;
  final bool droppedBeforeCreate;
  final bool dataLoaded;

  const TableOperationResponse({
    required this.status,
    required this.message,
    required this.tenantName,
    required this.tableName,
    required this.schema,
    this.droppedBeforeCreate = false,
    this.dataLoaded = false,
  });

  /// Create TableOperationResponse from JSON response
  factory TableOperationResponse.fromJson(Map<String, dynamic> json) {
    return TableOperationResponse(
      status: json['status'] as String,
      message: json['message'] as String,
      tenantName: json['tenant_name'] as String,
      tableName: json['table_name'] as String,
      schema: json['schema'] as String,
      droppedBeforeCreate: json['dropped_before_create'] as bool? ?? false,
      dataLoaded: json['data_loaded'] as bool? ?? false,
    );
  }

  /// Check if the operation was successful
  bool get isSuccess {
    return status.toLowerCase() == 'success';
  }

  /// Check if the operation had partial success
  bool get isPartialSuccess {
    return status.toLowerCase() == 'partial_success';
  }

  @override
  String toString() {
    return 'TableOperationResponse(status: $status, table: $tableName, message: $message)';
  }
}