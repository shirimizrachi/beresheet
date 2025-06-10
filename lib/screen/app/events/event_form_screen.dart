import 'package:beresheet_app/model/event.dart';
import 'package:beresheet_app/services/event_service.dart';
import 'package:beresheet_app/services/modern_localization_service.dart';
import 'package:beresheet_app/theme/app_theme.dart';
import 'package:beresheet_app/utils/direction_utils.dart';
import 'package:flutter/material.dart';

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

  String _selectedType = 'class';
  DateTime _selectedDateTime = DateTime.now().add(const Duration(days: 1));
  bool _isSaving = false;

  final List<String> _eventTypes = [
    'class',
    'performance', 
    'cultural',
    'leisure',
    'workshop',
    'meeting',
    'sport',
    'health'
  ];

  @override
  void initState() {
    super.initState();
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
    _selectedDateTime = event.dateTime;
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
    final l10n = context.l10n;
    
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

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) return;

    final l10n = context.l10n;

    setState(() {
      _isSaving = true;
    });

    try {
      final event = Event(
        id: widget.event?.id ?? '',
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        type: _selectedType,
        dateTime: _selectedDateTime,
        location: _locationController.text.trim(),
        maxParticipants: int.parse(_maxParticipantsController.text),
        currentParticipants: int.parse(_currentParticipantsController.text),
        imageUrl: _imageUrlController.text.trim(),
        isRegistered: widget.event?.isRegistered ?? false,
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
      case 'class': return l10n.eventTypeClass;
      case 'performance': return l10n.eventTypePerformance;
      case 'cultural': return l10n.eventTypeCultural;
      case 'leisure': return l10n.eventTypeLeisure;
      case 'workshop': return l10n.eventTypeWorkshop;
      case 'meeting': return l10n.eventTypeMeeting;
      case 'sport': return l10n.eventTypeSport;
      case 'health': return l10n.eventTypeHealth;
      default: return type;
    }
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
                    onChanged: (value) {
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

              // Description
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: TextFormField(
                    controller: _descriptionController,
                    maxLines: 3,
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

              // Date and Time
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: DirectionUtils.crossAxisAlignmentStart,
                    children: [
                      InkWell(
                        onTap: _selectDateTime,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, color: AppColors.primary),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  '${l10n.dateTime}: ${_selectedDateTime.day}/${_selectedDateTime.month}/${_selectedDateTime.year} at ${_selectedDateTime.hour}:${_selectedDateTime.minute.toString().padLeft(2, '0')}',
                                  style: AppTextStyles.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Location
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: TextFormField(
                    controller: _locationController,
                    decoration: InputDecoration(
                      labelText: l10n.location,
                      hintText: l10n.enterEventLocation,
                    ),
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

              // Image URL
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: DirectionUtils.crossAxisAlignmentStart,
                    children: [
                      TextFormField(
                        controller: _imageUrlController,
                        decoration: InputDecoration(
                          labelText: l10n.imageUrl,
                          hintText: l10n.enterImageUrl,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return l10n.pleaseEnterImageUrl;
                          }
                          return null;
                        },
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
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveEvent,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.sm),
                    ),
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          widget.event == null ? l10n.createEventButton : l10n.updateEventButton,
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