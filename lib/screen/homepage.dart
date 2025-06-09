import 'package:beresheet_app/auth/auth_service.dart';
import 'package:beresheet_app/model/event.dart';
import 'package:beresheet_app/screen/registeredevents.dart';
import 'package:beresheet_app/screen/profilepage.dart';
import 'package:beresheet_app/screen/events_management_screen.dart';
import 'package:beresheet_app/services/event_service.dart';
import 'package:beresheet_app/theme/app_theme.dart';
import 'package:beresheet_app/widget/eventcard.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Event> events = [];
  int registeredEventsCount = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadEvents();
  }

  Future<void> loadEvents() async {
    try {
      final loadedEvents = await EventService.loadEvents();
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
    return Scaffold(
      backgroundColor: AppColors.background,
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
                    const Text(
                      'בראשית',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Text(
                      'קהילת מגורים',
                      style: TextStyle(
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
                    title: const Text("Profile", style: AppTextStyles.bodyMedium),
                    leading: const Icon(Icons.person, color: AppColors.primary),
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => const ProfilePage(),
                      ));
                    },
                  ),
                  ListTile(
                    title: const Text("My Registered Events", style: AppTextStyles.bodyMedium),
                    leading: const Icon(Icons.event_available, color: AppColors.primary),
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(builder: (context) => const RegisteredEventsScreen()));
                    },
                  ),
                  ListTile(
                    title: const Text("Manage Events", style: AppTextStyles.bodyMedium),
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
                  ListTile(
                    title: const Text("Log Out", style: AppTextStyles.bodyMedium),
                    leading: const Icon(Icons.logout, color: AppColors.primary),
                    onTap: () {
                      AuthRepo.logoutApp(context);
                    },
                  )
                ],
              ),
            ),
          ],
        ),
      ),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text(
          "בראשית - קהילת מגורים",
          style: TextStyle(
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
              icon: Badge(
                label: Text("$registeredEventsCount"),
                backgroundColor: AppColors.accent,
                child: const Icon(Icons.event_available)
              ),
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
      body: isLoading
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
                      return EventCard(event: events[index]);
                    },
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _refreshEvents,
                  child: const SingleChildScrollView(
                    physics: AlwaysScrollableScrollPhysics(),
                    child: SizedBox(
                      height: 400,
                      child: Center(
                        child: Text(
                          "No events found",
                          style: TextStyle(color: Colors.black),
                        ),
                      ),
                    ),
                  ),
                ),
    );
  }
}
