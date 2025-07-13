import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../../config/app_config.dart';
import '../../../services/user_session_service.dart';
import '../../../model/event.dart';
import '../../../services/modern_localization_service.dart';
import '../../../widgets/localized_date_time_widget.dart';

class EventGalleryPhoto {
  final String photoId;
  final String eventId;
  final String photo;
  final String? thumbnailUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;
  final String status;

  EventGalleryPhoto({
    required this.photoId,
    required this.eventId,
    required this.photo,
    this.thumbnailUrl,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.status = 'private',
  });

  factory EventGalleryPhoto.fromJson(Map<String, dynamic> json) {
    return EventGalleryPhoto(
      photoId: json['photo_id'] ?? '',
      eventId: json['event_id'] ?? '',
      photo: json['photo'] ?? '',
      thumbnailUrl: json['thumbnail_url'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      createdBy: json['created_by'],
      status: json['status'] ?? 'private',
    );
  }
}

class EventGalleryScreen extends StatefulWidget {
  final Event event;

  const EventGalleryScreen({Key? key, required this.event}) : super(key: key);

  @override
  State<EventGalleryScreen> createState() => _EventGalleryScreenState();
}

class _EventGalleryScreenState extends State<EventGalleryScreen> {
  List<EventGalleryPhoto> _galleryPhotos = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadGalleryPhotos();
  }

  Future<void> _loadGalleryPhotos() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final homeId = await UserSessionService.gethomeID();
      final userId = await UserSessionService.getUserId();

      if (homeId == null || userId == null) {
        setState(() {
          _errorMessage = context.l10n.userSessionNotFound;
          _isLoading = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse('${AppConfig.apiUrlWithPrefix}/api/events/${widget.event.id}/gallery'),
        headers: {
          'Content-Type': 'application/json',
          'homeID': homeId.toString(),
          'userId': userId,
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> photosData = json.decode(response.body);
        setState(() {
          _galleryPhotos = photosData.map((data) => EventGalleryPhoto.fromJson(data)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load gallery photos: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading gallery photos: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _uploadImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (images.isNotEmpty) {
        // Limit to 3 images maximum
        final imagesToUpload = images.take(3).toList();
        
        if (images.length > 3) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.maximumImagesAllowed),
              backgroundColor: Colors.orange,
            ),
          );
        }
        
        await _performUpload(imagesToUpload);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.errorSelectingImages(e.toString())),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _performUpload(List<XFile> images) async {
    setState(() {
      _isUploading = true;
    });

    try {
      final homeId = await UserSessionService.gethomeID();
      final userId = await UserSessionService.getUserId();

      if (homeId == null || userId == null) {
        throw Exception('User session not found');
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConfig.apiUrlWithPrefix}/api/events/${widget.event.id}/gallery'),
      );

      // Add headers
      request.headers.addAll({
        'homeID': homeId.toString(),
        'userId': userId,
      });

      // Add files
      for (final image in images) {
        final file = await http.MultipartFile.fromPath(
          'images',
          image.path,
          filename: image.name,
        );
        request.files.add(file);
      }

      final response = await request.send();

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.operationSuccessful),
            backgroundColor: Colors.green,
          ),
        );
        await _loadGalleryPhotos(); // Refresh the gallery
      } else {
        final responseBody = await response.stream.bytesToString();
        String errorMessage = 'Failed to upload images';
        try {
          final errorData = json.decode(responseBody);
          errorMessage = errorData['detail'] ?? errorMessage;
        } catch (e) {
          // Use default error message
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$errorMessage (Status: ${response.statusCode})'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading images: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  Future<void> _deletePhoto(EventGalleryPhoto photo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(context.l10n.deletePhoto),
          content: Text(context.l10n.areYouSureDeletePhoto),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text(context.l10n.delete, style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        final homeId = await UserSessionService.gethomeID();
        final userId = await UserSessionService.getUserId();

        if (homeId == null || userId == null) {
          throw Exception('User session not found');
        }

        final response = await http.delete(
          Uri.parse('${AppConfig.apiUrlWithPrefix}/api/events/${widget.event.id}/gallery/${photo.photoId}'),
          headers: {
            'Content-Type': 'application/json',
            'homeID': homeId.toString(),
            'userId': userId,
          },
        );

        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.operationSuccessful),
              backgroundColor: Colors.green,
            ),
          );
          await _loadGalleryPhotos(); // Refresh the gallery
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete photo: ${response.statusCode}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _approvePhoto(EventGalleryPhoto photo) async {
    try {
      final homeId = await UserSessionService.gethomeID();
      final userId = await UserSessionService.getUserId();

      if (homeId == null || userId == null) {
        throw Exception('User session not found');
      }

      final response = await http.put(
        Uri.parse('${AppConfig.apiUrlWithPrefix}/api/events/${widget.event.id}/gallery/${photo.photoId}/approve'),
        headers: {
          'Content-Type': 'application/json',
          'homeID': homeId.toString(),
          'currentUserId': userId,
        },
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.operationSuccessful),
            backgroundColor: Colors.green,
          ),
        );
        await _loadGalleryPhotos(); // Refresh the gallery
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to approve photo: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error approving photo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<bool> _canDeletePhoto(EventGalleryPhoto photo) async {
    final userId = await UserSessionService.getUserId();
    final userRole = await UserSessionService.getRole();
    
    if (userRole == 'manager' || userRole == 'staff') {
      return true; // Managers and staff can delete all images
    }
    
    // Regular users can only delete their own private images
    return photo.status == 'private' && photo.createdBy == userId;
  }

