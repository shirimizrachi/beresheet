import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../config/app_config.dart';
import '../../../services/web_auth_service.dart';
import '../../../services/modern_localization_service.dart';

class UpdateNotificationWeb extends StatefulWidget {
  final Map<String, dynamic> notification;

  const UpdateNotificationWeb({Key? key, required this.notification}) : super(key: key);

  @override
  _UpdateNotificationWebState createState() => _UpdateNotificationWebState();
}

class _UpdateNotificationWebState extends State<UpdateNotificationWeb> {
  String _currentStatus = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.notification['send_status'] ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(ModernLocalizationService.of(context).translate('update_notification')),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
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
                    _buildReadOnlyField(
                      ModernLocalizationService.of(context).translate('created_by'),
                      widget.notification['create_by_user_name'] ?? '',
                    ),
                    const SizedBox(height: 12),
                    _buildReadOnlyField(
                      ModernLocalizationService.of(context).translate('message'),
                      widget.notification['message'] ?? '',
                    ),
                    const SizedBox(height: 12),
                    _buildReadOnlyField(
                      ModernLocalizationService.of(context).translate('send_type'),
                      widget.notification['send_type'] ?? '',
                    ),
                    const SizedBox(height: 12),
                    _buildReadOnlyField(
                      ModernLocalizationService.of(context).translate('send_floor'),
                      widget.notification['send_floor']?.toString() ?? 
                          ModernLocalizationService.of(context).translate('all_residents'),
                    ),
                    const SizedBox(height: 12),
                    _buildReadOnlyField(
                      ModernLocalizationService.of(context).translate('send_datetime'),
                      _formatDateTime(widget.notification['send_datetime']),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      ModernLocalizationService.of(context).translate('update_status'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _currentStatus,
                      decoration: InputDecoration(
                        labelText: ModernLocalizationService.of(context).translate('send_status'),
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'pending-approval',
                          child: Text(ModernLocalizationService.of(context).translate('pending_approval')),
                        ),
                        DropdownMenuItem(
                          value: 'approved',
                          child: Text(ModernLocalizationService.of(context).translate('approved')),
                        ),
                        DropdownMenuItem(
                          value: 'canceled',
                          child: Text(ModernLocalizationService.of(context).translate('canceled')),
                        ),
                        DropdownMenuItem(
                          value: 'sent',
                          child: Text(ModernLocalizationService.of(context).translate('sent')),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _currentStatus = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: _isLoading ? null : _updateStatus,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[800],
                            foregroundColor: Colors.white,
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : Text(ModernLocalizationService.of(context).translate('update_status')),
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
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(value),
        ),
      ],
    );
  }

  String _formatDateTime(dynamic dateTime) {
    if (dateTime == null) return '';
    try {
      DateTime dt = DateTime.parse(dateTime.toString());
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTime.toString();
    }
  }

  Future<void> _updateStatus() async {
    // Show warning for approval
    if (_currentStatus == 'approved' && widget.notification['send_status'] != 'approved') {
      bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(ModernLocalizationService.of(context).translate('confirm_approval')),
            content: Text(ModernLocalizationService.of(context).translate('approval_warning_message')),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(ModernLocalizationService.of(context).translate('cancel')),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: Text(ModernLocalizationService.of(context).translate('confirm')),
              ),
            ],
          );
        },
      );
      
      if (confirmed != true) {
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final token = await WebAuthService.getStoredToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.put(
        Uri.parse('${AppConfig.apiUrl}/api/home-notifications/${widget.notification['id']}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'send_status': _currentStatus,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ModernLocalizationService.of(context).translate('notification_updated_successfully')),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        throw Exception('Failed to update notification: ${response.statusCode}');
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
}
