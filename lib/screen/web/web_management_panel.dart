import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../config/app_config.dart';
import '../../services/web_auth_service.dart';
import 'web_login_web.dart';
import 'users/create_user_web.dart';
import 'events/events_registration_management_web.dart';
import 'users/user_list_web.dart';
import 'events/event_form_web.dart';
import 'events/event_registrations_web.dart';

class WebManagementPanel extends StatefulWidget {
  final String? initialTab;
  
  const WebManagementPanel({Key? key, this.initialTab}) : super(key: key);

  @override
  State<WebManagementPanel> createState() => _WebManagementPanelState();
}

class _WebManagementPanelState extends State<WebManagementPanel> {
  bool _isLoading = true;
  bool _isAuthenticated = false;
  String? _errorMessage;
  String _selectedTab = 'home';

  @override
  void initState() {
    super.initState();
    // Set initial tab based on parameter or default to 'home'
    _selectedTab = widget.initialTab ?? 'home';
    _validateSession();
  }

  Future<void> _validateSession() async {
    // Initialize session from persistent storage first
    await WebAuthService.initializeSession();
    
    if (!WebAuthService.isLoggedIn) {
      _redirectToLogin();
      return;
    }

    try {
      final isValid = await WebAuthService.validateSession();

      if (isValid) {
        // Check if user has manager role
        if (WebAuthService.isManager) {
          setState(() {
            _isAuthenticated = true;
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = 'Access denied: Manager role required';
            _isLoading = false;
          });
        }
      } else {
        _redirectToLogin();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Session validation failed: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _redirectToLogin() async {
    await WebAuthService.clearSession();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const WebLoginWeb()),
      );
    }
  }

  Future<void> _logout() async {
    await WebAuthService.logout();
    _redirectToLogin();
  }

  Widget _buildNavigationRail() {
    final userRole = WebAuthService.userRole ?? '';
    List<NavigationRailDestination> destinations = [];
    List<String> availableTabs = [];
    
    // Home tab - available for all authenticated users
    destinations.add(const NavigationRailDestination(
      icon: Icon(Icons.home),
      selectedIcon: Icon(Icons.home),
      label: Text('Home'),
    ));
    availableTabs.add('home');
    
    // Event creation tab - available for manager, staff, and instructor
    if (userRole == 'manager' || userRole == 'staff' || userRole == 'instructor') {
      destinations.add(const NavigationRailDestination(
        icon: Icon(Icons.event_note),
        selectedIcon: Icon(Icons.event_note),
        label: Text('Create Event'),
      ));
      availableTabs.add('create_event');
    }
    
    // Event registrations tab - available for manager and staff
    if (userRole == 'manager' || userRole == 'staff') {
      destinations.add(const NavigationRailDestination(
        icon: Icon(Icons.event_available),
        selectedIcon: Icon(Icons.event_available),
        label: Text('Event Registrations'),
      ));
      availableTabs.add('event_registrations');
      
      destinations.add(const NavigationRailDestination(
        icon: Icon(Icons.event),
        selectedIcon: Icon(Icons.event),
        label: Text('Events Management'),
      ));
      availableTabs.add('events');
    }
    
    // User management tabs - only for managers
    if (userRole == 'manager') {
      destinations.add(const NavigationRailDestination(
        icon: Icon(Icons.person_add),
        selectedIcon: Icon(Icons.person_add),
        label: Text('Create User'),
      ));
      availableTabs.add('create_user');
      
      destinations.add(const NavigationRailDestination(
        icon: Icon(Icons.people),
        selectedIcon: Icon(Icons.people),
        label: Text('User List'),
      ));
      availableTabs.add('user_list');
    }
    
    // Find current selected index
    int selectedIndex = availableTabs.indexOf(_selectedTab);
    if (selectedIndex == -1) {
      selectedIndex = 0;
      _selectedTab = availableTabs[0];
    }
    
    return NavigationRail(
      selectedIndex: selectedIndex,
      onDestinationSelected: (int index) {
        setState(() {
          _selectedTab = availableTabs[index];
        });
      },
      labelType: NavigationRailLabelType.all,
      destinations: destinations,
    );
  }

