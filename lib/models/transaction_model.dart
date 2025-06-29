import 'package:cloud_firestore/cloud_firestore.dart';

enum TransactionType { topUp, withdrawal, commission, payment, refund }

class TransactionModel {
  final String id;
  final double amount;
  final TransactionType type;
  final String description;
  final Timestamp timestamp;
  final String? relatedTaskId;

  TransactionModel({
    required this.id,
    required this.amount,
    required this.type,
    required this.description,
    required this.timestamp,
    this.relatedTaskId,
  });

  factory TransactionModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    // Convert string from Firestore to enum
    TransactionType type = TransactionType.values.firstWhere(
            (e) => e.name == (data['type'] as String?),
        orElse: () => TransactionType.topUp);

    return TransactionModel(
      id: doc.id,
      amount: (data['amount'] as num? ?? 0.0).toDouble(),
      type: type,
      description: data['description'] as String? ?? 'No description',
      timestamp: data['timestamp'] as Timestamp? ?? Timestamp.now(),
      relatedTaskId: data['relatedTaskId'] as String?,
    );
  }
}
