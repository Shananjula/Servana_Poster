import 'package:cloud_firestore/cloud_firestore.dart';

class Offer {
  final String id;
  final String taskId;
  final String helperId;
  final String helperName;
  final String? helperAvatarUrl; // FIX: Renamed from helperPhotoUrl to match usage
  final double amount;
  final String message;
  final Timestamp timestamp;
  final String? status;
  final String? numberExchangeStatus; // FIX: Added missing field
  final int? helperTrustScore;      // FIX: Added missing field

  Offer({
    required this.id,
    required this.taskId,
    required this.helperId,
    required this.helperName,
    this.helperAvatarUrl,
    required this.amount,
    required this.message,
    required this.timestamp,
    this.status,
    this.numberExchangeStatus, // FIX: Added to constructor
    this.helperTrustScore,     // FIX: Added to constructor
  });

  factory Offer.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw StateError("Missing data for Offer doc: ${doc.id}");
    }
    return Offer(
      id: doc.id,
      taskId: data['taskId'] ?? '',
      helperId: data['helperId'] ?? '',
      helperName: data['helperName'] ?? 'Anonymous',
      helperAvatarUrl: data['helperAvatarUrl'], // FIX: Using new field name
      amount: (data['amount'] ?? 0).toDouble(),
      message: data['message'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
      status: data['status'],
      numberExchangeStatus: data['numberExchangeStatus'], // FIX: Reading from Firestore
      helperTrustScore: data['helperTrustScore'],         // FIX: Reading from Firestore
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'taskId': taskId,
      'helperId': helperId,
      'helperName': helperName,
      'helperAvatarUrl': helperAvatarUrl, // FIX: Using new field name
      'amount': amount,
      'message': message,
      'timestamp': timestamp,
      'status': status,
      'numberExchangeStatus': numberExchangeStatus, // FIX: Writing to Firestore
      'helperTrustScore': helperTrustScore,         // FIX: Writing to Firestore
    };
  }
}
