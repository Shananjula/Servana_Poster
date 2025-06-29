import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single conversation channel between two or more users.
class ChatChannel {
  /// The unique ID of the chat channel document.
  /// Typically a composite key of participant IDs.
  final String id;

  /// A map of participant user IDs to their display names.
  /// e.g., {'userId1': 'Alice', 'userId2': 'Bob'}
  final Map<String, String> participantNames;

  /// A map of participant user IDs to their avatar URLs.
  final Map<String, String?> participantAvatars;

  /// The text of the last message sent in the channel.
  final String? lastMessage;

  /// The timestamp of the last message.
  final Timestamp? lastMessageTimestamp;

  /// The ID of the user who sent the last message.
  final String? lastMessageSenderId;

  /// A list of user IDs participating in the chat.
  /// This is useful for Firestore security rules and queries.
  final List<String> participants;

  ChatChannel({
    required this.id,
    required this.participantNames,
    required this.participantAvatars,
    this.lastMessage,
    this.lastMessageTimestamp,
    this.lastMessageSenderId,
    required this.participants,
  });

  /// Factory constructor to create a ChatChannel from a Firestore document.
  factory ChatChannel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return ChatChannel(
      id: doc.id,
      // Firestore stores maps as Map<String, dynamic>, so we cast it.
      participantNames: Map<String, String>.from(data['participantNames'] ?? {}),
      participantAvatars: Map<String, String?>.from(data['participantAvatars'] ?? {}),
      lastMessage: data['lastMessage'] as String?,
      lastMessageTimestamp: data['lastMessageTimestamp'] as Timestamp?,
      lastMessageSenderId: data['lastMessageSenderId'] as String?,
      // Firestore stores arrays as List<dynamic>, so we cast it.
      participants: List<String>.from(data['participants'] ?? []),
    );
  }

  /// Converts this ChatChannel object to a Map for writing to Firestore.
  Map<String, dynamic> toFirestore() {
    return {
      'participantNames': participantNames,
      'participantAvatars': participantAvatars,
      'lastMessage': lastMessage,
      'lastMessageTimestamp': lastMessageTimestamp,
      'lastMessageSenderId': lastMessageSenderId,
      'participants': participants,
    };
  }
}
