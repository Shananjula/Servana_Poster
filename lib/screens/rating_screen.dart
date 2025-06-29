import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:helpify/models/user_model.dart';
import '../models/task_model.dart';

/// A screen for users to rate each other after a task is completed.
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
  double _rating = 0.0;
  final _reviewController = TextEditingController();
  bool _isLoading = false;

  /// Submits the review and updates the user's average rating in a single transaction.
  Future<void> _submitReview() async {
    if (_rating == 0.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a star rating.'), backgroundColor: Colors.red),
      );
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to leave a review.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final ratedUserRef = FirebaseFirestore.instance.collection('users').doc(widget.personToRateId);
    final reviewRef = FirebaseFirestore.instance.collection('reviews').doc();
    final taskRef = FirebaseFirestore.instance.collection('tasks').doc(widget.task.id);

    try {
      // Use a transaction to ensure all database operations succeed or fail together.
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final ratedUserDoc = await transaction.get(ratedUserRef);
        if (!ratedUserDoc.exists) {
          throw Exception("User to be rated not found!");
        }

        final ratedUserData = HelpifyUser.fromFirestore(ratedUserDoc);

        // Calculate new average rating
        final oldRatingTotal = ratedUserData.averageRating * ratedUserData.ratingCount;
        final newRatingCount = ratedUserData.ratingCount + 1;
        final newAverageRating = (oldRatingTotal + _rating) / newRatingCount;

        // 1. Update the rated user's profile with the new average and count.
        transaction.update(ratedUserRef, {
          'averageRating': newAverageRating,
          'ratingCount': newRatingCount,
        });

        // 2. Create the new review document.
        transaction.set(reviewRef, {
          'rating': _rating,
          'reviewText': _reviewController.text.trim(),
          'taskId': widget.task.id,
          'taskTitle': widget.task.title,
          'reviewerId': currentUser.uid,
          'reviewerName': currentUser.displayName ?? 'Anonymous',
          'reviewerAvatarUrl': currentUser.photoURL,
          'ratedUserId': widget.personToRateId,
          'timestamp': FieldValue.serverTimestamp(),
        });

        // 3. Mark the task as 'completed'.
        transaction.update(taskRef, {
          'status': 'completed',
          'ratedAt': FieldValue.serverTimestamp(),
        });
      });

      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thank you for your feedback!'), backgroundColor: Colors.green),
        );
      }

    } catch (e) {
      print("Failed to submit review: $e");
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
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: theme.textTheme.bodyLarge?.color,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 45,
                backgroundColor: theme.colorScheme.surfaceVariant,
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
                  fillColor: theme.colorScheme.surface,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitReview,
                style: theme.elevatedButtonTheme.style,
                child: _isLoading
                    ? const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white))
                    : const Text('Submit Review'),
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
