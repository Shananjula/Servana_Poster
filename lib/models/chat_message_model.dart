import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String text;
  final String senderId;
  final Timestamp timestamp;
  // --- NEW: For supporting images and other types ---
  final String type; // 'text' or 'image'
  final String? imageUrl;
  final bool? isFlagged; // For safety agent

  ChatMessage({
    required this.id,
    required this.text,
    required this.senderId,
    required this.timestamp,
    this.type = 'text',
    this.imageUrl,
    this.isFlagged,
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
    );
  }
}
