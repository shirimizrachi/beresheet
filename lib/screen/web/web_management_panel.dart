import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:html' as html;
import '../../config/app_config.dart';
import '../../utils/display_name_utils.dart';
import '../../services/web/web_jwt_auth_service.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'web_jwt_login_screen.dart';
import 'users/create_user_web.dart';
import 'events/events_registration_management_web.dart';
import 'events/events_management_web.dart';
import 'users/user_list_web.dart';
import 'events/event_form_web.dart';
import 'events/event_registrations_web.dart';
import 'rooms_management_web.dart';
import 'service_provider_types_management_web.dart';
import 'event_instructor_management_web.dart';
import 'events/events_summary_web.dart';
import 'notifications/notifications_list_web.dart';

class WebManagementPanel extends StatefulWidget {
  final String? initialTab;
  
  const WebManagementPanel({Key? key, this.initialTab}) : super(key: key);

  @override
  State<WebManagementPanel> createState() => _WebManagementPanelState();
}

class _WebManagementPanelState extends State<WebManagementPanel> {
  String _selectedTab = 'home';
  String? _userRole;
  String? _userFullName;

  @override
  void initState() {
    super.initState();
    // Set initial tab based on parameter or default to 'home'
    _selectedTab = widget.initialTab ?? 'home';
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    // Since authentication is handled by the router wrapper (WebJwtManagerPage),
    // we just need to load user info for display purposes
    final user = await WebJwtAuthService.getCurrentUser();
    if (user != null && mounted) {
      setState(() {
        _userRole = user.role;
        _userFullName = user.fullName;
      });
    }
  }

  Future<void> _logout() async {
    await WebJwtAuthService.logout();
    // After logout, the auth wrapper will handle redirection to login
  }

  Widget _buildNavigationRail() {
    final userRole = _userRole ?? '';
    
    return Container(
      width: 250,
      child: SingleChildScrollView(
        child: Column(
          children: [
          // Home section
          _buildSectionHeader(AppLocalizations.of(context)!.home, Icons.home),
          _buildNavigationItem(
            icon: Icons.home,
            label: AppLocalizations.of(context)!.home,
            tabKey: 'home',
            isSelected: _selectedTab == 'home',
          ),
          
          // Events section
          if (userRole == AppConfig.userRoleManager ||
              userRole == AppConfig.userRoleStaff ||
              userRole == AppConfig.userRoleInstructor) ...[
            const SizedBox(height: 16),
            _buildSectionHeader(AppLocalizations.of(context)!.events, Icons.event),
            _buildNavigationItem(
              icon: Icons.event_note,
              label: AppLocalizations.of(context)!.webCreateEvent,
              tabKey: 'create_event',
              isSelected: _selectedTab == 'create_event',
            ),
            _buildNavigationItem(
              icon: Icons.event,
              label: AppLocalizations.of(context)!.webEventsList,
              tabKey: 'events',
              isSelected: _selectedTab == 'events',
            ),
            if (userRole == AppConfig.userRoleManager || userRole == AppConfig.userRoleStaff)
              _buildNavigationItem(
                icon: Icons.event_available,
                label: AppLocalizations.of(context)!.webEventRegistrations,
                tabKey: 'event_registrations',
                isSelected: _selectedTab == 'event_registrations',
              ),
            _buildNavigationItem(
              icon: Icons.school,
              label: AppLocalizations.of(context)!.eventInstructors,
              tabKey: 'event_instructors',
              isSelected: _selectedTab == 'event_instructors',
            ),
            _buildNavigationItem(
              icon: Icons.analytics,
              label: AppLocalizations.of(context)!.eventsSummary,
              tabKey: 'events_summary',
              isSelected: _selectedTab == 'events_summary',
            ),
            _buildNavigationItem(
              icon: Icons.meeting_room,
              label: AppLocalizations.of(context)!.webRooms,
              tabKey: 'rooms_management',
              isSelected: _selectedTab == 'rooms_management',
            ),
          ],
          
          // Users section
          if (userRole == AppConfig.userRoleManager) ...[
            const SizedBox(height: 16),
            _buildSectionHeader(AppLocalizations.of(context)!.users, Icons.people),
            _buildNavigationItem(
              icon: Icons.person_add,
              label: AppLocalizations.of(context)!.webCreateUser,
              tabKey: 'create_user',
              isSelected: _selectedTab == 'create_user',
            ),
            _buildNavigationItem(
              icon: Icons.people,
              label: AppLocalizations.of(context)!.webUserList,
              tabKey: 'user_list',
              isSelected: _selectedTab == 'user_list',
            ),
          ],
          
          // Service Providers section
          if (userRole == AppConfig.userRoleManager) ...[
            const SizedBox(height: 16),
            _buildSectionHeader(AppLocalizations.of(context)!.serviceProviders, Icons.work),
            _buildNavigationItem(
              icon: Icons.work,
              label: AppLocalizations.of(context)!.serviceProviderTypes,
              tabKey: 'service_provider_types',
              isSelected: _selectedTab == 'service_provider_types',
            ),
          ],
          
          // Notifications section
          if (userRole == AppConfig.userRoleManager ||
              userRole == AppConfig.userRoleStaff ||
              userRole == AppConfig.userRoleInstructor) ...[
            const SizedBox(height: 16),
            _buildSectionHeader(AppLocalizations.of(context)!.notifications, Icons.notifications),
            _buildNavigationItem(
              icon: Icons.notifications,
              label: AppLocalizations.of(context)!.notifications,
              tabKey: 'notifications',
              isSelected: _selectedTab == 'notifications',
            ),
          ],
        ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(
          top: BorderSide(color: Colors.grey[300]!),
          bottom: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[700]),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationItem({
    required IconData icon,
    required String label,
    required String tabKey,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedTab = tabKey;
        });
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[50] : null,
          border: Border(
            left: BorderSide(
              color: isSelected ? Colors.blue : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? Colors.blue : Colors.grey[600],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? Colors.blue : Colors.grey[800],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    final userRole = _userRole ?? '';
    
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
      
      case 'events_summary':
        // Check if user has manager, staff, or instructor role
        if (userRole == AppConfig.userRoleManager || userRole == AppConfig.userRoleStaff || userRole == AppConfig.userRoleInstructor) {
          return const EventsSummaryWeb();
        } else {
          return _buildAccessDeniedPage('Events Summary requires manager, staff, or instructor role');
        }
      
      case 'notifications':
        // Check if user has manager, staff, or instructor role
        if (userRole == AppConfig.userRoleManager || userRole == AppConfig.userRoleStaff || userRole == AppConfig.userRoleInstructor) {
          return const NotificationsListWeb();
        } else {
          return _buildAccessDeniedPage('Notifications management requires manager, staff, or instructor role');
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
    final userRole = _userRole ?? '';
    final userFullName = _userFullName ?? 'User';
    
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
          icon: Icons.analytics,
          title: AppLocalizations.of(context)!.eventsSummary,
          description: 'View comprehensive events analysis and load_events_for_home results',
          onTap: () => setState(() => _selectedTab = 'events_summary'),
          color: Colors.deepOrange,
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
    // Authentication is handled by the router wrapper (WebJwtManagerPage),
    // so we can directly build the management panel content
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
                      _userFullName ?? 'Unknown User',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      _formatRole(_userRole ?? 'user'),
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
