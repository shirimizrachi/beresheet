import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/web_auth_service.dart';
import '../../model/event.dart';
import '../../services/event_service.dart';

class EventFormWebWeb extends StatefulWidget {
  final Event? event; // null for creating new event

  const EventFormWebWeb({Key? key, this.event}) : super(key: key);

  @override
  State<EventFormWebWeb> createState() => _EventFormWebWebState();
}

class _EventFormWebWebState extends State<EventFormWebWeb> {
  final _formKey = GlobalKey<FormState>();
  
  // Form controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _maxParticipantsController = TextEditingController();
  final TextEditingController _currentParticipantsController = TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController();
  final TextEditingController _recurringPatternController = TextEditingController();
  
  // Form variables
  String _selectedType = 'class';
  String _selectedStatus = 'pending-approval';
  String _selectedRecurring = 'none';
  DateTime _selectedDateTime = DateTime.now().add(const Duration(days: 1));
  DateTime? _recurringEndDate;
  
  // Image handling
  String _imageSource = 'url'; // 'url' or 'upload'
  
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  // Event type options
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

  final List<String> _statusOptions = [
    'pending-approval',
    'active',
    'canceled',
    'suspended'
  ];

  final List<String> _recurringOptions = [
    'none',
    'daily',
    'weekly',
    'monthly',
    'yearly',
    'custom'
  ];

  @override
  void initState() {
    super.initState();
    _checkPermissions();
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
    _recurringPatternController.text = event.recurringPattern ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _maxParticipantsController.dispose();
    _currentParticipantsController.dispose();
    _imageUrlController.dispose();
    _recurringPatternController.dispose();
    super.dispose();
  }

  void _checkPermissions() {
    final userRole = WebAuthService.userRole ?? '';
    if (userRole != 'manager' && userRole != 'staff' && userRole != 'instructor') {
      setState(() {
        _errorMessage = 'Access denied: Manager, Staff, or Instructor role required';
        _isLoading = false;
      });
    }
  }

  bool get _isEditable {
    // New events are always editable
    if (widget.event == null) return true;
    
    // Existing events are only editable if status is "pending-approval"
    return _selectedStatus == 'pending-approval';
  }

  bool get _isFieldEditable {
    // For new events, all fields except status and currentParticipants are editable
    if (widget.event == null) return true;
    
    // For existing events, depends on status
    return _selectedStatus == 'pending-approval';
  }

