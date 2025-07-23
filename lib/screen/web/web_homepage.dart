import 'dart:async';

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import 'package:beresheet_app/config/app_config.dart';
import 'package:beresheet_app/model/event.dart' as app_event;
import 'package:beresheet_app/screen/web/web_events_gallery.dart';
import 'package:beresheet_app/services/event_service.dart';
import 'package:beresheet_app/services/modern_localization_service.dart';
import 'package:beresheet_app/services/user_session_service.dart';
import 'package:beresheet_app/services/web/web_jwt_auth_service.dart';
import 'package:beresheet_app/services/web/web_jwt_session_service.dart';
import 'package:beresheet_app/services/web_image_cache_service.dart';
import 'package:beresheet_app/theme/app_theme.dart';
import 'package:beresheet_app/widgets/localized_date_time_widget.dart';

class WebHomePage extends StatefulWidget {
  const WebHomePage({Key? key}) : super(key: key);

  @override
  State<WebHomePage> createState() => _WebHomePageState();
}

class _WebHomePageState extends State<WebHomePage> with TickerProviderStateMixin {
  List<app_event.Event> events = [];
  bool isLoading = true;
  int _currentSlide = 0;
  Timer? _autoSlideTimer;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  List<Widget> _prebuiltEventCards = [];
  
  // Add ValueNotifier to avoid unnecessary rebuilds
  late ValueNotifier<int> _currentSlideNotifier;
  
  // Cache for optimized widgets to prevent rebuilds
  Widget? _cachedCarouselIndicators;
  Widget? _cachedWelcomeSection;
  Widget? _cachedFooterSection;

