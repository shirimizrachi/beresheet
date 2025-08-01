import 'package:beresheet_app/auth/auth_service.dart';
import 'package:beresheet_app/model/event.dart';
import 'package:beresheet_app/screen/app/events/registeredevents.dart';
import 'package:beresheet_app/screen/app/users/new_profilepage.dart';
import 'package:beresheet_app/screen/app/events/events_management_screen.dart';
import 'package:beresheet_app/screen/app/events/eventdetail.dart';
import 'package:beresheet_app/screen/app/service_request_screen.dart';
import 'package:beresheet_app/screen/app/notifications/notifications_screen.dart';
import 'package:beresheet_app/services/event_service.dart';
import 'package:beresheet_app/services/image_cache_service.dart';
import 'package:beresheet_app/services/role_access_service.dart';
import 'package:beresheet_app/services/modern_localization_service.dart';
import 'package:beresheet_app/theme/app_theme.dart';
import 'package:beresheet_app/widget/eventcard.dart';
import 'package:beresheet_app/widgets/localized_date_time_widget.dart';
import 'package:beresheet_app/utils/display_name_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  List<Event> events = [];
  bool isLoading = true;
  bool isMenuExpanded = false;
  bool isCardView = true; // Default to card view
  int currentCardIndex = 0;
  double _dragOffset = 0.0;
  bool _isSwipingBackward = false; // Track swipe direction for proper card stacking
  late AnimationController _animationController;
  late AnimationController _cardAnimationController;
  late Animation<double> _animation;
  Set<String> selectedEventTypeFilters = {}; // Multiple filters for event types
  bool canEditEvents = false; // Role-based access for event editing

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _cardAnimationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    loadEvents();
    _checkEventEditPermission();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _cardAnimationController.dispose();
    super.dispose();
  }

  void toggleMenu() {
    setState(() {
      isMenuExpanded = !isMenuExpanded;
      if (isMenuExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  void toggleViewMode() {
    setState(() {
      isCardView = !isCardView;
    });
  }

  void _nextCard() {
    setState(() {
      currentCardIndex = (currentCardIndex + 1) % events.length;
    });
    _preloadUpcomingImages();
  }

  void _previousCard() {
    setState(() {
      currentCardIndex = (currentCardIndex - 1 + events.length) % events.length;
    });
    _preloadUpcomingImages();
  }

  /// Get the correct card index based on swipe direction
  int _getCardIndex(int offset) {
    if (_isSwipingBackward) {
      // When swiping backward, show previous cards underneath
      return (currentCardIndex - offset + events.length) % events.length;
    } else {
      // Normal forward stacking
      return (currentCardIndex + offset) % events.length;
    }
  }
  
  /// Preload upcoming images as user navigates through cards
  Future<void> _preloadUpcomingImages() async {
    if (events.isEmpty || !mounted) return;
    
    try {
      // Preload next 2 cards from current position
      final imagesToPreload = <String>[];
      for (int i = 1; i <= 2; i++) {
        final index = (currentCardIndex + i) % events.length;
        final event = events[index];
        if (event.imageUrl.isNotEmpty) {
          imagesToPreload.add(event.imageUrl);
        }
      }
      
      if (imagesToPreload.isNotEmpty) {
        ImageCacheService.precacheImages(context, imagesToPreload);
      }
    } catch (e) {
      print('Error preloading upcoming images: $e');
    }
  }


  void _likeEvent() {
    setState(() {
      _dragOffset = 300;
    });
    _cardAnimationController.forward().then((_) {
      setState(() {
        _dragOffset = 0;
        currentCardIndex = (currentCardIndex + 1) % events.length;
      });
      _cardAnimationController.reset();
    });
  }

  void _passEvent() {
    setState(() {
      _dragOffset = -300;
      _isSwipingBackward = true;
    });
    _cardAnimationController.forward().then((_) {
      setState(() {
        _dragOffset = 0;
        currentCardIndex = (currentCardIndex - 1 + events.length) % events.length;
        _isSwipingBackward = false;
      });
      _cardAnimationController.reset();
    });
  }


  Future<void> loadEvents({bool forceRefresh = false}) async {
    try {
      final loadedEvents = await EventService.loadEventsForHome(forceRefresh: forceRefresh);
      
      setState(() {
        events = loadedEvents;
        isLoading = false;
      });
      
      // Preload images for better performance
      _preloadEventImages();
    } catch (e) {
      print('Error loading events: $e');
      setState(() {
        isLoading = false;
      });
    }
  }
  
  /// Preload the next few event images to improve card swiping performance
  Future<void> _preloadEventImages() async {
    if (events.isEmpty || !mounted) return;
    
    try {
      // Preload current card and next 3 cards
      final preloadCount = events.length < 4 ? events.length : 4;
      final imagesToPreload = <String>[];
      
      for (int i = 0; i < preloadCount; i++) {
        final index = (currentCardIndex + i) % events.length;
        final event = events[index];
        if (event.imageUrl.isNotEmpty) {
          imagesToPreload.add(event.imageUrl);
        }
      }
      
      if (imagesToPreload.isNotEmpty) {
        await ImageCacheService.precacheImages(context, imagesToPreload);
      }
    } catch (e) {
      print('Error preloading event images: $e');
    }
  }

  Future<void> _refreshEvents() async {
    await loadEvents(forceRefresh: true);
  }

  Future<void> _checkEventEditPermission() async {
    final hasPermission = await RoleAccessService.canEditEvents();
    setState(() {
      canEditEvents = hasPermission;
    });
  }


  // Get unique event types from the current events list
  List<String> _getUniqueEventTypes() {
    final Set<String> uniqueTypes = events.map((event) => event.type).toSet();
    return uniqueTypes.toList()..sort();
  }

  // Filter events based on selected types
  List<Event> _getFilteredEvents() {
    if (selectedEventTypeFilters.isEmpty) {
      return events;
    }
    return events.where((event) => selectedEventTypeFilters.contains(event.type)).toList();
  }

  // Build the event type filter widget
  Widget _buildEventTypeFilter() {
    final uniqueTypes = _getUniqueEventTypes();
    if (uniqueTypes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: uniqueTypes.length,
        itemBuilder: (context, index) {
          final eventType = uniqueTypes[index];
          final isSelected = selectedEventTypeFilters.contains(eventType);
          
          return Container(
            margin: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(
                DisplayNameUtils.getEventTypeDisplayName(eventType, context),
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    selectedEventTypeFilters.add(eventType);
                  } else {
                    selectedEventTypeFilters.remove(eventType);
                  }
                });
              },
              backgroundColor: Colors.white,
              selectedColor: AppColors.primary,
              checkmarkColor: Colors.white,
              side: BorderSide(
                color: AppColors.primary,
                width: 1,
              ),
            ),
          );
        },
      ),
    );
  }

  // Helper method to get localized month name
  String _getLocalizedMonth(int month) {
    switch (month) {
      case 1: return context.l10n.january;
      case 2: return context.l10n.february;
      case 3: return context.l10n.march;
      case 4: return context.l10n.april;
      case 5: return context.l10n.may;
      case 6: return context.l10n.june;
      case 7: return context.l10n.july;
      case 8: return context.l10n.august;
      case 9: return context.l10n.september;
      case 10: return context.l10n.october;
      case 11: return context.l10n.november;
      case 12: return context.l10n.december;
      default: return month.toString();
    }
  }


  // Helper method to get localized day name
  String _getLocalizedDay(int weekday) {
    switch (weekday) {
      case 1: return context.l10n.monday;
      case 2: return context.l10n.tuesday;
      case 3: return context.l10n.wednesday;
      case 4: return context.l10n.thursday;
      case 5: return context.l10n.friday;
      case 6: return context.l10n.saturday;
      case 7: return context.l10n.sunday;
      default: return weekday.toString();
    }
  }

  // Helper method to group events by date
  Map<String, List<Event>> _groupEventsByDate(List<Event> eventsList) {
    final Map<String, List<Event>> groupedEvents = {};
    final now = DateTime.now();
    
    for (final event in eventsList) {
      final eventDate = DateTime(event.next_date_time.year, event.next_date_time.month, event.next_date_time.day);
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(Duration(days: 1));
      
      String dateKey;
      if (eventDate.isAtSameMomentAs(today)) {
        dateKey = context.l10n.today;
      } else if (eventDate.isAtSameMomentAs(tomorrow)) {
        dateKey = context.l10n.tomorrow;
      } else {
        // Format: "Weekday, dd Month" with localized names
        final dayName = _getLocalizedDay(eventDate.weekday);
        final monthName = _getLocalizedMonth(eventDate.month);
        dateKey = '$dayName, ${eventDate.day} $monthName';
      }
      
      if (!groupedEvents.containsKey(dateKey)) {
        groupedEvents[dateKey] = [];
      }
      groupedEvents[dateKey]!.add(event);
    }
    
    // Sort events within each date group by time
    groupedEvents.forEach((key, eventList) {
      eventList.sort((a, b) => a.next_date_time.compareTo(b.next_date_time));
    });
    
    return groupedEvents;
  }

  // Helper method to create date separator widget
  Widget _buildDateSeparator(String dateLabel) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      child: Row(
        children: [
          Text(
            dateLabel,
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 1,
              color: AppColors.primary.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to build grid view with date separators
  Widget _buildGridViewWithDateSeparators() {
    final filteredEvents = _getFilteredEvents();
    final groupedEvents = _groupEventsByDate(filteredEvents);
    final sortedDateKeys = groupedEvents.keys.toList();
    
    // Sort the date keys to ensure proper chronological order
    sortedDateKeys.sort((a, b) {
      if (a == context.l10n.today) return -1;
      if (b == context.l10n.today) return 1;
      if (a == context.l10n.tomorrow) return -1;
      if (b == context.l10n.tomorrow) return 1;
      
      // For other dates, we need to find the actual events to compare dates
      // since we can't easily parse localized date strings
      final eventsA = groupedEvents[a]!;
      final eventsB = groupedEvents[b]!;
      
      if (eventsA.isNotEmpty && eventsB.isNotEmpty) {
        return eventsA.first.next_date_time.compareTo(eventsB.first.next_date_time);
      }
      
      return a.compareTo(b);
    });

    return RefreshIndicator(
      onRefresh: _refreshEvents,
      child: CustomScrollView(
        slivers: [
          // Event Type Filter
          SliverToBoxAdapter(
            child: _buildEventTypeFilter(),
          ),
          // Events grouped by date
          for (String dateKey in sortedDateKeys) ...[
            // Date separator
            SliverToBoxAdapter(
              child: _buildDateSeparator(dateKey),
            ),
            // Events for this date in a grid
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.75,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final eventsForDate = groupedEvents[dateKey]!;
                    return EventCard(
                      event: eventsForDate[index],
                      isRegistered: eventsForDate[index].isRegistered,
                    );
                  },
                  childCount: groupedEvents[dateKey]!.length,
                ),
              ),
            ),
          ],
          // Empty state if no events match filter
          if (groupedEvents.isEmpty)
            SliverToBoxAdapter(
              child: Container(
                height: 200,
                child: Center(
                  child: Text(
                    context.l10n.noEventsFound,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Enable edge-to-edge display to use full screen
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: [SystemUiOverlay.top],
    );
    
    // Set system UI colors to transparent
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
    
    return Scaffold(
      backgroundColor: Colors.white,
      extendBody: true,
      drawer: Drawer(
        backgroundColor: AppColors.surface,
        child: Column(
          children: [
            // Header with logo and title
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: const BoxDecoration(
                color: AppColors.primary,
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    Container(
                      height: 60,
                      width: 60,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.apartment,
                        color: AppColors.primary,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      context.l10n.appName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      context.l10n.communitySubtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: ListView(
                children: [
                  ListTile(
                    title: Text(context.l10n.profile, style: AppTextStyles.bodyMedium),
                    leading: const Icon(Icons.person, color: AppColors.primary),
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => const NewProfilePage(),
                      ));
                    },
                  ),
                  ListTile(
                    title: Text(context.l10n.myRegisteredEvents, style: AppTextStyles.bodyMedium),
                    leading: const Icon(Icons.event_available, color: AppColors.primary),
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(builder: (context) => const RegisteredEventsScreen()));
                    },
                  ),
                  // Only show Manage Events for managers and staff
                  if (canEditEvents)
                    ListTile(
                      title: Text(context.l10n.manageEvents, style: AppTextStyles.bodyMedium),
                      leading: const Icon(Icons.event_note, color: AppColors.primary),
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) => const EventsManagementScreen(),
                        )).then((result) {
                          if (result == true) {
                            _refreshEvents();
                          }
                        });
                      },
                    ),
                  // Logout option removed - users need to delete app to logout
                ],
              ),
            ),
          ],
        ),
      ),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text(
          context.l10n.appTitle,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            color: Colors.white,
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            color: Colors.white,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main content
          Padding(
            padding: EdgeInsets.only(
              bottom: 160 + MediaQuery.of(context).padding.bottom,
            ), // Added bottom padding for expandable menu + system navigation bar
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : events.isNotEmpty
                    ? isCardView
                        ? _buildCardView()
                        : _buildGridViewWithDateSeparators()
                    : _buildNoEventsView(),
          ),
          
          // Expandable Bottom Menu
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                final bottomPadding = MediaQuery.of(context).padding.bottom;
                return Container(
                  height: isMenuExpanded ? 400 + bottomPadding : 160 + bottomPadding,
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
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Toggle button
                      GestureDetector(
                        onTap: toggleMenu,
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: AnimatedRotation(
                            turns: isMenuExpanded ? 0.5 : 0,
                            duration: Duration(milliseconds: 300),
                            child: Icon(
                              Icons.keyboard_arrow_up,
                              size: 24,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ),
                      
                      // Always visible bottom buttons - increased height when collapsed
                      if (!isMenuExpanded)
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildBottomMenuItem(isCardView ? Icons.grid_view : Icons.view_carousel,
                                  isCardView ? context.l10n.galleryView : context.l10n.cardView,
                                  onTap: toggleViewMode),
                                SizedBox(width: 40),
                                _buildBottomMenuItem(Icons.event_available, context.l10n.myRegisteredEvents),
                                SizedBox(width: 40),
                                _buildBottomMenuItem(Icons.build_circle_outlined, context.l10n.serviceRequest),
                              ],
                            ),
                          ),
                        ),
                      
                      // Expanded menu content
                      if (isMenuExpanded)
                        Expanded(
                          child: SingleChildScrollView(
                            child: Padding(
                              padding: EdgeInsets.all(8),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // First row
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _buildBottomMenuItem(isCardView ? Icons.grid_view : Icons.view_carousel,
                                        isCardView ? context.l10n.galleryView : context.l10n.cardView,
                                        onTap: toggleViewMode),
                                      SizedBox(width: 40),
                                      _buildBottomMenuItem(Icons.event_available, context.l10n.myRegisteredEvents),
                                      SizedBox(width: 40),
                                      _buildBottomMenuItem(Icons.build_circle_outlined, context.l10n.serviceRequest),
                                    ],
                                  ),
                                  SizedBox(height: 24),
                                  
                                  // Second row - Additional features
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _buildBottomMenuItem(Icons.settings, 'Settings'),
                                      SizedBox(width: 40),
                                      _buildBottomMenuItem(Icons.help, 'Help', onTap: toggleViewMode),
                                      SizedBox(width: 40),
                                      _buildBottomMenuItem(Icons.info, 'About'),
                                    ],
                                  ),
                                  SizedBox(height: 24),
                                  
                                  // Third row - More options
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _buildBottomMenuItem(Icons.notification_important, 'Notifications'),
                                      SizedBox(width: 40),
                                      _buildBottomMenuItem(Icons.security, 'Privacy'),
                                      SizedBox(width: 40),
                                      _buildBottomMenuItem(Icons.feedback, 'Feedback'),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardView() {
    return RefreshIndicator(
      onRefresh: _refreshEvents,
      child: ListView(
        physics: AlwaysScrollableScrollPhysics(),
        children: [
          Container(
            height: MediaQuery.of(context).size.height -
                    kToolbarHeight -
                    MediaQuery.of(context).padding.top -
                    160 -
                    MediaQuery.of(context).padding.bottom,
            child: Column(
              children: [
                // Add top margin from header
                SizedBox(height: 40),
                
                // Card Stack - centered vertically
                Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 25),
                    child: Center(
                      child: Container(
                        height: MediaQuery.of(context).size.height * 0.55, // Increased from 0.45 to 0.55
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Background cards - showing 3 cards with deck effect
                            for (int offset = 2; offset >= 0; offset--)
                              _buildEventCard(_getCardIndex(offset), offset),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Action Buttons
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildActionButton(
                        icon: Icons.close,
                        color: Colors.grey,
                        onTap: _passEvent,
                      ),
                      _buildActionButton(
                        icon: Icons.star,
                        color: Colors.blue,
                        onTap: _likeEvent,
                        size: 35,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(int index, int position) {
    if (events.isEmpty) return Container();
    
    final event = events[index % events.length];
    final isCurrentCard = position == 0;
    
    return AnimatedBuilder(
      key: ValueKey('card_${index}_${position}'),
      animation: _cardAnimationController,
      builder: (context, child) {
        double scale = 1.0 - (position * 0.05);
        double verticalOffset = position * 8.0;
        double rotation = position * 0.01;
        
        double swipeRotation = 0.0;
        double swipeScale = 1.0;
        double swipeOffset = 0.0;
        
        if (isCurrentCard) {
          swipeOffset = _dragOffset;
          swipeRotation = (_dragOffset / 300) * 0.2;
          
          if (_dragOffset.abs() > 50) {
            swipeScale = 1.0 - (_dragOffset.abs() / 1000);
          }
          
          if (_cardAnimationController.isAnimating) {
            swipeOffset = _dragOffset * (1 + _cardAnimationController.value * 3);
            swipeRotation = (_dragOffset / 300) * 0.5 * _cardAnimationController.value;
            swipeScale = 1.0 - _cardAnimationController.value * 0.3;
          }
        }

        return Positioned(
          top: verticalOffset,
          left: 0,
          right: 0,
          child: Transform.scale(
            scale: scale * swipeScale,
            child: Transform.rotate(
              angle: rotation + swipeRotation,
              child: GestureDetector(
                onTap: isCurrentCard ? () {
                  // Navigate to event details when tapping the current card
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => EventDetailPage(event: event),
                    ),
                  );
                } : null,
                onPanUpdate: isCurrentCard ? _onPanUpdate : null,
                onPanEnd: isCurrentCard ? _onPanEnd : null,
                child: Transform.translate(
                  offset: Offset(swipeOffset, 0),
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2 - (position * 0.05)),
                          blurRadius: 20 - (position * 3),
                          offset: Offset(0, 10 - (position * 2)),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        height: MediaQuery.of(context).size.height * 0.52, // Increased from 0.42 to 0.52
                        decoration: BoxDecoration(
                          color: Colors.white, // Add solid white background
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Stack(
                          children: [
                            // Background Image
                            Container(
                              width: double.infinity,
                              height: double.infinity,
                              child: ImageCacheService.buildEventImage(
                                imageUrl: event.imageUrl,
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                                placeholder: Container(
                                  color: AppColors.primary.withOpacity(0.3),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withOpacity(0.8)),
                                      strokeWidth: 3,
                                    ),
                                  ),
                                ),
                                errorWidget: Container(
                                  color: AppColors.primary.withOpacity(0.3),
                                  child: Icon(
                                    Icons.event,
                                    size: 100,
                                    color: Colors.white.withOpacity(0.5),
                                  ),
                                ),
                              ),
                            ),
                            
                            // Gradient Overlay
                            Container(
                              decoration: BoxDecoration(
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
                            
                            // Event Information
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                padding: EdgeInsets.all(24),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Registration Status Badge for Card View
                                    if (event.isRegistered) ...[
                                      Container(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.green[100],
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.check_circle,
                                              size: 14,
                                              color: Colors.green[700],
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              context.l10n.registered.toUpperCase(),
                                              style: TextStyle(
                                                color: Colors.green[700],
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    Text(
                                      event.name,
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.location_on,
                                          color: Colors.white.withOpacity(0.8),
                                          size: 16,
                                        ),
                                        SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            event.location,
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.white.withOpacity(0.8),
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: LocalizedDateTimeWidget(
                                            dateTime: event.next_date_time,
                                            size: DateTimeDisplaySize.medium,
                                            textColor: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      event.description,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.white.withOpacity(0.9),
                                        height: 1.4,
                                      ),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.delta.dx;
      _dragOffset = _dragOffset.clamp(-400.0, 400.0);
      
      // Update swipe direction based on current drag offset
      _isSwipingBackward = _dragOffset < -10; // Left swipe threshold
    });
  }

  void _onPanEnd(DragEndDetails details) {
    final threshold = 80.0;
    final velocity = details.velocity.pixelsPerSecond.dx;
    
    if (_dragOffset > threshold || velocity > 500) {
      _likeEvent();
    } else if (_dragOffset < -threshold || velocity < -500) {
      _passEvent();
    } else {
      _cardAnimationController.duration = Duration(milliseconds: 200);
      _cardAnimationController.forward().then((_) {
        _cardAnimationController.reset();
        _cardAnimationController.duration = Duration(milliseconds: 300);
        setState(() {
          _dragOffset = 0.0;
          _isSwipingBackward = false; // Reset swipe direction
        });
      });
    }
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    double size = 30,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: color,
          size: size,
        ),
      ),
    );
  }


  Widget _buildBottomMenuItem(IconData icon, String title, {bool hasNotification = false, int notificationCount = 0, VoidCallback? onTap}) {
    return SizedBox(
      width: 90,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(30),
                    onTap: () {
                      if (onTap != null) {
                        onTap();
                      } else {
                        // Handle navigation based on title
                        if (title == context.l10n.myRegisteredEvents) {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) => const RegisteredEventsScreen(),
                          ));
                        } else if (title == context.l10n.serviceRequest) {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) => const ServiceRequestScreen(),
                          ));
                        }
                      }
                    },
                    child: Icon(
                      icon,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 8),
              Container(
                constraints: BoxConstraints(maxWidth: 80),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (hasNotification && notificationCount > 0)
            Positioned(
              top: 0,
              right: 8,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$notificationCount',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
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

  Widget _buildNoEventsView() {
    return isCardView
        ? Column(
            children: [
              SizedBox(height: 40),
              Expanded(
                child: Center(
                  child: Text(
                    context.l10n.noEventsFound,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              ),
              Container(height: 96), // Same height as action buttons area
            ],
          )
        : RefreshIndicator(
            onRefresh: _refreshEvents,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: Container(height: 40)), // Filter area space
                SliverFillRemaining(
                  child: Center(
                    child: Text(
                      context.l10n.noEventsFound,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
              ],
            ),
          );
  }
}
