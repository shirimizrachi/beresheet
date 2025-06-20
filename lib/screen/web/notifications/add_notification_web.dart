import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../config/app_config.dart';
import '../../../services/web_auth_service.dart';
import '../../../services/modern_localization_service.dart';

class AddNotificationWeb extends StatefulWidget {
  const AddNotificationWeb({Key? key}) : super(key: key);

  @override
  _AddNotificationWebState createState() => _AddNotificationWebState();
}

class _AddNotificationWebState extends State<AddNotificationWeb> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  final _sendFloorController = TextEditingController();
  String _sendType = 'regular';
  DateTime? _sendDateTime;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.add),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.eventDetails, // Using closest available translation
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          labelText: 'Message',
                          border: const OutlineInputBorder(),
                        ),
                        maxLines: 4,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return context.l10n.fieldRequired;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _sendFloorController,
                              decoration: InputDecoration(
                                labelText: 'Send Floor',
                                hintText: 'Leave empty for all residents',
                                border: const OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _sendType,
                              decoration: InputDecoration(
                                labelText: 'Send Type',
                                border: const OutlineInputBorder(),
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: 'regular',
                                  child: Text('Regular'),
                                ),
                                DropdownMenuItem(
                                  value: 'urgent',
                                  child: Text('Urgent'),
                                ),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _sendType = value!;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            final TimeOfDay? timePicked = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.now(),
                            );
                            if (timePicked != null) {
                              setState(() {
                                _sendDateTime = DateTime(
                                  picked.year,
                                  picked.month,
                                  picked.day,
                                  timePicked.hour,
                                  timePicked.minute,
                                );
                              });
                            }
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today),
                              const SizedBox(width: 8),
                              Text(
                                _sendDateTime != null
                                    ? '${_sendDateTime!.day}/${_sendDateTime!.month}/${_sendDateTime!.year} ${_sendDateTime!.hour}:${_sendDateTime!.minute.toString().padLeft(2, '0')}'
                                    : 'Select Send Date & Time',
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: _isLoading ? null : _submitNotification,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[800],
                              foregroundColor: Colors.white,
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : Text(context.l10n.add),
                          ),
                          const SizedBox(width: 16),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(context.l10n.cancel),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitNotification() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (!WebAuthService.isLoggedIn) {
        throw Exception('User not authenticated');
      }

      final requestBody = {
        'message': _messageController.text,
        'send_type': _sendType,
      };

      if (_sendFloorController.text.isNotEmpty) {
        requestBody['send_floor'] = _sendFloorController.text; // Keep as string to avoid type error
      }

      if (_sendDateTime != null) {
        requestBody['send_datetime'] = _sendDateTime!.toIso8601String();
      }

      final response = await http.post(
        Uri.parse('${AppConfig.apiUrlWithPrefix}/api/home-notifications'),
        headers: {
          ...WebAuthService.getAuthHeaders(),
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.operationSuccessful),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        throw Exception('Failed to create notification: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.l10n.error}: $e'),
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
  void dispose() {
    _messageController.dispose();
    _sendFloorController.dispose();
    super.dispose();
  }
}
