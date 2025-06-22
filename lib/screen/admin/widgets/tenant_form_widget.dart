import 'package:flutter/material.dart';
import '../../../config/admin_config.dart';
import '../../../model/admin/tenant.dart';
import '../../../services/admin/admin_api_service.dart';

/// Widget for creating and editing tenants
/// Provides a form modal for tenant data entry and validation
class TenantFormWidget extends StatefulWidget {
  final Tenant? tenant; // null for create, non-null for edit
  final Function(Tenant) onTenantSaved;

  const TenantFormWidget({
    Key? key,
    this.tenant,
    required this.onTenantSaved,
  }) : super(key: key);

  @override
  State<TenantFormWidget> createState() => _TenantFormWidgetState();
}

class _TenantFormWidgetState extends State<TenantFormWidget> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _databaseNameController = TextEditingController();
  final _databaseSchemaController = TextEditingController();
  final _adminEmailController = TextEditingController();
  final _adminPasswordController = TextEditingController();

  String _selectedDatabaseType = AdminConfig.supportedDatabaseTypes.first;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  bool get _isEditing => widget.tenant != null;

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _databaseNameController.dispose();
    _databaseSchemaController.dispose();
    _adminEmailController.dispose();
    _adminPasswordController.dispose();
    super.dispose();
  }

  /// Initialize form with existing tenant data if editing
  void _initializeForm() {
    if (_isEditing) {
      final tenant = widget.tenant!;
      _nameController.text = tenant.name;
      _databaseNameController.text = tenant.databaseName;
      _databaseSchemaController.text = tenant.databaseSchema;
      _adminEmailController.text = tenant.adminUserEmail;
      _adminPasswordController.text = tenant.adminUserPassword;
      _selectedDatabaseType = tenant.databaseType;
    } else {
      // Set defaults for new tenant
      _databaseNameController.text = 'residents';
      _selectedDatabaseType = 'mssql';
    }

    // Auto-generate schema name when tenant name changes
    _nameController.addListener(_updateSchemaName);
  }

  /// Auto-update schema name based on tenant name
  void _updateSchemaName() {
    if (!_isEditing && _nameController.text.isNotEmpty) {
      final tenantName = _nameController.text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_');
      _databaseSchemaController.text = tenantName;
    }
  }

  /// Handle form submission
  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isEditing) {
        await _updateTenant();
      } else {
        await _createTenant();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Create new tenant
  Future<void> _createTenant() async {
    final tenantCreate = TenantCreate.fromForm(
      name: _nameController.text.trim(),
      databaseName: _databaseNameController.text.trim(),
      databaseType: _selectedDatabaseType,
      databaseSchema: _databaseSchemaController.text.trim(),
      adminUserEmail: _adminEmailController.text.trim(),
      adminUserPassword: _adminPasswordController.text,
    );

    final tenant = await AdminApiService.createTenant(tenantCreate);
    widget.onTenantSaved(tenant);
    
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  /// Update existing tenant
  Future<void> _updateTenant() async {
    final tenantUpdate = TenantUpdate(
      name: _nameController.text.trim() != widget.tenant!.name ? _nameController.text.trim() : null,
      databaseName: _databaseNameController.text.trim() != widget.tenant!.databaseName ? _databaseNameController.text.trim() : null,
      databaseType: _selectedDatabaseType != widget.tenant!.databaseType ? _selectedDatabaseType : null,
      databaseSchema: _databaseSchemaController.text.trim() != widget.tenant!.databaseSchema ? _databaseSchemaController.text.trim() : null,
      adminUserEmail: _adminEmailController.text.trim() != widget.tenant!.adminUserEmail ? _adminEmailController.text.trim() : null,
      adminUserPassword: _adminPasswordController.text != widget.tenant!.adminUserPassword ? _adminPasswordController.text : null,
    );

    if (!tenantUpdate.hasUpdates) {
      Navigator.of(context).pop();
      return;
    }

    final tenant = await AdminApiService.updateTenant(widget.tenant!.id, tenantUpdate);
    widget.onTenantSaved(tenant);
    
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  /// Validate tenant name
  String? _validateTenantName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Tenant name is required';
    }
    if (!AdminConfig.isValidTenantName(value)) {
      return 'Tenant name must be alphanumeric (with optional hyphens and underscores)';
    }
    if (value.length > AdminConfig.maxTenantNameLength) {
      return 'Tenant name must be less than ${AdminConfig.maxTenantNameLength} characters';
    }
    return null;
  }

  /// Validate database name
  String? _validateDatabaseName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Database name is required';
    }
    return null;
  }

  /// Validate schema name
  String? _validateSchemaName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Database schema is required';
    }
    if (!AdminConfig.isValidSchemaName(value)) {
      return 'Schema name must start with a letter and contain only letters, numbers, and underscores';
    }
    return null;
  }

  /// Validate email
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Admin email is required';
    }
    if (!AdminConfig.isValidEmail(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  /// Validate password
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Admin password is required';
    }
    if (!AdminConfig.isValidPassword(value)) {
      return 'Password must be at least ${AdminConfig.minPasswordLength} characters';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(AdminConfig.largePadding),
              decoration: const BoxDecoration(
                color: Color(AdminConfig.primaryColorValue),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isEditing ? Icons.edit : Icons.add,
                    color: Colors.white,
                  ),
                  const SizedBox(width: AdminConfig.smallPadding),
                  Expanded(
                    child: Text(
                      _isEditing ? 'Edit Tenant' : 'Add New Tenant',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Form content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AdminConfig.largePadding),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Error message
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(AdminConfig.defaultPadding),
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
                                size: 20,
                              ),
                              const SizedBox(width: AdminConfig.smallPadding),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    color: Color(AdminConfig.errorColorValue),
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AdminConfig.defaultPadding),
                      ],

                      // Tenant name
                      TextFormField(
                        controller: _nameController,
                        enabled: !_isLoading,
                        validator: _validateTenantName,
                        decoration: const InputDecoration(
                          labelText: 'Tenant Name',
                          hintText: 'e.g., acme-corp',
                          border: OutlineInputBorder(),
                          helperText: 'Alphanumeric with optional hyphens/underscores',
                        ),
                      ),

                      const SizedBox(height: AdminConfig.defaultPadding),

                      // Database name
                      TextFormField(
                        controller: _databaseNameController,
                        enabled: !_isLoading,
                        validator: _validateDatabaseName,
                        decoration: const InputDecoration(
                          labelText: 'Database Name',
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: AdminConfig.defaultPadding),

                      // Database type
                      DropdownButtonFormField<String>(
                        value: _selectedDatabaseType,
                        onChanged: _isLoading ? null : (value) {
                          setState(() {
                            _selectedDatabaseType = value!;
                          });
                        },
                        items: AdminConfig.supportedDatabaseTypes
                            .map((type) => DropdownMenuItem(
                                  value: type,
                                  child: Text(type.toUpperCase()),
                                ))
                            .toList(),
                        decoration: const InputDecoration(
                          labelText: 'Database Type',
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: AdminConfig.defaultPadding),

                      // Database schema
                      TextFormField(
                        controller: _databaseSchemaController,
                        enabled: !_isLoading,
                        validator: _validateSchemaName,
                        decoration: const InputDecoration(
                          labelText: 'Database Schema',
                          border: OutlineInputBorder(),
                          helperText: 'Must start with letter, contain only letters/numbers/_',
                        ),
                      ),

                      const SizedBox(height: AdminConfig.defaultPadding),

                      // Admin email
                      TextFormField(
                        controller: _adminEmailController,
                        keyboardType: TextInputType.emailAddress,
                        enabled: !_isLoading,
                        validator: _validateEmail,
                        decoration: const InputDecoration(
                          labelText: 'Admin Email',
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: AdminConfig.defaultPadding),

                      // Admin password
                      TextFormField(
                        controller: _adminPasswordController,
                        obscureText: _obscurePassword,
                        enabled: !_isLoading,
                        validator: _validatePassword,
                        decoration: InputDecoration(
                          labelText: 'Admin Password',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          helperText: 'Minimum ${AdminConfig.minPasswordLength} characters',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer buttons
            Container(
              padding: const EdgeInsets.all(AdminConfig.largePadding),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: AdminConfig.defaultPadding),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(AdminConfig.successColorValue),
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading
                        ? const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                              SizedBox(width: AdminConfig.smallPadding),
                              Text('Saving...'),
                            ],
                          )
                        : Text(_isEditing ? 'Update Tenant' : 'Create Tenant'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}