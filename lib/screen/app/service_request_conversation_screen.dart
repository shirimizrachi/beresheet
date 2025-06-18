import 'package:beresheet_app/services/modern_localization_service.dart';
import 'package:beresheet_app/services/user_session_service.dart';
import 'package:beresheet_app/config/app_config.dart';
import 'package:beresheet_app/theme/app_theme.dart';
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
  final String? existingRequestId;

  const ServiceRequestConversationScreen({
    Key? key,
    required this.serviceProviderId,
    required this.serviceProviderName,
    this.existingRequestId,
  }) : super(key: key);

  @override
  State<ServiceRequestConversationScreen> createState() => _ServiceRequestConversationScreenState();
}

class _ServiceRequestConversationScreenState extends State<ServiceRequestConversationScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  List<Map<String, dynamic>> messages = [];
  bool isLoading = true;
  bool isSending = false;
  bool isRecording = false;
  bool isUploadingMedia = false;
  String? requestId;
  String? errorMessage;
  bool showAutoResponse = false;
  bool hasText = false;

  @override
  void initState() {
    super.initState();
    requestId = widget.existingRequestId;
    _messageController.addListener(_onTextChanged);
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
    _messageController.dispose();
    _scrollController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {
      hasText = _messageController.text.trim().isNotEmpty;
    });
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
        Uri.parse('${AppConfig.apiBaseUrl}/api/requests/${widget.existingRequestId}/chat'),
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

    if (isSending || isUploadingMedia) return null;

    setState(() {
      if (mediaPath != null) {
        isUploadingMedia = true;
      } else {
        isSending = true;
      }
    });

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
          Uri.parse('${AppConfig.apiBaseUrl}/api/requests'),
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
        final uri = Uri.parse('${AppConfig.apiBaseUrl}/api/requests/upload-media');
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
          Uri.parse('${AppConfig.apiBaseUrl}/api/requests/$requestId/chat'),
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

      // Show auto-response for first message
      if (isFirstMessage && textMessage != null && textMessage.trim().isNotEmpty) {
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

      // Clear input and update state
      setState(() {
        if (textMessage != null) {
          _messageController.clear();
          isSending = false;
        }
        if (mediaPath != null) {
          isUploadingMedia = false;
        }
      });

      _scrollToBottom();
      return requestId;

    } catch (e) {
      setState(() {
        isSending = false;
        isUploadingMedia = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending message: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }
  }

  /// Send text message
  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;
    
    await sendRequestMessage(textMessage: messageText);
  }

  /// Send media (audio, video, image)
  Future<void> _sendMediaMessage(String mediaPath, String mediaType) async {
    await sendRequestMessage(mediaPath: mediaPath, mediaType: mediaType);
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (image != null) {
        await _sendMediaMessage(image.path, 'image');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (image != null) {
        await _sendMediaMessage(image.path, 'image');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error taking photo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickVideo() async {
    try {
      final XFile? video = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 30), // Max 30 seconds
      );
      
      if (video != null) {
        await _sendMediaMessage(video.path, 'video');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking video: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _recordVideo() async {
    try {
      final XFile? video = await _imagePicker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(seconds: 15), // Max 15 seconds
      );
      
      if (video != null) {
        await _sendMediaMessage(video.path, 'video');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error recording video: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        setState(() {
          isRecording = true;
        });
        
        final String path = '${(await getTemporaryDirectory()).path}/audio_${DateTime.now().millisecondsSinceEpoch}.aac';
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Microphone permission required'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        isRecording = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error starting recording: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() {
        isRecording = false;
      });
      
      if (path != null) {
        await _sendMediaMessage(path, 'audio');
      }
    } catch (e) {
      setState(() {
        isRecording = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error stopping recording: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showMediaOptions() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: Icon(Icons.photo_library),
                title: Text(context.l10n.gallery),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage();
                },
              ),
              ListTile(
                leading: Icon(Icons.camera_alt),
                title: Text(context.l10n.camera),
                onTap: () {
                  Navigator.of(context).pop();
                  _takePhoto();
                },
              ),
              ListTile(
                leading: Icon(Icons.video_library),
                title: Text(context.l10n.videoGallery),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickVideo();
                },
              ),
              ListTile(
                leading: Icon(Icons.videocam),
                title: Text(context.l10n.recordVideo),
                onTap: () {
                  Navigator.of(context).pop();
                  _recordVideo();
                },
              ),
            ],
          ),
        );
      },
    );
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
    
    // Get text direction
    final isRTL = Directionality.of(context) == TextDirection.rtl;
    
    // In RTL: user on right, service provider on left
    // In LTR: user on left, service provider on right
    final shouldAlignEnd = isRTL ? isResident : !isResident;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        mainAxisAlignment: shouldAlignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          // Show avatar on the left only for non-resident, non-system messages in LTR
          // or on the right for non-resident, non-system messages in RTL
          if (!isResident && !isSystem && !isRTL) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary,
              child: Text(
                widget.serviceProviderName[0].toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSystem
                    ? Colors.blue.shade100
                    : isResident
                        ? AppColors.primary
                        : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(16),
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
                          Icon(Icons.audiotrack, color: isResident ? Colors.white : AppColors.primary),
                          const SizedBox(width: 8),
                          Text(
                            context.l10n.audioMessage,
                            style: TextStyle(
                              color: isResident ? Colors.white : Colors.black87,
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
                        color: isSystem
                            ? Colors.blue.shade700
                            : isResident
                                ? Colors.white
                                : Colors.black87,
                        fontSize: 16,
                      ),
                    ),
                  if (timestamp != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _formatTimestamp(timestamp),
                      style: TextStyle(
                        color: isSystem
                            ? Colors.blue.shade500
                            : isResident
                                ? Colors.white70
                                : Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Show avatar on the right only for non-resident, non-system messages in RTL
          if (!isResident && !isSystem && isRTL) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary,
              child: Text(
                widget.serviceProviderName[0].toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTimestamp(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

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
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text(
          widget.serviceProviderName,
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
              : Column(
                  children: [
                    // Messages Area
                    Expanded(
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
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: messages.length,
                              itemBuilder: (context, index) {
                                return _buildMessage(messages[index]);
                              },
                            ),
                    ),

                    // Media Upload Progress
                    if (isUploadingMedia)
                      Container(
                        padding: const EdgeInsets.all(16),
                        color: Colors.grey.shade100,
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 12),
                            Text(context.l10n.uploadingMedia),
                          ],
                        ),
                      ),

                    // Input Area
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: SafeArea(
                        child: Row(
                          children: [
                            // Media button
                            IconButton(
                              onPressed: isUploadingMedia ? null : _showMediaOptions,
                              icon: Icon(Icons.attach_file, color: AppColors.primary),
                            ),
                            
                            // Voice record button (when recording)
                            if (isRecording)
                              GestureDetector(
                                onTap: _stopRecording,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.stop, color: Colors.white),
                                ),
                              )
                            // Text input (always visible when not recording)
                            else ...[
                              Expanded(
                                child: TextField(
                                  controller: _messageController,
                                  decoration: InputDecoration(
                                    hintText: context.l10n.typeMessage,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(25),
                                      borderSide: BorderSide.none,
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey.shade100,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                  ),
                                  maxLines: 5,
                                  minLines: 1,
                                  textInputAction: TextInputAction.send,
                                  onSubmitted: (_) => _sendMessage(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Send button (when has text) or Voice button (when no text)
                              if (hasText)
                                IconButton(
                                  onPressed: (isSending || isUploadingMedia) ? null : _sendMessage,
                                  icon: isSending
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : Icon(Icons.send, color: AppColors.primary),
                                )
                              else
                                GestureDetector(
                                  onTap: isUploadingMedia ? null : _startRecording,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.mic, color: Colors.white),
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}