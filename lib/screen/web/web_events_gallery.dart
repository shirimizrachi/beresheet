import 'package:flutter/material.dart';
import 'dart:async';
import 'package:beresheet_app/model/event.dart';
import 'package:beresheet_app/services/event_service.dart';
import 'package:beresheet_app/services/web_image_cache_service.dart';
import 'package:beresheet_app/theme/app_theme.dart';
import 'package:beresheet_app/widgets/localized_date_time_widget.dart';
import 'package:beresheet_app/utils/display_name_utils.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class WebEventsGallery extends StatefulWidget {
  const WebEventsGallery({Key? key}) : super(key: key);

  @override
  State<WebEventsGallery> createState() => _WebEventsGalleryState();
}

class _WebEventsGalleryState extends State<WebEventsGallery> {
  List<Event> events = [];
  bool isLoading = true;
  int _currentSlide = 0;
  Map<String, int> _galleryImageStartIndex = {};
  PageController? _pageController;
  Timer? _autoSlideTimer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    loadEvents();
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _pageController?.dispose();
    super.dispose();
  }

  void _nextSlide() {
    if (events.isEmpty || _pageController == null) return;
    final nextIndex = (_currentSlide + 1) % events.length;
    _pageController!.animateToPage(
      nextIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _previousSlide() {
    if (events.isEmpty || _pageController == null) return;
    final prevIndex = (_currentSlide - 1 + events.length) % events.length;
    _pageController!.animateToPage(
      prevIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onPageChanged(int index) {
    _currentSlide = index;
  }

  void _startAutoSlide() {
    if (events.isEmpty || _pageController == null) return;
    
    _autoSlideTimer?.cancel();
    _autoSlideTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_pageController != null && events.isNotEmpty) {
        final nextIndex = (_currentSlide + 1) % events.length;
        _pageController!.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _goToSlide(int index) {
    if (_pageController != null && events.isNotEmpty) {
      _pageController!.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> loadEvents() async {
    try {
      // Load events with gallery photos
      final loadedEvents = await EventService.loadEventsWithGallery();
      
      setState(() {
        events = loadedEvents;
        isLoading = false;
        _currentSlide = 0;
        // Initialize gallery image indices for each event
        for (final event in events) {
          if (!_galleryImageStartIndex.containsKey(event.id)) {
            _galleryImageStartIndex[event.id] = 0;
          }
        }
      });
      
      // Preload gallery images
      await _preloadGalleryImages();
      
      // Start auto-slide after loading events
      if (events.isNotEmpty) {
        Future.delayed(const Duration(seconds: 1), () {
          _startAutoSlide();
        });
      }
    } catch (e) {
      print('Error loading gallery events: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  /// Preload gallery images for better performance
  Future<void> _preloadGalleryImages() async {
    if (!mounted || events.isEmpty) return;
    
    final Set<String> imagesToPreload = {};
    
    // Collect all gallery image URLs
    for (final event in events) {
      // Main event image
      if (event.imageUrl.isNotEmpty) {
        imagesToPreload.add(event.imageUrl);
      }
      
      // Gallery photos (both thumbnail and full size URLs)
      for (final photo in event.gallery_photos) {
        if (photo['thumbnail_url'] != null && photo['thumbnail_url'].toString().isNotEmpty) {
          imagesToPreload.add(photo['thumbnail_url'].toString());
        }
        if (photo['image_url'] != null && photo['image_url'].toString().isNotEmpty) {
          imagesToPreload.add(photo['image_url'].toString());
        }
      }
    }
    
    // Preload all unique images using carousel optimization
    await WebImageCacheService.preloadImagesForCarousel(context, imagesToPreload.toList());
    
    if (mounted) {
      print('Successfully preloaded all gallery images');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Events Gallery',
          style: AppTextStyles.heading2.copyWith(color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : events.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.photo_library_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'No gallery events available',
                        style: AppTextStyles.heading3.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Gallery Display
                    Expanded(
                      child: _buildGalleryView(),
                    ),
                    
                    // Carousel Indicators
                    if (events.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.lg),
                      _buildCarouselIndicators(),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    
                    // Navigation Controls
                    if (events.length > 1) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: _previousSlide,
                            icon: const Icon(Icons.arrow_back_ios),
                            iconSize: 32,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: AppSpacing.xl),
                          IconButton(
                            onPressed: _nextSlide,
                            icon: const Icon(Icons.arrow_forward_ios),
                            iconSize: 32,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                  ],
                ),
    );
  }

  Widget _buildGalleryView() {
    return SizedBox(
      height: 700,
      child: PageView.builder(
        controller: _pageController,
        itemCount: events.length,
        onPageChanged: _onPageChanged,
        itemBuilder: (context, index) {
          return _buildGalleryCard(events[index]);
        },
      ),
    );
  }

  Widget _buildGalleryCard(Event event) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.large),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppBorderRadius.large),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Colors.grey[50]!,
              ],
            ),
          ),
          child: Row(
            children: [
              // Left side: Event Details
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Event Type Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          DisplayNameUtils.getEventTypeDisplayName(event.type, context),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Event Name
                      Text(
                        event.name,
                        style: AppTextStyles.heading2.copyWith(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      
                      // Event Description
                      Text(
                        event.description,
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontSize: 24,
                          color: Colors.grey[700],
                          height: 1.5,
                        ),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      
                      // Event Date and Time
                      LocalizedDateTimeWidget(
                        dateTime: event.next_date_time,
                        size: DateTimeDisplaySize.large,
                        textColor: Theme.of(context).primaryColor,
                      ),
                    ],
                  ),
                ),
              ),
              
              // Right side: Gallery Grid
              Expanded(
                flex: 3,
                child: _buildGalleryGrid(event),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGalleryGrid(Event event) {
    if (event.gallery_photos.isEmpty) {
      return Container(
        margin: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(AppBorderRadius.medium),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.photo_library_outlined,
                size: 64,
                color: Colors.grey,
              ),
              SizedBox(height: AppSpacing.md),
              Text(
                'No gallery photos available',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final startIndex = _galleryImageStartIndex[event.id] ?? 0;
    final photosToShow = <Map<String, dynamic>>[];
    
    for (int i = 0; i < 6 && i < event.gallery_photos.length; i++) {
      final index = (startIndex + i) % event.gallery_photos.length;
      photosToShow.add(event.gallery_photos[index]);
    }

    return Container(
      margin: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Expanded(
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: AppSpacing.sm,
                mainAxisSpacing: AppSpacing.sm,
                childAspectRatio: 1.0,
              ),
              itemCount: photosToShow.length,
              itemBuilder: (context, index) {
                final photo = photosToShow[index];
                final imageUrl = photo['thumbnail_url']?.toString() ?? 
                               photo['image_url']?.toString() ?? '';
                
                return ClipRRect(
                  borderRadius: BorderRadius.circular(AppBorderRadius.small),
                  child: WebImageCacheService.buildEventImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    errorWidget: Container(
                      color: Colors.grey[300],
                      child: const Icon(
                        Icons.broken_image,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (event.gallery_photos.length > 6) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () => _rotateGalleryImages(event, -6),
                  icon: const Icon(Icons.arrow_back_ios),
                  iconSize: 20,
                ),
                Text(
                  '${startIndex + 1}-${(startIndex + photosToShow.length).clamp(0, event.gallery_photos.length)} / ${event.gallery_photos.length}',
                  style: AppTextStyles.bodySmall,
                ),
                IconButton(
                  onPressed: () => _rotateGalleryImages(event, 6),
                  icon: const Icon(Icons.arrow_forward_ios),
                  iconSize: 20,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _rotateGalleryImages(Event event, int direction) {
    setState(() {
      final currentStart = _galleryImageStartIndex[event.id] ?? 0;
      final newStart = (currentStart + direction) % event.gallery_photos.length;
      _galleryImageStartIndex[event.id] = newStart;
    });
  }

  Widget _buildCarouselIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: events.asMap().entries.map((entry) {
        final index = entry.key;
        return Container(
          width: 12,
          height: 12,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _currentSlide == index 
                ? AppColors.accent 
                : Colors.grey[400],
          ),
          child: InkWell(
            onTap: () => _goToSlide(index),
            borderRadius: BorderRadius.circular(6),
          ),
        );
      }).toList(),
    );
  }
}