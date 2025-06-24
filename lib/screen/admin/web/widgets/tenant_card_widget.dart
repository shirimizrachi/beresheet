import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../config/admin_config.dart';
import '../../../../model/admin/tenant.dart';
import '../../../../model/admin/tenant_table.dart';
import '../../../../services/admin/admin_api_service.dart';
import 'table_management_widget.dart';

/// Widget for displaying tenant information in a card format
/// Includes actions for editing, deleting, viewing, and managing tables
class TenantCardWidget extends StatefulWidget {
  final Tenant tenant;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onRefreshTables;

  const TenantCardWidget({
    Key? key,
    required this.tenant,
    required this.onEdit,
    required this.onDelete,
    required this.onRefreshTables,
  }) : super(key: key);

  @override
  State<TenantCardWidget> createState() => _TenantCardWidgetState();
}

class _TenantCardWidgetState extends State<TenantCardWidget> {
  bool _isTablesExpanded = false;
  bool _isLoadingTables = false;
  List<TenantTable> _tables = [];
  String? _tablesError;

  /// Toggle table management section
  Future<void> _toggleTablesSection() async {
    setState(() {
      _isTablesExpanded = !_isTablesExpanded;
    });

    if (_isTablesExpanded && _tables.isEmpty) {
      await _loadTables();
    }
  }

  /// Load tables for this tenant
  Future<void> _loadTables() async {
    setState(() {
      _isLoadingTables = true;
      _tablesError = null;
    });

    try {
      final tablesResponse = await AdminApiService.getTenantTables(widget.tenant.name);
      if (mounted) {
        setState(() {
          _tables = tablesResponse.tables;
        });
      }
    } catch (e) {
      print('Error loading tables for tenant ${widget.tenant.name}: $e');
      if (mounted) {
        setState(() {
          _tablesError = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingTables = false;
        });
      }
    }
  }

  /// Handle table operation completion
  void _onTableOperationComplete() {
    _loadTables();
    widget.onRefreshTables();
  }

  /// Open tenant in new browser tab/window
  void _viewTenant() {
    final url = '/${widget.tenant.name}/web';
    // For Flutter web, this would open in a new tab
    // In a real implementation, you might use url_launcher package
    print('Opening tenant URL: $url');
    
    // Show snackbar with URL for now
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Tenant URL: $url'),
        action: SnackBarAction(
          label: 'Copy',
          onPressed: () {
            Clipboard.setData(ClipboardData(text: url));
          },
        ),
      ),
    );
  }

  /// Get tenant status color based on creation date
  Color _getTenantStatusColor() {
    final daysSinceCreation = DateTime.now().difference(widget.tenant.createdAt).inDays;
    if (daysSinceCreation < 1) {
      return const Color(AdminConfig.successColorValue);
    } else if (daysSinceCreation < 7) {
      return const Color(AdminConfig.infoColorValue);
    } else {
      return const Color(AdminConfig.primaryColorValue);
    }
  }

  /// Format date for display
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Container(
        padding: const EdgeInsets.all(AdminConfig.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with tenant name and status
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.tenant.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(AdminConfig.primaryColorValue),
                    ),
                  ),
                ),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _getTenantStatusColor(),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: AdminConfig.smallPadding),

            // Tenant information
            _buildInfoRow('ID', widget.tenant.id.toString()),
            _buildInfoRow('Database', widget.tenant.databaseName),
            _buildInfoRow('Schema', widget.tenant.databaseSchema),
            _buildInfoRow('Type', widget.tenant.databaseType.toUpperCase()),
            _buildInfoRow('Admin', widget.tenant.adminUserEmail),
            _buildInfoRow('Created', _formatDate(widget.tenant.createdAt)),

            const SizedBox(height: AdminConfig.defaultPadding),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: widget.onEdit,
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(AdminConfig.accentColorValue),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: AdminConfig.smallPadding),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _viewTenant,
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('View'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(AdminConfig.successColorValue),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AdminConfig.smallPadding),

            // Delete and Tables buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: widget.onDelete,
                    icon: const Icon(Icons.delete, size: 16),
                    label: const Text('Delete'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(AdminConfig.errorColorValue),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: AdminConfig.smallPadding),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _toggleTablesSection,
                    icon: Icon(
                      _isTablesExpanded ? Icons.expand_less : Icons.expand_more,
                      size: 16,
                    ),
                    label: const Text('Tables'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(AdminConfig.infoColorValue),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),

            // Table management section
            if (_isTablesExpanded) ...[
              const SizedBox(height: AdminConfig.defaultPadding),
              Container(
                padding: const EdgeInsets.all(AdminConfig.defaultPadding),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.table_chart,
                          size: 16,
                          color: Color(AdminConfig.primaryColorValue),
                        ),
                        const SizedBox(width: AdminConfig.smallPadding),
                        const Text(
                          'Schema Tables',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(AdminConfig.primaryColorValue),
                          ),
                        ),
                        const Spacer(),
                        if (_isLoadingTables)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),

                    const SizedBox(height: AdminConfig.smallPadding),

                    // Tables content
                    if (_isLoadingTables)
                      const Padding(
                        padding: EdgeInsets.all(AdminConfig.defaultPadding),
                        child: Center(child: Text('Loading tables...')),
                      )
                    else if (_tablesError != null)
                      Container(
                        padding: const EdgeInsets.all(AdminConfig.smallPadding),
                        decoration: BoxDecoration(
                          color: const Color(AdminConfig.errorColorValue).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error,
                              size: 16,
                              color: Color(AdminConfig.errorColorValue),
                            ),
                            const SizedBox(width: AdminConfig.smallPadding),
                            Expanded(
                              child: Text(
                                'Error: $_tablesError',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(AdminConfig.errorColorValue),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (_tables.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(AdminConfig.defaultPadding),
                        child: Center(
                          child: Text(
                            'No tables found in this schema',
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      )
                    else
                      TableManagementWidget(
                        tenantName: widget.tenant.name,
                        tables: _tables,
                        onTableOperationComplete: _onTableOperationComplete,
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Build information row
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}