import 'package:beresheet_app/model/event.dart';
import 'package:beresheet_app/services/event_service.dart';
import 'package:beresheet_app/services/modern_localization_service.dart';
import 'package:beresheet_app/theme/app_theme.dart';
import 'package:beresheet_app/utils/direction_utils.dart';
import 'package:beresheet_app/widgets/unsplash_image_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
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

  String _selectedType = AppConfig.eventTypeClass;
  String _selectedStatus = AppConfig.eventStatusPendingApproval;
  DateTime _selectedDateTime = DateTime.now().add(const Duration(days: 1));
  bool _isSaving = false;
  String _selectedRecurring = 'none';
  DateTime? _recurringEndDate;
  
  // User role for determining edit permissions
  String? _userRole;
  
  // Image handling
  String _imageSource = 'url'; // 'url', 'gallery', or 'unsplash'
  File? _selectedImageFile;
  final ImagePicker _imagePicker = ImagePicker();
  
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
    _selectedRoomName = event.location; // For existing events, set the room from location
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

      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/api/rooms/public'),
        headers: {
          'Content-Type': 'application/json',
          'homeID': homeId.toString(),
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
          _imageSource = 'gallery';
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

  Future<void> _downloadImageFromUrl() async {
    if (_imageUrlController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an image URL first'),
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
          _imageSource = 'url';
          _selectedImageFile = null;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image URL validated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Failed to load image from URL');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading image: $e'),
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
    // New events are always editable
    if (widget.event == null) return true;
    
    // Existing events are only editable if status is "pending-approval"
    return _selectedStatus == AppConfig.eventStatusPendingApproval;
  }

  bool get _isFieldEditable {
    // For new events, all fields except status and currentParticipants are editable
    if (widget.event == null) return true;
    
    // For existing events, allow editing if status is pending-approval OR user has manager/staff role
    return _selectedStatus == AppConfig.eventStatusPendingApproval || _canUserEditAllFields;
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
        const SnackBar(
          content: Text('End date is required for recurring events'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final l10n = context.l10n;

    setState(() {
      _isSaving = true;
    });

    try {
      // Determine the image URL to use
      String imageUrl = _imageUrlController.text.trim();
      if (_imageSource == 'gallery' && _selectedImageFile != null) {
        // In a real app, you would upload the file to a server and get the URL
        // For now, we'll use a placeholder or the file path
        imageUrl = _selectedImageFile!.path;
      }

      final event = Event(
        id: widget.event?.id ?? '',
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        type: _selectedType,
        status: _selectedStatus,
        dateTime: _selectedDateTime,
        location: _selectedRoomName ?? _locationController.text.trim(),
        maxParticipants: int.parse(_maxParticipantsController.text),
        currentParticipants: widget.event == null ? 0 : int.parse(_currentParticipantsController.text),
        imageUrl: imageUrl,
        recurring: _selectedRecurring,
        recurringEndDate: _recurringEndDate,
        recurringPattern: null, // No longer using custom patterns
      );

      final Event? result = widget.event == null
          ? await EventService.createEvent(
              name: event.name,
              type: event.type,
              description: event.description,
              dateTime: event.dateTime,
              location: event.location,
              maxParticipants: event.maxParticipants,
              imageUrl: event.imageUrl,
              recurring: event.recurring,
              recurringEndDate: event.recurringEndDate,
              recurringPattern: event.recurringPattern,
            )
          : await EventService.updateEvent(
              eventId: event.id,
              name: event.name,
              type: event.type,
              description: event.description,
              dateTime: event.dateTime,
              location: event.location,
              maxParticipants: event.maxParticipants,
              imageUrl: event.imageUrl,
              currentParticipants: event.currentParticipants,
              status: event.status,
              recurring: event.recurring,
              recurringEndDate: event.recurringEndDate,
              recurringPattern: event.recurringPattern,
            );

      if (result != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.event == null ? l10n.eventCreated : l10n.eventUpdated),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
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
      case AppConfig.eventTypeClass: return l10n.eventTypeClass;
      case AppConfig.eventTypePerformance: return l10n.eventTypePerformance;
      case AppConfig.eventTypeCultural: return l10n.eventTypeCultural;
      case AppConfig.eventTypeLeisure: return l10n.eventTypeLeisure;
      case AppConfig.eventTypeWorkshop: return l10n.eventTypeWorkshop;
      case AppConfig.eventTypeMeeting: return l10n.eventTypeMeeting;
      case AppConfig.eventTypeSport: return l10n.eventTypeSport;
      case AppConfig.eventTypeHealth: return l10n.eventTypeHealth;
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
            onPressed: _isSaving ? null : _saveEvent,
            child: Text(
              l10n.save.toUpperCase(),
              style: AppTextStyles.buttonText.copyWith(
                color: Colors.white,
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

              // Status (read-only)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: DropdownButtonFormField<String>(
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
                          value: _selectedRoomName,
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
                      const SizedBox(height: AppSpacing.md),
                      
                      // Date and Time (moved here)
                      InkWell(
                        onTap: _selectDateTime,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            child: Column(
                              crossAxisAlignment: DirectionUtils.crossAxisAlignmentStart,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(
                                      child: Text(
                                        '${l10n.dateTime} *: ${_selectedDateTime.day}/${_selectedDateTime.month}/${_selectedDateTime.year} at ${_selectedDateTime.hour}:${_selectedDateTime.minute.toString().padLeft(2, '0')}',
                                        style: AppTextStyles.bodyMedium,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      
                      if (_selectedRecurring != 'none') ...[
                        const SizedBox(height: AppSpacing.md),
                        ListTile(
                          title: Text('${l10n.endDate} *: ${_recurringEndDate?.toString().split(' ')[0] ?? l10n.notSet}'),
                          subtitle: Text('Required for recurring events'),
                          trailing: const Icon(Icons.calendar_today),
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
                              value: 'gallery',
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
                              title: Text(l10n.url),
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
                              title: Text(l10n.unsplash),
                              value: 'unsplash',
                              groupValue: _imageSource,
                              onChanged: (value) {
                                setState(() {
                                  _imageSource = value!;
                                  _selectedImageFile = null;
                                  _imageUrlController.clear();
                                });
                              },
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
                      ] else if (_imageSource == 'gallery') ...[
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _selectImageFromGallery,
                                icon: const Icon(Icons.photo_library),
                                label: Text(l10n.webUploadImage),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
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
                        ],
                      ] else ...[
                        TextFormField(
                          controller: _imageUrlController,
                          enabled: true,
                          decoration: InputDecoration(
                            labelText: l10n.imageUrl,
                            hintText: l10n.enterImageUrl,
                          ),
                          validator: (value) {
                            if (_imageSource == 'url' && (value == null || value.trim().isEmpty)) {
                              return l10n.pleaseEnterImageUrl;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _downloadImageFromUrl,
                                icon: const Icon(Icons.download),
                                label: Text(l10n.validateImageUrl),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          '${l10n.imagePreview}:',
                          style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        if (_imageUrlController.text.isNotEmpty)
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
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.error, color: Colors.red),
                                    const SizedBox(height: AppSpacing.sm),
                                    Text(l10n.invalidImageUrl),
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
                  onPressed: (_isSaving || !_isEditable) ? null : _saveEvent,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isEditable ? AppColors.primary : Colors.grey,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.sm),
                    ),
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          widget.event == null
                              ? l10n.createEventButton
                              : _isEditable
                                  ? l10n.updateEventButton
                                  : 'Cannot Edit - Status not Pending Approval',
                          style: AppTextStyles.buttonText,
                        ),
                ),
              ),
              
              // Show status warning for non-editable events
              if (widget.event != null && !_isEditable) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    border: Border.all(color: Colors.orange),
                    borderRadius: BorderRadius.circular(AppSpacing.sm),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.orange),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'This event cannot be edited because its status is "${_getStatusDisplayName(_selectedStatus)}". Only events with "Pending Approval" status can be modified.',
                          style: const TextStyle(color: Colors.orange),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}