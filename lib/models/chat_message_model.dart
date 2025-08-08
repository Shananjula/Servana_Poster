import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String text;
  final String senderId;
  final Timestamp timestamp;
  final String type; // 'text', 'image', or 'offer'
  final String? imageUrl;
  final bool? isFlagged;

  final double? offerAmount;
  final String? offerStatus;
  final String? offerId; // --- ADDED THIS LINE ---

  ChatMessage({
    required this.id,
    required this.text,
    required this.senderId,
    required this.timestamp,
    this.type = 'text',
    this.imageUrl,
    this.isFlagged,
    this.offerAmount,
    this.offerStatus,
    this.offerId, // --- ADDED THIS LINE ---
  });

  factory ChatMessage.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data() ?? {};
    return ChatMessage(
      id: snapshot.id,
      text: data['text'] as String? ?? '',
      senderId: data['senderId'] as String? ?? '',
      timestamp: data['timestamp'] as Timestamp? ?? Timestamp.now(),
      type: data['type'] as String? ?? 'text',
      imageUrl: data['imageUrl'] as String?,
      isFlagged: data['isFlagged'] as bool?,
      offerAmount: (data['offerAmount'] as num?)?.toDouble(),
      offerStatus: data['offerStatus'] as String?,
      offerId: data['offerId'] as String?, // --- ADDED THIS LINE ---
    );
  }
}