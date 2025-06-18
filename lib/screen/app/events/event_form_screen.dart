import 'package:beresheet_app/model/event.dart';
import 'package:beresheet_app/services/event_service.dart';
import 'package:beresheet_app/services/image_cache_service.dart';
import 'package:beresheet_app/services/modern_localization_service.dart';
import 'package:beresheet_app/theme/app_theme.dart';
import 'package:beresheet_app/utils/direction_utils.dart';
import 'package:beresheet_app/widgets/unsplash_image_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:io';
import 'dart:convert';
import '../../../config/app_config.dart';
import '../../../utils/display_name_utils.dart';
import '../../../services/user_session_service.dart';

class EventFormScreen extends StatefulWidget {
  final Event? event; // null for creating new event

  const EventFormScreen({Key? key, this.event}) : super(key: key);

  @override
  State<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends State<EventFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _maxParticipantsController = TextEditingController();
  final TextEditingController _currentParticipantsController = TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController();

  String _selectedType = AppConfig.eventTypeEvent;
  String _selectedStatus = AppConfig.eventStatusPendingApproval;
  DateTime _selectedDateTime = DateTime.now().add(const Duration(days: 1));
  bool _isSaving = false;
  String _selectedRecurring = 'none';
  DateTime? _recurringEndDate;
  
  // Recurring pattern variables
  int? _selectedDayOfWeek;
  int? _selectedDayOfMonth;
  TimeOfDay? _recurringTime;
  int? _interval;
  
  // User role for determining edit permissions
  String? _userRole;
  
  // Image handling
  String _imageSource = 'upload'; // 'upload' or 'unsplash'
  File? _selectedImageFile;
  final ImagePicker _imagePicker = ImagePicker();
  
  // Rooms functionality
  List<Map<String, dynamic>> _rooms = [];
  bool _isLoadingRooms = true;
  String? _selectedRoomName;

