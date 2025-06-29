import 'package:cloud_firestore/cloud_firestore.dart';

class Service {
  final String id;
  final String title;
  final String category;
  final double rate;
  final String rateType;
  final bool isActive;

  Service({
    required this.id,
    required this.title,
    required this.category,
    required this.rate,
    required this.rateType,
    this.isActive = true,
  });

  factory Service.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot, SnapshotOptions? options) {
    final data = snapshot.data();
    return Service(
      id: snapshot.id,
      title: data?['title'] ?? 'No Title',
      category: data?['category'] ?? 'Uncategorized',
      rate: (data?['rate'] as num? ?? 0.0).toDouble(),
      rateType: data?['rateType'] ?? 'per hour',
      isActive: data?['isActive'] ?? true,
    );
  }
}
