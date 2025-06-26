import 'package:flutter/material.dart';
import '../../../../config/admin_config.dart';
import '../../../../model/admin/tenant.dart';
import '../../../../services/admin/admin_api_service.dart';

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

  bool _isLoading = false;
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
    super.dispose();
  }

  /// Initialize form with existing tenant data if editing
  void _initializeForm() {
    if (_isEditing) {
      final tenant = widget.tenant!;
      _nameController.text = tenant.name;
    }
    // For new tenants, we only need the name - everything else is handled by backend
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

  /// Create new tenant (only requires name now)
  Future<void> _createTenant() async {
    final tenantCreate = TenantCreate.fromForm(
      name: _nameController.text.trim(),
    );

    final tenant = await AdminApiService.createTenant(tenantCreate);
    widget.onTenantSaved(tenant);
    
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  /// Update existing tenant (editing still supported but simplified)
  Future<void> _updateTenant() async {
    final tenantUpdate = TenantUpdate(
      name: _nameController.text.trim() != widget.tenant!.name ? _nameController.text.trim() : null,
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

                      // Tenant name (only field needed now)
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

                      // Info text explaining automatic configuration
                      Container(
                        padding: const EdgeInsets.all(AdminConfig.defaultPadding),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          border: Border.all(color: Colors.blue.withOpacity(0.3)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.info,
                              color: Colors.blue,
                              size: 20,
                            ),
                            SizedBox(width: AdminConfig.smallPadding),
                            Expanded(
                              child: Text(
                                'Database configuration, admin credentials, and schema will be automatically configured based on your environment settings and login credentials.',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
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