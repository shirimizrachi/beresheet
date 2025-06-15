import 'package:beresheet_app/config/app_config.dart';
import 'package:beresheet_app/model/event.dart';
import 'package:beresheet_app/services/event_service.dart';
import 'package:beresheet_app/services/image_cache_service.dart';
import 'package:beresheet_app/services/modern_localization_service.dart';
import 'package:beresheet_app/services/web_auth_service.dart';
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
    // Initialize web auth service to check existing session
    await WebAuthService.initializeSession();
    
    // Synchronize session data with UserSessionService for API calls
    if (WebAuthService.isLoggedIn && WebAuthService.homeId != null) {
      await UserSessionService.sethomeID(WebAuthService.homeId!);
      if (WebAuthService.userId != null) {
        await UserSessionService.setUserId(WebAuthService.userId!);
      }
      if (WebAuthService.userRole != null) {
        await UserSessionService.setRole(WebAuthService.userRole!);
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
      final loadedEvents = await EventService.loadApprovedEvents();
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
            actions: [
              // Simple text link for management panel
              if (WebAuthService.isLoggedIn)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.md),
                  child: TextButton(
                    onPressed: () {
                      html.window.location.hash = '#manage';
                    },
                    child: Text(
                      context.l10n.managementPanel,
                      style: const TextStyle(
                        color: Colors.white,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
            ],
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
                  
                  // Carousel
                  if (isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.xl),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (events.isEmpty)
                    Center(
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
                    )
                  else
                    SizedBox(
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
                                                ActivityTypeHelper.getDisplayName(event.type),
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
                        },
                      ),
                    ),

                  // Carousel Indicators
                  if (events.isNotEmpty) ...[
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

          // Bottom Footer Section
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          // Navigate to management panel using URL hash
                          html.window.location.hash = '#manage';
                        },
                        icon: const Icon(Icons.admin_panel_settings),
                        label: Text(context.l10n.managementPanel),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: AppSpacing.md,
                          ),
                          textStyle: AppTextStyles.buttonText.copyWith(fontSize: 16),
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
    );
  }
}