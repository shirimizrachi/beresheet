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
        title: Text(ModernLocalizationService.of(context).translate('add_notification')),
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
                        ModernLocalizationService.of(context).translate('notification_details'),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          labelText: ModernLocalizationService.of(context).translate('message'),
                          border: const OutlineInputBorder(),
                        ),
                        maxLines: 4,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return ModernLocalizationService.of(context).translate('please_enter_message');
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
                                labelText: ModernLocalizationService.of(context).translate('send_floor'),
                                hintText: ModernLocalizationService.of(context).translate('leave_empty_for_all_residents'),
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
                                labelText: ModernLocalizationService.of(context).translate('send_type'),
                                border: const OutlineInputBorder(),
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: 'regular',
                                  child: Text(ModernLocalizationService.of(context).translate('regular')),
                                ),
                                DropdownMenuItem(
                                  value: 'urgent',
                                  child: Text(ModernLocalizationService.of(context).translate('urgent')),
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
                                    : ModernLocalizationService.of(context).translate('select_send_datetime'),
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
                                : Text(ModernLocalizationService.of(context).translate('create_notification')),
                          ),
                          const SizedBox(width: 16),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(ModernLocalizationService.of(context).translate('cancel')),
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
      final token = await WebAuthService.getStoredToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final requestBody = {
        'message': _messageController.text,
        'send_type': _sendType,
      };

      if (_sendFloorController.text.isNotEmpty) {
        requestBody['send_floor'] = int.parse(_sendFloorController.text);
      }

      if (_sendDateTime != null) {
        requestBody['send_datetime'] = _sendDateTime!.toIso8601String();
      }

      final response = await http.post(
        Uri.parse('${AppConfig.apiUrl}/api/home-notifications'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ModernLocalizationService.of(context).translate('notification_created_successfully')),
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
          content: Text('${ModernLocalizationService.of(context).translate('error')}: $e'),
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
