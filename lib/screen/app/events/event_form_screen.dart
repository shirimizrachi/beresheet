import 'package:beresheet_app/model/event.dart';
import 'package:beresheet_app/services/event_service.dart';
import 'package:beresheet_app/theme/app_theme.dart';
import 'package:flutter/material.dart';

class EventFormScreen extends StatefulWidget {
  final Event? event; // null for creating new event, non-null for editing

  const EventFormScreen({Key? key, this.event}) : super(key: key);

  @override
  State<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends State<EventFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _maxParticipantsController = TextEditingController();
  final _currentParticipantsController = TextEditingController();

  String _selectedType = 'class';
  DateTime _selectedDateTime = DateTime.now().add(const Duration(days: 1));
  bool _isLoading = false;

  final List<String> _eventTypes = ['class', 'performance', 'cultural', 'leisure'];

  @override
  void initState() {
    super.initState();
    if (widget.event != null) {
      // Editing existing event
      _nameController.text = widget.event!.name;
      _descriptionController.text = widget.event!.description;
      _locationController.text = widget.event!.location;
      _imageUrlController.text = widget.event!.imageUrl;
      _maxParticipantsController.text = widget.event!.maxParticipants.toString();
      _currentParticipantsController.text = widget.event!.currentParticipants.toString();
      _selectedType = widget.event!.type;
      _selectedDateTime = widget.event!.dateTime;
    } else {
      // Creating new event - set default values
      _maxParticipantsController.text = '20';
      _currentParticipantsController.text = '0';
      _imageUrlController.text = 'https://images.unsplash.com/photo-1511578314322-379afb476865?w=400';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _imageUrlController.dispose();
    _maxParticipantsController.dispose();
    _currentParticipantsController.dispose();
    super.dispose();
  }

  Future<void> _selectDateTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
      );

      if (pickedTime != null) {
        setState(() {
          _selectedDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      Event? savedEvent;

      if (widget.event == null) {
        // Creating new event
        savedEvent = await EventService.createEvent(
          name: _nameController.text.trim(),
          type: _selectedType,
          description: _descriptionController.text.trim(),
          dateTime: _selectedDateTime,
          location: _locationController.text.trim(),
          maxParticipants: int.parse(_maxParticipantsController.text),
          imageUrl: _imageUrlController.text.trim(),
        );
      } else {
        // Updating existing event
        savedEvent = await EventService.updateEvent(
          eventId: widget.event!.id,
          name: _nameController.text.trim(),
          type: _selectedType,
          description: _descriptionController.text.trim(),
          dateTime: _selectedDateTime,
          location: _locationController.text.trim(),
          maxParticipants: int.parse(_maxParticipantsController.text),
          imageUrl: _imageUrlController.text.trim(),
          currentParticipants: int.parse(_currentParticipantsController.text),
        );
      }

      if (savedEvent != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.event == null ? 'Event created successfully' : 'Event updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true); // Return true to indicate success
      } else {
        throw Exception('Failed to save event');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text(
          widget.event == null ? 'Create Event' : 'Edit Event',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: Colors.white,
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveEvent,
            child: Text(
              'SAVE',
              style: AppTextStyles.buttonText.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Event Name
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Event Name',
                        hintText: 'Enter event name',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter event name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Event Type
                    DropdownButtonFormField<String>(
                      value: _selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Event Type',
                      ),
                      items: _eventTypes.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Row(
                            children: [
                              Icon(
                                ActivityTypeHelper.getIcon(type),
                                color: ActivityTypeHelper.getColor(type),
                                size: 20,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text(ActivityTypeHelper.getDisplayName(type)),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedType = value!;
                        });
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Description
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'Enter event description',
                      ),
                      maxLines: 3,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter event description';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Date and Time
                    InkWell(
                      onTap: _selectDateTime,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.md),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, color: AppColors.primary),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              'Date & Time: ${_selectedDateTime.day}/${_selectedDateTime.month}/${_selectedDateTime.year} at ${_selectedDateTime.hour}:${_selectedDateTime.minute.toString().padLeft(2, '0')}',
                              style: AppTextStyles.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Location
                    TextFormField(
                      controller: _locationController,
                      decoration: const InputDecoration(
                        labelText: 'Location',
                        hintText: 'Enter event location',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter event location';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Max Participants
                    TextFormField(
                      controller: _maxParticipantsController,
                      decoration: const InputDecoration(
                        labelText: 'Maximum Participants',
                        hintText: 'Enter maximum number of participants',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter maximum participants';
                        }
                        final number = int.tryParse(value);
                        if (number == null || number <= 0) {
                          return 'Please enter a valid positive number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Current Participants (only show when editing)
                    if (widget.event != null) ...[
                      TextFormField(
                        controller: _currentParticipantsController,
                        decoration: const InputDecoration(
                          labelText: 'Current Participants',
                          hintText: 'Enter current number of participants',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter current participants';
                          }
                          final number = int.tryParse(value);
                          if (number == null || number < 0) {
                            return 'Please enter a valid non-negative number';
                          }
                          final maxParticipants = int.tryParse(_maxParticipantsController.text) ?? 0;
                          if (number > maxParticipants) {
                            return 'Current participants cannot exceed maximum participants';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],

                    // Image URL
                    TextFormField(
                      controller: _imageUrlController,
                      decoration: const InputDecoration(
                        labelText: 'Image URL',
                        hintText: 'Enter image URL',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter image URL';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Preview Image
                    if (_imageUrlController.text.isNotEmpty) ...[
                      Text(
                        'Image Preview:',
                        style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                        child: Image.network(
                          _imageUrlController.text,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 200,
                              color: Colors.grey[300],
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.broken_image, size: 48, color: Colors.grey),
                                  SizedBox(height: AppSpacing.sm),
                                  Text('Invalid image URL'),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveEvent,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                widget.event == null ? 'CREATE EVENT' : 'UPDATE EVENT',
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