  @override
  void initState() {
    super.initState();
    _currentSlideNotifier = ValueNotifier<int>(0);
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400), // Matching display.html's 0.8s ease-in-out
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut, // Matching display.html's ease-in-out
    ));
    _initializeSession();
    loadEvents();
  }

  Future<void> _initializeSession() async {
    // Initialize JWT auth service
    await WebJwtAuthService.initialize();
    
    // Set default home ID for public access (homepage viewing)
    // Authentication will be handled by WebJwtAuthWrapper if needed
    await UserSessionService.sethomeID(AppConfig.defaultHomeId);
    
    // Refresh the UI after session initialization
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _fadeController.dispose();
    _currentSlideNotifier.dispose();
    super.dispose();
  }

  void _nextSlide() {
    if (events.isEmpty) return;
    _changeToSlide((_currentSlide + 1) % events.length);
  }

  void _previousSlide() {
    if (events.isEmpty) return;
    _changeToSlide((_currentSlide - 1 + events.length) % events.length);
  }

  Future<void> _changeToSlide(int newIndex) async {
    if (newIndex == _currentSlide || events.isEmpty) return;
    
    // AnimatedSwitcher will handle the smooth crossfade transition automatically
    _currentSlide = newIndex;
    _currentSlideNotifier.value = newIndex;
  }

  void _startAutoSlide() {
    if (events.isEmpty) return;
    
    _autoSlideTimer?.cancel();
    _autoSlideTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (events.isNotEmpty) {
        final nextIndex = (_currentSlide + 1) % events.length;
        _changeToSlide(nextIndex);
      }
    });
  }

  void _stopAutoSlide() {
    _autoSlideTimer?.cancel();
    _autoSlideTimer = null;
  }

  void _restartAutoSlide() {
    _stopAutoSlide();
    _startAutoSlide();
  }

  void _goToSlide(int index) {
    if (events.isNotEmpty && index >= 0 && index < events.length) {
      _changeToSlide(index);
    }
  }

  Future<void> loadEvents() async {
    try {
      List<app_event.Event> loadedEvents;
      
      // Load carousel events only
      loadedEvents = await EventService.loadApprovedEvents();
      
      setState(() {
        events = loadedEvents;
        isLoading = false;
        _currentSlide = 0;
      });
      
      // Prebuild optimized event cards
      _prebuildEventCards();
      
      // Preload all images for all carousel modes with enhanced memory caching
      await _preloadAllEventImages();
      
      // Start auto-slide after a short delay
      if (events.isNotEmpty) {
        Future.delayed(const Duration(seconds: 2), () {
          _startAutoSlide();
        });
      }
    } catch (e) {
      print('Error loading events: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  /// Prebuild all event cards with stable keys to avoid rebuilding during transitions
  void _prebuildEventCards() {
    _prebuiltEventCards = events.asMap().entries.map((entry) {
      final index = entry.key;
      final event = entry.value;
      return KeyedSubtree(
        key: ValueKey('event_card_${event.id}_$index'),
        child: _buildEventCard(event),
      );
    }).toList();
    
    // Clear cached widgets when events change
    _cachedCarouselIndicators = null;
    _cachedWelcomeSection = null;
    _cachedFooterSection = null;
  }

  /// Preload carousel event images only (no gallery images)
  Future<void> _preloadAllEventImages() async {
    if (!mounted || events.isEmpty) return;
    
    final Set<String> imagesToPreload = {};
    
    // Collect only main event images for carousel display
    for (final event in events) {
      // Main event image only
      if (event.imageUrl.isNotEmpty) {
        imagesToPreload.add(event.imageUrl);
      }
      
      // Instructor photo if exists
      if (event.instructorPhoto != null && event.instructorPhoto!.isNotEmpty) {
        imagesToPreload.add(event.instructorPhoto!);
      }
    }
    
    // Preload all unique images with enhanced carousel optimization
    try {
      print('Preloading ${imagesToPreload.length} unique carousel images...');
      
      // Use enhanced carousel preloading
      await WebImageCacheService.preloadImagesForCarousel(context, imagesToPreload.toList());
      
      print('Successfully preloaded all carousel images');
    } catch (e) {
      print('Error preloading carousel images: $e');
    }
  }

  Future<void> _refreshEvents() async {
    await loadEvents();
  }

  /// Navigate to Events Gallery page
  void _openEventsGallery() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const WebEventsGallery(),
      ),
    );
  }

  /// Open the Events Display page with JWT token
  Future<void> _openEventsDisplay() async {
    try {
      // Get the current JWT token from WebJwtSessionService
      final token = await WebJwtSessionService.getJwtToken();
      
      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Authentication required. Please log in.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Try to get tenant name from WebJwtSessionService first, then UserSessionService as fallback
      String? tenantName = await WebJwtSessionService.getHomeName();
      if (tenantName == null) {
        tenantName = await UserSessionService.getTenantName();
      }
      
      if (tenantName == null) {
        // Use demo as default tenant
        tenantName = 'demo';
      }

      // Set JWT token in cookie for the display page to access
      web.document.cookie = 'jwt_token=$token; path=/; secure; samesite=strict';

      // Construct the display URL
      final displayUrl = '/display/$tenantName';
      
      // Navigate to the display page - the cookie will be sent automatically
      web.window.location.href = displayUrl;
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening Events Display: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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

    return _buildCarouselView();
  }

  Widget _buildCarouselView() {
    if (_prebuiltEventCards.isEmpty) return const SizedBox.shrink();
    
    return SizedBox(
      height: 700,
      child: Stack(
        children: [
          // Stack all event cards like display.html - no widget rebuilding/reloading
          for (int i = 0; i < _prebuiltEventCards.length; i++)
            ValueListenableBuilder<int>(
              valueListenable: _currentSlideNotifier,
              builder: (context, currentSlide, child) {
                return AnimatedOpacity(
                  duration: const Duration(milliseconds: 800), // Matching display.html 0.8s
                  curve: Curves.easeInOut, // Matching display.html ease-in-out
                  opacity: i == currentSlide ? 1.0 : 0.0,
                  child: IgnorePointer(
                    ignoring: i != currentSlide, // Only allow interaction with visible slide
                    child: _prebuiltEventCards[i],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }





  Widget _buildEventCard(app_event.Event event) {
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
              // Event Image with stable key
              Expanded(
                flex: 2,
                child: ClipRRect(
                  child: KeyedSubtree(
                    key: ValueKey('event_image_${event.id}_${event.imageUrl}'),
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
                                dateTime: event.next_date_time,
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

  /// Build optimized carousel indicators with minimal rebuilds
  Widget _buildCarouselIndicators() {
    if (_cachedCarouselIndicators == null) {
      _cachedCarouselIndicators = ValueListenableBuilder<int>(
        valueListenable: _currentSlideNotifier,
        builder: (context, currentSlide, child) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(events.length, (index) {
              final isActive = currentSlide == index;
              return GestureDetector(
                onTap: () => _goToSlide(index),
                child: Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive
                        ? AppColors.primary
                        : Colors.grey[300],
                  ),
                ),
              );
            }),
          );
        },
      );
    }
    return _cachedCarouselIndicators!;
  }

  /// Build cached welcome section to avoid rebuilds
  Widget _buildWelcomeSection(BuildContext context) {
    if (_cachedWelcomeSection == null) {
      _cachedWelcomeSection = Container(
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
      );
    }
    return _cachedWelcomeSection!;
  }

  /// Build cached footer section to avoid rebuilds
  Widget _buildFooterSection(BuildContext context) {
    if (_cachedFooterSection == null) {
      _cachedFooterSection = Container(
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
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              children: [
                // Event Gallery Link
                TextButton(
                  onPressed: _openEventsGallery,
                  child: Text(
                    context.l10n.eventGallery,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                
                // Events Display Link
                TextButton(
                  onPressed: () => _openEventsDisplay(),
                  child: Text(
                    context.l10n.eventDisplayMode,
                    style: const TextStyle(
                      color: Colors.white70,
                      decoration: TextDecoration.underline,
                      fontSize: 16,
                    ),
                  ),
                ),
                
                // Management Panel Link
                TextButton(
                  onPressed: () {
                    web.window.location.hash = '#manage';
                  },
                  child: Text(
                    context.l10n.managementPanel,
                    style: const TextStyle(
                      color: Colors.white70,
                      decoration: TextDecoration.underline,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }
    return _cachedFooterSection!;
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

          // Welcome Section - Cached for performance
          SliverToBoxAdapter(
            child: _buildWelcomeSection(context),
          ),

          // Events Carousel Section with Mode Selection Buttons
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Removed Mode Selection Buttons as requested
                  const SizedBox(height: AppSpacing.xl),
                  
                  // Event Display based on selected mode
                  _buildEventDisplay(),
                  
                  // Carousel Indicators
                  if (events.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.lg),
                    _buildCarouselIndicators(),
                  ],
                ],
              ),
            ),
          ),

          // Bottom Footer Section with Display Mode Links - Cached for performance
          SliverToBoxAdapter(
            child: _buildFooterSection(context),
          ),
        ],
      ),
    );
  }
}