  Widget _buildMainContent() {
    final userRole = WebAuthService.userRole ?? '';
    
    switch (_selectedTab) {
      case 'home':
        return _buildHomePage();
      
      case 'create_event':
        // Check if user has manager, staff, or instructor role
        if (userRole == 'manager' || userRole == 'staff' || userRole == 'instructor') {
          return const EventFormWeb();
        } else {
          return _buildAccessDeniedPage('Event creation requires manager, staff, or instructor role.');
        }
      
      case 'event_registrations':
        // Check if user has manager or staff role
        if (userRole == 'manager' || userRole == 'staff') {
          return const EventRegistrationsWeb();
        } else {
          return _buildAccessDeniedPage('Event registrations management requires manager or staff role.');
        }
      
      case 'events':
        // Check if user has manager or staff role
        if (userRole == 'manager' || userRole == 'staff') {
          return const EventsRegistrationManagementWeb();
        } else {
          return _buildAccessDeniedPage('Events management requires manager or staff role.');
        }
      
      case 'create_user':
        // Check if user has manager role
        if (userRole == 'manager') {
          return const CreateUserWeb();
        } else {
          return _buildAccessDeniedPage('User creation requires manager role.');
        }
      
      case 'user_list':
        // Check if user has manager role
        if (userRole == 'manager') {
          return const UserListWeb();
        } else {
          return _buildAccessDeniedPage('User management requires manager role.');
        }
      
      default:
        return _buildHomePage();
    }
  }

  Widget _buildHomePage() {
    final userRole = WebAuthService.userRole ?? '';
    final userFullName = WebAuthService.userFullName ?? 'User';
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  const Icon(
                    Icons.dashboard,
                    size: 48,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome, $userFullName!',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Role: ${_formatRole(userRole)}',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Available Features
          const Text(
            'Available Features',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Feature Cards
          _buildFeatureCards(userRole),
        ],
      ),
    );
  }

  Widget _buildFeatureCards(String userRole) {
    List<Widget> cards = [];
    
    // Event creation card - for manager, staff, and instructor
    if (userRole == 'manager' || userRole == 'staff' || userRole == 'instructor') {
      cards.add(
        _buildFeatureCard(
          icon: Icons.event_note,
          title: 'Create Event',
          description: 'Create new events and activities',
          onTap: () => setState(() => _selectedTab = 'create_event'),
          color: Colors.indigo,
        ),
      );
    }
    
    // Event registrations card - for manager and staff
    if (userRole == 'manager' || userRole == 'staff') {
      cards.add(
        _buildFeatureCard(
          icon: Icons.event_available,
          title: 'Event Registrations',
          description: 'View and manage event registrations',
          onTap: () => setState(() => _selectedTab = 'event_registrations'),
          color: Colors.teal,
        ),
      );
      
      cards.add(
        _buildFeatureCard(
          icon: Icons.event,
          title: 'Events Management',
          description: 'Manage existing events',
          onTap: () => setState(() => _selectedTab = 'events'),
          color: Colors.green,
        ),
      );
    }
    
    // User management cards - only for managers
    if (userRole == 'manager') {
      cards.add(
        _buildFeatureCard(
          icon: Icons.person_add,
          title: 'Create User',
          description: 'Add new users to the system',
          onTap: () => setState(() => _selectedTab = 'create_user'),
          color: Colors.blue,
        ),
      );
      
      cards.add(
        _buildFeatureCard(
          icon: Icons.people,
          title: 'User Management',
          description: 'View and edit existing users',
          onTap: () => setState(() => _selectedTab = 'user_list'),
          color: Colors.purple,
        ),
      );
    }
    
    // If no special features available
    if (cards.isEmpty) {
      cards.add(
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 48,
                  color: Colors.orange,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Limited Access',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your current role (${_formatRole(userRole)}) has limited access to management features.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.1,
      children: cards,
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 48,
                color: color,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccessDeniedPage(String message) {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              const Text(
                'Access Denied',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => setState(() => _selectedTab = 'home'),
                child: const Text('Return to Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatRole(String role) {
    switch (role) {
      case 'manager':
        return 'Manager';
      case 'staff':
        return 'Staff';
      case 'instructor':
        return 'Instructor';
      case 'resident':
        return 'Resident';
      case 'caregiver':
        return 'Caregiver';
      case 'service':
        return 'Service';
      default:
        return role.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!_isAuthenticated) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red[400],
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage ?? 'Authentication failed',
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.red,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _redirectToLogin,
                child: const Text('Return to Login'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Management Panel',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.blue[700],
        actions: [
          // User info display
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      WebAuthService.userFullName ?? 'Unknown User',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      _formatRole(WebAuthService.userRole ?? 'user'),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                const Icon(
                  Icons.account_circle,
                  color: Colors.white,
                  size: 32,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Row(
        children: [
          _buildNavigationRail(),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: _buildMainContent(),
          ),
        ],
      ),
    );
  }
}