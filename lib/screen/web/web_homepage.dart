import 'package:beresheet_app/config/app_config.dart';
import 'package:beresheet_app/model/event.dart';
import 'package:beresheet_app/services/event_service.dart';
import 'package:beresheet_app/services/web_image_cache_service.dart';
import 'package:beresheet_app/services/modern_localization_service.dart';
import 'package:beresheet_app/services/web/web_jwt_auth_service.dart';
import 'package:beresheet_app/services/web/web_jwt_session_service.dart';
import 'package:beresheet_app/services/user_session_service.dart';
import 'package:beresheet_app/theme/app_theme.dart';
import 'package:beresheet_app/widgets/localized_date_time_widget.dart';
import 'package:flutter/material.dart';
import 'dart:html' as html;

class WebHomePage extends StatefulWidget {
  const WebHomePage({Key? key}) : super(key: key);

  @override
  State<WebHomePage> createState() => _WebHomePageState();
}

class _WebHomePageState extends State<WebHomePage> {
  List<Event> events = [];
  bool isLoading = true;
  final PageController _pageController = PageController();
  final PageController _galleryPageController = PageController();
  int _currentPage = 0;
  int _currentGalleryPage = 0;
  Map<String, int> _galleryImageStartIndex = {}; // Track which set of 4 images to show per event
  String _displayMode = 'carousel'; // carousel, banner, reviews, gallery

  @override
  void initState() {
    super.initState();
    _initializeSession();
    loadEvents();
    
    // Auto-scroll carousel every 5 seconds
    Future.delayed(const Duration(seconds: 3), () {
      _startAutoScroll();
    });
  }

  Future<void> _initializeSession() async {
    // Initialize JWT auth service
    await WebJwtAuthService.initialize();
    
    // Check if user is authenticated
    final isAuthenticated = await WebJwtAuthService.isAuthenticated();
    
    if (isAuthenticated) {
      // Get current user and sync with UserSessionService for API calls
      final user = await WebJwtAuthService.getCurrentUser();
      if (user != null) {
        await UserSessionService.sethomeID(user.homeId);
        await UserSessionService.setUserId(user.id);
        await UserSessionService.setRole(user.role);
      }
    } else {
      // Set default home ID for public access (homepage viewing)
      await UserSessionService.sethomeID(AppConfig.defaultHomeId);
    }
    
    // Refresh the UI after session check
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _galleryPageController.dispose();
    super.dispose();
  }

