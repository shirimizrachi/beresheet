import 'package:beresheet_app/services/modern_localization_service.dart';
import 'package:beresheet_app/services/user_session_service.dart';
import 'package:beresheet_app/services/image_cache_service.dart';
import 'package:beresheet_app/config/app_config.dart';
import 'package:beresheet_app/theme/app_theme.dart';
import 'package:beresheet_app/widgets/chat_input_widget.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

class ServiceRequestConversationScreen extends StatefulWidget {
  final String serviceProviderId;
  final String serviceProviderName;
  final String? serviceProviderPhoto;
  final String? serviceProviderType;
  final String? serviceProviderTypeDescription;
  final String? existingRequestId;

  const ServiceRequestConversationScreen({
    Key? key,
    required this.serviceProviderId,
    required this.serviceProviderName,
    this.serviceProviderPhoto,
    this.serviceProviderType,
    this.serviceProviderTypeDescription,
    this.existingRequestId,
  }) : super(key: key);

  @override
  State<ServiceRequestConversationScreen> createState() => _ServiceRequestConversationScreenState();
}

class _ServiceRequestConversationScreenState extends State<ServiceRequestConversationScreen> {
  final ScrollController _scrollController = ScrollController();
  
  List<Map<String, dynamic>> messages = [];
  bool isLoading = true;
  String? requestId;
  String? errorMessage;
  bool showAutoResponse = false;

