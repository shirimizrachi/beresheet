import 'package:beresheet_app/services/modern_localization_service.dart';
import 'package:beresheet_app/services/user_session_service.dart';
import 'package:beresheet_app/config/app_config.dart';
import 'package:beresheet_app/theme/app_theme.dart';
import 'package:beresheet_app/screen/app/service_request_conversation_screen.dart';
import 'package:beresheet_app/utils/display_name_utils.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ServiceRequestHistoryScreen extends StatefulWidget {
  final String? serviceProviderId;
  final String? serviceProviderName;
  final String? serviceProviderPhoto;
  final String? serviceProviderType;
  final String? serviceProviderTypeDescription;
  
  const ServiceRequestHistoryScreen({
    Key? key,
    this.serviceProviderId,
    this.serviceProviderName,
    this.serviceProviderPhoto,
    this.serviceProviderType,
    this.serviceProviderTypeDescription,
  }) : super(key: key);

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
        Uri.parse('${AppConfig.apiUrlWithPrefix}/api/requests/resident/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'homeID': homeId.toString(),
          'userId': userId,
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        List<Map<String, dynamic>> allRequests = data.map((item) => item as Map<String, dynamic>).toList();
        
        // Filter requests by service provider if specified
        if (widget.serviceProviderId != null) {
          allRequests = allRequests.where((request) =>
            request['service_provider_id'] == widget.serviceProviderId
          ).toList();
        }
        
        // Sort by modified date descending (most recent first)
        allRequests.sort((a, b) {
          final aModified = a['request_modified_at'] ?? a['request_created_at'];
          final bModified = b['request_modified_at'] ?? b['request_created_at'];
          
          if (aModified == null && bModified == null) return 0;
          if (aModified == null) return 1;
          if (bModified == null) return -1;
          
          try {
            final aDate = DateTime.parse(aModified);
            final bDate = DateTime.parse(bModified);
            return bDate.compareTo(aDate); // Descending order
          } catch (e) {
            return 0;
          }
        });
        
        setState(() {
          requests = allRequests;
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
        return '${DisplayNameUtils.getLocalizedFormattedDate(dateTime, context)} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
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
          serviceProviderPhoto: request['service_provider_photo'],
          serviceProviderTypeDescription: request['service_provider_type_description'],
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
    final requestMessage = request['request_message'] ?? '';
    final status = request['request_status'] ?? 'unknown';
    final modifiedAt = _formatDateTime(request['request_modified_at'] ?? request['request_created_at'], context);
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
              // Header with status and date
              Row(
                children: [
                  Expanded(
                    child: Text(
                      modifiedAt,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
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
              
              // Footer with action indicator
              Row(
                children: [
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
        title: widget.serviceProviderName != null
            ? Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    backgroundImage: widget.serviceProviderPhoto != null && widget.serviceProviderPhoto!.isNotEmpty
                        ? NetworkImage(widget.serviceProviderPhoto!)
                        : null,
                    child: widget.serviceProviderPhoto == null || widget.serviceProviderPhoto!.isEmpty
                        ? Text(
                            widget.serviceProviderName!.isNotEmpty ? widget.serviceProviderName![0].toUpperCase() : 'S',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.serviceProviderName!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (widget.serviceProviderTypeDescription != null)
                          Text(
                            widget.serviceProviderTypeDescription!,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          )
                        else if (widget.serviceProviderType != null)
                          Text(
                            widget.serviceProviderType!,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.l10n.requestHistory,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  if (!isLoading && errorMessage == null)
                    Text(
                      context.l10n.requestsCount(requests.length, requests.length != 1 ? 's' : ''),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                ],
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
                              widget.serviceProviderName != null
                                ? 'No service requests with ${widget.serviceProviderName} yet'
                                : context.l10n.noServiceRequestsYet,
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
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: requests.length,
                      itemBuilder: (context, index) {
                        return _buildRequestCard(requests[index]);
                      },
                    ),
    );
  }
}