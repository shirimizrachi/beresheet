import 'package:beresheet_app/services/modern_localization_service.dart';
import 'package:beresheet_app/services/user_session_service.dart';
import 'package:beresheet_app/config/app_config.dart';
import 'package:beresheet_app/utils/direction_utils.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class EventVoteReviewScreen extends StatefulWidget {
  final String eventRegistrationId;
  final String eventId;
  final String eventName;

  const EventVoteReviewScreen({
    Key? key,
    required this.eventRegistrationId,
    required this.eventId,
    required this.eventName,
  }) : super(key: key);

  @override
  State<EventVoteReviewScreen> createState() => _EventVoteReviewScreenState();
}

class _EventVoteReviewScreenState extends State<EventVoteReviewScreen> {
  bool isLoading = true;
  String? errorMessage;
  int? currentVote;
  List<Map<String, dynamic>> reviews = [];
  final TextEditingController _reviewController = TextEditingController();
  bool isSubmittingVote = false;
  bool isSubmittingReview = false;

  @override
  void initState() {
    super.initState();
    _loadVoteAndReviews();
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _loadVoteAndReviews() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final currentUserId = await UserSessionService.getUserId();
      final homeId = await UserSessionService.gethomeID();

      if (currentUserId == null || homeId == null) {
        throw Exception('User not logged in');
      }

      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/api/events/${widget.eventId}/vote-review'),
        headers: {
          'Content-Type': 'application/json',
          'homeID': homeId.toString(),
          'userId': currentUserId,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          currentVote = data['vote'];
          reviews = List<Map<String, dynamic>>.from(data['reviews'] ?? []);
          isLoading = false;
        });
      } else if (response.statusCode == 404) {
        // No existing vote/review data
        setState(() {
          currentVote = null;
          reviews = [];
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load vote and reviews: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Error loading data: $e';
      });
    }
  }

  Future<void> _submitVote(int vote) async {
    setState(() {
      isSubmittingVote = true;
    });

    try {
      final currentUserId = await UserSessionService.getUserId();
      final homeId = await UserSessionService.gethomeID();

      if (currentUserId == null || homeId == null) {
        throw Exception('User not logged in');
      }

      final response = await http.put(
        Uri.parse('${AppConfig.apiBaseUrl}/api/events/${widget.eventId}/vote-review'),
        headers: {
          'Content-Type': 'application/json',
          'homeID': homeId.toString(),
          'userId': currentUserId,
        },
        body: json.encode({
          'vote': vote,
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          currentVote = vote;
          isSubmittingVote = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.voteSubmittedSuccessfully),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Failed to submit vote: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        isSubmittingVote = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting vote: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _submitReview() async {
    final reviewText = _reviewController.text.trim();
    if (reviewText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.pleaseEnterReview),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      isSubmittingReview = true;
    });

    try {
      final currentUserId = await UserSessionService.getUserId();
      final homeId = await UserSessionService.gethomeID();

      if (currentUserId == null || homeId == null) {
        throw Exception('User not logged in');
      }

      final response = await http.put(
        Uri.parse('${AppConfig.apiBaseUrl}/api/events/${widget.eventId}/vote-review'),
        headers: {
          'Content-Type': 'application/json',
          'homeID': homeId.toString(),
          'userId': currentUserId,
        },
        body: json.encode({
          'review_text': reviewText,
        }),
      );

      if (response.statusCode == 200) {
        _reviewController.clear();
        await _loadVoteAndReviews(); // Refresh to show new review
        setState(() {
          isSubmittingReview = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.reviewSubmittedSuccessfully),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Failed to submit review: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        isSubmittingReview = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting review: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildStarRating() {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.rateThisEvent,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starValue = index + 1;
                return GestureDetector(
                  onTap: isSubmittingVote ? null : () => _submitVote(starValue),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      starValue <= (currentVote ?? 0) ? Icons.star : Icons.star_border,
                      size: 40,
                      color: starValue <= (currentVote ?? 0) ? Colors.amber : Colors.grey,
                    ),
                  ),
                );
              }),
            ),
            if (currentVote != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Your rating: $currentVote star${currentVote! > 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            if (isSubmittingVote)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewSection() {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.writeReview,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reviewController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: context.l10n.shareYourExperience,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: theme.colorScheme.primary),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isSubmittingReview ? null : _submitReview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: isSubmittingReview
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(context.l10n.submitReview),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewsList() {
    final theme = Theme.of(context);
    
    if (reviews.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(Icons.reviews, size: 48, color: Colors.grey),
              const SizedBox(height: 8),
              Text(
                context.l10n.noReviewsYet,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(
            context.l10n.yourReviews,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        ...reviews.map((review) {
          final date = DateTime.parse(review['date']);
          final formattedDate = '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
          
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.rate_review, color: theme.colorScheme.primary, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        formattedDate,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    review['review'],
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.l10n.voteAndReview,
          style: TextStyle(
            color: theme.colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: theme.colorScheme.primary,
        iconTheme: IconThemeData(color: theme.colorScheme.onPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadVoteAndReviews,
            tooltip: context.l10n.refresh,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
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
                          onPressed: _loadVoteAndReviews,
                          child: Text(context.l10n.retry),
                        ),
                      ],
                    ),
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
                              Icon(Icons.event, color: theme.colorScheme.primary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.eventName,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'ID: ${widget.eventRegistrationId}',
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
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Star Rating Section
                      _buildStarRating(),
                      
                      const SizedBox(height: 16),
                      
                      // Review Section
                      _buildReviewSection(),
                      
                      const SizedBox(height: 16),
                      
                      // Reviews List
                      _buildReviewsList(),
                    ],
                  ),
                ),
    );
  }
}