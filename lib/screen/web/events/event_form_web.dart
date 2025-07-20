import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'package:beresheet_app/services/web/web_jwt_session_service.dart';
import 'package:beresheet_app/services/web_image_cache_service.dart';
import 'package:beresheet_app/model/event.dart';
import 'package:beresheet_app/services/event_service.dart';
import 'package:beresheet_app/widgets/unsplash_image_picker.dart';
import 'package:beresheet_app/config/app_config.dart';
import 'package:beresheet_app/utils/display_name_utils.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http_parser/http_parser.dart';

class EventFormWeb extends StatefulWidget {
  final Event? event; // null for creating new event

  const EventFormWeb({Key? key, this.event}) : super(key: key);

  @override
  State<EventFormWeb> createState() => _EventFormWebState();
}

class _EventFormWebState extends State<EventFormWeb> {
  final _formKey = GlobalKey<FormState>();
  
  // Form controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _maxParticipantsController = TextEditingController();
  final TextEditingController _currentParticipantsController = TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController();
  final TextEditingController _imageSearchController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  
  // Form variables
  String _selectedType = AppConfig.eventTypeEvent;
  String _selectedStatus = AppConfig.eventStatusPendingApproval;
  String _selectedRecurring = AppConfig.eventRecurringNone;
  DateTime _selectedDateTime = DateTime.now().add(const Duration(days: 1));
  DateTime? _recurringEndDate;
  int _selectedDuration = 60; // Default duration in minutes
  
  // Recurring pattern variables
  int? _selectedDayOfWeek;
  int? _selectedDayOfMonth;
  TimeOfDay? _recurringTime;
  int? _interval;
  
  // Image handling
  String _imageSource = 'upload'; // 'upload', 'gallery', or 'unsplash'
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  String _imageSearchQuery = '';
  
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  
  // Rooms functionality
  List<Map<String, dynamic>> _rooms = [];
  bool _isLoadingRooms = true;
  String? _selectedRoomName;


  // Instructor functionality
  List<Map<String, dynamic>> _instructors = [];
  bool _isLoadingInstructors = true;
  Map<String, dynamic>? _selectedInstructor;
  String? _instructorName;
  String? _instructorDesc;
  String? _instructorPhoto;

