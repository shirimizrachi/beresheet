import 'package:flutter/material.dart';
import '../../../config/admin_config.dart';
import '../../../services/admin/admin_auth_service.dart';
import '../../../services/admin/admin_api_service.dart';
import '../../../model/admin/admin_user.dart';
import '../../../model/admin/tenant.dart';
import 'admin_login_screen.dart';
import 'widgets/tenant_card_widget.dart';
import 'widgets/tenant_form_widget.dart';

/// Independent admin dashboard screen for the tenant management system
/// Provides complete tenant management functionality
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  AdminUser? _currentUser;
  List<Tenant> _tenants = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;
  String? _successMessage;
  Map<String, dynamic>? _healthData;

  @override
  void initState() {
    super.initState();
    _initializeDashboard();
  }

  /// Initialize dashboard by checking auth and loading data
  Future<void> _initializeDashboard() async {
    try {
      // Check authentication
      final isAuthenticated = await AdminAuthService.isAuthenticated();
      if (!isAuthenticated) {
        _navigateToLogin();
        return;
      }

      // Load current user
      _currentUser = await AdminAuthService.getCurrentUser();
      
      // Load initial data
      await _loadAllData();
    } catch (e) {
      print('Error initializing admin dashboard: $e');
      _showErrorMessage('Failed to initialize dashboard: ${e.toString()}');
    }
  }

  /// Load all dashboard data
  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await Future.wait([
        _loadTenants(),
        _performHealthCheck(),
      ]);
    } catch (e) {
      print('Error loading dashboard data: $e');
      _showErrorMessage('Failed to load data: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Load tenants from API
  Future<void> _loadTenants() async {
    try {
      final tenants = await AdminApiService.getTenants();
      if (mounted) {
        setState(() {
          _tenants = tenants;
        });
      }
    } catch (e) {
      print('Error loading tenants: $e');
      rethrow;
    }
  }

  /// Perform health check
  Future<void> _performHealthCheck() async {
    try {
      final healthData = await AdminApiService.healthCheck();
      if (mounted) {
        setState(() {
          _healthData = healthData;
        });
      }
    } catch (e) {
      print('Error performing health check: $e');
      // Don't rethrow - health check failure shouldn't prevent dashboard loading
    }
  }

  /// Refresh data
  Future<void> _refreshData() async {
    setState(() {
      _isRefreshing = true;
    });

    try {
      await _loadAllData();
      _showSuccessMessage('Data refreshed successfully');
    } catch (e) {
      _showErrorMessage('Failed to refresh data: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  /// Show tenant creation form
  void _showCreateTenantForm() {
    showDialog(
      context: context,
      builder: (context) => TenantFormWidget(
        onTenantSaved: (tenant) {
          _refreshData();
          _showSuccessMessage(AdminConfig.tenantCreatedMessage);
        },
      ),
    );
  }

  /// Show tenant edit form
  void _showEditTenantForm(Tenant tenant) {
    showDialog(
      context: context,
      builder: (context) => TenantFormWidget(
        tenant: tenant,
        onTenantSaved: (updatedTenant) {
          _refreshData();
          _showSuccessMessage(AdminConfig.tenantUpdatedMessage);
        },
      ),
    );
  }

  /// Delete tenant
  Future<void> _deleteTenant(Tenant tenant) async {
    final confirmed = await _showDeleteConfirmation(tenant);
    if (!confirmed) return;

    try {
      await AdminApiService.deleteTenant(tenant.id);
      await _refreshData();
      _showSuccessMessage(AdminConfig.tenantDeletedMessage);
    } catch (e) {
      _showErrorMessage('Failed to delete tenant: ${e.toString()}');
    }
  }

  /// Show delete confirmation dialog
  Future<bool> _showDeleteConfirmation(Tenant tenant) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Tenant'),
        content: Text(
          'Are you sure you want to delete tenant "${tenant.name}"?\n\n'
          'This action cannot be undone and will remove all tenant data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(AdminConfig.errorColorValue),
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ?? false;
  }

  /// Handle logout
  Future<void> _handleLogout() async {
    try {
      await AdminAuthService.logout();
      _navigateToLogin();
    } catch (e) {
      print('Error during logout: $e');
      // Navigate to login anyway
      _navigateToLogin();
    }
  }

  /// Navigate to login screen
  void _navigateToLogin() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const AdminLoginScreen(),
      ),
    );
  }

  /// Show success message
  void _showSuccessMessage(String message) {
    setState(() {
      _successMessage = message;
      _errorMessage = null;
    });

    // Auto-hide after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _successMessage = null;
        });
      }
    });
  }

  /// Show error message
  void _showErrorMessage(String message) {
    setState(() {
      _errorMessage = message;
      _successMessage = null;
    });

    // Auto-hide after 10 seconds
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) {
        setState(() {
          _errorMessage = null;
        });
      }
    });
  }

  /// Build app bar
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        AdminConfig.adminDashboardTitle,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      backgroundColor: const Color(AdminConfig.primaryColorValue),
      elevation: 2,
      automaticallyImplyLeading: false,
      actions: [
        // Health status indicator
        if (_healthData != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AdminConfig.smallPadding),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AdminConfig.smallPadding,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _healthData!['status'] == 'healthy'
                      ? const Color(AdminConfig.successColorValue)
                      : const Color(AdminConfig.errorColorValue),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _healthData!['status'] == 'healthy'
                          ? Icons.favorite
                          : Icons.error,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${_healthData!['tenant_count']} tenants',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // User info and logout
        PopupMenuButton<String>(
          icon: const Icon(Icons.account_circle, color: Colors.white),
          onSelected: (value) {
            if (value == 'logout') {
              _handleLogout();
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem<String>(
              enabled: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _currentUser?.name ?? 'Admin User',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _currentUser?.adminUserEmail ?? '',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem<String>(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout),
                  SizedBox(width: 8),
                  Text('Logout'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Build action buttons
  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(AdminConfig.defaultPadding),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          ElevatedButton.icon(
            onPressed: _isLoading || _isRefreshing ? null : _refreshData,
            icon: _isRefreshing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            label: Text(_isRefreshing ? 'Refreshing...' : 'Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(AdminConfig.accentColorValue),
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: AdminConfig.defaultPadding),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _showCreateTenantForm,
            icon: const Icon(Icons.add),
            label: const Text('Add New Tenant'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(AdminConfig.successColorValue),
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: AdminConfig.defaultPadding),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _performHealthCheck,
            icon: const Icon(Icons.favorite),
            label: const Text('Health Check'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(AdminConfig.infoColorValue),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// Build status messages
  Widget? _buildStatusMessage() {
    if (_successMessage != null) {
      return Container(
        padding: const EdgeInsets.all(AdminConfig.defaultPadding),
        margin: const EdgeInsets.only(bottom: AdminConfig.defaultPadding),
        decoration: BoxDecoration(
          color: const Color(AdminConfig.successColorValue).withOpacity(0.1),
          border: Border.all(color: const Color(AdminConfig.successColorValue)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.check_circle,
              color: Color(AdminConfig.successColorValue),
            ),
            const SizedBox(width: AdminConfig.smallPadding),
            Expanded(
              child: Text(
                _successMessage!,
                style: const TextStyle(
                  color: Color(AdminConfig.successColorValue),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Container(
        padding: const EdgeInsets.all(AdminConfig.defaultPadding),
        margin: const EdgeInsets.only(bottom: AdminConfig.defaultPadding),
        decoration: BoxDecoration(
          color: const Color(AdminConfig.errorColorValue).withOpacity(0.1),
          border: Border.all(color: const Color(AdminConfig.errorColorValue)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.error,
              color: Color(AdminConfig.errorColorValue),
            ),
            const SizedBox(width: AdminConfig.smallPadding),
            Expanded(
              child: Text(
                _errorMessage!,
                style: const TextStyle(
                  color: Color(AdminConfig.errorColorValue),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              onPressed: () {
                setState(() {
                  _errorMessage = null;
                });
              },
              icon: const Icon(
                Icons.close,
                color: Color(AdminConfig.errorColorValue),
              ),
            ),
          ],
        ),
      );
    }

    return null;
  }

  /// Build tenant grid
  Widget _buildTenantGrid() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: AdminConfig.defaultPadding),
            Text('Loading tenants...'),
          ],
        ),
      );
    }

    if (_tenants.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.business,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: AdminConfig.defaultPadding),
            Text(
              'No tenants configured yet.',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: AdminConfig.smallPadding),
            Text(
              'Click "Add New Tenant" to create your first tenant.',
              style: TextStyle(
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AdminConfig.defaultPadding,
        mainAxisSpacing: AdminConfig.defaultPadding,
        childAspectRatio: 1.2,
      ),
      itemCount: _tenants.length,
      itemBuilder: (context, index) {
        final tenant = _tenants[index];
        return TenantCardWidget(
          tenant: tenant,
          onEdit: () => _showEditTenantForm(tenant),
          onDelete: () => _deleteTenant(tenant),
          onRefreshTables: _refreshData,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Container(
        constraints: const BoxConstraints(maxWidth: AdminConfig.adminPanelMaxWidth),
        margin: const EdgeInsets.symmetric(horizontal: AdminConfig.defaultPadding),
        child: Column(
          children: [
            const SizedBox(height: AdminConfig.defaultPadding),
            
            // Action buttons
            _buildActionButtons(),
            
            const SizedBox(height: AdminConfig.defaultPadding),

            // Status messages
            if (_buildStatusMessage() != null) _buildStatusMessage()!,

            // Tenant grid
            Expanded(
              child: _buildTenantGrid(),
            ),
          ],
        ),
      ),
    );
  }
}