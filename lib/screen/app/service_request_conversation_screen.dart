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
  bool showAttachmentMenu = false;
  bool showEmojiPanel = false;

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
          showAttachmentMenu = false;
          showEmojiPanel = false;
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
    setState(() {
      showAttachmentMenu = !showAttachmentMenu;
      showEmojiPanel = false;
    });
  }

  void _showEmojiOptions() {
    setState(() {
      showEmojiPanel = !showEmojiPanel;
      showAttachmentMenu = false;
    });
  }

  void _insertEmoji(String emoji) {
    final currentPosition = _messageController.selection.base.offset;
    final text = _messageController.text;
    final newText = text.substring(0, currentPosition) + emoji + text.substring(currentPosition);
    _messageController.text = newText;
    _messageController.selection = TextSelection.fromPosition(
      TextPosition(offset: currentPosition + emoji.length),
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

  Widget _buildAttachmentMenu() {
    return GestureDetector(
      onTap: () {
        setState(() {
          showAttachmentMenu = false;
        });
      },
      child: Container(
        color: Colors.black.withOpacity(0.3),
        child: Column(
          children: [
            Expanded(child: Container()),
            Container(
              margin: EdgeInsets.only(bottom: 80),
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildAttachmentOption(
                        icon: Icons.photo,
                        label: context.l10n.gallery,
                        color: Color(0xFF2196F3),
                        onTap: () {
                          setState(() {
                            showAttachmentMenu = false;
                          });
                          _pickImage();
                        },
                      ),
                      _buildAttachmentOption(
                        icon: Icons.camera_alt,
                        label: context.l10n.camera,
                        color: Color(0xFF424242),
                        onTap: () {
                          setState(() {
                            showAttachmentMenu = false;
                          });
                          _takePhoto();
                        },
                      ),
                      _buildAttachmentOption(
                        icon: Icons.video_library,
                        label: context.l10n.videoGallery,
                        color: Color(0xFF4CAF50),
                        onTap: () {
                          setState(() {
                            showAttachmentMenu = false;
                          });
                          _pickVideo();
                        },
                      ),
                      _buildAttachmentOption(
                        icon: Icons.videocam,
                        label: context.l10n.recordVideo,
                        color: Color(0xFF757575),
                        onTap: () {
                          setState(() {
                            showAttachmentMenu = false;
                          });
                          _recordVideo();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 28,
            ),
          ),
          SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmojiPanel() {
    final List<String> emojis = [
      '😀', '😃', '😄', '😁', '😆', '😅', '😂', '🤣',
      '😊', '😇', '🙂', '🙃', '😉', '😌', '😍', '🥰',
      '😘', '😗', '😙', '😚', '😋', '😛', '😝', '😜',
      '🤪', '🤨', '🧐', '🤓', '😎', '🤩', '🥳', '😏',
      '😒', '😞', '😔', '😟', '😕', '🙁', '☹️', '😣',
      '😖', '😫', '😩', '🥺', '😢', '😭', '😤', '😠',
      '😡', '🤬', '🤯', '😳', '🥵', '🥶', '😱', '😨',
      '😰', '😥', '😓', '🤗', '🤔', '🤭', '🤫', '🤥',
      '😶', '😐', '😑', '😬', '🙄', '😯', '😦', '😧',
      '😮', '😲', '🥱', '😴', '🤤', '😪', '😵', '🤐',
      '🥴', '🤢', '🤮', '🤧', '😷', '🤒', '🤕', '🤑',
      '🤠', '😈', '👿', '👹', '👺', '🤡', '💩', '👻',
      '💀', '☠️', '👽', '👾', '🤖', '🎃', '😺', '😸',
    ];

    return Container(
      height: 350,
      color: Colors.white,
      child: Column(
        children: [
          Container(
            margin: EdgeInsets.symmetric(vertical: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 8,
                  childAspectRatio: 1.0,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4,
                ),
                itemCount: emojis.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () {
                      _insertEmoji(emojis[index]);
                    },
                    child: Container(
                      margin: EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          emojis[index],
                          style: TextStyle(fontSize: 20),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
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
            CircleAvatar(
              radius: 20,
              backgroundColor: Color(0xFF25D366),
              backgroundImage: widget.serviceProviderPhoto != null && widget.serviceProviderPhoto!.isNotEmpty
                  ? NetworkImage(widget.serviceProviderPhoto!)
                  : null,
              child: widget.serviceProviderPhoto == null || widget.serviceProviderPhoto!.isEmpty
                  ? Text(
                      widget.serviceProviderName.isNotEmpty ? widget.serviceProviderName[0].toUpperCase() : 'S',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    )
                  : null,
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
                            color: showAttachmentMenu || showEmojiPanel
                                ? Color(0xFFE5DDD5).withOpacity(0.7)
                                : Color(0xFFE5DDD5),
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
                        SafeArea(
                          child: Container(
                            color: Colors.white,
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            child: Row(
                              children: [
                                IconButton(
                                  icon: Icon(Icons.add, color: Colors.grey[600], size: 28),
                                  onPressed: isUploadingMedia ? null : _showMediaOptions,
                                ),
                                // Voice recording indication when recording
                                if (isRecording) ...[
                                  Expanded(
                                    child: Container(
                                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(25),
                                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 12,
                                            height: 12,
                                            decoration: BoxDecoration(
                                              color: Colors.red,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'Recording...',
                                            style: TextStyle(
                                              color: Colors.red,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Spacer(),
                                          Icon(Icons.graphic_eq, color: Colors.red),
                                        ],
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  CircleAvatar(
                                    backgroundColor: Colors.red,
                                    radius: 25,
                                    child: IconButton(
                                      icon: Icon(Icons.stop, color: Colors.white, size: 22),
                                      onPressed: _stopRecording,
                                    ),
                                  ),
                                ]
                                // Normal input field when not recording
                                else ...[
                                  Expanded(
                                    child: Container(
                                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        borderRadius: BorderRadius.circular(25),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: TextField(
                                              controller: _messageController,
                                              textAlign: TextAlign.right,
                                              textDirection: TextDirection.rtl,
                                              decoration: InputDecoration(
                                                hintText: 'הודעה',
                                                hintStyle: TextStyle(
                                                  color: Colors.grey[500],
                                                  fontSize: 16,
                                                ),
                                                border: InputBorder.none,
                                                contentPadding: EdgeInsets.zero,
                                              ),
                                              style: TextStyle(fontSize: 16),
                                              maxLines: null,
                                              textInputAction: TextInputAction.send,
                                              onSubmitted: (_) => _sendMessage(),
                                            ),
                                          ),
                                          Container(
                                            width: 24,
                                            height: 24,
                                            child: IconButton(
                                              icon: Icon(
                                                showEmojiPanel ? Icons.keyboard : Icons.description,
                                                color: Colors.grey[600],
                                                size: 20,
                                              ),
                                              onPressed: _showEmojiOptions,
                                              padding: EdgeInsets.zero,
                                              constraints: BoxConstraints(),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  CircleAvatar(
                                    backgroundColor: hasText ? Color(0xFF25D366) : Color(0xFF25D366),
                                    radius: 25,
                                    child: IconButton(
                                      icon: Icon(
                                        hasText ? Icons.send : Icons.mic,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                      onPressed: hasText
                                          ? (isSending || isUploadingMedia ? null : _sendMessage)
                                          : (isUploadingMedia || isRecording ? null : _startRecording),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        if (showEmojiPanel)
                          SafeArea(
                            top: false,
                            child: _buildEmojiPanel(),
                          ),
                      ],
                    ),
                    if (showAttachmentMenu) _buildAttachmentMenu(),
                  ],
                ),
    );
  }
}