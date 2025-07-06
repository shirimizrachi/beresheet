import 'package:beresheet_app/config/app_config.dart';
import 'package:beresheet_app/model/event.dart';
import 'package:beresheet_app/services/event_service.dart';
import 'package:beresheet_app/services/image_cache_service.dart';
import 'package:beresheet_app/services/modern_localization_service.dart';
import 'package:beresheet_app/services/web/web_jwt_auth_service.dart';
import 'package:beresheet_app/services/web/web_jwt_session_service.dart';
import 'package:beresheet_app/services/user_session_service.dart';
import 'package:beresheet_app/theme/app_theme.dart';
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
  int _currentPage = 0;
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
          loadedEvents = await EventService.loadCompletedEventsWithGallery();
          break;
        default:
          loadedEvents = await EventService.loadApprovedEvents();
      }
      
      setState(() {
        events = loadedEvents;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading events: $e');
      setState(() {
        isLoading = false;
      });
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
      height: 400,
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
      height: 300,
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
                    child: ImageCacheService.buildEventImage(
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
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundImage: NetworkImage(event.instructorPhoto!),
                                    onBackgroundImageError: (_, __) {},
                                    child: event.instructorPhoto == null
                                        ? const Icon(Icons.person, size: 20)
                                        : null,
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
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          
                          // Event Info
                          Text(
                            '${event.formattedDate} at ${event.formattedTime}',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: Colors.white70,
                            ),
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
                            fontSize: 20,
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
                  if (event.reviews.isNotEmpty) ...[
                    Text(
                      'Reviews:',
                      style: AppTextStyles.heading4.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ...event.reviews.take(3).map((review) {
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
                  ] else
                    Text(
                      'No reviews yet',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGalleryView() {
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
                            fontSize: 20,
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
                  
                  // Gallery Section
                  if (event.galleryPhotos.isNotEmpty) ...[
                    Text(
                      'Event Gallery:',
                      style: AppTextStyles.heading4.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      height: 150,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: event.galleryPhotos.length,
                        itemBuilder: (context, index) {
                          final photo = event.galleryPhotos[index];
                          return Container(
                            margin: const EdgeInsets.only(right: AppSpacing.sm),
                            width: 150,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(AppBorderRadius.small),
                              child: Image.network(
                                photo['image_url'] ?? '',
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey[300],
                                    child: const Icon(
                                      Icons.image_not_supported,
                                      size: 32,
                                      color: Colors.grey,
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ] else
                    Text(
                      'No photos available',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
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
                  child: ImageCacheService.buildEventImage(
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
                          fontSize: 24,
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
                          fontSize: 16,
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
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${event.formattedDate} at ${event.formattedTime}',
                            style: AppTextStyles.bodySmall.copyWith(
                              fontSize: 14,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              event.location,
                              style: AppTextStyles.bodySmall.copyWith(
                                fontSize: 14,
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
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${event.currentParticipants}/${event.maxParticipants} ${context.l10n.participants}',
                            style: AppTextStyles.bodySmall.copyWith(
                              fontSize: 14,
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
                  Text(
                    context.l10n.featuredEvents,
                    style: AppTextStyles.heading2.copyWith(
                      fontSize: 28,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  
                  // Event Display based on selected mode
                  _buildEventDisplay(),
                  // Carousel Indicators (only for carousel and banner modes)
                  if (events.isNotEmpty && (_displayMode == 'carousel' || _displayMode == 'banner')) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: events.asMap().entries.map((entry) {
                        return Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _currentPage == entry.key
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
                    context.l10n.beresheetCommunity,
                    style: AppTextStyles.heading2.copyWith(
                      color: Colors.white,
                      fontSize: 24,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.md),
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