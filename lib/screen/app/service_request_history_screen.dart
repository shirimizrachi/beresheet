import 'package:beresheet_app/services/modern_localization_service.dart';
import 'package:beresheet_app/services/user_session_service.dart';
import 'package:beresheet_app/config/app_config.dart';
import 'package:beresheet_app/theme/app_theme.dart';
import 'package:beresheet_app/screen/app/service_request_conversation_screen.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ServiceRequestHistoryScreen extends StatefulWidget {
  const ServiceRequestHistoryScreen({Key? key}) : super(key: key);

  @override
  State<ServiceRequestHistoryScreen> createState() => _ServiceRequestHistoryScreenState();
}

class _ServiceRequestHistoryScreenState extends State<ServiceRequestHistoryScreen> {
  List<Map<String, dynamic>> requests = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadRequestHistory();
  }

  Future<void> _loadRequestHistory() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final homeId = await UserSessionService.gethomeID();
      final userId = await UserSessionService.getUserId();
      
      if (homeId == null || userId == null) {
        throw Exception('User not logged in');
      }

      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/api/requests/resident/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'homeID': homeId.toString(),
          'userId': userId,
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          requests = data.map((item) => item as Map<String, dynamic>).toList();
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load request history: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Error loading request history: $e';
      });
    }
  }

  String _formatDateTime(String? dateTimeString, BuildContext context) {
    if (dateTimeString == null) return context.l10n.unknownDate;
    try {
      final dateTime = DateTime.parse(dateTimeString);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays == 0) {
        return '${context.l10n.today} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
      } else if (difference.inDays == 1) {
        return '${context.l10n.yesterday} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
      } else {
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      }
    } catch (e) {
      return dateTimeString;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return Colors.blue;
      case 'in_progress':
        return Colors.orange;
      case 'closed':
        return Colors.green;
      case 'abandoned':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusDisplayText(String status, BuildContext context) {
    switch (status.toLowerCase()) {
      case 'open':
        return context.l10n.requestStatusOpen;
      case 'in_progress':
        return context.l10n.requestStatusInProgress;
      case 'closed':
        return context.l10n.requestStatusClosed;
      case 'abandoned':
        return context.l10n.requestStatusAbandoned;
      default:
        return status;
    }
  }

  void _openConversation(Map<String, dynamic> request) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ServiceRequestConversationScreen(
          serviceProviderId: request['service_provider_id'],
          serviceProviderName: request['service_provider_full_name'] ?? 'Service Provider',
          existingRequestId: request['id'],
        ),
      ),
    ).then((_) {
      // Refresh the list when returning from conversation
      _loadRequestHistory();
    });
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final serviceProviderName = request['service_provider_full_name'] ?? context.l10n.unknownProvider;
    final serviceProviderType = request['service_provider_type'] ?? context.l10n.serviceProvider;
    final requestMessage = request['request_message'] ?? '';
    final status = request['request_status'] ?? 'unknown';
    final createdAt = _formatDateTime(request['request_created_at'], context);
    final statusColor = _getStatusColor(status);
    final statusText = _getStatusDisplayText(status, context);

    // Truncate message for preview
    final messagePreview = requestMessage.length > 100 
        ? '${requestMessage.substring(0, 100)}...' 
        : requestMessage;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: InkWell(
        onTap: () => _openConversation(request),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with provider info and status
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    child: Icon(
                      Icons.person,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          serviceProviderName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          serviceProviderType,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Message preview
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.chat_bubble_outline,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        messagePreview,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Footer with date and action
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: Colors.grey[500],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    createdAt,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text(
          context.l10n.requestHistory,
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
          IconButton(
            icon: const Icon(Icons.refresh),
            color: Colors.white,
            onPressed: _loadRequestHistory,
            tooltip: context.l10n.refresh,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          errorMessage!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadRequestHistory,
                          child: Text(context.l10n.retry),
                        ),
                      ],
                    ),
                  ),
                )
              : requests.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.history,
                              size: 80,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 24),
                            Text(
                              context.l10n.noRequestHistory,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              context.l10n.noServiceRequestsYet,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        // Header
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            border: Border(
                              bottom: BorderSide(
                                color: AppColors.primary.withOpacity(0.2),
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.history,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      context.l10n.requestHistory,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    Text(
                                      context.l10n.requestsCount(requests.length, requests.length != 1 ? 's' : ''),
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Requests List
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: requests.length,
                            itemBuilder: (context, index) {
                              return _buildRequestCard(requests[index]);
                            },
                          ),
                        ),
                      ],
                    ),
    );
  }
}