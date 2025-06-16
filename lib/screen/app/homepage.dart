import 'package:beresheet_app/auth/auth_service.dart';
import 'package:beresheet_app/model/event.dart';
import 'package:beresheet_app/screen/app/events/registeredevents.dart';
import 'package:beresheet_app/screen/app/users/new_profilepage.dart';
import 'package:beresheet_app/screen/app/events/events_management_screen.dart';
import 'package:beresheet_app/services/event_service.dart';
import 'package:beresheet_app/services/modern_localization_service.dart';
import 'package:beresheet_app/theme/app_theme.dart';
import 'package:beresheet_app/widget/eventcard.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  List<Event> events = [];
  int registeredEventsCount = 0;
  bool isLoading = true;
  bool isMenuExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _animation;

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
    loadEvents();
  }

  @override
  void dispose() {
    _animationController.dispose();
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

  Future<void> loadEvents() async {
    try {
      final loadedEvents = await EventService.loadApprovedEvents();
      final registeredEvents = await EventService.getRegisteredEvents();
      setState(() {
        events = loadedEvents;
        registeredEventsCount = registeredEvents.length;
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
          Container(
            margin: const EdgeInsets.only(right: AppSpacing.md),
            child: IconButton(
              icon: registeredEventsCount > 0
                ? Badge(
                    label: Text("$registeredEventsCount"),
                    backgroundColor: AppColors.accent,
                    child: const Icon(Icons.event_available)
                  )
                : const Icon(Icons.event_available),
              color: Colors.white,
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const RegisteredEventsScreen()),
                );
                if (result == true) {
                  _refreshEvents();
                }
              },
            ),
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
                    ? RefreshIndicator(
                        onRefresh: _refreshEvents,
                        child: GridView.builder(
                          padding: const EdgeInsets.all(10),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.75,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: events.length,
                          itemBuilder: (context, index) {
                            return EventCard(
                              event: events[index],
                              onRegistrationChanged: _refreshEvents,
                            );
                          },
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _refreshEvents,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: SizedBox(
                            height: 400,
                            child: Center(
                              child: Text(
                                context.l10n.noEventsFound,
                                style: const TextStyle(color: Colors.black),
                              ),
                            ),
                          ),
                        ),
                      ),
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
                                _buildBottomMenuItem(Icons.person, context.l10n.profile),
                                SizedBox(width: 40),
                                _buildBottomMenuItem(Icons.event_available, context.l10n.myRegisteredEvents, hasNotification: registeredEventsCount > 0, notificationCount: registeredEventsCount),
                                SizedBox(width: 40),
                                _buildBottomMenuItem(Icons.event_note, context.l10n.manageEvents),
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
                                      _buildBottomMenuItem(Icons.person, context.l10n.profile),
                                      SizedBox(width: 40),
                                      _buildBottomMenuItem(Icons.event_available, context.l10n.myRegisteredEvents, hasNotification: registeredEventsCount > 0, notificationCount: registeredEventsCount),
                                      SizedBox(width: 40),
                                      _buildBottomMenuItem(Icons.event_note, context.l10n.manageEvents),
                                    ],
                                  ),
                                  SizedBox(height: 24),
                                  
                                  // Second row - Additional features
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _buildBottomMenuItem(Icons.settings, 'Settings'),
                                      SizedBox(width: 40),
                                      _buildBottomMenuItem(Icons.help, 'Help'),
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

  Widget _buildBottomMenuItem(IconData icon, String title, {bool hasNotification = false, int notificationCount = 0}) {
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
                      // Handle navigation based on title
                      if (title == context.l10n.profile) {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) => const NewProfilePage(),
                        ));
                      } else if (title == context.l10n.myRegisteredEvents) {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) => const RegisteredEventsScreen(),
                        )).then((result) {
                          if (result == true) {
                            _refreshEvents();
                          }
                        });
                      } else if (title == context.l10n.manageEvents) {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) => const EventsManagementScreen(),
                        )).then((result) {
                          if (result == true) {
                            _refreshEvents();
                          }
                        });
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
}
