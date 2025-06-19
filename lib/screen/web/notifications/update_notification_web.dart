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
        title: Text(context.l10n.edit),
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
                      context.l10n.eventDetails, // Using closest available translation
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    _buildReadOnlyField(
                      'Created By',
                      widget.notification['create_by_user_name'] ?? '',
                    ),
                    const SizedBox(height: 12),
                    _buildReadOnlyField(
                      'Message',
                      widget.notification['message'] ?? '',
                    ),
                    const SizedBox(height: 12),
                    _buildReadOnlyField(
                      'Send Type',
                      widget.notification['send_type'] ?? '',
                    ),
                    const SizedBox(height: 12),
                    _buildReadOnlyField(
                      'Send Floor',
                      widget.notification['send_floor']?.toString() ??
                          'All Residents',
                    ),
                    const SizedBox(height: 12),
                    _buildReadOnlyField(
                      context.l10n.dateTime,
                      _formatDateTime(widget.notification['send_datetime']),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Update Status',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _currentStatus,
                      decoration: InputDecoration(
                        labelText: 'Send Status',
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'pending-approval',
                          child: Text('Pending Approval'),
                        ),
                        DropdownMenuItem(
                          value: 'approved',
                          child: Text('Approved'),
                        ),
                        DropdownMenuItem(
                          value: 'canceled',
                          child: Text('Canceled'),
                        ),
                        DropdownMenuItem(
                          value: 'sent',
                          child: Text('Sent'),
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
                              : Text('Update Status'),
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
            title: Text('Confirm Approval'),
            content: Text('Are you sure you want to approve this notification? This action will send it to all recipients.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(context.l10n.cancel),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: Text('Confirm'),
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
      if (!WebAuthService.isLoggedIn) {
        throw Exception('User not authenticated');
      }

      final response = await http.put(
        Uri.parse('${AppConfig.apiBaseUrl}/api/home-notifications/${widget.notification['id']}'),
        headers: {
          ...WebAuthService.getAuthHeaders(),
        },
        body: json.encode({
          'send_status': _currentStatus,
        }),
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
        throw Exception('Failed to update notification: ${response.statusCode}');
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
}
