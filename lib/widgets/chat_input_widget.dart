import 'package:beresheet_app/services/modern_localization_service.dart';
import 'package:beresheet_app/services/user_session_service.dart';
import 'package:beresheet_app/config/app_config.dart';
import 'package:beresheet_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

enum ChatInputType {
  community, // For homepage community chat
  serviceRequest, // For service request conversations
}

class ChatInputWidget extends StatefulWidget {
  final ChatInputType inputType;
  final String? requestId; // Required for service request type
  final String? serviceProviderId; // Required for service request type
  final Function(Map<String, dynamic>)? onMessageSent; // Callback when message is sent
  final bool isExpandable; // Whether the widget can expand to show messages
  final List<Map<String, dynamic>>? initialMessages; // Initial messages to display

  const ChatInputWidget({
    Key? key,
    required this.inputType,
    this.requestId,
    this.serviceProviderId,
    this.onMessageSent,
    this.isExpandable = true,
    this.initialMessages,
  }) : super(key: key);

  @override
  State<ChatInputWidget> createState() => _ChatInputWidgetState();
}

class _ChatInputWidgetState extends State<ChatInputWidget>
    with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  late AnimationController _animationController;
  late Animation<double> _animation;
  
  List<Map<String, dynamic>> messages = [];
  bool isExpanded = false;
  bool isSendingMessage = false;
  bool isRecording = false;
  bool isUploadingMedia = false;
  bool hasText = false;
  bool showAttachmentMenu = false;
  bool showEmojiPanel = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _messageController.addListener(_onTextChanged);
    
    if (widget.initialMessages != null) {
      messages = List.from(widget.initialMessages!);
    }
    
    if (widget.inputType == ChatInputType.community) {
      _loadRecentMessages();
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _animationController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {
      hasText = _messageController.text.trim().isNotEmpty;
    });
  }

  void _toggleExpansion() {
    if (!widget.isExpandable) return;
    
    setState(() {
      isExpanded = !isExpanded;
      if (isExpanded) {
        _animationController.forward();
        if (widget.inputType == ChatInputType.community) {
          _loadRecentMessages();
        }
      } else {
        _animationController.reverse();
      }
    });
  }

  Future<void> _loadRecentMessages() async {
    if (widget.inputType != ChatInputType.community) return;
    
    try {
      final homeId = await UserSessionService.gethomeID();
      final userId = await UserSessionService.getUserId();
      
      if (homeId == null || userId == null) return;

      final response = await http.get(
        Uri.parse('${AppConfig.apiUrlWithPrefix}/api/chat/messages/recent?limit=5'),
        headers: {
          'Content-Type': 'application/json',
          'homeID': homeId.toString(),
          'userId': userId,
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> messageData = json.decode(response.body);
        setState(() {
          messages = messageData.cast<Map<String, dynamic>>();
        });
      }
    } catch (e) {
      print('Error loading recent messages: $e');
    }
  }

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty || isSendingMessage) return;
    
    setState(() {
      isSendingMessage = true;
    });

    try {
      final homeId = await UserSessionService.gethomeID();
      final userId = await UserSessionService.getUserId();
      
      if (homeId == null || userId == null) {
        throw Exception('User not logged in');
      }

      Map<String, dynamic> newMessage;
      
      if (widget.inputType == ChatInputType.community) {
        // Send to community chat API
        final response = await http.post(
          Uri.parse('${AppConfig.apiUrlWithPrefix}/api/chat/messages'),
          headers: {
            'Content-Type': 'application/json',
            'homeID': homeId.toString(),
            'userId': userId,
          },
          body: json.encode({
            'message': messageText,
          }),
        );

        if (response.statusCode == 201) {
          newMessage = json.decode(response.body);
        } else {
          throw Exception('Failed to send message: ${response.statusCode}');
        }
      } else {
        // Send to service request chat API
        if (widget.requestId == null) {
          throw Exception('Request ID is required for service request messages');
        }
        
        final response = await http.post(
          Uri.parse('${AppConfig.apiUrlWithPrefix}/api/requests/${widget.requestId}/chat'),
          headers: {
            'Content-Type': 'application/json',
            'homeID': homeId.toString(),
            'userId': userId,
          },
          body: json.encode({
            'message': messageText,
          }),
        );

        if (response.statusCode == 200) {
          // For service requests, we get the full request back, extract the new message
          final requestData = json.decode(response.body);
          final chatMessages = requestData['chat_messages'] as List<dynamic>;
          newMessage = chatMessages.last; // Get the last (newest) message
        } else {
          throw Exception('Failed to send message: ${response.statusCode}');
        }
      }
      
      setState(() {
        messages.insert(0, newMessage); // Add to beginning (newest first)
        _messageController.clear();
        isSendingMessage = false;
      });

      // Call the callback if provided
      if (widget.onMessageSent != null) {
        widget.onMessageSent!(newMessage);
      }
      
    } catch (e) {
      setState(() {
        isSendingMessage = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending message: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildChatMessage(Map<String, dynamic> message) {
    final isCurrentUser = widget.inputType == ChatInputType.community 
        ? message['user_id'] == 'current_user' // TODO: Get actual current user ID
        : message['sender_type'] == 'resident';
    final messageText = message['message'] ?? '';
    final userName = message['user_name'] ?? message['sender_type'] ?? 'Unknown';
    final timestamp = message['timestamp'];
    final mediaType = message['media_type'];
    final mediaUrl = message['media_url'];

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isCurrentUser) SizedBox(width: 50),
          Flexible(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 8),
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isCurrentUser ? Color(0xFFDCF8C6) : Colors.white,
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
                  if (!isCurrentUser && widget.inputType == ChatInputType.community)
                    Text(
                      userName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
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
                          Icon(Icons.audiotrack, color: Colors.black87),
                          const SizedBox(width: 8),
                          Text(
                            context.l10n.audioMessage,
                            style: TextStyle(color: Colors.black87),
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
                        color: Colors.black87,
                      ),
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
                      if (isCurrentUser) ...[
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
          if (isCurrentUser) SizedBox(width: 50),
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
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'Now';
      }
    } catch (e) {
      return '';
    }
  }

  Future<void> _sendMediaMessage(String mediaPath, String mediaType) async {
    setState(() {
      isUploadingMedia = true;
    });

    try {
      final homeId = await UserSessionService.gethomeID();
      final userId = await UserSessionService.getUserId();
      
      if (homeId == null || userId == null) {
        throw Exception('User not logged in');
      }

      final file = File(mediaPath);
      final fileName = file.path.split('/').last;
      
      String uploadUrl;
      Map<String, String> fields = {};
      
      if (widget.inputType == ChatInputType.community) {
        uploadUrl = '${AppConfig.apiUrlWithPrefix}/api/chat/upload-media';
        fields['message'] = 'Media message';
      } else {
        uploadUrl = '${AppConfig.apiUrlWithPrefix}/api/requests/upload-media';
        fields['message_id'] = DateTime.now().millisecondsSinceEpoch.toString();
        fields['service_provider_id'] = widget.serviceProviderId ?? '';
        fields['request_message'] = 'Media message';
        if (widget.requestId != null) {
          fields['request_id'] = widget.requestId!;
        }
      }

      final request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
      request.headers.addAll({
        'homeID': homeId.toString(),
        'userId': userId,
      });
      
      request.fields.addAll(fields);
      request.files.add(await http.MultipartFile.fromPath('file', mediaPath));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        
        // Add the media message to local messages
        Map<String, dynamic> newMessage;
        if (widget.inputType == ChatInputType.community) {
          newMessage = responseData['message'];
        } else {
          // For service requests, extract from the response
          newMessage = {
            'message_id': responseData['message_id'],
            'sender_type': 'resident',
            'message': 'Media message',
            'media_type': mediaType,
            'media_url': responseData['media_url'],
            'timestamp': DateTime.now().toIso8601String(),
          };
        }
        
        setState(() {
          messages.insert(0, newMessage);
          isUploadingMedia = false;
        });

        if (widget.onMessageSent != null) {
          widget.onMessageSent!(newMessage);
        }
      } else {
        throw Exception('Failed to upload media: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        isUploadingMedia = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading media: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showMediaOptions() {
    try {
      setState(() {
        showAttachmentMenu = !showAttachmentMenu;
        showEmojiPanel = false;
      });
    } catch (e) {
      print('Error showing media options: $e');
    }
  }

  void _showEmojiOptions() {
    try {
      setState(() {
        showEmojiPanel = !showEmojiPanel;
        showAttachmentMenu = false;
      });
    } catch (e) {
      print('Error showing emoji options: $e');
    }
  }

  Future<void> _startRecording() async {
    try {
      // Check if context is still mounted
      if (!mounted) return;
      
      if (await _audioRecorder.hasPermission()) {
        setState(() {
          isRecording = true;
          showAttachmentMenu = false;
          showEmojiPanel = false;
        });
        
        final tempDir = await getTemporaryDirectory();
        final String path = '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.aac';
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Microphone permission required'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error starting recording: $e');
      if (mounted) {
        setState(() {
          isRecording = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting recording'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      if (mounted) {
        setState(() {
          isRecording = false;
        });
        
        if (path != null && path.isNotEmpty) {
          await _sendMediaMessage(path, 'audio');
        }
      }
    } catch (e) {
      print('Error stopping recording: $e');
      if (mounted) {
        setState(() {
          isRecording = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error stopping recording'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (image != null && mounted) {
        await _sendMediaMessage(image.path, 'image');
      }
    } catch (e) {
      print('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
      
      if (image != null && mounted) {
        await _sendMediaMessage(image.path, 'image');
      }
    } catch (e) {
      print('Error taking photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error taking photo'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickVideo() async {
    try {
      final XFile? video = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 30),
      );
      
      if (video != null && mounted) {
        await _sendMediaMessage(video.path, 'video');
      }
    } catch (e) {
      print('Error picking video: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking video'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _recordVideo() async {
    try {
      final XFile? video = await _imagePicker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(seconds: 15),
      );
      
      if (video != null && mounted) {
        await _sendMediaMessage(video.path, 'video');
      }
    } catch (e) {
      print('Error recording video: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error recording video'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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

  Widget _buildAttachmentMenu() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: EdgeInsets.zero, // No margin - directly adjacent to text field
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, -1),
          ),
        ],
      ),
      child: Row(
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

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final screenHeight = MediaQuery.of(context).size.height;
    final collapsedHeight = 144.0;
    final chatMessagesHeight = screenHeight * 0.5; // 50% of screen height
    
    return Stack(
      children: [
        // Chat Messages Overlay (when expanded) - positioned above the fixed chat widget
        if (widget.isExpandable && isExpanded)
          Positioned(
            left: 0,
            right: 0,
            bottom: collapsedHeight + bottomPadding, // Position above the chat widget
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, (1 - _animation.value) * chatMessagesHeight),
                  child: Container(
                    height: chatMessagesHeight,
                    margin: EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Color(0xFFE5DDD5),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: Offset(0, -5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Handle bar at the top
                        Container(
                          margin: EdgeInsets.symmetric(vertical: 8),
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[400],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        // Messages area
                        Expanded(
                          child: messages.isEmpty
                              ? Center(
                                  child: Text(
                                    widget.inputType == ChatInputType.community
                                        ? 'Start a conversation with your community'
                                        : 'Send message to ${widget.serviceProviderId ?? 'Service Provider'}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 16,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              : ListView.builder(
                                  reverse: true,
                                  padding: EdgeInsets.all(8),
                                  itemCount: messages.length > 10 ? 10 : messages.length, // Show more messages in larger area
                                  itemBuilder: (context, index) {
                                    return _buildChatMessage(messages[index]);
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        
        // Fixed Chat Widget (always stays at the bottom)
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            height: showAttachmentMenu
                ? collapsedHeight + bottomPadding + 50
                : collapsedHeight + bottomPadding,
            padding: EdgeInsets.only(bottom: bottomPadding),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Expand/Collapse Toggle (only show if expandable)
                if (widget.isExpandable)
                  GestureDetector(
                    onTap: _toggleExpansion,
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0,
                        duration: Duration(milliseconds: 300),
                        child: Icon(
                          Icons.keyboard_arrow_up,
                          size: 24,
                          color: Colors.grey[600],
                        ),
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
                        Text('Uploading media...'),
                      ],
                    ),
                  ),
              
              // Attachment Menu (show above text field when open)
              if (showAttachmentMenu)
                _buildAttachmentMenu(),
              
              // Chat Input Area
              Container(
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
                                    showEmojiPanel ? Icons.keyboard : Icons.sentiment_satisfied,
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
                              ? (isSendingMessage || isUploadingMedia ? null : _sendMessage)
                              : (isUploadingMedia || isRecording ? null : _startRecording),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (showEmojiPanel)
                _buildEmojiPanel(),
            ],
          ),
        ),
        ),
      ],
    );
  }
}