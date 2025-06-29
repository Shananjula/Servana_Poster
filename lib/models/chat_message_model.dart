import 'package:cloud_firestore/cloud_firestore.dart';

// The data model for a single chat message.
class ChatMessage {
  final String id;
  final String text;
  final String senderId;
  final Timestamp timestamp;

  ChatMessage({
    required this.id,
    required this.text,
    required this.senderId,
    required this.timestamp,
  });

  factory ChatMessage.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot, [SnapshotOptions? options]) {
    final data = snapshot.data() ?? {};
    return ChatMessage(
      id: snapshot.id,
      text: data['text'] ?? '',
      senderId: data['senderId'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
    );
  }
}
