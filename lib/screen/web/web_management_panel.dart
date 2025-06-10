import 'package:beresheet_app/screen/app/events/events_management_screen.dart';
import 'package:beresheet_app/screen/web/create_user_screen.dart';
import 'package:beresheet_app/services/modern_localization_service.dart';
import 'package:beresheet_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'dart:html' as html;

class WebManagementPanel extends StatelessWidget {
  const WebManagementPanel({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          context.l10n.managementPanelTitle,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.primary,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.home, color: Colors.white),
          onPressed: () {
            // Navigate back to home using URL hash
            html.window.location.hash = '#home';
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
                    context.l10n.managementPanel,
                    style: AppTextStyles.heading1.copyWith(
                      fontSize: 32,
                      color: AppColors.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    context.l10n.manageAllAspects,
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
              context.l10n.managementTools,
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
                      title: context.l10n.eventsManagement,
                      description: context.l10n.createEditManageEvents,
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
                    
                    // Users Management Card
                    _buildManagementCard(
                      context: context,
                      title: context.l10n.usersManagement,
                      description: context.l10n.manageMembersPermissions,
                      icon: Icons.people,
                      color: Colors.green,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CreateUserScreen(),
                          ),
                        );
                      },
                    ),
                    
                    // Future: Announcements Management Card
                    _buildManagementCard(
                      context: context,
                      title: context.l10n.announcements,
                      description: context.l10n.createManageAnnouncements,
                      icon: Icons.campaign,
                      color: Colors.orange,
                      isComingSoon: true,
                      onTap: () {
                        _showComingSoonDialog(context, context.l10n.announcements);
                      },
                    ),
                    
                    // Future: Facilities Management Card
                    _buildManagementCard(
                      context: context,
                      title: context.l10n.facilities,
                      description: context.l10n.manageFacilitiesBookings,
                      icon: Icons.apartment,
                      color: Colors.purple,
                      isComingSoon: true,
                      onTap: () {
                        _showComingSoonDialog(context, context.l10n.facilities);
                      },
                    ),
                    
                    // Future: Reports & Analytics Card
                    _buildManagementCard(
                      context: context,
                      title: context.l10n.reportsAnalytics,
                      description: context.l10n.viewStatisticsReports,
                      icon: Icons.analytics,
                      color: Colors.teal,
                      isComingSoon: true,
                      onTap: () {
                        _showComingSoonDialog(context, context.l10n.reportsAnalytics);
                      },
                    ),
                    
                    // Future: Settings Card
                    _buildManagementCard(
                      context: context,
                      title: context.l10n.systemSettings,
                      description: context.l10n.configureSystemSettings,
                      icon: Icons.settings,
                      color: Colors.grey,
                      isComingSoon: true,
                      onTap: () {
                        _showComingSoonDialog(context, context.l10n.systemSettings);
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
                          context.l10n.soon,
                          style: const TextStyle(
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
              const Icon(Icons.construction, color: Colors.orange),
              const SizedBox(width: AppSpacing.sm),
              Text(context.l10n.comingSoon),
            ],
          ),
          content: Text(
            '$feature ${context.l10n.featureUnderDevelopment}',
            style: AppTextStyles.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                context.l10n.ok,
                style: TextStyle(color: AppColors.primary),
              ),
            ),
          ],
        );
      },
    );
  }
}