  void _startAutoScroll() {
    if (events.isNotEmpty) {
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted && _pageController.hasClients) {
          setState(() {
            _currentPage = (_currentPage + 1) % events.length;
          });
          _pageController.animateToPage(
            _currentPage,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
          _startAutoScroll();
        }
      });
    }
  }

  void _startGalleryAutoScroll() {
    if (events.isNotEmpty && _displayMode == 'gallery') {
      Future.delayed(const Duration(seconds: 7), () {
        if (mounted && _galleryPageController.hasClients) {
          setState(() {
            _currentGalleryPage = (_currentGalleryPage + 1) % events.length;
            // Each time we move to the next event, rotate to next set of 6 gallery images
            final event = events[_currentGalleryPage];
            if (event.gallery_photos.isNotEmpty) {
              final currentStartIndex = _galleryImageStartIndex[event.id] ?? 0;
              final nextStartIndex = (currentStartIndex + 6) % event.gallery_photos.length;
              _galleryImageStartIndex[event.id] = nextStartIndex;
            }
          });
          _galleryPageController.animateToPage(
            _currentGalleryPage,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOut,
          );
          _startGalleryAutoScroll();
        }
      });
    }
  }

  Future<void> loadEvents() async {
    try {
      List<Event> loadedEvents;
      
      switch (_displayMode) {
        case 'carousel':
        case 'banner':
          loadedEvents = await EventService.loadApprovedEvents();
          break;
        case 'reviews':
          loadedEvents = await EventService.loadCompletedEventsWithReviews();
          break;
        case 'gallery':
          loadedEvents = await EventService.loadEventsWithGallery();
          break;
        default:
          loadedEvents = await EventService.loadApprovedEvents();
      }
      
      setState(() {
        events = loadedEvents;
        isLoading = false;
        _currentGalleryPage = 0;
        // Initialize gallery image indices for each event
        for (final event in events) {
          if (!_galleryImageStartIndex.containsKey(event.id)) {
            _galleryImageStartIndex[event.id] = 0;
          }
        }
      });
      
      // Preload all images for all carousel modes with enhanced memory caching
      await _preloadAllEventImages();
      
      // Start gallery auto-scroll if in gallery mode
      if (_displayMode == 'gallery' && events.isNotEmpty) {
        Future.delayed(const Duration(seconds: 3), () {
          _startGalleryAutoScroll();
        });
      }
    } catch (e) {
      print('Error loading events: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  /// Preload all event images to cache them for carousel display
  Future<void> _preloadAllEventImages() async {
    if (!mounted || events.isEmpty) return;
    
    final Set<String> imagesToPreload = {};
    
    // Collect all image URLs from all events for all display modes
    for (final event in events) {
      // Main event image
      if (event.imageUrl.isNotEmpty) {
        imagesToPreload.add(event.imageUrl);
      }
      
      // Instructor photo
      if (event.instructorPhoto != null && event.instructorPhoto!.isNotEmpty) {
        imagesToPreload.add(event.instructorPhoto!);
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
    
    // Preload all unique images with enhanced carousel optimization
    try {
      print('Preloading ${imagesToPreload.length} unique images for carousel...');
      
      if (_displayMode == 'carousel' || _displayMode == 'banner') {
        // Use enhanced carousel preloading for carousel modes
        await WebImageCacheService.preloadImagesForCarousel(context, imagesToPreload.toList());
      } else {
        // Use standard preloading for other modes
        await WebImageCacheService.precacheImages(context, imagesToPreload.toList());
      }
      
      print('Successfully preloaded all event images');
    } catch (e) {
      print('Error preloading images: $e');
    }
  }

  Future<void> _refreshEvents() async {
    await loadEvents();
  }

  void _changeDisplayMode(String mode) {
    setState(() {
      _displayMode = mode;
      isLoading = true;
    });
    loadEvents();
  }

  Widget _buildEventDisplay() {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (events.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            children: [
              Icon(
                Icons.event_busy,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                context.l10n.noEventsAvailable,
                style: AppTextStyles.heading3.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    switch (_displayMode) {
      case 'carousel':
        return _buildCarouselView();
      case 'banner':
        return _buildBannerView();
      case 'reviews':
        return _buildReviewsView();
      case 'gallery':
        return _buildGalleryView();
      default:
        return _buildCarouselView();
    }
  }

  Widget _buildCarouselView() {
    return SizedBox(
      height: 700, // Reduced from 800 to 700 (100px reduction)
      child: PageView.builder(
        controller: _pageController,
        onPageChanged: (page) {
          setState(() {
            _currentPage = page;
          });
        },
        itemCount: events.length,
        itemBuilder: (context, index) {
          final event = events[index];
          return _buildEventCard(event);
        },
      ),
    );
  }

  Widget _buildBannerView() {
    return SizedBox(
      height: 700, // Reduced from 800 to 700 (100px reduction)
      child: PageView.builder(
        controller: _pageController,
        onPageChanged: (page) {
          setState(() {
            _currentPage = page;
          });
        },
        itemCount: events.length,
        itemBuilder: (context, index) {
          final event = events[index];
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppBorderRadius.large),
              ),
              child: Stack(
                children: [
                  // Background Image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppBorderRadius.large),
                    child: WebImageCacheService.buildEventImage(
                      imageUrl: event.imageUrl,
                      height: double.infinity,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorWidget: Container(
                        color: Colors.grey[300],
                        child: const Icon(
                          Icons.image_not_supported,
                          size: 64,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  
                  // Gradient Overlay
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppBorderRadius.large),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                  
                  // Event Info Overlay
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Instructor Info (if available)
                          if (event.instructorName != null)
                            Row(
                              children: [
                                if (event.instructorPhoto != null)
                                  WebImageCacheService.buildCircularUserImage(
                                    imageUrl: event.instructorPhoto,
                                    radius: 20,
                                  ),
                                const SizedBox(width: AppSpacing.sm),
                                Text(
                                  event.instructorName!,
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          if (event.instructorName != null)
                            const SizedBox(height: AppSpacing.sm),
                          
                          // Event Name
                          Text(
                            event.name,
                            style: AppTextStyles.heading3.copyWith(
                              fontSize: 64,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          
                          // Event Info
                          LocalizedDateTimeWidget(
                            dateTime: event.date_time,
                            size: DateTimeDisplaySize.large,
                            textColor: Colors.white70,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildReviewsView() {
    return Column(
      children: events.map((event) {
        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppBorderRadius.medium),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Event Header
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          event.name,
                          style: AppTextStyles.heading3.copyWith(
                            fontSize: 52,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Completed',
                          style: AppTextStyles.chipText.copyWith(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  
                  // Reviews Section
                  _buildReviewsSection(event),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildReviewsSection(Event event) {
    if (event.reviews == null) {
      return Text(
        'No reviews yet',
        style: AppTextStyles.bodyMedium.copyWith(
          color: Colors.grey[600],
          fontStyle: FontStyle.italic,
        ),
      );
    }
    
    // Handle new format (Map with average_rating and reviews list)
    if (event.reviews is Map) {
      final reviewsData = event.reviews as Map;
      final averageRating = (reviewsData['average_rating'] ?? 0.0).toDouble();
      final totalRatings = reviewsData['total_ratings'] ?? 0;
      final reviewsList = reviewsData['reviews'] as List? ?? [];
      
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Average Rating Display - at the top
          if (totalRatings > 0) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(AppBorderRadius.small),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.star,
                    color: Colors.amber,
                    size: 24,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    averageRating.toStringAsFixed(1),
                    style: AppTextStyles.heading3.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[800],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    '/ 5.0',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '($totalRatings ${totalRatings == 1 ? 'rating' : 'ratings'})',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          
          // Reviews List - below the rating
          if (reviewsList.isNotEmpty) ...[
            Text(
              'Reviews:',
              style: AppTextStyles.heading4.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ...reviewsList.take(3).map((review) {
              return Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(AppBorderRadius.small),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          review['user_name'] ?? 'Anonymous',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        if (review['date'] != null && review['date'].toString().isNotEmpty) ...[
                          Text(
                            review['date'].toString().substring(0, 10), // Show just the date part
                            style: AppTextStyles.bodySmall.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (review['comment'] != null && review['comment'].toString().isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        review['comment'],
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
          ] else if (totalRatings == 0) ...[
            Text(
              'No reviews yet',
              style: AppTextStyles.bodyMedium.copyWith(
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      );
    }
    
    // Handle old format (List) - fallback for backward compatibility
    if (event.reviews is List && (event.reviews as List).isNotEmpty) {
      final reviewsList = event.reviews as List;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reviews:',
            style: AppTextStyles.heading4.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...reviewsList.take(3).map((review) {
            return Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(AppBorderRadius.small),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        review['user_name'] ?? 'Anonymous',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: List.generate(5, (starIndex) {
                          return Icon(
                            starIndex < (review['rating'] ?? 0)
                                ? Icons.star
                                : Icons.star_border,
                            size: 16,
                            color: Colors.amber,
                          );
                        }),
                      ),
                    ],
                  ),
                  if (review['comment'] != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      review['comment'],
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ],
      );
    }
    
    return Text(
      'No reviews yet',
      style: AppTextStyles.bodyMedium.copyWith(
        color: Colors.grey[600],
        fontStyle: FontStyle.italic,
      ),
    );
  }

  Widget _buildGalleryView() {
    return SizedBox(
      height: 700, // Reduced from 800 to 700 (100px reduction)
      child: PageView.builder(
        controller: _galleryPageController,
        onPageChanged: (page) {
          setState(() {
            _currentGalleryPage = page;
          });
        },
        itemCount: events.length,
        itemBuilder: (context, index) {
          final event = events[index];
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
                                horizontal: AppSpacing.md,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: ActivityTypeHelper.getColor(event.type),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                ActivityTypeHelper.getDisplayName(event.type, context),
                                style: AppTextStyles.chipText.copyWith(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            
                            // Event Name
                            Text(
                              event.name,
                              style: AppTextStyles.heading2.copyWith(
                                fontSize: 64,
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
                                fontSize: 36,
                                color: Colors.grey[700],
                                height: 1.5,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            
                            // Event Info
                            Row(
                              children: [
                                Icon(
                                  Icons.schedule,
                                  size: 20,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: LocalizedDateTimeWidget(
                                    dateTime: event.date_time,
                                    size: DateTimeDisplaySize.large,
                                    textColor: AppColors.primary,
                                    fontWeight: FontWeight.w500,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            _buildEventInfo(Icons.location_on, event.location),
                            const SizedBox(height: AppSpacing.sm),
                            _buildEventInfo(Icons.people, '${event.current_participants}/${event.max_participants} ${context.l10n.participants}'),
                            const SizedBox(height: AppSpacing.sm),
                            _buildEventInfo(Icons.timer, '${event.duration} ${context.l10n.minutesShort}'),
                            const SizedBox(height: AppSpacing.lg),
                            
                            // Gallery Photos Count
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.blue[200]!),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.photo_library, color: Colors.blue[600], size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${event.gallery_photos.length} Photos',
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      color: Colors.blue[600],
                                      fontWeight: FontWeight.bold,
                                      fontSize: 32,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Right side: 4 Gallery Images Grid
                    Expanded(
                      flex: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: _buildGalleryGrid(event),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEventInfo(IconData icon, String text) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: AppColors.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.bodyMedium.copyWith(
              fontSize: 32,
              color: AppColors.primary,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildGalleryGrid(Event event) {
    if (event.gallery_photos.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(AppBorderRadius.medium),
        ),
        child: Center(
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
                'No Gallery Photos',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Get current set of images to display for 3x2 grid (6 images max)
    final startIndex = _galleryImageStartIndex[event.id] ?? 0;
    final imagesToShow = <Map<String, dynamic>>[];
    final availableImages = event.gallery_photos.length;
    
    // Only show up to 6 images and don't repeat if we have fewer than 6
    final imagesToDisplay = availableImages >= 6 ? 6 : availableImages;
    
    for (int i = 0; i < imagesToDisplay; i++) {
      final imageIndex = (startIndex + i) % event.gallery_photos.length;
      imagesToShow.add(event.gallery_photos[imageIndex]);
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, // 3 columns for 3x2 grid
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
        childAspectRatio: 1.0, // Square aspect ratio for thumbnails
      ),
      itemCount: 6, // 3x2 = 6 images
      itemBuilder: (context, index) {
        if (index < imagesToShow.length) {
          final photo = imagesToShow[index];
          return Container(
            width: 60, // 60px width for thumbnails
            height: 60, // 60px height for thumbnails
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppBorderRadius.medium),
              child: WebImageCacheService.buildEventImage(
                imageUrl: photo['thumbnail_url'] ?? '',
                width: 60, // Explicit width constraint
                height: 60, // Explicit height constraint
                fit: BoxFit.cover,
                errorWidget: Container(
                  color: Colors.grey[300],
                  child: const Icon(
                    Icons.image_not_supported,
                    size: 20, // Reduced icon size to match smaller thumbnails
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
          );
        } else {
          // Empty placeholder if less than 6 images
          return Container(
            width: 60, // Consistent size for placeholders - 60px
            height: 60,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(AppBorderRadius.medium),
            ),
            child: Icon(
              Icons.add_photo_alternate_outlined,
              size: 20, // Reduced icon size to match smaller thumbnails
              color: Colors.grey[400],
            ),
          );
        }
      },
    );
  }

  Widget _buildEventCard(Event event) {
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
                ActivityTypeHelper.getColor(event.type).withOpacity(0.1),
                Colors.white,
              ],
            ),
          ),
          child: Row(
            children: [
              // Event Image
              Expanded(
                flex: 2,
                child: ClipRRect(
                  child: WebImageCacheService.buildEventImage(
                    imageUrl: event.imageUrl,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(AppBorderRadius.large),
                      bottomLeft: Radius.circular(AppBorderRadius.large),
                    ),
                    errorWidget: Container(
                      color: Colors.grey[300],
                      child: const Icon(
                        Icons.image_not_supported,
                        size: 64,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
              ),
              
              // Event Details
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Event Type Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: ActivityTypeHelper.getColor(event.type),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          ActivityTypeHelper.getDisplayName(event.type, context),
                          style: AppTextStyles.chipText.copyWith(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      
                          // Event Name
                          Text(
                            event.name,
                            style: AppTextStyles.heading3.copyWith(
                              fontSize: 56,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          
                          // Event Description
                          Text(
                            event.description,
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontSize: 36,
                              color: Colors.grey[600],
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          
                          // Event Info Row
                          Row(
                            children: [
                              Icon(
                                Icons.schedule,
                                size: 20,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 4),
                              LocalizedDateTimeWidget(
                                dateTime: event.date_time,
                                size: DateTimeDisplaySize.large,
                                textColor: AppColors.primary,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 20,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  event.location,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    fontSize: 32,
                                    color: AppColors.primary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            children: [
                              Icon(
                                Icons.people,
                                size: 20,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${event.current_participants}/${event.max_participants} ${context.l10n.participants}',
                                style: AppTextStyles.bodySmall.copyWith(
                                  fontSize: 32,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            children: [
                              Icon(
                                Icons.timer,
                                size: 20,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${event.duration} ${context.l10n.minutesShort}',
                                style: AppTextStyles.bodySmall.copyWith(
                                  fontSize: 32,
                                  color: AppColors.primary,
                                ),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: 80,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.primary,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                context.l10n.appTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
              centerTitle: true,
            ),
          ),

          // Welcome Section
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                children: [
                  Text(
                    context.l10n.welcomeToBeresheet,
                    style: AppTextStyles.heading1.copyWith(
                      fontSize: 36,
                      color: AppColors.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    context.l10n.discoverEvents,
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

          // Events Carousel Section
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Event Display based on selected mode
                  _buildEventDisplay(),
                  // Carousel Indicators (for carousel, banner, and gallery modes)
                  if (events.isNotEmpty && (_displayMode == 'carousel' || _displayMode == 'banner' || _displayMode == 'gallery')) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: events.asMap().entries.map((entry) {
                        final isActive = _displayMode == 'gallery'
                            ? _currentGalleryPage == entry.key
                            : _currentPage == entry.key;
                        return Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isActive
                                ? AppColors.primary
                                : Colors.grey[300],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Bottom Footer Section with Display Mode Links
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.only(top: AppSpacing.xxl),
              padding: const EdgeInsets.all(AppSpacing.xl),
              color: AppColors.primary,
              child: Column(
                children: [
                  Text(
                    context.l10n.buildingStrongerCommunity,
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  
                  // Display Mode Links and Management Panel
                  FutureBuilder<bool>(
                    future: WebJwtAuthService.isAuthenticated(),
                    builder: (context, snapshot) {
                      final isAuthenticated = snapshot.data ?? false;
                      
                      return Wrap(
                        alignment: WrapAlignment.center,
                        spacing: AppSpacing.md,
                        runSpacing: AppSpacing.sm,
                        children: [
                          // Display Mode 1: Carousel
                          TextButton(
                            onPressed: () => _changeDisplayMode('carousel'),
                            child: Text(
                              '1 - ${context.l10n.carouselView}',
                              style: TextStyle(
                                color: _displayMode == 'carousel' ? AppColors.accent : Colors.white70,
                                decoration: _displayMode == 'carousel' ? TextDecoration.underline : null,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          
                          // Display Mode 2: Banner
                          TextButton(
                            onPressed: () => _changeDisplayMode('banner'),
                            child: Text(
                              '2 - ${context.l10n.bannerView}',
                              style: TextStyle(
                                color: _displayMode == 'banner' ? AppColors.accent : Colors.white70,
                                decoration: _displayMode == 'banner' ? TextDecoration.underline : null,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          
                          // Display Mode 3: Reviews
                          TextButton(
                            onPressed: () => _changeDisplayMode('reviews'),
                            child: Text(
                              '3 - ${context.l10n.reviewsView}',
                              style: TextStyle(
                                color: _displayMode == 'reviews' ? AppColors.accent : Colors.white70,
                                decoration: _displayMode == 'reviews' ? TextDecoration.underline : null,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          
                          // Display Mode 4: Gallery
                          TextButton(
                            onPressed: () => _changeDisplayMode('gallery'),
                            child: Text(
                              '4 - ${context.l10n.galleryView}',
                              style: TextStyle(
                                color: _displayMode == 'gallery' ? AppColors.accent : Colors.white70,
                                decoration: _displayMode == 'gallery' ? TextDecoration.underline : null,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          
                          // Management Panel Link (only if authenticated)
                          if (isAuthenticated)
                            TextButton(
                              onPressed: () {
                                html.window.location.hash = '#manage';
                              },
                              child: Text(
                                context.l10n.managementPanel,
                                style: const TextStyle(
                                  color: Colors.white,
                                  decoration: TextDecoration.underline,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