  // Use constants from AppConfig for consistency
  List<String> get _eventTypes => AppConfig.eventTypes;
  List<String> get _statusOptions => AppConfig.userSelectableEventStatusOptions;
  List<String> get _recurringOptions => AppConfig.eventRecurringOptions;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _loadRooms();
    if (widget.event != null) {
      _populateFields();
    }
  }

  Future<void> _loadUserRole() async {
    try {
      final role = await UserSessionService.getRole();
      setState(() {
        _userRole = role;
      });
    } catch (e) {
      print('Error loading user role: $e');
    }
  }

  void _populateFields() {
    final event = widget.event!;
    _nameController.text = event.name;
    _descriptionController.text = event.description;
    _locationController.text = event.location;
    _maxParticipantsController.text = event.maxParticipants.toString();
    _currentParticipantsController.text = event.currentParticipants.toString();
    _imageUrlController.text = event.imageUrl;
    _selectedType = event.type;
    _selectedStatus = event.status;
    _selectedDateTime = event.dateTime;
    _selectedRecurring = event.recurring;
    _recurringEndDate = event.recurringEndDate;
    
    // Set the selected room name from the event location
    // This will be updated after rooms are loaded to match existing room names
    _selectedRoomName = event.location;
    
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

      final homeId = await UserSessionService.gethomeID();
      if (homeId == null) {
        setState(() {
          _isLoadingRooms = false;
        });
        return;
      }

      final url = '${AppConfig.apiBaseUrl}/api/rooms/public';
      print('🔍 DEBUG: Making HTTP GET request to: $url');
      print('🔍 DEBUG: Headers: homeID=${homeId.toString()}');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'homeID': homeId.toString(),
        },
      );

      print('🔍 DEBUG: Response received - Status Code: ${response.statusCode}');
      print('🔍 DEBUG: Response Body: ${response.body}');
      print('🔍 DEBUG: Response Headers: ${response.headers}');

      if (response.statusCode == 200) {
        final List<dynamic> roomsData = json.decode(response.body);
        print('🔍 DEBUG: Successfully parsed ${roomsData.length} rooms');
        setState(() {
          _rooms = roomsData.cast<Map<String, dynamic>>();
          _isLoadingRooms = false;
          
          // If editing an existing event, try to match the room name from the location
          if (widget.event != null && _selectedRoomName != null) {
            print('Looking for room: $_selectedRoomName');
            print('Available rooms: ${_rooms.map((r) => r['room_name']).toList()}');
            
            final matchingRoom = _rooms.firstWhere(
              (room) => room['room_name'] == _selectedRoomName,
              orElse: () => <String, dynamic>{},
            );
            
            if (matchingRoom.isNotEmpty) {
              _selectedRoomName = matchingRoom['room_name'];
              print('Room matched: $_selectedRoomName');
            } else {
              print('No matching room found, setting first room as fallback');
              if (_rooms.isNotEmpty) {
                _selectedRoomName = _rooms.first['room_name'];
              } else {
                _selectedRoomName = null;
              }
            }
          }
        });
      } else {
        print('❌ DEBUG: HTTP request failed with status ${response.statusCode}');
        print('❌ DEBUG: Error response body: ${response.body}');
        setState(() {
          _isLoadingRooms = false;
        });
      }
    } catch (e) {
      print('❌ DEBUG: Exception occurred during HTTP request: $e');
      print('❌ DEBUG: Exception type: ${e.runtimeType}');
      setState(() {
        _isLoadingRooms = false;
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

  Future<void> _selectDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      if (mounted) {
        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
        );

        if (time != null) {
          setState(() {
            _selectedDateTime = DateTime(
              date.year,
              date.month,
              date.day,
              time.hour,
              time.minute,
            );
          });
        }
      }
    }
  }

  Future<void> _selectImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      
      if (image != null) {
        setState(() {
          _selectedImageFile = File(image.path);
          _imageSource = 'upload';
          _imageUrlController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _validateUnsplashImage() async {
    if (_imageUrlController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an Unsplash image URL first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      setState(() {
        _isSaving = true;
      });

      final response = await http.get(Uri.parse(_imageUrlController.text.trim()));
      
      if (response.statusCode == 200) {
        setState(() {
          _imageSource = 'unsplash';
          _selectedImageFile = null;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unsplash image validated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Failed to load image from Unsplash URL');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error validating Unsplash image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  bool get _isEditable {
    // Events are always editable (matching web behavior)
    return true;
  }

  bool get _isFieldEditable {
    // For new events, all fields except status and currentParticipants are editable
    if (widget.event == null) return true;
    
    // If event status is "done", no fields should be editable (view-only mode)
    if (_selectedStatus == AppConfig.eventStatusDone) return false;
    
    // Fields are always editable for managers and staff (except when status is done)
    return true;
  }

  bool get _canUserEditAllFields {
    // Users with manager or staff roles can edit all fields
    return _userRole == AppConfig.userRoleManager || _userRole == AppConfig.userRoleStaff;
  }


  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) return;

    // Additional validation for recurring events
    if (_selectedRecurring != 'none' && _recurringEndDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.endDateRequiredForRecurringEvents),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate recurring pattern for recurring events
    if (_selectedRecurring != 'none') {
      if (_recurringTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.pleaseSelectTimeForRecurringEvents),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      if ((_selectedRecurring == 'weekly' || _selectedRecurring == 'bi-weekly') && _selectedDayOfWeek == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.pleaseSelectDayOfWeekForWeeklyEvents),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      if (_selectedRecurring == 'monthly' && _selectedDayOfMonth == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.pleaseSelectDayOfMonthForMonthlyEvents),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    final l10n = context.l10n;

    setState(() {
      _isSaving = true;
    });

    try {
      final homeId = await UserSessionService.gethomeID();
      final userId = await UserSessionService.getUserId();
      
      if (homeId == null || userId == null) {
        throw Exception('User session not found - homeId: $homeId, userId: $userId');
      }

      // Create multipart request
      final uri = widget.event == null
          ? Uri.parse('${AppConfig.apiBaseUrl}/api/events')
          : Uri.parse('${AppConfig.apiBaseUrl}/api/events/${widget.event!.id}');
      
      final request = widget.event == null
          ? http.MultipartRequest('POST', uri)
          : http.MultipartRequest('PUT', uri);

      // Add headers
      request.headers.addAll({
        'homeID': homeId.toString(),
        'userId': userId,
      });

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
        'dateTime': _selectedDateTime.toIso8601String(),
        'location': _selectedRoomName ?? _locationController.text.trim(),
        'maxParticipants': _maxParticipantsController.text.trim(),
        'currentParticipants': widget.event == null ? '0' : _currentParticipantsController.text.trim(),
        'status': _selectedStatus,
        'recurring': _selectedRecurring,
      });

      if (_recurringEndDate != null) {
        request.fields['recurring_end_date'] = _recurringEndDate!.toIso8601String();
      }
      
      if (recurringPatternJson != null) {
        request.fields['recurring_pattern'] = recurringPatternJson;
      }

      // Handle image based on source
      if (_imageSource == 'upload' && _selectedImageFile != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'image',
          _selectedImageFile!.path,
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
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error downloading Unsplash image: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
          setState(() { _isSaving = false; });
          return;
        }
      }

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      
      if (response.statusCode == 201 || response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.event == null ? l10n.eventCreated : l10n.eventUpdated),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop(true);
        }
      } else {
        try {
          final errorData = json.decode(responseBody);
          throw Exception(errorData['detail'] ?? 'Unknown error');
        } catch (e) {
          throw Exception('Server error: ${response.statusCode} - $responseBody');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.error}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String _getEventTypeDisplayName(String type) {
    final l10n = context.l10n;
    
    switch (type) {
      case AppConfig.eventTypeEvent: return l10n.eventTypeEvent;
      case AppConfig.eventTypeCultural: return l10n.eventTypeCultural;
      case AppConfig.eventTypeSport: return l10n.eventTypeSport;
      case AppConfig.eventTypeArt: return l10n.eventTypeArt;
      case AppConfig.eventTypeEnglish: return l10n.eventTypeEnglish;
      case AppConfig.eventTypeReligion: return l10n.eventTypeReligion;
      default: return type;
    }
  }

  String _getRecurringDisplayName(String recurring) {
    return DisplayNameUtils.getRecurringDisplayName(recurring, context);
  }

  // Use AppConfig method for consistency
  String _getStatusDisplayName(String status) {
    return DisplayNameUtils.getEventStatusDisplayName(status, context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.event == null ? l10n.createEvent : l10n.editEvent,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: Icon(DirectionUtils.backIcon),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
            onPressed: (_isSaving || _selectedStatus == AppConfig.eventStatusDone) ? null : _saveEvent,
            child: Text(
              l10n.save.toUpperCase(),
              style: AppTextStyles.buttonText.copyWith(
                color: (_selectedStatus == AppConfig.eventStatusDone) ? Colors.grey : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: DirectionUtils.crossAxisAlignmentStart,
            children: [
              // Event Name
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: TextFormField(
                    controller: _nameController,
                    enabled: _isFieldEditable,
                    decoration: InputDecoration(
                      labelText: l10n.eventName,
                      hintText: l10n.enterEventName,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return l10n.pleaseEnterEventName;
                      }
                      return null;
                    },
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Event Type
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: DropdownButtonFormField<String>(
                    value: _selectedType,
                    decoration: InputDecoration(
                      labelText: l10n.eventType,
                    ),
                    items: _eventTypes.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(_getEventTypeDisplayName(type)),
                      );
                    }).toList(),
                    onChanged: widget.event != null ? null : (value) {
                      if (value != null) {
                        setState(() {
                          _selectedType = value;
                        });
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Status - show as read-only text if status is "done", otherwise allow selection
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: _selectedStatus == AppConfig.eventStatusDone
                    ? TextFormField(
                        initialValue: _getStatusDisplayName(_selectedStatus),
                        decoration: InputDecoration(
                          labelText: l10n.status,
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
                          labelText: l10n.status,
                        ),
                        items: _statusOptions.map((status) {
                          return DropdownMenuItem(
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
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Description
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: TextFormField(
                    controller: _descriptionController,
                    maxLines: 3,
                    enabled: _isFieldEditable,
                    decoration: InputDecoration(
                      labelText: l10n.description,
                      hintText: l10n.enterEventDescription,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return l10n.pleaseEnterEventDescription;
                      }
                      return null;
                    },
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),


              // Room Selection
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: _isLoadingRooms
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      : DropdownButtonFormField<String>(
                          value: _rooms.any((room) => room['room_name'] == _selectedRoomName)
                              ? _selectedRoomName
                              : null,
                          decoration: InputDecoration(
                            labelText: l10n.location,
                            hintText: l10n.webSelectRoom,
                          ),
                          items: _rooms.map((room) {
                            final roomName = room['room_name'] as String;
                            return DropdownMenuItem<String>(
                              value: roomName,
                              child: Text(roomName),
                            );
                          }).toList(),
                          onChanged: _isFieldEditable ? (value) {
                            print('Room dropdown changed to: $value');
                            setState(() {
                              _selectedRoomName = value;
                              if (value != null) {
                                _locationController.text = value;
                              }
                            });
                          } : null,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return l10n.pleaseEnterEventLocation;
                            }
                            return null;
                          },
                        ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Max Participants
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: TextFormField(
                    controller: _maxParticipantsController,
                    keyboardType: TextInputType.number,
                    enabled: _isFieldEditable,
                    decoration: InputDecoration(
                      labelText: l10n.maxParticipants,
                      hintText: l10n.enterMaximumParticipants,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return l10n.pleaseEnterMaximumParticipants;
                      }
                      final number = int.tryParse(value);
                      if (number == null || number <= 0) {
                        return l10n.pleaseEnterValidPositiveNumber;
                      }
                      return null;
                    },
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Current Participants (only for editing)
              if (widget.event != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: TextFormField(
                      controller: _currentParticipantsController,
                      keyboardType: TextInputType.number,
                      enabled: false, // Always read-only
                      decoration: InputDecoration(
                        labelText: l10n.currentParticipants,
                        hintText: l10n.enterCurrentParticipants,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return l10n.pleaseEnterCurrentParticipants;
                        }
                        final number = int.tryParse(value);
                        if (number == null || number < 0) {
                          return l10n.pleaseEnterValidNonNegativeNumber;
                        }
                        final maxParticipants = int.tryParse(_maxParticipantsController.text) ?? 0;
                        if (number > maxParticipants) {
                          return l10n.currentParticipantsCannotExceed;
                        }
                        return null;
                      },
                    ),
                  ),
                ),
              if (widget.event != null) const SizedBox(height: AppSpacing.md),

              // Recurring Settings
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: DirectionUtils.crossAxisAlignmentStart,
                    children: [
                      Text(
                        l10n.recurringSettings,
                        style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      
                      // Initial Reference Date & Time
                      Text(
                        _selectedRecurring == 'none'
                            ? l10n.eventDateTime
                            : l10n.recurringEventStartDate,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w600,
                        ),
                        textDirection: AppConfig.textDirection,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      InkWell(
                        onTap: _isFieldEditable ? _selectDateTime : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    '${_selectedDateTime.day}/${_selectedDateTime.month}/${_selectedDateTime.year} at ${_selectedDateTime.hour}:${_selectedDateTime.minute.toString().padLeft(2, '0')}',
                                    style: AppTextStyles.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: AppSpacing.md),
                      
                      // Recurrence Type
                      DropdownButtonFormField<String>(
                        value: _selectedRecurring,
                        decoration: InputDecoration(
                          labelText: l10n.recurrence,
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
                            return l10n.fieldRequired;
                          }
                          return null;
                        },
                      ),
                      
                      if (_selectedRecurring != 'none') ...[
                        const SizedBox(height: AppSpacing.md),
                        
                        // Recurring Schedule Configuration
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            border: Border.all(color: Colors.blue[200]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: DirectionUtils.crossAxisAlignmentStart,
                            children: [
                              Text(
                                l10n.recurringScheduleConfiguration,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue[800],
                                ),
                                textDirection: AppConfig.textDirection,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              
                              // Recurring Time
                              ListTile(
                                title: Text(
                                  '${l10n.recurringEventTime} *',
                                  textDirection: AppConfig.textDirection,
                                ),
                                subtitle: Text(
                                  _recurringTime != null
                                      ? '${_recurringTime!.hour.toString().padLeft(2, '0')}:${_recurringTime!.minute.toString().padLeft(2, '0')}'
                                      : l10n.selectTimeForRecurringEvents,
                                  textDirection: AppConfig.textDirection,
                                ),
                                trailing: const Icon(Icons.access_time),
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
                              ),
                              
                              if (_selectedRecurring == 'weekly' || _selectedRecurring == 'bi-weekly') ...[
                                const SizedBox(height: AppSpacing.sm),
                                DropdownButtonFormField<int>(
                                  value: _selectedDayOfWeek,
                                  decoration: InputDecoration(
                                    labelText: '${l10n.dayOfWeek} *',
                                    border: const OutlineInputBorder(),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  items: [
                                    DropdownMenuItem(value: 0, child: Text(l10n.sunday, textDirection: AppConfig.textDirection)),
                                    DropdownMenuItem(value: 1, child: Text(l10n.monday, textDirection: AppConfig.textDirection)),
                                    DropdownMenuItem(value: 2, child: Text(l10n.tuesday, textDirection: AppConfig.textDirection)),
                                    DropdownMenuItem(value: 3, child: Text(l10n.wednesday, textDirection: AppConfig.textDirection)),
                                    DropdownMenuItem(value: 4, child: Text(l10n.thursday, textDirection: AppConfig.textDirection)),
                                    DropdownMenuItem(value: 5, child: Text(l10n.friday, textDirection: AppConfig.textDirection)),
                                    DropdownMenuItem(value: 6, child: Text(l10n.saturday, textDirection: AppConfig.textDirection)),
                                  ],
                                  onChanged: _isFieldEditable ? (value) {
                                    setState(() {
                                      _selectedDayOfWeek = value;
                                    });
                                  } : null,
                                  validator: (value) {
                                    if (value == null) {
                                      return l10n.pleaseSelectDayOfWeek;
                                    }
                                    return null;
                                  },
                                ),
                              ],
                              
                              if (_selectedRecurring == 'monthly') ...[
                                const SizedBox(height: AppSpacing.sm),
                                DropdownButtonFormField<int>(
                                  value: _selectedDayOfMonth,
                                  decoration: InputDecoration(
                                    labelText: '${l10n.dayOfMonth} *',
                                    border: const OutlineInputBorder(),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                                      return l10n.pleaseSelectDayOfMonth;
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: AppSpacing.md),
                        
                        // End Date
                        ListTile(
                          title: Text(
                            '${l10n.endDate} *',
                            textDirection: AppConfig.textDirection,
                          ),
                          subtitle: Text(
                            _recurringEndDate?.toString().split(' ')[0] ?? l10n.notSet,
                            textDirection: AppConfig.textDirection,
                          ),
                          trailing: const Icon(Icons.calendar_today),
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
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Image Selection
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: DirectionUtils.crossAxisAlignmentStart,
                    children: [
                      Text(
                        l10n.eventImage,
                        style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      
                      // Image source selection
                      Wrap(
                        spacing: 8,
                        children: [
                          SizedBox(
                            width: 160,
                            child: RadioListTile<String>(
                              title: Text(l10n.webUpload),
                              value: 'upload',
                              groupValue: _imageSource,
                              onChanged: _isFieldEditable ? (value) {
                                setState(() {
                                  _imageSource = value!;
                                  _imageUrlController.clear();
                                });
                              } : null,
                            ),
                          ),
                          SizedBox(
                            width: 160,
                            child: RadioListTile<String>(
                              title: Text(l10n.unsplash),
                              value: 'unsplash',
                              groupValue: _imageSource,
                              onChanged: _isFieldEditable ? (value) {
                                setState(() {
                                  _imageSource = value!;
                                  _selectedImageFile = null;
                                  _imageUrlController.clear();
                                });
                              } : null,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: AppSpacing.md),
                      
                      // Image source specific UI
                      if (_imageSource == 'unsplash') ...[
                        const SizedBox(height: AppSpacing.md),
                        SizedBox(
                          height: 400,
                          child: UnsplashImagePicker(
                            eventType: _selectedType,
                            crossAxisCount: 2,
                            onImageSelected: (imageUrl) {
                              setState(() {
                                _imageUrlController.text = imageUrl;
                              });
                            },
                          ),
                        ),
                      ] else if (_imageSource == 'upload') ...[
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _isFieldEditable ? _selectImageFromGallery : null,
                                icon: const Icon(Icons.photo_library),
                                label: Text(l10n.webUploadImage),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isFieldEditable ? AppColors.primary : Colors.grey,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_selectedImageFile != null) ...[
                          const SizedBox(height: AppSpacing.md),
                          Container(
                            height: 200,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(AppSpacing.sm),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(AppSpacing.sm),
                              child: Image.file(
                                _selectedImageFile!,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ] else if (widget.event != null && _imageUrlController.text.isNotEmpty) ...[
                          // Show existing event image when editing
                          const SizedBox(height: AppSpacing.md),
                          Container(
                            height: 200,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(AppSpacing.sm),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(AppSpacing.sm),
                              child: Image.network(
                                _imageUrlController.text,
                                fit: BoxFit.contain, // Changed from cover to contain to show full image
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey[200],
                                    child: const Icon(
                                      Icons.error,
                                      color: Colors.red,
                                      size: 50,
                                    ),
                                  );
                                },
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ],
                      
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: (_isSaving || _selectedStatus == AppConfig.eventStatusDone) ? null : _saveEvent,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (_selectedStatus == AppConfig.eventStatusDone) ? Colors.grey : AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.sm),
                    ),
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          widget.event == null
                              ? l10n.createEventButton
                              : l10n.updateEventButton,
                          style: AppTextStyles.buttonText,
                        ),
                ),
              ),
              
            ],
          ),
        ),
      ),
    );
  }
}