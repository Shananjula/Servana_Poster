import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  final String id;
  final String title;
  final String body;
  final Timestamp timestamp;
  final String type; // e.g., 'new_offer', 'task_assigned', 'dispute_update', 'new_badge'
  final String? relatedId; // e.g., taskId, userId
  final bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    required this.type,
    this.relatedId,
    this.isRead = false,
  });

  factory AppNotification.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AppNotification(
      id: doc.id,
      title: data['title'] as String? ?? 'No Title',
      body: data['body'] as String? ?? 'No content',
      timestamp: data['timestamp'] ?? Timestamp.now(),
      type: data['type'] as String? ?? 'general',
      relatedId: data['relatedId'] as String?,
      isRead: data['isRead'] as bool? ?? false,
    );
  }
}
