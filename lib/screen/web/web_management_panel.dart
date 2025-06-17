import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:html' as html;
import '../../config/app_config.dart';
import '../../utils/display_name_utils.dart';
import '../../services/web_auth_service.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'web_login_web.dart';
import 'users/create_user_web.dart';
import 'events/events_registration_management_web.dart';
import 'events/events_management_web.dart';
import 'users/user_list_web.dart';
import 'events/event_form_web.dart';
import 'events/event_registrations_web.dart';
import 'rooms_management_web.dart';
import 'service_provider_types_management_web.dart';
import 'event_instructor_management_web.dart';

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
            _errorMessage = AppLocalizations.of(context)!.accessDeniedManagerRole;
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
    destinations.add(NavigationRailDestination(
      icon: const Icon(Icons.home),
      selectedIcon: const Icon(Icons.home),
      label: Text(AppLocalizations.of(context)!.home),
    ));
    availableTabs.add('home');
    
    // EVENTS SECTION - available for manager, staff, and instructor
    if (userRole == AppConfig.userRoleManager ||
        userRole == AppConfig.userRoleStaff ||
        userRole == AppConfig.userRoleInstructor) {
      destinations.add(NavigationRailDestination(
        icon: const Icon(Icons.event_note),
        selectedIcon: const Icon(Icons.event_note),
        label: Text(AppLocalizations.of(context)!.webCreateEvent),
      ));
      availableTabs.add('create_event');
      
      // Events List (renamed from Events Management)
      destinations.add(NavigationRailDestination(
        icon: const Icon(Icons.event),
        selectedIcon: const Icon(Icons.event),
        label: Text(AppLocalizations.of(context)!.webEventsList),
      ));
      availableTabs.add('events');
      
      // Event Registrations (only for manager and staff)
      if (userRole == AppConfig.userRoleManager || userRole == AppConfig.userRoleStaff) {
        destinations.add(NavigationRailDestination(
          icon: const Icon(Icons.event_available),
          selectedIcon: const Icon(Icons.event_available),
          label: Text(AppLocalizations.of(context)!.webEventRegistrations),
        ));
        availableTabs.add('event_registrations');
      }
    }
    
    // USERS SECTION - only for managers
    if (userRole == AppConfig.userRoleManager) {
      destinations.add(NavigationRailDestination(
        icon: const Icon(Icons.person_add),
        selectedIcon: const Icon(Icons.person_add),
        label: Text(AppLocalizations.of(context)!.webCreateUser),
      ));
      availableTabs.add('create_user');
      
      destinations.add(NavigationRailDestination(
        icon: const Icon(Icons.people),
        selectedIcon: const Icon(Icons.people),
        label: Text(AppLocalizations.of(context)!.webUserList),
      ));
      availableTabs.add('user_list');
      
      // SETTINGS SECTION
      destinations.add(NavigationRailDestination(
        icon: const Icon(Icons.meeting_room),
        selectedIcon: const Icon(Icons.meeting_room),
        label: Text(AppLocalizations.of(context)!.webRooms),
      ));
      availableTabs.add('rooms_management');
      
      destinations.add(NavigationRailDestination(
        icon: const Icon(Icons.school),
        selectedIcon: const Icon(Icons.school),
        label: Text(AppLocalizations.of(context)!.eventInstructors),
      ));
      availableTabs.add('event_instructors');
      
      destinations.add(NavigationRailDestination(
        icon: const Icon(Icons.work),
        selectedIcon: const Icon(Icons.work),
        label: Text(AppLocalizations.of(context)!.serviceProviderTypes),
      ));
      availableTabs.add('service_provider_types');
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
        if (userRole == AppConfig.userRoleManager || userRole == AppConfig.userRoleStaff || userRole == AppConfig.userRoleInstructor) {
          return const EventFormWeb();
        } else {
          return _buildAccessDeniedPage(AppLocalizations.of(context)!.webEventCreationRequiresRole);
        }
      
      case 'event_registrations':
        // Check if user has manager or staff role
        if (userRole == AppConfig.userRoleManager || userRole == AppConfig.userRoleStaff) {
          return const EventRegistrationsWeb();
        } else {
          return _buildAccessDeniedPage(AppLocalizations.of(context)!.eventRegistrationsManagementRequiresRole);
        }
      
      case 'events':
        // Check if user has manager or staff role
        if (userRole == AppConfig.userRoleManager || userRole == AppConfig.userRoleStaff) {
          return const EventsManagementWeb();
        } else {
          return _buildAccessDeniedPage(AppLocalizations.of(context)!.eventsManagementRequiresRole);
        }
      
      
      case 'create_user':
        // Check if user has manager role
        if (userRole == AppConfig.userRoleManager) {
          return const CreateUserWeb();
        } else {
          return _buildAccessDeniedPage(AppLocalizations.of(context)!.userCreationRequiresRole);
        }
      
      case 'user_list':
        // Check if user has manager role
        if (userRole == AppConfig.userRoleManager) {
          return const UserListWeb();
        } else {
          return _buildAccessDeniedPage(AppLocalizations.of(context)!.userManagementRequiresRole);
        }
      
      case 'rooms_management':
        // Check if user has manager role
        if (userRole == AppConfig.userRoleManager) {
          return const RoomsManagementWeb();
        } else {
          return _buildAccessDeniedPage(AppLocalizations.of(context)!.roomsManagementRequiresRole);
        }
      
      case 'event_instructors':
        // Check if user has manager role
        if (userRole == AppConfig.userRoleManager) {
          return const EventInstructorManagementWeb();
        } else {
          return _buildAccessDeniedPage(AppLocalizations.of(context)!.eventInstructorManagementRequiresRole);
        }
      
      case 'service_provider_types':
        // Check if user has manager role
        if (userRole == AppConfig.userRoleManager) {
          return const ServiceProviderTypesManagementWeb();
        } else {
          return _buildAccessDeniedPage(AppLocalizations.of(context)!.serviceProviderTypesManagementRequiresRole);
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
                          AppLocalizations.of(context)!.welcomeUser(userFullName),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppLocalizations.of(context)!.roleLabel(_formatRole(userRole)),
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
          Text(
            AppLocalizations.of(context)!.availableFeatures,
            style: const TextStyle(
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
    if (userRole == AppConfig.userRoleManager || userRole == AppConfig.userRoleStaff || userRole == AppConfig.userRoleInstructor) {
      cards.add(
        _buildFeatureCard(
          icon: Icons.event_note,
          title: AppLocalizations.of(context)!.webCreateEvent,
          description: AppLocalizations.of(context)!.createNewEventsAndActivities,
          onTap: () => setState(() => _selectedTab = 'create_event'),
          color: Colors.indigo,
        ),
      );
    }
    
    // Event registrations card - for manager and staff
    if (userRole == AppConfig.userRoleManager || userRole == AppConfig.userRoleStaff) {
      cards.add(
        _buildFeatureCard(
          icon: Icons.event_available,
          title: AppLocalizations.of(context)!.webEventRegistrations,
          description: AppLocalizations.of(context)!.viewAndManageEventRegistrations,
          onTap: () => setState(() => _selectedTab = 'event_registrations'),
          color: Colors.teal,
        ),
      );
      
      cards.add(
        _buildFeatureCard(
          icon: Icons.event,
          title: AppLocalizations.of(context)!.webEventsManagement,
          description: AppLocalizations.of(context)!.manageExistingEvents,
          onTap: () => setState(() => _selectedTab = 'events'),
          color: Colors.green,
        ),
      );
      
      cards.add(
        _buildFeatureCard(
          icon: Icons.people,
          title: AppLocalizations.of(context)!.eventRegistrations,
          description: AppLocalizations.of(context)!.manageEventRegistrations,
          onTap: () => setState(() => _selectedTab = 'event_registrations_management'),
          color: Colors.purple,
        ),
      );
    }
    
    // User management cards - only for managers
    if (userRole == AppConfig.userRoleManager) {
      cards.add(
        _buildFeatureCard(
          icon: Icons.person_add,
          title: AppLocalizations.of(context)!.createUser,
          description: AppLocalizations.of(context)!.addNewUsersToTheSystem,
          onTap: () => setState(() => _selectedTab = 'create_user'),
          color: Colors.blue,
        ),
      );
      
      cards.add(
        _buildFeatureCard(
          icon: Icons.people,
          title: AppLocalizations.of(context)!.userManagement,
          description: AppLocalizations.of(context)!.viewAndEditExistingUsers,
          onTap: () => setState(() => _selectedTab = 'user_list'),
          color: Colors.purple,
        ),
      );
      
      cards.add(
        _buildFeatureCard(
          icon: Icons.meeting_room,
          title: AppLocalizations.of(context)!.roomsManagement,
          description: AppLocalizations.of(context)!.manageEventRoomsAndLocations,
          onTap: () => setState(() => _selectedTab = 'rooms_management'),
          color: Colors.orange,
        ),
      );
      
      cards.add(
        _buildFeatureCard(
          icon: Icons.school,
          title: AppLocalizations.of(context)!.eventInstructors,
          description: AppLocalizations.of(context)!.manageEventInstructors,
          onTap: () => setState(() => _selectedTab = 'event_instructors'),
          color: Colors.cyan,
        ),
      );
      
      cards.add(
        _buildFeatureCard(
          icon: Icons.work,
          title: AppLocalizations.of(context)!.serviceProviderTypesManagement,
          description: AppLocalizations.of(context)!.manageServiceProviderTypeCategories,
          onTap: () => setState(() => _selectedTab = 'service_provider_types'),
          color: Colors.deepPurple,
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
                Text(
                  AppLocalizations.of(context)!.limitedAccess,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context)!.yourCurrentRoleHasLimitedAccess(_formatRole(userRole)),
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
              Text(
                AppLocalizations.of(context)!.accessDeniedTitle,
                style: const TextStyle(
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
                child: Text(AppLocalizations.of(context)!.returnToHome),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatRole(String role) {
    return DisplayNameUtils.getUserRoleDisplayName(role, context);
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
                _errorMessage ?? AppLocalizations.of(context)!.authenticationFailed,
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.red,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _redirectToLogin,
                child: Text(AppLocalizations.of(context)!.returnToLogin),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            TextButton(
              onPressed: () {
                // Navigate to homepage using proper URL
                html.window.location.href = AppConfig.webHomepageUrl;
              },
              child: Text(
                AppLocalizations.of(context)!.homepage,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            const Text(' | ', style: TextStyle(color: Colors.white)),
            Text(
              AppLocalizations.of(context)!.managementPanelLabel,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
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
            tooltip: AppLocalizations.of(context)!.logoutTooltip,
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