import 'package:flutter/material.dart';
import 'package:beresheet_app/model/service_provider_type.dart';
import 'package:beresheet_app/services/service_provider_type_service.dart';
import 'package:beresheet_app/services/web/web_jwt_session_service.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class ServiceProviderTypesManagementWeb extends StatefulWidget {
  const ServiceProviderTypesManagementWeb({Key? key}) : super(key: key);

  @override
  State<ServiceProviderTypesManagementWeb> createState() => _ServiceProviderTypesManagementWebState();
}

class _ServiceProviderTypesManagementWebState extends State<ServiceProviderTypesManagementWeb> {
  List<ServiceProviderType> _serviceProviderTypes = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _successMessage;

  // Form controllers
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  ServiceProviderType? _editingType;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _loadServiceProviderTypes();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _checkPermissions() async {
    final user = await WebJwtSessionService.getCurrentUser();
    final userRole = user?.role ?? '';
    if (userRole != 'manager') {
      setState(() {
        _errorMessage = AppLocalizations.of(context)!.accessDeniedManagerRoleRequired;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadServiceProviderTypes() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final types = await ServiceProviderTypeService.getServiceProviderTypesWeb();
      setState(() {
        _serviceProviderTypes = types;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '${AppLocalizations.of(context)!.failedToLoadServiceProviderTypes}: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _createServiceProviderType() async {
    if (_nameController.text.trim().isEmpty) {
      _showMessage(AppLocalizations.of(context)!.pleaseEnterName, isError: true);
      return;
    }

    try {
      setState(() {
        _isLoading = true;
      });

      final newType = await ServiceProviderTypeService.createServiceProviderTypeWeb(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isNotEmpty 
            ? _descriptionController.text.trim() 
            : null,
      );

      if (newType != null) {
        _clearForm();
        await _loadServiceProviderTypes();
        _showMessage(AppLocalizations.of(context)!.serviceProviderTypeCreatedSuccessfully, isError: false);
      }
    } catch (e) {
      _showMessage('${AppLocalizations.of(context)!.failedToCreateServiceProviderType}: $e', isError: true);
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateServiceProviderType() async {
    if (_editingType == null) return;

    try {
      setState(() {
        _isLoading = true;
      });

      final updatedType = await ServiceProviderTypeService.updateServiceProviderTypeWeb(
        typeId: _editingType!.id,
        description: _descriptionController.text.trim().isNotEmpty 
            ? _descriptionController.text.trim() 
            : null,
      );

      if (updatedType != null) {
        _clearForm();
        await _loadServiceProviderTypes();
        _showMessage(AppLocalizations.of(context)!.serviceProviderTypeUpdatedSuccessfully, isError: false);
      }
    } catch (e) {
      _showMessage('${AppLocalizations.of(context)!.failedToUpdateServiceProviderType}: $e', isError: true);
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteServiceProviderType(ServiceProviderType type) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.confirmDelete),
        content: Text(AppLocalizations.of(context)!.deleteServiceProviderTypeConfirmation(type.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(AppLocalizations.of(context)!.delete),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      setState(() {
        _isLoading = true;
      });

      final success = await ServiceProviderTypeService.deleteServiceProviderTypeWeb(
        typeId: type.id,
      );

      if (success) {
        await _loadServiceProviderTypes();
        _showMessage(AppLocalizations.of(context)!.serviceProviderTypeDeletedSuccessfully, isError: false);
      }
    } catch (e) {
      _showMessage('${AppLocalizations.of(context)!.failedToDeleteServiceProviderType}: $e', isError: true);
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _editServiceProviderType(ServiceProviderType type) {
    setState(() {
      _editingType = type;
      _nameController.text = type.name;
      _descriptionController.text = type.description ?? '';
    });
  }

  void _clearForm() {
    setState(() {
      _editingType = null;
      _nameController.clear();
      _descriptionController.clear();
    });
  }

  void _showMessage(String message, {required bool isError}) {
    setState(() {
      if (isError) {
        _errorMessage = message;
        _successMessage = null;
      } else {
        _successMessage = message;
        _errorMessage = null;
      }
    });

    // Auto clear message after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _errorMessage = null;
          _successMessage = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Permission check is handled in initState, so we rely on error state
    if (_errorMessage != null && _errorMessage!.contains('access denied')) {
      return _buildAccessDeniedPage();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.serviceProviderTypesManagementTitle,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.blue[700],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Form Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _editingType == null ? AppLocalizations.of(context)!.createNewServiceProviderType : AppLocalizations.of(context)!.editServiceProviderType,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Name field
                    TextFormField(
                      controller: _nameController,
                      enabled: _editingType == null, // Name is not editable when updating
                      decoration: InputDecoration(
                        labelText: '${AppLocalizations.of(context)!.serviceProviderTypeName} *',
                        border: const OutlineInputBorder(),
                        helperText: _editingType != null ? AppLocalizations.of(context)!.nameCannotBeChanged : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Description field
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.serviceProviderTypeDescription,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Action buttons
                    Row(
                      children: [
                        if (_editingType != null) ...[
                          ElevatedButton(
                            onPressed: _isLoading ? null : _updateServiceProviderType,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                            child: Text(AppLocalizations.of(context)!.update),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: _clearForm,
                            child: Text(AppLocalizations.of(context)!.cancel),
                          ),
                        ] else ...[
                          ElevatedButton(
                            onPressed: _isLoading ? null : _createServiceProviderType,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            child: Text(AppLocalizations.of(context)!.create),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: _clearForm,
                            child: Text(AppLocalizations.of(context)!.clear),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Messages
            if (_errorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  border: Border.all(color: Colors.red[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red[700]),
                  textAlign: TextAlign.center,
                ),
              ),
            
            if (_successMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  border: Border.all(color: Colors.green[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _successMessage!,
                  style: TextStyle(color: Colors.green[700]),
                  textAlign: TextAlign.center,
                ),
              ),
            
            // Service Provider Types List
            Text(
              AppLocalizations.of(context)!.existingServiceProviderTypes,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _serviceProviderTypes.isEmpty
                      ? Center(
                          child: Text(
                            AppLocalizations.of(context)!.noServiceProviderTypesFound,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        )
                      : Card(
                          child: ListView.builder(
                            itemCount: _serviceProviderTypes.length,
                            itemBuilder: (context, index) {
                              final type = _serviceProviderTypes[index];
                              return ListTile(
                                title: Text(
                                  type.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: type.description != null
                                    ? Text(type.description!)
                                    : Text(AppLocalizations.of(context)!.noDescription),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.blue),
                                      onPressed: () => _editServiceProviderType(type),
                                      tooltip: AppLocalizations.of(context)!.editTooltip,
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => _deleteServiceProviderType(type),
                                      tooltip: AppLocalizations.of(context)!.deleteTooltip,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccessDeniedPage() {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.serviceProviderTypesManagementTitle),
        backgroundColor: Colors.red[700],
      ),
      body: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context)!.webAccessDenied,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context)!.serviceProviderTypesManagementRequiresManagerRole,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}