import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single review left by a user for a completed task.
class Review {
  final String id;
  final String taskId;
  final String taskTitle;

  final String reviewerId;
  final String reviewerName;
  final String? reviewerAvatarUrl;

  final String ratedUserId;

  final double rating;
  final String reviewText;
  final Timestamp timestamp;

  Review({
    required this.id,
    required this.taskId,
    required this.taskTitle,
    required this.reviewerId,
    required this.reviewerName,
    this.reviewerAvatarUrl,
    required this.ratedUserId,
    required this.rating,
    required this.reviewText,
    required this.timestamp,
  });

  factory Review.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data() ?? {};

    return Review(
      id: snapshot.id,
      taskId: data['taskId'] as String? ?? '',
      taskTitle: data['taskTitle'] as String? ?? '',
      reviewerId: data['reviewerId'] as String? ?? '',
      reviewerName: data['reviewerName'] as String? ?? 'Anonymous',
      reviewerAvatarUrl: data['reviewerAvatarUrl'] as String?,
      ratedUserId: data['ratedUserId'] as String? ?? '',
      rating: (data['rating'] as num? ?? 0.0).toDouble(),
      reviewText: data['reviewText'] as String? ?? '',
      timestamp: data['timestamp'] as Timestamp? ?? Timestamp.now(),
    );
  }
}