  // Use constants from AppConfig for consistency
  List<String> get _eventTypes => AppConfig.eventTypes;
  List<String> get _statusOptions => AppConfig.userSelectableEventStatusOptions;
  List<String> get _recurringOptions => AppConfig.eventRecurringOptions;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _loadRooms();
    _loadInstructors();
    if (widget.event != null) {
      _populateFields();
    }
  }

  void _populateFields() {
    final event = widget.event!;
    _nameController.text = event.name;
    _descriptionController.text = event.description;
    _locationController.text = event.location;
    _maxParticipantsController.text = event.max_participants.toString();
    _currentParticipantsController.text = event.current_participants.toString();
    _imageUrlController.text = event.imageUrl;
    _durationController.text = event.duration.toString();
    _selectedType = event.type;
    _selectedStatus = event.status;
    _selectedDateTime = event.date_time;
    _selectedRecurring = event.recurring;
    _recurringEndDate = event.recurringEndDate;
    _selectedDuration = event.duration;
    _selectedRoomName = event.location; // For existing events, set the room from location
    
    // Set instructor fields
    _instructorName = event.instructorName;
    _instructorDesc = event.instructorDesc;
    _instructorPhoto = event.instructorPhoto;
    
    // Parse recurring pattern if it exists
    if (event.parsedRecurrencePattern != null) {
      final pattern = event.parsedRecurrencePattern!;
      _selectedDayOfWeek = pattern.dayOfWeek;
      _selectedDayOfMonth = pattern.dayOfMonth;
      _interval = pattern.interval;
      
      if (pattern.time != null) {
        final timeParts = pattern.time!.split(':');
        if (timeParts.length == 2) {
          _recurringTime = TimeOfDay(
            hour: int.tryParse(timeParts[0]) ?? 0,
            minute: int.tryParse(timeParts[1]) ?? 0,
          );
        }
      }
    }
  }

  Future<void> _loadRooms() async {
    try {
      setState(() {
        _isLoadingRooms = true;
      });

      final response = await http.get(
        Uri.parse('${AppConfig.apiUrlWithPrefix}/api/rooms/public'),
        headers: await WebJwtSessionService.getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> roomsData = json.decode(response.body);
        setState(() {
          _rooms = roomsData.cast<Map<String, dynamic>>();
          _isLoadingRooms = false;
        });
      } else {
        setState(() {
          _isLoadingRooms = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingRooms = false;
      });
    }
  }


  Future<void> _loadInstructors() async {
    try {
      setState(() {
        _isLoadingInstructors = true;
      });

      final response = await http.get(
        Uri.parse('${AppConfig.apiUrlWithPrefix}/api/event-instructors'),
        headers: await WebJwtSessionService.getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> instructorsData = json.decode(response.body);
        setState(() {
          _instructors = instructorsData.cast<Map<String, dynamic>>();
          _isLoadingInstructors = false;
          
          // If editing an existing event, try to match the instructor
          if (widget.event != null && _instructorName != null && _instructorName!.isNotEmpty) {
            print('Looking for instructor: $_instructorName');
            print('Available instructors: ${_instructors.map((i) => i['name']).toList()}');
            
            final matchingInstructor = _instructors.firstWhere(
              (instructor) => instructor['name'] == _instructorName,
              orElse: () => <String, dynamic>{},
            );
            
            if (matchingInstructor.isNotEmpty) {
              _selectedInstructor = matchingInstructor;
              print('Instructor matched: $_instructorName');
            } else {
              print('No matching instructor found for: $_instructorName');
            }
          }
        });
      } else {
        setState(() {
          _isLoadingInstructors = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingInstructors = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _maxParticipantsController.dispose();
    _currentParticipantsController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  void _checkPermissions() async {
    final user = await WebJwtSessionService.getCurrentUser();
    final userRole = user?.role ?? '';
    if (userRole != 'manager' && userRole != 'staff' && userRole != 'instructor') {
      setState(() {
        _errorMessage = AppLocalizations.of(context)!.webEventCreationRequiresRole;
        _isLoading = false;
      });
    }
  }

  bool get _isEditable {
    // New events are always editable
    if (widget.event == null) return true;
    
    // Events are always editable for managers and staff
    return true;
  }

  bool get _isFieldEditable {
    // For new events, all fields except status and current_participants are editable
    if (widget.event == null) return true;
    
    // If event status is "done", no fields should be editable (view-only mode)
    if (_selectedStatus == AppConfig.eventStatusDone) return false;
    
    // Fields are always editable for managers and staff (except when status is done)
    return true;
  }

  Future<void> _validateImageUrl() async {
    if (_imageUrlController.text.trim().isEmpty) {
      _showMessage(AppLocalizations.of(context)!.pleaseEnterImageUrl, isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.get(Uri.parse(_imageUrlController.text.trim()));
      
      if (response.statusCode == 200) {
        _showMessage('${AppLocalizations.of(context)!.imageUrl} validated successfully', isError: false);
      } else {
        throw Exception('Failed to load image from URL');
      }
    } catch (e) {
      _showMessage('${AppLocalizations.of(context)!.error} validating image: $e', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImageFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.bytes != null) {
        setState(() {
          _selectedImageBytes = result.files.single.bytes;
          _selectedImageName = result.files.single.name;
        });
      }
    } catch (e) {
      _showMessage('Error picking image: $e', isError: true);
    }
  }

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Additional validation for recurring events
    if (_selectedRecurring != 'none' && _recurringEndDate == null) {
      setState(() {
        _errorMessage = AppLocalizations.of(context)!.endDateRequiredForRecurringEvents;
        _isLoading = false;
      });
      return;
    }

    // Validate recurring pattern for recurring events
    if (_selectedRecurring != 'none') {
      if (_recurringTime == null) {
        setState(() {
          _errorMessage = AppLocalizations.of(context)!.pleaseSelectTimeForRecurringEvents;
          _isLoading = false;
        });
        return;
      }
      
      if ((_selectedRecurring == 'weekly' || _selectedRecurring == 'bi-weekly') && _selectedDayOfWeek == null) {
        setState(() {
          _errorMessage = AppLocalizations.of(context)!.pleaseSelectDayOfWeekForWeeklyEvents;
          _isLoading = false;
        });
        return;
      }
      
      if (_selectedRecurring == 'monthly' && _selectedDayOfMonth == null) {
        setState(() {
          _errorMessage = AppLocalizations.of(context)!.pleaseSelectDayOfMonthForMonthlyEvents;
          _isLoading = false;
        });
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      // Create multipart request
      final uri = widget.event == null
          ? Uri.parse('${AppConfig.apiUrlWithPrefix}/api/events')
          : Uri.parse('${AppConfig.apiUrlWithPrefix}/api/events/${widget.event!.id}');
      
      final request = widget.event == null
          ? http.MultipartRequest('POST', uri)
          : http.MultipartRequest('PUT', uri);

      // Add headers
      final headers = await WebJwtSessionService.getAuthHeaders();
      request.headers.addAll(headers);

      // Generate recurring pattern JSON
      String? recurringPatternJson;
      if (_selectedRecurring != 'none' && _recurringTime != null) {
        final pattern = <String, dynamic>{};
        
        if (_selectedDayOfWeek != null) {
          pattern['dayOfWeek'] = _selectedDayOfWeek;
        }
        if (_selectedDayOfMonth != null) {
          pattern['dayOfMonth'] = _selectedDayOfMonth;
        }
        if (_interval != null) {
          pattern['interval'] = _interval;
        }
        
        // Format time as HH:MM
        pattern['time'] = '${_recurringTime!.hour.toString().padLeft(2, '0')}:${_recurringTime!.minute.toString().padLeft(2, '0')}';
        
        recurringPatternJson = json.encode(pattern);
      }

      // Add form fields
      request.fields.addAll({
        'name': _nameController.text.trim(),
        'type': _selectedType,
        'description': _descriptionController.text.trim(),
        'date_time': _selectedDateTime.toIso8601String(),
        'location': _selectedRoomName ?? _locationController.text.trim(),
        'max_participants': _maxParticipantsController.text.trim(),
        'current_participants': widget.event == null ? '0' : _currentParticipantsController.text.trim(),
        'status': _selectedStatus,
        'recurring': _selectedRecurring,
        'duration': _selectedDuration.toString(),
      });

      // Add instructor fields if selected
      if (_instructorName != null) {
        request.fields['instructor_name'] = _instructorName!;
      }
      if (_instructorDesc != null) {
        request.fields['instructor_desc'] = _instructorDesc!;
      }
      if (_instructorPhoto != null) {
        request.fields['instructor_photo'] = _instructorPhoto!;
      }

      if (_recurringEndDate != null) {
        request.fields['recurring_end_date'] = _recurringEndDate!.toIso8601String();
      }
      
      if (recurringPatternJson != null) {
        request.fields['recurring_pattern'] = recurringPatternJson;
      }

      // Handle image based on source
      if (_imageSource == 'upload' && _selectedImageBytes != null) {
        request.files.add(http.MultipartFile.fromBytes(
          'image',
          _selectedImageBytes!,
          filename: _selectedImageName ?? 'event_image.jpg',
          contentType: MediaType('image', 'jpeg'),
        ));
      } else if (_imageSource == 'unsplash' && _imageUrlController.text.isNotEmpty) {
        // For Unsplash images, download and upload as bytes
        try {
          final imageResponse = await http.get(Uri.parse(_imageUrlController.text.trim()));
          if (imageResponse.statusCode == 200) {
            request.files.add(http.MultipartFile.fromBytes(
              'image',
              imageResponse.bodyBytes,
              filename: 'unsplash_image.jpg',
              contentType: MediaType('image', 'jpeg'),
            ));
          }
        } catch (e) {
          _showMessage('Error downloading Unsplash image: $e', isError: true);
          setState(() { _isLoading = false; });
          return;
        }
      }

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 201 || response.statusCode == 200) {
        setState(() {
          _successMessage = widget.event == null
              ? AppLocalizations.of(context)!.eventCreated
              : AppLocalizations.of(context)!.eventUpdated;
          _isLoading = false;
        });
        
        if (widget.event == null) {
          _clearForm();
        }
        
        // Show success message for 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _successMessage = null;
            });
          }
        });
      } else {
        try {
          final errorData = json.decode(responseBody);
          setState(() {
            _errorMessage = '${AppLocalizations.of(context)!.operationFailed}: ${errorData['detail'] ?? response.statusCode}';
            _isLoading = false;
          });
        } catch (e) {
          setState(() {
            _errorMessage = '${AppLocalizations.of(context)!.operationFailed}: ${response.statusCode}';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = '${AppLocalizations.of(context)!.error} saving event: $e';
        _isLoading = false;
      });
    }
  }

  void _clearForm() {
    _nameController.clear();
    _descriptionController.clear();
    _locationController.clear();
    _maxParticipantsController.clear();
    _currentParticipantsController.clear();
    _imageUrlController.clear();
    _imageSearchController.clear();
    _durationController.clear();
    setState(() {
      _selectedType = AppConfig.eventTypeEvent;
      _selectedStatus = AppConfig.eventStatusPendingApproval;
      _selectedRecurring = AppConfig.eventRecurringNone;
      _selectedDateTime = DateTime.now().add(const Duration(days: 1));
      _recurringEndDate = null;
      _selectedDayOfWeek = null;
      _selectedDayOfMonth = null;
      _recurringTime = null;
      _interval = null;
      _selectedDuration = 60;
      _imageSource = 'upload';
      _selectedImageBytes = null;
      _selectedImageName = null;
      _imageSearchQuery = '';
      _selectedInstructor = null;
      _instructorName = null;
      _instructorDesc = null;
      _instructorPhoto = null;
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

  Future<void> _deleteEvent() async {
    if (widget.event == null) return;

    // First confirmation
    final firstConfirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.webConfirmDelete),
        content: Text(AppLocalizations.of(context)!.webDeleteConfirmMessage(widget.event!.name)),
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

    if (firstConfirmed != true) return;

    // Second confirmation about removing from all users
    final secondConfirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.webFinalConfirmation),
        content: Text(AppLocalizations.of(context)!.webFinalConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(AppLocalizations.of(context)!.webYesRemoveFromAllUsers),
          ),
        ],
      ),
    );

    if (secondConfirmed != true) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final response = await http.delete(
        Uri.parse('${AppConfig.apiUrlWithPrefix}/api/events/${widget.event!.id}'),
        headers: await WebJwtSessionService.getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          Navigator.of(context).pop(true); // Return true to indicate successful deletion
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.eventDeletedSuccessfully(widget.event!.name))),
          );
        }
      } else {
        _showMessage('${AppLocalizations.of(context)!.operationFailed}: ${response.statusCode}', isError: true);
      }
    } catch (e) {
      _showMessage('${AppLocalizations.of(context)!.error} deleting event: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (picked != null) {
      setState(() {
        _selectedDateTime = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _selectedDateTime.hour,
          _selectedDateTime.minute,
        );
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
    );
    
    if (picked != null) {
      setState(() {
        _selectedDateTime = DateTime(
          _selectedDateTime.year,
          _selectedDateTime.month,
          _selectedDateTime.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  // Use AppConfig method for consistency
  String _formatEventType(String type) {
    return DisplayNameUtils.getEventTypeDisplayName(type, context);
  }

  String _getStatusDisplayName(String status) {
    return DisplayNameUtils.getEventStatusDisplayName(status, context);
  }

  // Use AppConfig method for consistency
  String _getRecurringDisplayName(String recurring) {
    return DisplayNameUtils.getRecurringDisplayName(recurring, context);
  }

  // Generate duration options using DisplayNameUtils
  List<DropdownMenuItem<int>> _generateDurationOptions() {
    final durationOptions = DisplayNameUtils.getDurationOptions(context);
    return durationOptions.map((option) {
      return DropdownMenuItem<int>(
        value: option['value'] as int,
        child: Text(option['label'] as String),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    // Permission check is handled in initState/_checkPermissions
    if (_errorMessage != null && _errorMessage!.contains('requires')) {
      return _buildAccessDeniedPage();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.event == null ? AppLocalizations.of(context)!.webCreateEvent : AppLocalizations.of(context)!.editEvent,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.blue[700],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Event Details Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.event, color: Colors.blue),
                          const SizedBox(width: 8),
                          Text(
                            AppLocalizations.of(context)!.eventDetails,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Name
                      TextFormField(
                        controller: _nameController,
                        enabled: _isFieldEditable,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context)!.eventName,
                          border: const OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return AppLocalizations.of(context)!.pleaseEnterEventName;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Event Type
                      DropdownButtonFormField<String>(
                        value: _selectedType,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context)!.eventType,
                          border: const OutlineInputBorder(),
                        ),
                        items: _eventTypes.map((String type) {
                          return DropdownMenuItem<String>(
                            value: type,
                            child: Text(_formatEventType(type)),
                          );
                        }).toList(),
                        onChanged: _isFieldEditable ? (String? newValue) {
                          setState(() {
                            _selectedType = newValue!;
                          });
                        } : null,
                      ),
                      const SizedBox(height: 16),

                      // Status - show as read-only text if status is "done", otherwise allow selection
                      _selectedStatus == AppConfig.eventStatusDone
                        ? TextFormField(
                            initialValue: _getStatusDisplayName(_selectedStatus),
                            decoration: InputDecoration(
                              labelText: AppLocalizations.of(context)!.webStatus,
                              border: const OutlineInputBorder(),
                            ),
                            readOnly: true,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          )
                        : DropdownButtonFormField<String>(
                            value: _selectedStatus,
                            decoration: InputDecoration(
                              labelText: AppLocalizations.of(context)!.webStatus,
                              border: const OutlineInputBorder(),
                            ),
                            items: _statusOptions.map((String status) {
                              return DropdownMenuItem<String>(
                                value: status,
                                child: Text(_getStatusDisplayName(status)),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _selectedStatus = value;
                                });
                              }
                            },
                          ),
                      const SizedBox(height: 16),
                      
                      // Description
                      TextFormField(
                        controller: _descriptionController,
                        enabled: _isFieldEditable,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context)!.description,
                          border: const OutlineInputBorder(),
                        ),
                        maxLines: 3,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return AppLocalizations.of(context)!.pleaseEnterEventDescription;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Room Selection
                      _isLoadingRooms
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          : DropdownButtonFormField<String>(
                              value: _selectedRoomName,
                              decoration: InputDecoration(
                                labelText: AppLocalizations.of(context)!.locationRoom,
                                border: const OutlineInputBorder(),
                              ),
                              items: _rooms.map((room) {
                                final roomName = room['room_name'] as String;
                                return DropdownMenuItem<String>(
                                  value: roomName,
                                  child: Text(roomName),
                                );
                              }).toList(),
                              onChanged: _isFieldEditable ? (value) {
                                setState(() {
                                  _selectedRoomName = value;
                                  if (value != null) {
                                    _locationController.text = value;
                                  }
                                });
                              } : null,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return AppLocalizations.of(context)!.pleaseEnterEventLocation;
                                }
                                return null;
                              },
                            ),
                      const SizedBox(height: 16),
                      
                      // Instructor Selection
                      _isLoadingInstructors
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          : DropdownButtonFormField<Map<String, dynamic>>(
                             value: _instructors.isNotEmpty && _selectedInstructor != null
                                 ? _instructors.firstWhere(
                                     (instructor) => instructor['id'] == _selectedInstructor!['id'],
                                     orElse: () => <String, dynamic>{},
                                   ).isNotEmpty
                                     ? _instructors.firstWhere(
                                         (instructor) => instructor['id'] == _selectedInstructor!['id'],
                                       )
                                     : null
                                 : null,
                              decoration: InputDecoration(
                                labelText: AppLocalizations.of(context)!.eventInstructorOptional,
                                border: const OutlineInputBorder(),
                              ),
                              items: [
                                // Show "Instructor Exists" if there's existing instructor data, otherwise "No Instructor"
                                DropdownMenuItem<Map<String, dynamic>>(
                                  value: null,
                                  child: Text(
                                    (_instructorName != null && _instructorName!.isNotEmpty)
                                      ? AppLocalizations.of(context)!.instructorExists
                                      : AppLocalizations.of(context)!.noInstructor
                                  ),
                                ),
                                ..._instructors.map((instructor) {
                                  return DropdownMenuItem<Map<String, dynamic>>(
                                    value: instructor,
                                    child: Text(instructor['name'] as String),
                                  );
                                }).toList(),
                              ],
                              onChanged: _isFieldEditable ? (value) {
                                setState(() {
                                  _selectedInstructor = value;
                                  if (value != null) {
                                    _instructorName = value['name'] as String?;
                                    _instructorDesc = value['description'] as String?;
                                    _instructorPhoto = value['photo'] as String?;
                                  } else {
                                    _instructorName = null;
                                    _instructorDesc = null;
                                    _instructorPhoto = null;
                                  }
                                });
                              } : null,
                            ),
                      
                      // Show instructor details if selected from dropdown OR if there's existing instructor data
                      if (_selectedInstructor != null || (_instructorName != null && _instructorName!.isNotEmpty)) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            border: Border.all(color: Colors.blue[200]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  // Instructor photo - use existing data or selected instructor
                                  Builder(
                                    builder: (context) {
                                      final photoUrl = _instructorPhoto ?? _selectedInstructor?['photo'];
                                      if (photoUrl != null && photoUrl.toString().isNotEmpty) {
                                        return Container(
                                          width: 60,
                                          height: 60,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.blue[300]!, width: 2),
                                          ),
                                          child: ClipOval(
                                            child: WebImageCacheService.buildCircularUserImage(
                                              imageUrl: photoUrl.toString(),
                                              radius: 30,
                                              errorWidget: Container(
                                                color: Colors.grey[300],
                                                child: const Icon(Icons.person, color: Colors.grey),
                                              ),
                                            ),
                                          ),
                                        );
                                      } else {
                                        return Container(
                                          width: 60,
                                          height: 60,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.grey[300],
                                            border: Border.all(color: Colors.blue[300]!, width: 2),
                                          ),
                                          child: const Icon(Icons.person, color: Colors.grey, size: 30),
                                        );
                                      }
                                    },
                                  ),
                                  const SizedBox(width: 16),
                                  // Instructor details - use existing data or selected instructor
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _instructorName ?? _selectedInstructor?['name'] ?? 'Unknown',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        Builder(
                                          builder: (context) {
                                            final description = _instructorDesc ?? _selectedInstructor?['description'];
                                            if (description != null && description.toString().isNotEmpty) {
                                              return Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    description.toString(),
                                                    style: TextStyle(
                                                      color: Colors.grey[700],
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ],
                                              );
                                            }
                                            return const SizedBox.shrink();
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Capacity Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.people, color: Colors.orange),
                          const SizedBox(width: 8),
                          Text(
                            AppLocalizations.of(context)!.participants,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      Row(
                        children: [
                          // Max Participants
                          Expanded(
                            child: TextFormField(
                              controller: _maxParticipantsController,
                              enabled: _isFieldEditable,
                              decoration: InputDecoration(
                                labelText: AppLocalizations.of(context)!.max_participants,
                                border: const OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return AppLocalizations.of(context)!.pleaseEnterMaximumParticipants;
                                }
                                final number = int.tryParse(value.trim());
                                if (number == null || number <= 0) {
                                  return AppLocalizations.of(context)!.pleaseEnterValidPositiveNumber;
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          
                          // Current Participants (only for editing)
                          if (widget.event != null)
                            Expanded(
                              child: TextFormField(
                                controller: _currentParticipantsController,
                                enabled: false, // Always read-only
                                decoration: InputDecoration(
                                  labelText: AppLocalizations.of(context)!.current_participants,
                                  border: const OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Duration dropdown
                      DropdownButtonFormField<int>(
                        value: _selectedDuration,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context)!.durationMinutes,
                          border: const OutlineInputBorder(),
                        ),
                        items: _generateDurationOptions(),
                        onChanged: _isFieldEditable ? (value) {
                          if (value != null) {
                            setState(() {
                              _selectedDuration = value;
                              _durationController.text = value.toString();
                            });
                          }
                        } : null,
                        validator: (value) {
                          if (value == null) {
                            return AppLocalizations.of(context)!.pleaseEnterDuration;
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Recurring Settings Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.repeat, color: Colors.purple),
                          const SizedBox(width: 8),
                          Text(
                            AppLocalizations.of(context)!.recurringSettings,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Initial Date & Time section (for reference)
                      Text(
                        _selectedRecurring == 'none'
                            ? AppLocalizations.of(context)!.eventDateTime
                            : AppLocalizations.of(context)!.recurringEventStartDate,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                        textDirection: AppConfig.textDirection,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          // Date Picker
                          Expanded(
                            child: InkWell(
                              onTap: _isFieldEditable ? _selectDate : null,
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: '${AppLocalizations.of(context)!.eventDate} *',
                                  border: const OutlineInputBorder(),
                                  suffixIcon: const Icon(Icons.calendar_today),
                                ),
                                child: Text(
                                  '${_selectedDateTime.day}/${_selectedDateTime.month}/${_selectedDateTime.year}',
                                  style: const TextStyle(),
                                ),
                              ),
                            ),
                          ),
                          
                          // Time Picker - only show for non-recurring events
                          if (_selectedRecurring == 'none') ...[
                            const SizedBox(width: 16),
                            Expanded(
                              child: InkWell(
                                onTap: _isFieldEditable ? _selectTime : null,
                                child: InputDecorator(
                                  decoration: InputDecoration(
                                    labelText: '${AppLocalizations.of(context)!.eventTime} *',
                                    border: const OutlineInputBorder(),
                                    suffixIcon: const Icon(Icons.access_time),
                                  ),
                                  child: Text(
                                    '${_selectedDateTime.hour}:${_selectedDateTime.minute.toString().padLeft(2, '0')}',
                                    style: const TextStyle(),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Recurrence Type
                      DropdownButtonFormField<String>(
                        value: _selectedRecurring,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context)!.recurrence,
                          border: const OutlineInputBorder(),
                        ),
                        items: _recurringOptions.map((recurring) {
                          return DropdownMenuItem(
                            value: recurring,
                            child: Text(_getRecurringDisplayName(recurring)),
                          );
                        }).toList(),
                        onChanged: _isFieldEditable ? (value) {
                          if (value != null) {
                            setState(() {
                              _selectedRecurring = value;
                              if (value == 'none') {
                                _recurringEndDate = null;
                                _selectedDayOfWeek = null;
                                _selectedDayOfMonth = null;
                                _recurringTime = null;
                                _interval = null;
                              } else {
                                // Set default values for recurring events
                                _recurringTime = TimeOfDay.fromDateTime(_selectedDateTime);
                                if (value == 'bi-weekly') {
                                  _interval = 2;
                                }
                              }
                            });
                          }
                        } : null,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return AppLocalizations.of(context)!.fieldRequired;
                          }
                          return null;
                        },
                      ),
                      
                      if (_selectedRecurring != 'none') ...[
                        const SizedBox(height: 16),
                        
                        // Recurring Schedule Configuration
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            border: Border.all(color: Colors.blue[200]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: AppConfig.isRTL ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppLocalizations.of(context)!.recurringScheduleConfiguration,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue[800],
                                ),
                                textDirection: AppConfig.textDirection,
                              ),
                              const SizedBox(height: 12),
                              
                              // Recurring Time
                              InkWell(
                                onTap: _isFieldEditable ? () async {
                                  final TimeOfDay? picked = await showTimePicker(
                                    context: context,
                                    initialTime: _recurringTime ?? TimeOfDay.fromDateTime(_selectedDateTime),
                                  );
                                  if (picked != null) {
                                    setState(() {
                                      _recurringTime = picked;
                                    });
                                  }
                                } : null,
                                child: InputDecorator(
                                  decoration: InputDecoration(
                                    labelText: '${AppLocalizations.of(context)!.recurringEventTime} *',
                                    border: const OutlineInputBorder(),
                                    suffixIcon: const Icon(Icons.access_time),
                                  ),
                                  child: Text(
                                    _recurringTime != null
                                        ? '${_recurringTime!.hour.toString().padLeft(2, '0')}:${_recurringTime!.minute.toString().padLeft(2, '0')}'
                                        : AppLocalizations.of(context)!.selectTimeForRecurringEvents,
                                    style: const TextStyle(),
                                    textDirection: AppConfig.textDirection,
                                  ),
                                ),
                              ),
                              
                              if (_selectedRecurring == 'weekly' || _selectedRecurring == 'bi-weekly') ...[
                                const SizedBox(height: 12),
                                DropdownButtonFormField<int>(
                                  value: _selectedDayOfWeek,
                                  decoration: InputDecoration(
                                    labelText: '${AppLocalizations.of(context)!.dayOfWeek} *',
                                    border: const OutlineInputBorder(),
                                  ),
                                  items: [
                                    DropdownMenuItem(value: 0, child: Text(AppLocalizations.of(context)!.sunday, textDirection: AppConfig.textDirection)),
                                    DropdownMenuItem(value: 1, child: Text(AppLocalizations.of(context)!.monday, textDirection: AppConfig.textDirection)),
                                    DropdownMenuItem(value: 2, child: Text(AppLocalizations.of(context)!.tuesday, textDirection: AppConfig.textDirection)),
                                    DropdownMenuItem(value: 3, child: Text(AppLocalizations.of(context)!.wednesday, textDirection: AppConfig.textDirection)),
                                    DropdownMenuItem(value: 4, child: Text(AppLocalizations.of(context)!.thursday, textDirection: AppConfig.textDirection)),
                                    DropdownMenuItem(value: 5, child: Text(AppLocalizations.of(context)!.friday, textDirection: AppConfig.textDirection)),
                                    DropdownMenuItem(value: 6, child: Text(AppLocalizations.of(context)!.saturday, textDirection: AppConfig.textDirection)),
                                  ],
                                  onChanged: _isFieldEditable ? (value) {
                                    setState(() {
                                      _selectedDayOfWeek = value;
                                    });
                                  } : null,
                                  validator: (value) {
                                    if (value == null) {
                                      return AppLocalizations.of(context)!.pleaseSelectDayOfWeek;
                                    }
                                    return null;
                                  },
                                ),
                              ],
                              
                              if (_selectedRecurring == 'monthly') ...[
                                const SizedBox(height: 12),
                                DropdownButtonFormField<int>(
                                  value: _selectedDayOfMonth,
                                  decoration: InputDecoration(
                                    labelText: '${AppLocalizations.of(context)!.dayOfMonth} *',
                                    border: const OutlineInputBorder(),
                                  ),
                                  items: List.generate(31, (index) {
                                    final day = index + 1;
                                    return DropdownMenuItem(
                                      value: day,
                                      child: Text(day.toString(), textDirection: AppConfig.textDirection),
                                    );
                                  }),
                                  onChanged: _isFieldEditable ? (value) {
                                    setState(() {
                                      _selectedDayOfMonth = value;
                                    });
                                  } : null,
                                  validator: (value) {
                                    if (value == null) {
                                      return AppLocalizations.of(context)!.pleaseSelectDayOfMonth;
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // End Date
                        InkWell(
                          onTap: _isFieldEditable ? () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: _recurringEndDate ?? DateTime.now().add(const Duration(days: 90)),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                            );
                            if (picked != null) {
                              setState(() {
                                _recurringEndDate = picked;
                              });
                            }
                          } : null,
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: '${AppLocalizations.of(context)!.endDate} *',
                              border: const OutlineInputBorder(),
                              suffixIcon: const Icon(Icons.calendar_today),
                            ),
                            child: Text(
                              _recurringEndDate?.toString().split(' ')[0] ?? AppLocalizations.of(context)!.webSelectDate,
                              style: const TextStyle(),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),

              // Image Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.image, color: Colors.teal),
                          const SizedBox(width: 8),
                          Text(
                            AppLocalizations.of(context)!.eventImage,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Image source selection
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            children: [
                              SizedBox(
                                width: 160,
                                child: RadioListTile<String>(
                                  title: Text(AppLocalizations.of(context)!.upload),
                                  value: 'upload',
                                  groupValue: _imageSource,
                                  onChanged: _isFieldEditable ? (value) {
                                    setState(() {
                                      _imageSource = value!;
                                      _selectedImageBytes = null;
                                      _selectedImageName = null;
                                      _imageSearchController.clear();
                                      _imageSearchQuery = '';
                                    });
                                  } : null,
                                ),
                              ),
                              SizedBox(
                                width: 160,
                                child: RadioListTile<String>(
                                  title: Text(AppLocalizations.of(context)!.unsplash),
                                  value: 'unsplash',
                                  groupValue: _imageSource,
                                  onChanged: _isFieldEditable ? (value) {
                                    setState(() {
                                      _imageSource = value!;
                                      _imageUrlController.clear();
                                      _selectedImageBytes = null;
                                      _selectedImageName = null;
                                    });
                                  } : null,
                                ),
                              ),
                            ],
                          ),
                          
                          // Search field for image bank - only visible when unsplash is selected
                          if (_imageSource == 'unsplash') ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              width: 300,
                              child: TextField(
                                controller: _imageSearchController,
                                enabled: _isFieldEditable,
                                decoration: InputDecoration(
                                  labelText: AppLocalizations.of(context)!.searchImages,
                                  hintText: AppLocalizations.of(context)!.enterKeywordsToSearchImages,
                                  border: const OutlineInputBorder(),
                                  prefixIcon: const Icon(Icons.search),
                                  suffixIcon: _imageSearchController.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear),
                                          onPressed: () {
                                            setState(() {
                                              _imageSearchController.clear();
                                              _imageSearchQuery = '';
                                            });
                                          },
                                        )
                                      : null,
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    if (value.length >= 2) {
                                      _imageSearchQuery = value;
                                    } else {
                                      _imageSearchQuery = '';
                                    }
                                  });
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),

                      if (_imageSource == 'unsplash') ...[
                        SizedBox(
                          height: 400,
                          child: UnsplashImagePicker(
                            eventType: _imageSearchQuery.isNotEmpty ? null : _selectedType,
                            searchQuery: _imageSearchQuery.isNotEmpty ? _imageSearchQuery : null,
                            crossAxisCount: 6,
                            onImageSelected: (imageUrl) {
                              setState(() {
                                _imageUrlController.text = imageUrl;
                              });
                            },
                          ),
                        ),
                      ] else ...[
                        // File upload section for 'upload'
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isFieldEditable ? _pickImageFile : null,
                            icon: const Icon(Icons.upload_file),
                            label: Text(AppLocalizations.of(context)!.webUploadImage),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isFieldEditable ? Colors.blue : Colors.grey,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Show selected file info
                        if (_selectedImageName != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              border: Border.all(color: Colors.green[300]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle, color: Colors.green),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Selected: $_selectedImageName',
                                    style: TextStyle(color: Colors.green[700]),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _selectedImageBytes = null;
                                      _selectedImageName = null;
                                    });
                                  },
                                  child: const Text('Remove'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ],
                      
                      const SizedBox(height: 16),
                      Text(
                        '${AppLocalizations.of(context)!.imagePreview}:',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      if (_selectedImageBytes != null ||
                          _imageUrlController.text.isNotEmpty ||
                          (widget.event != null && widget.event!.imageUrl.isNotEmpty))
                        Container(
                          height: 200,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _selectedImageBytes != null
                                ? Image.memory(
                                    _selectedImageBytes!,
                                    fit: BoxFit.cover,
                                  )
                                : WebImageCacheService.buildEventImage(
                                    imageUrl: _imageUrlController.text.isNotEmpty
                                        ? _imageUrlController.text
                                        : (widget.event?.imageUrl ?? ''),
                                    width: double.infinity,
                                    height: double.infinity,
                                    fit: BoxFit.contain,
                                    placeholder: const Center(child: CircularProgressIndicator()),
                                    errorWidget: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.error, color: Colors.red),
                                        const SizedBox(height: 8),
                                        Text(AppLocalizations.of(context)!.invalidImageUrl),
                                      ],
                                    ),
                                  ),
                          ),
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

              
              // Action Buttons
              Row(
                children: [
                  // Update/Create button
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (_isLoading || _selectedStatus == AppConfig.eventStatusDone) ? null : _saveEvent,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedStatus == AppConfig.eventStatusDone ? Colors.grey : Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              widget.event == null
                                  ? AppLocalizations.of(context)!.createEvent
                                  : AppLocalizations.of(context)!.updateEvent,
                            ),
                    ),
                  ),
                  // Delete button (only for existing events, comes after update)
                  if (widget.event != null) ...[
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: (_isLoading || _selectedStatus == AppConfig.eventStatusDone) ? null : _deleteEvent,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _selectedStatus == AppConfig.eventStatusDone ? Colors.grey : Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(AppLocalizations.of(context)!.deleteEvent),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccessDeniedPage() {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.webEventForm),
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
                  AppLocalizations.of(context)!.webEventCreationRequiresRole,
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