  Future<void> _validateImageUrl() async {
    if (_imageUrlController.text.trim().isEmpty) {
      _showMessage('Please enter an image URL first', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.get(Uri.parse(_imageUrlController.text.trim()));
      
      if (response.statusCode == 200) {
        _showMessage('Image URL validated successfully', isError: false);
      } else {
        throw Exception('Failed to load image from URL');
      }
    } catch (e) {
      _showMessage('Error validating image: $e', isError: true);
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
        'location': _locationController.text.trim(),
        'maxParticipants': int.parse(_maxParticipantsController.text.trim()),
        'image_url': _imageUrlController.text.trim(),
        'currentParticipants': widget.event == null ? 0 : int.parse(_currentParticipantsController.text.trim()),
        'recurring': _selectedRecurring,
        'recurring_end_date': _recurringEndDate?.toIso8601String(),
        'recurring_pattern': _selectedRecurring == 'custom' ? _recurringPatternController.text.trim() : null,
      };

      final response = widget.event == null
          ? await http.post(
              Uri.parse('http://localhost:8000/api/events'),
              headers: headers,
              body: json.encode(eventData),
            )
          : await http.put(
              Uri.parse('http://localhost:8000/api/events/${widget.event!.id}'),
              headers: headers,
              body: json.encode(eventData),
            );

      if (response.statusCode == 201 || response.statusCode == 200) {
        setState(() {
          _successMessage = widget.event == null 
              ? 'Event created successfully!' 
              : 'Event updated successfully!';
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
          _errorMessage = 'Failed to save event: ${errorData['detail'] ?? response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error saving event: $e';
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
    _recurringPatternController.clear();
    setState(() {
      _selectedType = 'class';
      _selectedStatus = 'pending-approval';
      _selectedRecurring = 'none';
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

  String _formatEventType(String type) {
    switch (type) {
      case 'class': return 'Class';
      case 'performance': return 'Performance';
      case 'cultural': return 'Cultural';
      case 'leisure': return 'Leisure';
      case 'workshop': return 'Workshop';
      case 'meeting': return 'Meeting';
      case 'sport': return 'Sport';
      case 'health': return 'Health';
      default: return type.toUpperCase();
    }
  }

  String _getStatusDisplayName(String status) {
    switch (status) {
      case 'pending-approval': return 'Pending Approval';
      case 'active': return 'Active';
      case 'canceled': return 'Canceled';
      case 'suspended': return 'Suspended';
      default: return status;
    }
  }

  String _getRecurringDisplayName(String recurring) {
    switch (recurring) {
      case 'none': return 'One-time event';
      case 'daily': return 'Daily';
      case 'weekly': return 'Weekly';
      case 'monthly': return 'Monthly';
      case 'yearly': return 'Yearly';
      case 'custom': return 'Custom';
      default: return recurring;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check permissions first
    final userRole = WebAuthService.userRole ?? '';
    if (userRole != 'manager' && userRole != 'staff' && userRole != 'instructor') {
      return _buildAccessDeniedPage();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.event == null ? 'Create New Event' : 'Edit Event',
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
                          const Text(
                            'Event Details',
                            style: TextStyle(
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
                          labelText: 'Event Name',
                          border: const OutlineInputBorder(),
                          helperText: !_isFieldEditable ? 'Read-only - status is not pending-approval' : null,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter event name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Event Type
                      DropdownButtonFormField<String>(
                        value: _selectedType,
                        decoration: InputDecoration(
                          labelText: 'Event Type',
                          border: const OutlineInputBorder(),
                          helperText: widget.event != null ? 'Read-only field' : null,
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
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          border: OutlineInputBorder(),
                          helperText: 'Read-only field - default: pending-approval',
                        ),
                        items: _statusOptions.map((String status) {
                          return DropdownMenuItem<String>(
                            value: status,
                            child: Text(_getStatusDisplayName(status)),
                          );
                        }).toList(),
                        onChanged: null, // Always read-only
                      ),
                      const SizedBox(height: 16),
                      
                      // Description
                      TextFormField(
                        controller: _descriptionController,
                        enabled: _isFieldEditable,
                        decoration: InputDecoration(
                          labelText: 'Description',
                          border: const OutlineInputBorder(),
                          helperText: !_isFieldEditable ? 'Read-only - status is not pending-approval' : null,
                        ),
                        maxLines: 3,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter event description';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Location
                      TextFormField(
                        controller: _locationController,
                        enabled: _isFieldEditable,
                        decoration: InputDecoration(
                          labelText: 'Location',
                          border: const OutlineInputBorder(),
                          helperText: !_isFieldEditable ? 'Read-only - status is not pending-approval' : null,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter event location';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Date & Time Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.schedule, color: Colors.green),
                          const SizedBox(width: 8),
                          const Text(
                            'Date & Time',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      Row(
                        children: [
                          // Date Picker
                          Expanded(
                            child: InkWell(
                              onTap: _isFieldEditable ? _selectDate : null,
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Event Date',
                                  border: const OutlineInputBorder(),
                                  suffixIcon: Icon(
                                    Icons.calendar_today,
                                    color: _isFieldEditable ? null : Colors.grey,
                                  ),
                                  helperText: !_isFieldEditable ? 'Read-only' : null,
                                ),
                                child: Text(
                                  '${_selectedDateTime.day}/${_selectedDateTime.month}/${_selectedDateTime.year}',
                                  style: TextStyle(
                                    color: _isFieldEditable ? null : Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          
                          // Time Picker
                          Expanded(
                            child: InkWell(
                              onTap: _isFieldEditable ? _selectTime : null,
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Event Time',
                                  border: const OutlineInputBorder(),
                                  suffixIcon: Icon(
                                    Icons.access_time,
                                    color: _isFieldEditable ? null : Colors.grey,
                                  ),
                                  helperText: !_isFieldEditable ? 'Read-only' : null,
                                ),
                                child: Text(
                                  '${_selectedDateTime.hour}:${_selectedDateTime.minute.toString().padLeft(2, '0')}',
                                  style: TextStyle(
                                    color: _isFieldEditable ? null : Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
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
                          const Text(
                            'Participants',
                            style: TextStyle(
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
                                labelText: 'Max Participants',
                                border: const OutlineInputBorder(),
                                helperText: !_isFieldEditable ? 'Read-only' : null,
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter max participants';
                                }
                                final number = int.tryParse(value.trim());
                                if (number == null || number <= 0) {
                                  return 'Please enter a valid number';
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
                                decoration: const InputDecoration(
                                  labelText: 'Current Participants',
                                  border: OutlineInputBorder(),
                                  helperText: 'Read-only - default to 0',
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
                          const Text(
                            'Recurring Settings',
                            style: TextStyle(
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
                          labelText: 'Recurrence',
                          border: const OutlineInputBorder(),
                          helperText: !_isFieldEditable ? 'Read-only - status is not pending-approval' : null,
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
                                _recurringPatternController.clear();
                              }
                            });
                          }
                        } : null,
                      ),
                      
                      if (_selectedRecurring != 'none') ...[
                        const SizedBox(height: 16),
                        InkWell(
                          onTap: _isFieldEditable ? () async {
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
                          } : null,
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'End Date',
                              border: const OutlineInputBorder(),
                              suffixIcon: Icon(
                                Icons.calendar_today,
                                color: _isFieldEditable ? null : Colors.grey,
                              ),
                              helperText: !_isFieldEditable ? 'Read-only' : null,
                            ),
                            child: Text(
                              _recurringEndDate?.toString().split(' ')[0] ?? 'Not set',
                              style: TextStyle(
                                color: _isFieldEditable ? null : Colors.grey,
                              ),
                            ),
                          ),
                        ),
                        
                        if (_selectedRecurring == 'custom') ...[
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _recurringPatternController,
                            enabled: _isFieldEditable,
                            decoration: InputDecoration(
                              labelText: 'Custom Pattern',
                              hintText: 'Enter custom recurring pattern (JSON format)',
                              border: const OutlineInputBorder(),
                              helperText: !_isFieldEditable ? 'Read-only - status is not pending-approval' : null,
                            ),
                            maxLines: 2,
                          ),
                        ],
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
                          const Text(
                            'Event Image',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _imageUrlController,
                        enabled: _isFieldEditable,
                        decoration: InputDecoration(
                          labelText: 'Image URL',
                          hintText: 'Enter image URL',
                          border: const OutlineInputBorder(),
                          helperText: !_isFieldEditable ? 'Read-only - status is not pending-approval' : null,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter image URL';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      if (_isFieldEditable)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _validateImageUrl,
                            icon: const Icon(Icons.download),
                            label: const Text('Validate Image URL'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      
                      const SizedBox(height: 16),
                      const Text(
                        'Image Preview:',
                        style: TextStyle(fontWeight: FontWeight.bold),
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
                              errorBuilder: (context, error, stackTrace) => const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.error, color: Colors.red),
                                  SizedBox(height: 8),
                                  Text('Invalid image URL'),
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

              // Show status warning for non-editable events
              if (widget.event != null && !_isEditable)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    border: Border.all(color: Colors.orange[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This event cannot be edited because its status is "${_getStatusDisplayName(_selectedStatus)}". Only events with "Pending Approval" status can be modified.',
                          style: TextStyle(color: Colors.orange[700]),
                        ),
                      ),
                    ],
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
                        child: const Text('Clear Form'),
                      ),
                    ),
                  if (widget.event == null) const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (_isLoading || !_isEditable) ? null : _saveEvent,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isEditable ? Colors.blue : Colors.grey,
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
                                  ? 'Create Event' 
                                  : _isEditable 
                                      ? 'Update Event'
                                      : 'Cannot Edit - Status not Pending Approval',
                            ),
                    ),
                  ),
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
        title: const Text('Event Form'),
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
                const Text(
                  'Access Denied',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Event management requires Manager, Staff, or Instructor role.',
                  style: TextStyle(
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