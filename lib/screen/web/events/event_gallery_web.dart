import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../config/app_config.dart';
import '../../../services/web/web_jwt_auth_service.dart';
import '../../../services/web_image_cache_service.dart';
import '../../../model/event.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http_parser/http_parser.dart';

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
    required this.status,
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

class EventGalleryWeb extends StatefulWidget {
  final Event event;

  const EventGalleryWeb({Key? key, required this.event}) : super(key: key);

  @override
  State<EventGalleryWeb> createState() => _EventGalleryWebState();
}

class _EventGalleryWebState extends State<EventGalleryWeb> {
  List<EventGalleryPhoto> _galleryPhotos = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isUploading = false;

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
      final response = await http.get(
        Uri.parse('${AppConfig.apiUrlWithPrefix}/api/events/${widget.event.id}/gallery'),
        headers: await WebJwtAuthService.getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> photosData = json.decode(response.body);
        setState(() {
          _galleryPhotos = photosData.map((data) => EventGalleryPhoto.fromJson(data)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = '${AppLocalizations.of(context)!.failedToLoadGalleryPhotos}: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '${AppLocalizations.of(context)!.errorLoadingGalleryPhotos}: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _uploadImages() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png'],
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        // Limit to 3 files maximum
        final filesToUpload = result.files.take(3).toList();
        
        if (result.files.length > 3) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.maximumImagesAllowed),
              backgroundColor: Colors.orange,
            ),
          );
        }
        
