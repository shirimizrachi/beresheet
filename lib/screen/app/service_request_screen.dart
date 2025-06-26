import 'package:beresheet_app/services/modern_localization_service.dart';
import 'package:beresheet_app/services/user_session_service.dart';
import 'package:beresheet_app/config/app_config.dart';
import 'package:beresheet_app/theme/app_theme.dart';
import 'package:beresheet_app/screen/app/service_request_conversation_screen.dart';
import 'package:beresheet_app/screen/app/service_request_history_screen.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ServiceRequestScreen extends StatefulWidget {
  const ServiceRequestScreen({Key? key}) : super(key: key);

  @override
  State<ServiceRequestScreen> createState() => _ServiceRequestScreenState();
}

class _ServiceRequestScreenState extends State<ServiceRequestScreen> {
  List<Map<String, dynamic>> serviceProviders = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadServiceProviders();
  }

  Future<void> _loadServiceProviders() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final homeId = await UserSessionService.gethomeID();
      final userId = await UserSessionService.getUserId();
      
      if (homeId == null || userId == null) {
        throw Exception('User not logged in');
      }

      final response = await http.get(
        Uri.parse('${AppConfig.apiUrlWithPrefix}/api/users/service-providers'),
        headers: {
          'Content-Type': 'application/json',
          'homeID': homeId.toString(),
          'userId': userId,
        },
      );
      
      print('Service providers request - HomeID: $homeId, Status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          serviceProviders = data.map((item) => item as Map<String, dynamic>).toList();
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load service providers: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Error loading service providers: $e';
      });
    }
  }

  void _openNewRequest(String serviceProviderId, String serviceProviderName, String? serviceProviderPhoto, String? serviceProviderType, String? serviceProviderTypeDescription) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ServiceRequestConversationScreen(
          serviceProviderId: serviceProviderId,
          serviceProviderName: serviceProviderName,
          serviceProviderPhoto: serviceProviderPhoto,
          serviceProviderType: serviceProviderType,
          serviceProviderTypeDescription: serviceProviderTypeDescription,
        ),
      ),
    );
  }

  void _openHistory(String serviceProviderId, String serviceProviderName, String? serviceProviderPhoto, String? serviceProviderType, String? serviceProviderTypeDescription) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ServiceRequestHistoryScreen(
          serviceProviderId: serviceProviderId,
          serviceProviderName: serviceProviderName,
          serviceProviderPhoto: serviceProviderPhoto,
          serviceProviderType: serviceProviderType,
          serviceProviderTypeDescription: serviceProviderTypeDescription,
        ),
      ),
    );
  }

  Widget _buildServiceProviderCard(Map<String, dynamic> provider) {
    final name = provider['full_name'] ?? context.l10n.unknownProvider;
    final serviceType = provider['service_provider_type_name'] ?? context.l10n.serviceProvider;
    final serviceTypeDescription = provider['service_provider_type_description'];
    final photo = provider['photo'];
    final requestCount = provider['request_count'] ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Profile Image
            CircleAvatar(
              radius: 30,
              backgroundColor: AppColors.primary.withOpacity(0.1),
              backgroundImage: photo != null && photo.isNotEmpty 
                  ? NetworkImage(photo) 
                  : null,
              child: photo == null || photo.isEmpty
                  ? Icon(
                      Icons.person,
                      size: 30,
                      color: AppColors.primary,
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            
            // Provider Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    serviceType,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        context.l10n.requestsCount(requestCount, requestCount == 1 ? '' : 's'),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Action Buttons
            Column(
              children: [
                SizedBox(
                  width: 80,
                  child: ElevatedButton(
                    onPressed: () => _openNewRequest(provider['id'], name, photo, serviceType, serviceTypeDescription),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: Text(
                      context.l10n.newRequest,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: 80,
                  child: OutlinedButton(
                    onPressed: () => _openHistory(provider['id'], name, photo, serviceType, serviceTypeDescription),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: Text(
                      context.l10n.history,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text(
          context.l10n.serviceRequest,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: Colors.white,
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            color: Colors.white,
            onPressed: _loadServiceProviders,
            tooltip: context.l10n.refresh,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          errorMessage!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadServiceProviders,
                          child: Text(context.l10n.retry),
                        ),
                      ],
                    ),
                  ),
                )
              : serviceProviders.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.build_circle_outlined,
                              size: 80,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 24),
                            Text(
                              context.l10n.noServiceProvidersAvailable,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              context.l10n.noServiceProvidersRegistered,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        // Header
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            border: Border(
                              bottom: BorderSide(
                                color: AppColors.primary.withOpacity(0.2),
                              ),
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.build_circle,
                                size: 40,
                                color: AppColors.primary,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                context.l10n.availableServiceProviders,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                              Text(
                                context.l10n.chooseServiceProviderToSendRequest,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Service Providers List
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: serviceProviders.length,
                            itemBuilder: (context, index) {
                              return _buildServiceProviderCard(serviceProviders[index]);
                            },
                          ),
                        ),
                      ],
                    ),
    );
  }
}