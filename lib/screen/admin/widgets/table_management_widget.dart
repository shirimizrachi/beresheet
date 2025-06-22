import 'package:flutter/material.dart';
import '../../../config/admin_config.dart';
import '../../../model/admin/tenant_table.dart';
import '../../../services/admin/admin_api_service.dart';

/// Widget for managing tenant tables
/// Provides functionality to recreate tables and load demo data
class TableManagementWidget extends StatefulWidget {
  final String tenantName;
  final List<TenantTable> tables;
  final VoidCallback onTableOperationComplete;

  const TableManagementWidget({
    Key? key,
    required this.tenantName,
    required this.tables,
    required this.onTableOperationComplete,
  }) : super(key: key);

  @override
  State<TableManagementWidget> createState() => _TableManagementWidgetState();
}

class _TableManagementWidgetState extends State<TableManagementWidget> {
  final Map<String, bool> _operationInProgress = {};
  final Map<String, bool> _dropBeforeRecreate = {};

  @override
  void initState() {
    super.initState();
    // Initialize drop flags to true by default
    for (final table in widget.tables) {
      _dropBeforeRecreate[table.tableName] = true;
    }
  }

  /// Recreate a table
  Future<void> _recreateTable(TenantTable table) async {
    final shouldDrop = _dropBeforeRecreate[table.tableName] ?? true;
    
    // Show confirmation dialog
    final confirmed = await _showRecreateConfirmation(table, shouldDrop);
    if (!confirmed) return;

    setState(() {
      _operationInProgress[table.tableName] = true;
    });

    try {
      final response = await AdminApiService.recreateTable(
        widget.tenantName,
        table.tableName,
        dropIfExists: shouldDrop,
      );

      if (mounted) {
        _showSuccessSnackBar(response.message);
        widget.onTableOperationComplete();
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to recreate table ${table.tableName}: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _operationInProgress[table.tableName] = false;
        });
      }
    }
  }

  /// Load demo data for a table
  Future<void> _loadTableData(TenantTable table) async {
    // Show confirmation dialog
    final confirmed = await _showLoadDataConfirmation(table);
    if (!confirmed) return;

    setState(() {
      _operationInProgress['${table.tableName}_data'] = true;
    });

    try {
      final response = await AdminApiService.loadTableData(
        widget.tenantName,
        table.tableName,
      );

      if (mounted) {
        _showSuccessSnackBar(response.message);
        widget.onTableOperationComplete();
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to load data for table ${table.tableName}: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _operationInProgress['${table.tableName}_data'] = false;
        });
      }
    }
  }

  /// Show recreate table confirmation dialog
  Future<bool> _showRecreateConfirmation(TenantTable table, bool shouldDrop) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recreate Table'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to recreate table "${table.tableName}"?'),
            const SizedBox(height: AdminConfig.defaultPadding),
            if (shouldDrop)
              const Text(
                'The table will be dropped first. All existing data will be lost.',
                style: TextStyle(
                  color: Color(AdminConfig.warningColorValue),
                  fontWeight: FontWeight.bold,
                ),
              )
            else
              const Text(
                'Existing data may be affected.',
                style: TextStyle(
                  color: Color(AdminConfig.infoColorValue),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(AdminConfig.warningColorValue),
              foregroundColor: Colors.white,
            ),
            child: const Text('Recreate'),
          ),
        ],
      ),
    ) ?? false;
  }

  /// Show load data confirmation dialog
  Future<bool> _showLoadDataConfirmation(TenantTable table) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Load Demo Data'),
        content: Text(
          'Are you sure you want to load demo data into table "${table.tableName}"?\n\n'
          'This will add or replace data in the table.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(AdminConfig.successColorValue),
              foregroundColor: Colors.white,
            ),
            child: const Text('Load Data'),
          ),
        ],
      ),
    ) ?? false;
  }

  /// Show success snackbar
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(AdminConfig.successColorValue),
      ),
    );
  }

  /// Show error snackbar
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(AdminConfig.errorColorValue),
      ),
    );
  }

  /// Get table display name
  String _getTableDisplayName(String tableName) {
    return tableName
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: widget.tables.length,
        itemBuilder: (context, index) {
          final table = widget.tables[index];
          final isRecreating = _operationInProgress[table.tableName] ?? false;
          final isLoadingData = _operationInProgress['${table.tableName}_data'] ?? false;
          
          return Container(
            margin: const EdgeInsets.only(bottom: AdminConfig.smallPadding),
            padding: const EdgeInsets.all(AdminConfig.smallPadding),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              children: [
                // Table info row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getTableDisplayName(table.tableName),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            table.statisticsSummary,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Demo data indicator
                    if (table.hasDemoData)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(AdminConfig.successColorValue).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(AdminConfig.successColorValue),
                            width: 1,
                          ),
                        ),
                        child: const Text(
                          'Demo Available',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(AdminConfig.successColorValue),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                
                const SizedBox(height: AdminConfig.smallPadding),
                
                // Actions row
                Row(
                  children: [
                    // Drop checkbox
                    Expanded(
                      flex: 2,
                      child: Row(
                        children: [
                          Checkbox(
                            value: _dropBeforeRecreate[table.tableName] ?? true,
                            onChanged: isRecreating ? null : (value) {
                              setState(() {
                                _dropBeforeRecreate[table.tableName] = value ?? true;
                              });
                            },
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          const Expanded(
                            child: Text(
                              'Drop first',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Recreate button
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: isRecreating || isLoadingData ? null : () => _recreateTable(table),
                        icon: isRecreating
                            ? const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh, size: 14),
                        label: Text(
                          isRecreating ? 'Creating...' : 'Recreate',
                          style: const TextStyle(fontSize: 11),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(AdminConfig.warningColorValue),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                          minimumSize: const Size(0, 28),
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: AdminConfig.smallPadding),
                    
                    // Load data button (only for tables with demo data)
                    if (table.hasDemoData)
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: isRecreating || isLoadingData ? null : () => _loadTableData(table),
                          icon: isLoadingData
                              ? const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.upload, size: 14),
                          label: Text(
                            isLoadingData ? 'Loading...' : 'Load Data',
                            style: const TextStyle(fontSize: 11),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(AdminConfig.successColorValue),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                            minimumSize: const Size(0, 28),
                          ),
                        ),
                      )
                    else
                      const Expanded(flex: 2, child: SizedBox()),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}