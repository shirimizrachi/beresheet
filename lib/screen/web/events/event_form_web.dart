import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:beresheet_app/services/web_auth_service.dart';
import 'package:beresheet_app/model/event.dart';
import 'package:beresheet_app/services/event_service.dart';
import 'package:beresheet_app/widgets/unsplash_image_picker.dart';
import 'package:beresheet_app/config/app_config.dart';
import 'package:beresheet_app/utils/display_name_utils.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

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
  
  // Form variables
  String _selectedType = AppConfig.eventTypeClass;
  String _selectedStatus = AppConfig.eventStatusPendingApproval;
  String _selectedRecurring = AppConfig.eventRecurringNone;
  DateTime _selectedDateTime = DateTime.now().add(const Duration(days: 1));
  DateTime? _recurringEndDate;
  
  // Image handling
  String _imageSource = 'url'; // 'url', 'unsplash', or 'upload'
  
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  
  // Rooms functionality
  List<Map<String, dynamic>> _rooms = [];
  bool _isLoadingRooms = true;
  String? _selectedRoomName;

  // Use constants from AppConfig for consistency
  List<String> get _eventTypes => AppConfig.eventTypes;
  List<String> get _statusOptions => AppConfig.eventStatusOptions;
  List<String> get _recurringOptions => AppConfig.eventRecurringOptions;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _loadRooms();
    if (widget.event != null) {
      _populateFields();
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
    _selectedRoomName = event.location; // For existing events, set the room from location
  }

  Future<void> _loadRooms() async {
    try {
      setState(() {
        _isLoadingRooms = true;
      });

      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/api/rooms/public'),
        headers: {
          'Content-Type': 'application/json',
          'homeID': WebAuthService.homeId.toString(),
        },
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

  void _checkPermissions() {
    final userRole = WebAuthService.userRole ?? '';
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
    // For new events, all fields except status and currentParticipants are editable
    if (widget.event == null) return true;
    
    // Fields are always editable for managers and staff
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

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Additional validation for recurring events
    if (_selectedRecurring != 'none' && _recurringEndDate == null) {
      setState(() {
        _errorMessage = '${AppLocalizations.of(context)!.endDate} is required for recurring events';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final headers = WebAuthService.getAuthHeaders();
      
      final eventData = {
        'name': _nameController.text.trim(),
        'type': _selectedType,
        'description': _descriptionController.text.trim(),
        'dateTime': _selectedDateTime.toIso8601String(),
        'location': _selectedRoomName ?? _locationController.text.trim(),
        'maxParticipants': int.parse(_maxParticipantsController.text.trim()),
        'image_url': _imageUrlController.text.trim(),
        'currentParticipants': widget.event == null ? 0 : int.parse(_currentParticipantsController.text.trim()),
        'status': _selectedStatus,
        'recurring': _selectedRecurring,
        'recurring_end_date': _recurringEndDate?.toIso8601String(),
        'recurring_pattern': null, // No longer using custom patterns
      };

      final response = widget.event == null
          ? await http.post(
              Uri.parse('${AppConfig.apiBaseUrl}/api/events'),
              headers: headers,
              body: json.encode(eventData),
            )
          : await http.put(
              Uri.parse('${AppConfig.apiBaseUrl}/api/events/${widget.event!.id}'),
              headers: headers,
              body: json.encode(eventData),
            );

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
        final errorData = json.decode(response.body);
        setState(() {
          _errorMessage = '${AppLocalizations.of(context)!.operationFailed}: ${errorData['detail'] ?? response.statusCode}';
          _isLoading = false;
        });
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
    setState(() {
      _selectedType = AppConfig.eventTypeClass;
      _selectedStatus = AppConfig.eventStatusPendingApproval;
      _selectedRecurring = AppConfig.eventRecurringNone;
      _selectedDateTime = DateTime.now().add(const Duration(days: 1));
      _recurringEndDate = null;
      _imageSource = 'url';
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
        Uri.parse('${AppConfig.apiBaseUrl}/api/events/${widget.event!.id}'),
        headers: {
          'Content-Type': 'application/json',
          'homeID': WebAuthService.homeId.toString(),
          'userId': WebAuthService.userId ?? '',
        },
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

  @override
  Widget build(BuildContext context) {
    // Check permissions first
    final userRole = WebAuthService.userRole ?? '';
    if (userRole != AppConfig.userRoleManager &&
        userRole != AppConfig.userRoleStaff &&
        userRole != AppConfig.userRoleInstructor) {
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
                        onChanged: widget.event != null ? null : (String? newValue) {
                          setState(() {
                            _selectedType = newValue!;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Status (read-only)
                      DropdownButtonFormField<String>(
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
                              onChanged: (value) {
                                setState(() {
                                  _selectedRoomName = value;
                                  if (value != null) {
                                    _locationController.text = value;
                                  }
                                });
                              },
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return AppLocalizations.of(context)!.pleaseEnterEventLocation;
                                }
                                return null;
                              },
                            ),
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
                                labelText: AppLocalizations.of(context)!.maxParticipants,
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
                                  labelText: AppLocalizations.of(context)!.currentParticipants,
                                  border: const OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                        ],
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
                      
                      const SizedBox(height: 16),
                      
                      // Date & Time section (moved here)
                      Row(
                        children: [
                          // Date Picker
                          Expanded(
                            child: InkWell(
                              onTap: _selectDate,
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
                          const SizedBox(width: 16),
                          
                          // Time Picker
                          Expanded(
                            child: InkWell(
                              onTap: _selectTime,
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
                      ),
                      
                      if (_selectedRecurring != 'none') ...[
                        const SizedBox(height: 16),
                        InkWell(
                          onTap: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: _recurringEndDate ?? DateTime.now().add(const Duration(days: 30)),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                            );
                            if (picked != null) {
                              setState(() {
                                _recurringEndDate = picked;
                              });
                            }
                          },
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
                      Wrap(
                        spacing: 8,
                        children: [
                          SizedBox(
                            width: 160,
                            child: RadioListTile<String>(
                              title: Text(AppLocalizations.of(context)!.url),
                              value: 'url',
                              groupValue: _imageSource,
                              onChanged: (value) {
                                setState(() {
                                  _imageSource = value!;
                                });
                              },
                            ),
                          ),
                          SizedBox(
                            width: 160,
                            child: RadioListTile<String>(
                              title: Text(AppLocalizations.of(context)!.upload),
                              value: 'upload',
                              groupValue: _imageSource,
                              onChanged: (value) {
                                setState(() {
                                  _imageSource = value!;
                                });
                              },
                            ),
                          ),
                          SizedBox(
                            width: 160,
                            child: RadioListTile<String>(
                              title: Text(AppLocalizations.of(context)!.unsplash),
                              value: 'unsplash',
                              groupValue: _imageSource,
                              onChanged: (value) {
                                setState(() {
                                  _imageSource = value!;
                                  _imageUrlController.clear();
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      if (_imageSource == 'unsplash') ...[
                        SizedBox(
                          height: 400,
                          child: UnsplashImagePicker(
                            eventType: _selectedType,
                            crossAxisCount: 6,
                            onImageSelected: (imageUrl) {
                              setState(() {
                                _imageUrlController.text = imageUrl;
                              });
                            },
                          ),
                        ),
                      ] else
                        TextFormField(
                        controller: _imageUrlController,
                        enabled: _isFieldEditable,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context)!.imageUrl,
                          hintText: AppLocalizations.of(context)!.webEnterImageUrl,
                          border: const OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return AppLocalizations.of(context)!.pleaseEnterImageUrl;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      if (true)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _validateImageUrl,
                            icon: const Icon(Icons.download),
                            label: Text(AppLocalizations.of(context)!.validateImageUrl),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      
                      const SizedBox(height: 16),
                      Text(
                        '${AppLocalizations.of(context)!.imagePreview}:',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      if (_imageUrlController.text.isNotEmpty)
                        Container(
                          height: 200,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              _imageUrlController.text,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.error, color: Colors.red),
                                  const SizedBox(height: 8),
                                  Text(AppLocalizations.of(context)!.invalidImageUrl),
                                ],
                              ),
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return const Center(child: CircularProgressIndicator());
                              },
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
                  if (widget.event == null)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _clearForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(AppLocalizations.of(context)!.clearForm),
                      ),
                    ),
                  if (widget.event == null) const SizedBox(width: 16),
                  // Update/Create button (comes first)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveEvent,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
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
                        onPressed: _isLoading ? null : _deleteEvent,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
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