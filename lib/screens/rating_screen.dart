import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:servana/models/task_model.dart';
import 'package:servana/services/firestore_service.dart';

class RatingScreen extends StatefulWidget {
  final Task task;
  final String personToRateId;
  final String personToRateName;
  final String? personToRateAvatarUrl;

  const RatingScreen({
    Key? key,
    required this.task,
    required this.personToRateId,
    required this.personToRateName,
    this.personToRateAvatarUrl,
  }) : super(key: key);

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  double _rating = 0.0;
  final _reviewController = TextEditingController();
  bool _isLoading = false;

  /// Submits the review by calling the centralized service function.
  Future<void> _submitReview() async {
    if (_rating == 0.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a star rating.'), backgroundColor: Colors.orange),
      );
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    setState(() => _isLoading = true);

    try {
      await _firestoreService.submitReviewAndCloseTask(
        task: widget.task,
        ratedUserId: widget.personToRateId,
        reviewerId: currentUser.uid,
        reviewerName: currentUser.displayName ?? 'Anonymous',
        reviewerAvatarUrl: currentUser.photoURL,
        rating: _rating,
        reviewText: _reviewController.text.trim(),
      );

      if (mounted) {
        // Pop back to the root screen (e.g., home screen) after successful rating
        Navigator.of(context).popUntil((route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thank you for your feedback!'), backgroundColor: Colors.green),
        );
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit review: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rate Your Experience'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 45,
                backgroundImage: widget.personToRateAvatarUrl != null && widget.personToRateAvatarUrl!.isNotEmpty
                    ? NetworkImage(widget.personToRateAvatarUrl!)
                    : null,
                child: (widget.personToRateAvatarUrl == null || widget.personToRateAvatarUrl!.isEmpty)
                    ? const Icon(Icons.person, size: 45)
                    : null,
              ),
              const SizedBox(height: 16),
              Text(
                'How was your experience with ${widget.personToRateName}?',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Your feedback helps build a trusted community.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 32),
              _buildStarRating(),
              const SizedBox(height: 32),
              TextField(
                controller: _reviewController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Share more details... (optional)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitReview,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: _isLoading
                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white))
                      : const Text('Submit Review & Complete Task'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStarRating() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        return IconButton(
          iconSize: 40,
          splashRadius: 40,
          icon: Icon(
            index < _rating ? Icons.star_rounded : Icons.star_border_rounded,
            color: Colors.amber,
          ),
          onPressed: () {
            setState(() {
              _rating = index + 1.0;
            });
          },
        );
      }),
    );
  }
}