        await _performUpload(filesToUpload);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppLocalizations.of(context)!.errorSelectingFiles}: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _performUpload(List<PlatformFile> files) async {
    setState(() {
      _isUploading = true;
    });

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConfig.apiUrlWithPrefix}/api/events/${widget.event.id}/gallery'),
      );

      // Add headers
      final authHeaders = await WebJwtAuthService.getAuthHeaders();
      request.headers.addAll(authHeaders);

      // Add files
      for (int i = 0; i < files.length; i++) {
        final file = files[i];
        
        if (file.bytes != null) {
          // Determine content type based on file extension
          String mimeType = 'image/jpeg';
          if (file.name.toLowerCase().endsWith('.png')) {
            mimeType = 'image/png';
          } else if (file.name.toLowerCase().endsWith('.jpg') || file.name.toLowerCase().endsWith('.jpeg')) {
            mimeType = 'image/jpeg';
          }
          
          request.files.add(
            http.MultipartFile.fromBytes(
              'images',
              file.bytes!,
              filename: file.name,
              contentType: MediaType.parse(mimeType),
            ),
          );
        }
      }

      final response = await request.send();

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.imagesUploadedSuccessfully),
            backgroundColor: Colors.green,
          ),
        );
        await _loadGalleryPhotos(); // Refresh the gallery
      } else {
        final responseBody = await response.stream.bytesToString();
        String errorMessage = AppLocalizations.of(context)!.failedToUploadImages;
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
          content: Text('${AppLocalizations.of(context)!.errorUploadingImages}: $e'),
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
          title: Text(AppLocalizations.of(context)!.deletePhoto),
          content: Text(AppLocalizations.of(context)!.areYouSureDeletePhoto),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text(AppLocalizations.of(context)!.delete, style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        final response = await http.delete(
          Uri.parse('${AppConfig.apiUrlWithPrefix}/api/events/${widget.event.id}/gallery/${photo.photoId}'),
          headers: await WebJwtAuthService.getAuthHeaders(),
        );

        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.photoDeletedSuccessfully),
              backgroundColor: Colors.green,
            ),
          );
          await _loadGalleryPhotos(); // Refresh the gallery
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${AppLocalizations.of(context)!.failedToDeletePhoto}: ${response.statusCode}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.of(context)!.errorDeletingPhoto}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _approvePhoto(EventGalleryPhoto photo) async {
    try {
      final authHeaders = await WebJwtAuthService.getAuthHeaders();
      
      final response = await http.put(
        Uri.parse('${AppConfig.apiUrlWithPrefix}/api/events/${widget.event.id}/gallery/${photo.photoId}/approve'),
        headers: {
          ...authHeaders,
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.photoApprovedSuccessfully),
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

  void _showFullSizeImage(int initialIndex) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return _FullSizeImageViewer(
          photos: _galleryPhotos,
          initialIndex: initialIndex,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.event.name} - ${AppLocalizations.of(context)!.gallery}'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          if (!_isUploading)
            ElevatedButton.icon(
              onPressed: _uploadImages,
              icon: Icon(Icons.add_photo_alternate),
              label: Text(AppLocalizations.of(context)!.uploadImagesMax3),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          if (_isUploading)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
          SizedBox(width: 16),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event Info Header
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(Icons.event, size: 24, color: Colors.blue),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.event.name,
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '${widget.event.location} • ${_formatDateTime(widget.event.date_time)}',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      AppLocalizations.of(context)!.photoCount(_galleryPhotos.length),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24),

            // Gallery Grid
            Expanded(
              child: _buildGalleryGrid(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGalleryGrid() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red),
            SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.error,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(_errorMessage!),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadGalleryPhotos,
              child: Text(AppLocalizations.of(context)!.retry),
            ),
          ],
        ),
      );
    }

    if (_galleryPhotos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.noPhotosYet,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(AppLocalizations.of(context)!.uploadSomePhotos),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _uploadImages,
              icon: Icon(Icons.add_photo_alternate),
              label: Text(AppLocalizations.of(context)!.uploadImages),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _calculateCrossAxisCount(),
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.0,
      ),
      itemCount: _galleryPhotos.length,
      itemBuilder: (context, index) {
        final photo = _galleryPhotos[index];
        return _buildGalleryTile(photo, index);
      },
    );
  }

  int _calculateCrossAxisCount() {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 1200) return 4;
    if (screenWidth > 800) return 3;
    return 2;
  }

  Widget _buildGalleryTile(EventGalleryPhoto photo, int index) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Stack(
        children: [
          // Main clickable area (excludes action buttons area)
          Positioned.fill(
            child: InkWell(
              onTap: () => _showFullSizeImage(index),
              borderRadius: BorderRadius.circular(12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  child: WebImageCacheService.buildEventImage(
                    imageUrl: photo.thumbnailUrl ?? photo.photo,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: Container(
                      color: Colors.grey[100],
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    errorWidget: Container(
                      color: Colors.grey[100],
                      child: const Icon(
                        Icons.image_not_supported,
                        color: Colors.grey,
                        size: 40,
                      ),
                    ),
                  ),
                ),
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
                  AppLocalizations.of(context)!.privatePhotoStatus,
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
                // Approve button (for private photos)
                if (photo.status == 'private')
                  Container(
                    margin: EdgeInsets.only(bottom: 4),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _approvePhoto(photo),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                
                // Delete button (for all images in web)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _deletePhoto(photo),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.delete,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // View icon overlay
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black26,
                    ],
                  ),
                ),
                child: Center(
                  child: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.zoom_in,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime date_time) {
    return '${date_time.day}/${date_time.month}/${date_time.year} ${date_time.hour}:${date_time.minute.toString().padLeft(2, '0')}';
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
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          // Image viewer
          PageView.builder(
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
                  child: WebImageCacheService.buildEventImage(
                    imageUrl: photo.photo,
                    fit: BoxFit.contain,
                    placeholder: const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                      ),
                    ),
                    errorWidget: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error, color: Colors.white, size: 64),
                          const SizedBox(height: 16),
                          Text(
                            AppLocalizations.of(context)!.failedToLoadImage,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // Close button
          Positioned(
            top: 40,
            right: 40,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(30),
              ),
              child: IconButton(
                icon: Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.of(context).pop(),
                padding: EdgeInsets.all(12),
              ),
            ),
          ),

          // Navigation arrows
          if (widget.photos.length > 1) ...[
            // Left arrow
            if (_currentIndex > 0)
              Positioned(
                left: 40,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.arrow_back_ios, color: Colors.white, size: 30),
                      onPressed: () {
                        _pageController.previousPage(
                          duration: Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      padding: EdgeInsets.all(12),
                    ),
                  ),
                ),
              ),

            // Right arrow
            if (_currentIndex < widget.photos.length - 1)
              Positioned(
                right: 40,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 30),
                      onPressed: () {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                ),
              ),
          ],

          // Image counter
          if (widget.photos.length > 1)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_currentIndex + 1} / ${widget.photos.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
