import 'package:beresheet_app/services/modern_localization_service.dart';
import 'package:beresheet_app/services/web_auth_service.dart';
import 'package:beresheet_app/config/app_config.dart';
import 'package:beresheet_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class EventVoteReviewWeb extends StatefulWidget {
  final String eventRegistrationId;
  final String eventId;
  final String eventName;

  const EventVoteReviewWeb({
    Key? key,
    required this.eventRegistrationId,
    required this.eventId,
    required this.eventName,
  }) : super(key: key);

  @override
  State<EventVoteReviewWeb> createState() => _EventVoteReviewWebState();
}

class _EventVoteReviewWebState extends State<EventVoteReviewWeb> {
  bool isLoading = true;
  String? errorMessage;
  List<Map<String, dynamic>> votesReviewsData = [];
  String eventName = '';
  int totalVotesReviews = 0;

  @override
  void initState() {
    super.initState();
    _loadAllVotesAndReviews();
  }

  Future<void> _loadAllVotesAndReviews() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiUrlWithPrefix}/api/events/${widget.eventId}/votes-reviews/all'),
        headers: {
          'Content-Type': 'application/json',
          'homeID': WebAuthService.homeId.toString(),
          'currentUserId': WebAuthService.userId ?? '',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          votesReviewsData = List<Map<String, dynamic>>.from(data['votes_reviews'] ?? []);
          eventName = data['event_name'] ?? widget.eventName;
          totalVotesReviews = data['total_votes_reviews'] ?? 0;
          isLoading = false;
        });
      } else if (response.statusCode == 403) {
        setState(() {
          isLoading = false;
          errorMessage = 'Access denied: Manager role required';
        });
      } else {
        throw Exception('Failed to load votes and reviews: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Error loading data: $e';
      });
    }
  }

  String _formatDateTime(String? dateTimeString) {
    if (dateTimeString == null) return 'N/A';
    try {
      final dateTime = DateTime.parse(dateTimeString);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTimeString;
    }
  }

  Widget _buildStarDisplay(int? vote) {
    if (vote == null) return Text('No vote', style: TextStyle(color: Colors.grey[600]));
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < vote ? Icons.star : Icons.star_border,
          size: 20,
          color: index < vote ? Colors.amber : Colors.grey,
        );
      }),
    );
  }

  Widget _buildReviewsList(List<dynamic> reviews) {
    if (reviews.isEmpty) {
      return Text('No reviews', style: TextStyle(color: Colors.grey[600]));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: reviews.map((review) {
        final date = DateTime.tryParse(review['date'] ?? '');
        final formattedDate = date != null ? _formatDateTime(review['date']) : 'Unknown date';
        
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.rate_review, size: 14, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    formattedDate,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                review['review'] ?? '',
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildVotesReviewsTable() {
    if (votesReviewsData.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.rate_review, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'No votes or reviews yet',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Users who register for this event can submit votes and reviews',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Votes and Reviews ($totalVotesReviews)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            ...votesReviewsData.map((data) {
              final userName = data['user_name'] ?? 'Unknown User';
              final vote = data['vote'];
              final reviews = List<dynamic>.from(data['reviews'] ?? []);
              final registrationDate = _formatDateTime(data['registration_date']);

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // User info header
                    Row(
                      children: [
                        Icon(Icons.person, color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Registered: $registrationDate',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Vote section
                    Row(
                      children: [
                        Text(
                          'Vote: ',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[700],
                          ),
                        ),
                        _buildStarDisplay(vote),
                        if (vote != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            '($vote/5)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Reviews section
                    Text(
                      'Reviews (${reviews.length}):',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildReviewsList(reviews),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Votes & Reviews Management - $eventName',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllVotesAndReviews,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
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
                        onPressed: _loadAllVotesAndReviews,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Event Info Card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(Icons.event, color: AppColors.primary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      eventName,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'Event ID: ${widget.eventId}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  'Management View',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Votes and Reviews Table
                      _buildVotesReviewsTable(),
                    ],
                  ),
                ),
    );
  }
}