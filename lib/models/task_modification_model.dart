import 'package:cloud_firestore/cloud_firestore.dart';

class TaskModification {
  final String id;
  final String description;
  final double additionalCost;
  final String status; // 'pending', 'approved', 'rejected'
  final Timestamp timestamp;

  TaskModification({
    required this.id,
    required this.description,
    required this.additionalCost,
    required this.status,
    required this.timestamp,
  });

  factory TaskModification.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data() ?? {};
    return TaskModification(
      id: snapshot.id,
      description: data['description'] as String? ?? 'No description',
      additionalCost: (data['additionalCost'] as num? ?? 0.0).toDouble(),
      status: data['status'] as String? ?? 'pending',
      timestamp: data['timestamp'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'description': description,
      'additionalCost': additionalCost,
      'status': status,
      'timestamp': timestamp,
    };
  }
}