  @override
  void initState() {
    super.initState();
    requestId = widget.existingRequestId;
    if (requestId != null) {
      _loadExistingConversation();
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }


  Future<void> _loadExistingConversation() async {
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
        Uri.parse('${AppConfig.apiUrlWithPrefix}/api/requests/${widget.existingRequestId}/chat'),
        headers: {
          'Content-Type': 'application/json',
          'homeID': homeId.toString(),
          'userId': userId,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          messages = List<Map<String, dynamic>>.from(data['chat_messages'] ?? []);
          isLoading = false;
        });
        _scrollToBottom();
      } else {
        throw Exception('Failed to load conversation: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Error loading conversation: $e';
      });
    }
  }

  /// Unified function to send any type of message (text, audio, video)
  /// Creates the request if it doesn't exist and returns the request ID
  Future<String?> sendRequestMessage({
    String? textMessage,
    String? mediaPath,
    String? mediaType,
  }) async {
    // Validate input - at least one type of message must be provided
    if ((textMessage?.trim().isEmpty ?? true) && (mediaPath?.isEmpty ?? true)) {
      throw Exception('Message cannot be empty');
    }


    try {
      final homeId = await UserSessionService.gethomeID();
      final userId = await UserSessionService.getUserId();
      
      if (homeId == null || userId == null) {
        throw Exception('User not logged in');
      }

      bool isFirstMessage = requestId == null;
      
      // Create request if it doesn't exist (only for text messages)
      if (requestId == null && textMessage != null && textMessage.trim().isNotEmpty) {
        final initialMessage = textMessage.trim();
        final createResponse = await http.post(
          Uri.parse('${AppConfig.apiUrlWithPrefix}/api/requests'),
          headers: {
            'Content-Type': 'application/json',
            'homeID': homeId.toString(),
            'userId': userId,
          },
          body: json.encode({
            'service_provider_id': widget.serviceProviderId,
            'request_message': initialMessage,
          }),
        );

        if (createResponse.statusCode == 201) {
          final requestData = json.decode(createResponse.body);
          requestId = requestData['id'];
        } else {
          throw Exception('Failed to create request: ${createResponse.statusCode}');
        }
      }

      final messageId = DateTime.now().millisecondsSinceEpoch.toString();

      // Handle media upload
      if (mediaPath != null && mediaType != null) {
        final file = File(mediaPath);
        final fileBytes = await file.readAsBytes();
        final fileName = file.path.split('/').last;

        // Use the unified upload endpoint that can create request if needed
        final uri = Uri.parse('${AppConfig.apiUrlWithPrefix}/api/requests/upload-media');
        final request = http.MultipartRequest('POST', uri);
        
        request.headers.addAll({
          'homeID': homeId.toString(),
          'userId': userId,
        });
        
        request.fields['message_id'] = messageId;
        request.fields['service_provider_id'] = widget.serviceProviderId;
        request.fields['request_message'] = textMessage ?? 'Media message';
        
        // Include request_id if we have one, otherwise let backend create new request
        if (requestId != null) {
          request.fields['request_id'] = requestId!;
        }
        
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: fileName,
        ));

        final response = await request.send();
        
        if (response.statusCode == 200) {
          final responseData = await response.stream.bytesToString();
          final data = json.decode(responseData);
          final mediaUrl = data['media_url'];
          
          // Update requestId if it was just created
          if (requestId == null && data['request_id'] != null) {
            requestId = data['request_id'];
          }

          // Add media message to local messages list
          setState(() {
            messages.add({
              'message_id': messageId,
              'sender_id': userId,
              'sender_type': 'resident',
              'message': textMessage ?? '',
              'media_type': mediaType,
              'media_url': mediaUrl,
              'timestamp': DateTime.now().toIso8601String(),
            });
          });
        } else {
          throw Exception('Failed to upload media: ${response.statusCode}');
        }
      }
      // Handle text message
      else if (textMessage != null && textMessage.trim().isNotEmpty) {
        // Send text message to existing request
        final addMessageResponse = await http.post(
          Uri.parse('${AppConfig.apiUrlWithPrefix}/api/requests/$requestId/chat'),
          headers: {
            'Content-Type': 'application/json',
            'homeID': homeId.toString(),
            'userId': userId,
          },
          body: json.encode({
            'message': textMessage.trim(),
          }),
        );

        if (addMessageResponse.statusCode != 200) {
          throw Exception('Failed to send message: ${addMessageResponse.statusCode}');
        }

        // Add text message to local messages list
        setState(() {
          messages.add({
            'message_id': messageId,
            'sender_id': userId,
            'sender_type': 'resident',
            'message': textMessage.trim(),
            'timestamp': DateTime.now().toIso8601String(),
          });
        });
      }

      // Show auto-response for first message (any type: text, video, voice, image)
      if (isFirstMessage) {
        setState(() {
          showAutoResponse = true;
        });
        
        // Add the auto-response message after a brief delay
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() {
              messages.add({
                'message_id': 'auto_response',
                'sender_type': 'system',
                'message': context.l10n.serviceProviderAutoResponse(widget.serviceProviderName),
                'timestamp': DateTime.now().toIso8601String(),
              });
            });
            _scrollToBottom();
          }
        });
      }


      _scrollToBottom();
      return requestId;

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending message: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }
  }


  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildMessage(Map<String, dynamic> message) {
    final isResident = message['sender_type'] == 'resident';
    final isSystem = message['sender_type'] == 'system';
    final messageText = message['message'] ?? '';
    final mediaType = message['media_type'];
    final mediaUrl = message['media_url'];
    final timestamp = message['timestamp'];

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: isResident ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isResident && !isSystem) SizedBox(width: 50),
          Flexible(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 8),
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSystem
                    ? Colors.blue.shade100
                    : isResident
                        ? Color(0xFFDCF8C6)
                        : Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 1,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (mediaType != null && mediaUrl != null) ...[
                    if (mediaType == 'image')
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          mediaUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 100,
                              color: Colors.grey.shade300,
                              child: const Icon(Icons.error),
                            );
                          },
                        ),
                      )
                    else if (mediaType == 'video')
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Icon(Icons.play_circle_outline, color: Colors.white, size: 48),
                        ),
                      )
                    else if (mediaType == 'audio')
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.audiotrack, color: isResident ? Colors.black87 : Colors.black87),
                          const SizedBox(width: 8),
                          Text(
                            context.l10n.audioMessage,
                            style: TextStyle(
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    if (messageText.isNotEmpty) const SizedBox(height: 8),
                  ],
                  if (messageText.isNotEmpty)
                    Text(
                      messageText,
                      style: TextStyle(
                        fontSize: 14,
                        color: isSystem ? Colors.blue.shade700 : Colors.black87,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                  SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (timestamp != null)
                        Text(
                          _formatTimestamp(timestamp),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      if (isResident) ...[
                        SizedBox(width: 4),
                        Icon(
                          Icons.done_all,
                          size: 16,
                          color: Color(0xFF4FC3F7),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isResident) SizedBox(width: 50),
        ],
      ),
    );
  }


  String _formatTimestamp(String timestamp) {
    try {
      final date_time = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(date_time);

      if (difference.inDays > 0) {
        return context.l10n.daysAgo(difference.inDays);
      } else if (difference.inHours > 0) {
        return context.l10n.hoursAgo(difference.inHours);
      } else if (difference.inMinutes > 0) {
        return context.l10n.minutesAgo(difference.inMinutes);
      } else {
        return context.l10n.justNow;
      }
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFE5DDD5),
      appBar: AppBar(
        backgroundColor: Color(0xFF075E54),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            ImageCacheService.buildCircularUserImage(
              imageUrl: widget.serviceProviderPhoto,
              radius: 20,
              errorWidget: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Color(0xFF25D366),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    widget.serviceProviderName.isNotEmpty ? widget.serviceProviderName[0].toUpperCase() : 'S',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.serviceProviderName,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (widget.serviceProviderTypeDescription != null)
                    Text(
                      widget.serviceProviderTypeDescription!,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    )
                  else if (widget.serviceProviderType != null)
                    Text(
                      widget.serviceProviderType!,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
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
                          onPressed: _loadExistingConversation,
                          child: Text(context.l10n.retry),
                        ),
                      ],
                    ),
                  ),
                )
              : Stack(
                  children: [
                    Column(
                      children: [
                        // Messages Area
                        Expanded(
                          child: Container(
                            color: Color(0xFFE5DDD5),
                            child: messages.isEmpty
                                ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.chat_bubble_outline,
                                            size: 80,
                                            color: Colors.grey,
                                          ),
                                          const SizedBox(height: 24),
                                          Text(
                                            context.l10n.sendMessageTo(widget.serviceProviderName),
                                            style: TextStyle(
                                              fontSize: 18,
                                              color: Colors.grey[600],
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    controller: _scrollController,
                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                    itemCount: messages.length,
                                    itemBuilder: (context, index) {
                                      return _buildMessage(messages[index]);
                                    },
                                  ),
                          ),
                        ),

                        // Chat Input Widget
                        ChatInputWidget(
                          inputType: ChatInputType.serviceRequest,
                          requestId: requestId,
                          serviceProviderId: widget.serviceProviderId,
                          isExpandable: false, // Service request conversations don't expand
                          initialMessages: messages,
                          onMessageSent: (message) {
                            setState(() {
                              messages.add(message);
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
    );
  }
}