import 'package:beresheet_app/screen/events_management_screen.dart';
import 'package:beresheet_app/theme/app_theme.dart';
import 'package:flutter/material.dart';

class WebManagementPanel extends StatelessWidget {
  const WebManagementPanel({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Management Panel - בראשית קהילת מגורים',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.primary,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.home, color: Colors.white),
          onPressed: () {
            Navigator.of(context).pushReplacementNamed('/');
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withOpacity(0.1),
                    AppColors.accent.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppBorderRadius.large),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.admin_panel_settings,
                    size: 64,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Management Panel',
                    style: AppTextStyles.heading1.copyWith(
                      fontSize: 32,
                      color: AppColors.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Manage all aspects of the Beresheet community',
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: AppSpacing.xxl),
            
            // Management Sections
            Text(
              'Management Tools',
              style: AppTextStyles.heading2.copyWith(
                fontSize: 24,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            
            // Grid of Management Options
            LayoutBuilder(
              builder: (context, constraints) {
                int crossAxisCount = constraints.maxWidth > 800 ? 3 : 
                                   constraints.maxWidth > 600 ? 2 : 1;
                
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: AppSpacing.lg,
                  mainAxisSpacing: AppSpacing.lg,
                  childAspectRatio: 1.2,
                  children: [
                    // Events Management Card
                    _buildManagementCard(
                      context: context,
                      title: 'Events Management',
                      description: 'Create, edit, and manage community events',
                      icon: Icons.event_note,
                      color: Colors.blue,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const EventsManagementScreen(),
                          ),
                        );
                      },
                    ),
                    
                    // Future: Users Management Card
                    _buildManagementCard(
                      context: context,
                      title: 'Users Management',
                      description: 'Manage community members and permissions',
                      icon: Icons.people,
                      color: Colors.green,
                      isComingSoon: true,
                      onTap: () {
                        _showComingSoonDialog(context, 'Users Management');
                      },
                    ),
                    
                    // Future: Announcements Management Card
                    _buildManagementCard(
                      context: context,
                      title: 'Announcements',
                      description: 'Create and manage community announcements',
                      icon: Icons.campaign,
                      color: Colors.orange,
                      isComingSoon: true,
                      onTap: () {
                        _showComingSoonDialog(context, 'Announcements Management');
                      },
                    ),
                    
                    // Future: Facilities Management Card
                    _buildManagementCard(
                      context: context,
                      title: 'Facilities',
                      description: 'Manage community facilities and bookings',
                      icon: Icons.apartment,
                      color: Colors.purple,
                      isComingSoon: true,
                      onTap: () {
                        _showComingSoonDialog(context, 'Facilities Management');
                      },
                    ),
                    
                    // Future: Reports & Analytics Card
                    _buildManagementCard(
                      context: context,
                      title: 'Reports & Analytics',
                      description: 'View community statistics and reports',
                      icon: Icons.analytics,
                      color: Colors.teal,
                      isComingSoon: true,
                      onTap: () {
                        _showComingSoonDialog(context, 'Reports & Analytics');
                      },
                    ),
                    
                    // Future: Settings Card
                    _buildManagementCard(
                      context: context,
                      title: 'System Settings',
                      description: 'Configure system settings and preferences',
                      icon: Icons.settings,
                      color: Colors.grey,
                      isComingSoon: true,
                      onTap: () {
                        _showComingSoonDialog(context, 'System Settings');
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManagementCard({
    required BuildContext context,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isComingSoon = false,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppBorderRadius.large),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppBorderRadius.large),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppBorderRadius.large),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.1),
                Colors.white,
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                children: [
                  Icon(
                    icon,
                    size: 48,
                    color: isComingSoon ? Colors.grey[400] : color,
                  ),
                  if (isComingSoon)
                    Positioned(
                      right: -5,
                      top: -5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Soon',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                title,
                style: AppTextStyles.heading3.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isComingSoon ? Colors.grey[600] : AppColors.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                description,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showComingSoonDialog(BuildContext context, String feature) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppBorderRadius.large),
          ),
          title: Row(
            children: [
              Icon(Icons.construction, color: Colors.orange),
              const SizedBox(width: AppSpacing.sm),
              Text('Coming Soon'),
            ],
          ),
          content: Text(
            '$feature is currently under development and will be available in a future update.',
            style: AppTextStyles.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'OK',
                style: TextStyle(color: AppColors.primary),
              ),
            ),
          ],
        );
      },
    );
  }
}