  Future<bool> _canApprovePhoto(EventGalleryPhoto photo) async {
    final userRole = await UserSessionService.getRole();
    
    // Only managers and staff can approve photos, and only private photos
    return (userRole == 'manager' || userRole == 'staff') && photo.status == 'private';
  }

  void _showFullSizeImage(int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _FullSizeImageViewer(
          photos: _galleryPhotos,
          initialIndex: initialIndex,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.event.name} - ${context.l10n.gallery}'),
        backgroundColor: theme.colorScheme.primary,
        titleTextStyle: TextStyle(
          color: theme.colorScheme.onPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: theme.colorScheme.onPrimary),
        actions: [
          if (!_isUploading)
            IconButton(
              onPressed: _uploadImages,
              icon: Icon(Icons.add_photo_alternate),
              tooltip: context.l10n.uploadImagesMax3,
            ),
          if (_isUploading)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.onPrimary),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Event Info Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            color: theme.colorScheme.surface,
            child: Row(
              children: [
                Icon(Icons.event, color: theme.colorScheme.primary),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.event.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            widget.event.location,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            ' • ',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                          Expanded(
                            child: LocalizedDateTimeWidget(
                              dateTime: widget.event.date_time,
                              size: DateTimeDisplaySize.large,
                              textColor: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.colorScheme.primary),
                  ),
                  child: Text(
                    context.l10n.photoCount(_galleryPhotos.length),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Gallery Grid
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadGalleryPhotos,
              child: _buildGalleryGrid(),
            ),
          ),
        ],
      ),
      floatingActionButton: _isUploading ? null : FloatingActionButton(
        onPressed: _uploadImages,
        backgroundColor: theme.colorScheme.secondary,
        child: Icon(Icons.add_photo_alternate, color: theme.colorScheme.onSecondary),
        tooltip: context.l10n.uploadImages,
      ),
    );
  }

  Widget _buildGalleryGrid() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text(
                    context.l10n.error,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadGalleryPhotos,
                    child: Text(context.l10n.retry),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_galleryPhotos.isEmpty) {
      return SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    context.l10n.noPhotosYet,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    context.l10n.uploadSomePhotos,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  SizedBox(height: 16),
                  Center(
                    child: SizedBox(
                      child: ElevatedButton(
                        onPressed: _uploadImages,
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate),
                            SizedBox(width: 8),
                            Text(
                              context.l10n.uploadImages,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1.0,
        ),
        itemCount: _galleryPhotos.length,
        itemBuilder: (context, index) {
          final photo = _galleryPhotos[index];
          return _buildGalleryTile(photo, index);
        },
      ),
    );
  }

  Widget _buildGalleryTile(EventGalleryPhoto photo, int index) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showFullSizeImage(index),
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // Image
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                height: double.infinity,
                child: Image.network(
                  photo.thumbnailUrl ?? photo.photo,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: Colors.grey[100],
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[100],
                      child: Icon(
                        Icons.image_not_supported,
                        color: Colors.grey,
                        size: 40,
                      ),
                    );
                  },
                ),
              ),
            ),
            
            // Status indicator for private photos
            if (photo.status == 'private')
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    context.l10n.privatePhotoStatus,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            
            // Action buttons overlay
            Positioned(
              top: 8,
              right: 8,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Approve button (for managers/staff on private photos)
                  FutureBuilder<bool>(
                    future: _canApprovePhoto(photo),
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data == true) {
                        return Container(
                          margin: EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: IconButton(
                            icon: Icon(Icons.check, color: Colors.white, size: 18),
                            onPressed: () => _approvePhoto(photo),
                            padding: EdgeInsets.all(4),
                            constraints: BoxConstraints(minWidth: 28, minHeight: 28),
                            tooltip: 'Approve photo',
                          ),
                        );
                      }
                      return SizedBox.shrink();
                    },
                  ),
                  
                  // Delete button (conditional based on user permissions)
                  FutureBuilder<bool>(
                    future: _canDeletePhoto(photo),
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data == true) {
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: IconButton(
                            icon: Icon(Icons.delete, color: Colors.white, size: 18),
                            onPressed: () => _deletePhoto(photo),
                            padding: EdgeInsets.all(4),
                            constraints: BoxConstraints(minWidth: 28, minHeight: 28),
                            tooltip: 'Delete photo',
                          ),
                        );
                      }
                      return SizedBox.shrink();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime date_time) {
    return '${date_time.day}/${date_time.month}/${date_time.year}';
  }
}

class _FullSizeImageViewer extends StatefulWidget {
  final List<EventGalleryPhoto> photos;
  final int initialIndex;

  const _FullSizeImageViewer({
    required this.photos,
    required this.initialIndex,
  });

  @override
  State<_FullSizeImageViewer> createState() => _FullSizeImageViewerState();
}

class _FullSizeImageViewerState extends State<_FullSizeImageViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        title: widget.photos.length > 1 
            ? Text(
                '${_currentIndex + 1} / ${widget.photos.length}',
                style: TextStyle(color: Colors.white),
              )
            : null,
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.photos.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (context, index) {
          final photo = widget.photos[index];
          return Center(
            child: InteractiveViewer(
              child: Image.network(
                photo.photo,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                          : null,
                      color: Colors.white,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error, color: Colors.white, size: 64),
                        SizedBox(height: 16),
                        Text(
                          context.l10n.failedToLoadImage,
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
