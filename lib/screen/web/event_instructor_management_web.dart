import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import '../../config/app_config.dart';
import '../../services/web/web_jwt_session_service.dart';
import '../../services/web_image_cache_service.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http_parser/http_parser.dart';

class EventInstructorManagementWeb extends StatefulWidget {
  const EventInstructorManagementWeb({Key? key}) : super(key: key);

  @override
  State<EventInstructorManagementWeb> createState() => _EventInstructorManagementWebState();
}

class _EventInstructorManagementWebState extends State<EventInstructorManagementWeb> {
  List<Map<String, dynamic>> _instructors = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isCreating = false;
  bool _isUpdating = false;
  
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  
  Map<String, dynamic>? _editingInstructor;
  Uint8List? _selectedPhotoBytes;
  String? _selectedPhotoName;

  @override
  void initState() {
    super.initState();
    _loadInstructors();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadInstructors() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiUrlWithPrefix}/api/event-instructors'),
        headers: await WebJwtSessionService.getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> instructorsData = json.decode(response.body);
        setState(() {
          _instructors = instructorsData.cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load instructors: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading instructors: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _createInstructor() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.pleaseEnterInstructorName)),
      );
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConfig.apiUrlWithPrefix}/api/event-instructors'),
      );

      final headers = await WebJwtSessionService.getAuthHeaders();
      request.headers.addAll(headers);

      request.fields['name'] = _nameController.text.trim();
      request.fields['description'] = _descriptionController.text.trim();

      if (_selectedPhotoBytes != null) {
        request.files.add(http.MultipartFile.fromBytes(
          'photo',
          _selectedPhotoBytes!,
          filename: _selectedPhotoName ?? 'instructor_photo.jpg',
          contentType: MediaType('image', 'jpeg'),
        ));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        _nameController.clear();
        _descriptionController.clear();
        _selectedPhotoBytes = null;
        _selectedPhotoName = null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.instructorCreatedSuccessfully)),
        );
        await _loadInstructors();
      } else {
        String errorMessage = AppLocalizations.of(context)!.failedToCreateInstructor;
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['detail'] ?? errorMessage;
        } catch (e) {
          // Use default error message
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.errorCreatingInstructor(e.toString()))),
      );
    } finally {
      setState(() {
        _isCreating = false;
      });
    }
  }

  Future<void> _updateInstructor() async {
    if (_editingInstructor == null || _nameController.text.trim().isEmpty) {
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      final request = http.MultipartRequest(
        'PUT',
        Uri.parse('${AppConfig.apiUrlWithPrefix}/api/event-instructors/${_editingInstructor!['id']}'),
      );

      final headers = await WebJwtSessionService.getAuthHeaders();
      request.headers.addAll(headers);

      request.fields['name'] = _nameController.text.trim();
      request.fields['description'] = _descriptionController.text.trim();

      if (_selectedPhotoBytes != null) {
        request.files.add(http.MultipartFile.fromBytes(
          'photo',
          _selectedPhotoBytes!,
          filename: _selectedPhotoName ?? 'instructor_photo.jpg',
          contentType: MediaType('image', 'jpeg'),
        ));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        _nameController.clear();
        _descriptionController.clear();
        _selectedPhotoBytes = null;
        _selectedPhotoName = null;
        _editingInstructor = null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.instructorUpdatedSuccessfully)),
        );
        await _loadInstructors();
      } else {
        String errorMessage = AppLocalizations.of(context)!.failedToUpdateInstructor;
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['detail'] ?? errorMessage;
        } catch (e) {
          // Use default error message
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.errorUpdatingInstructor(e.toString()))),
      );
    } finally {
      setState(() {
        _isUpdating = false;
      });
    }
  }

  Future<void> _deleteInstructor(String instructorId, String instructorName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.confirmDeleteInstructor),
        content: Text(AppLocalizations.of(context)!.areYouSureDeleteInstructor(instructorName)),
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
      final response = await http.delete(
        Uri.parse('${AppConfig.apiUrlWithPrefix}/api/event-instructors/$instructorId'),
        headers: await WebJwtSessionService.getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.instructorDeletedSuccessfully(instructorName))),
        );
        await _loadInstructors();
      } else {
        String errorMessage = AppLocalizations.of(context)!.failedToDeleteInstructor;
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['detail'] ?? errorMessage;
        } catch (e) {
          // Use default error message
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.errorDeletingInstructor(e.toString()))),
      );
    }
  }

  void _startEditing(Map<String, dynamic> instructor) {
    setState(() {
      _editingInstructor = instructor;
      _nameController.text = instructor['name'] ?? '';
      _descriptionController.text = instructor['description'] ?? '';
      _selectedPhotoBytes = null;
      _selectedPhotoName = null;
    });
  }

  void _cancelEditing() {
    setState(() {
      _editingInstructor = null;
      _nameController.clear();
      _descriptionController.clear();
      _selectedPhotoBytes = null;
      _selectedPhotoName = null;
    });
  }

  Future<void> _pickPhoto() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.bytes != null) {
        setState(() {
          _selectedPhotoBytes = result.files.single.bytes;
          _selectedPhotoName = result.files.single.name;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking photo: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.school, size: 32, color: Colors.blue),
                const SizedBox(width: 16),
                Text(
                  AppLocalizations.of(context)!.eventInstructorsManagement,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _loadInstructors,
                  icon: const Icon(Icons.refresh),
                  label: Text(AppLocalizations.of(context)!.refresh),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Create/Edit Instructor Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _editingInstructor == null ? AppLocalizations.of(context)!.createNewInstructor : AppLocalizations.of(context)!.editInstructor,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    
                    // Main content row with photo preview and form fields
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Photo preview section
                        Column(
                          children: [
                            // Photo preview container
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[300]!, width: 2),
                                color: Colors.grey[50],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: _selectedPhotoBytes != null
                                    ? Image.memory(
                                        _selectedPhotoBytes!,
                                        fit: BoxFit.cover,
                                        width: 120,
                                        height: 120,
                                      )
                                    : (_editingInstructor != null &&
                                       _editingInstructor!['photo'] != null &&
                                       _editingInstructor!['photo'].toString().isNotEmpty)
                                        ? WebImageCacheService.buildUserProfileImage(
                                            imageUrl: _editingInstructor!['photo'],
                                            width: 120,
                                            height: 120,
                                            fit: BoxFit.cover,
                                            borderRadius: BorderRadius.circular(10),
                                            errorWidget: const Icon(Icons.school, size: 60, color: Colors.grey),
                                          )
                                        : const Icon(Icons.school, size: 60, color: Colors.grey),
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Photo selection button
                            ElevatedButton.icon(
                              onPressed: _pickPhoto,
                              icon: const Icon(Icons.photo_camera, size: 16),
                              label: Text(
                                _selectedPhotoBytes != null
                                    ? AppLocalizations.of(context)!.changePhoto
                                    : AppLocalizations.of(context)!.selectPhoto,
                                style: const TextStyle(fontSize: 12),
                              ),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                backgroundColor: Colors.blue[50],
                                foregroundColor: Colors.blue[700],
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(width: 24),
                        
                        // Form fields section
                        Expanded(
                          child: Column(
                            children: [
                              // Name field
                              TextField(
                                controller: _nameController,
                                decoration: InputDecoration(
                                  labelText: AppLocalizations.of(context)!.instructorName,
                                  hintText: AppLocalizations.of(context)!.enterInstructorName,
                                  border: const OutlineInputBorder(),
                                  prefixIcon: const Icon(Icons.person),
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              // Description field
                              TextField(
                                controller: _descriptionController,
                                decoration: InputDecoration(
                                  labelText: AppLocalizations.of(context)!.instructorDescription,
                                  hintText: AppLocalizations.of(context)!.enterDescription,
                                  border: const OutlineInputBorder(),
                                  prefixIcon: const Icon(Icons.description),
                                ),
                                maxLines: 3,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (_editingInstructor != null) ...[
                          TextButton.icon(
                            onPressed: _cancelEditing,
                            icon: const Icon(Icons.cancel),
                            label: Text(AppLocalizations.of(context)!.cancel),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        ElevatedButton.icon(
                          onPressed: (_isCreating || _isUpdating) ? null :
                            (_editingInstructor == null ? _createInstructor : _updateInstructor),
                          icon: (_isCreating || _isUpdating)
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Icon(_editingInstructor == null ? Icons.add : Icons.save),
                          label: Text(
                            (_isCreating || _isUpdating)
                              ? (_editingInstructor == null ? AppLocalizations.of(context)!.creatingInstructor : AppLocalizations.of(context)!.updatingInstructor)
                              : (_editingInstructor == null ? AppLocalizations.of(context)!.createInstructor : AppLocalizations.of(context)!.updateInstructor)
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _editingInstructor == null ? Colors.green : Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Instructors List
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.eventInstructorsCount(_instructors.length),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: _buildInstructorsList(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructorsList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.errorTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(_errorMessage!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadInstructors,
              child: Text(AppLocalizations.of(context)!.retryButton),
            ),
          ],
        ),
      );
    }

    if (_instructors.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.school_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.noInstructorsFound,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(AppLocalizations.of(context)!.createFirstInstructor),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _instructors.length,
      itemBuilder: (context, index) {
        final instructor = _instructors[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: WebImageCacheService.buildCircularUserImage(
              imageUrl: instructor['photo'] != null && instructor['photo'].isNotEmpty 
                  ? instructor['photo'] 
                  : null,
              radius: 20,
              errorWidget: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.school, color: Colors.white, size: 20),
              ),
            ),
            title: Text(
              instructor['name'] ?? AppLocalizations.of(context)!.unknownInstructor,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(instructor['description'] ?? AppLocalizations.of(context)!.noDescription),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.orange),
                  onPressed: () => _startEditing(instructor),
                  tooltip: AppLocalizations.of(context)!.editInstructorTooltip,
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteInstructor(
                    instructor['id']?.toString() ?? '',
                    instructor['name'] ?? AppLocalizations.of(context)!.unknownInstructor,
                  ),
                  tooltip: AppLocalizations.of(context)!.deleteInstructorTooltip,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
