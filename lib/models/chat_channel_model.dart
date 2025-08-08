import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single conversation channel between two or more users.
class ChatChannel {
  final String id;
  final String taskTitle;
  final Map<String, String> participantNames;
  final Map<String, String?> participantAvatars;
  final String? lastMessage;
  final Timestamp? lastMessageTimestamp;
  final String? lastMessageSenderId;
  final List<String> participantIds;

  ChatChannel({
    required this.id,
    required this.taskTitle,
    required this.participantNames,
    required this.participantAvatars,
    this.lastMessage,
    this.lastMessageTimestamp,
    this.lastMessageSenderId,
    required this.participantIds,
  });

  /// Factory constructor to create a ChatChannel from a Firestore document.
  factory ChatChannel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    // --- THIS IS THE FIX ---
    // This new logic safely builds the participantNames map.
    // It checks each entry and provides a default value if a name is null.
    final namesFromDb = data['participantNames'] as Map<String, dynamic>? ?? {};
    final safeParticipantNames = <String, String>{};
    namesFromDb.forEach((key, value) {
      safeParticipantNames[key] = value as String? ?? 'Unknown User';
    });

    return ChatChannel(
      id: doc.id,
      taskTitle: data['taskTitle'] as String? ?? 'Untitled Task',
      participantNames: safeParticipantNames, // Use the new safe map
      participantAvatars: Map<String, String?>.from(data['participantAvatars'] ?? {}),
      lastMessage: data['lastMessage'] as String?,
      lastMessageTimestamp: data['lastMessageTimestamp'] as Timestamp?,
      lastMessageSenderId: data['lastMessageSenderId'] as String?,
      participantIds: List<String>.from(data['participantIds'] ?? []),
    );
  }

  /// Converts this ChatChannel object to a Map for writing to Firestore.
  Map<String, dynamic> toFirestore() {
    return {
      'taskTitle': taskTitle,
      'participantNames': participantNames,
      'participantAvatars': participantAvatars,
      'lastMessage': lastMessage,
      'lastMessageTimestamp': lastMessageTimestamp,
      'lastMessageSenderId': lastMessageSenderId,
      'participantIds': participantIds,
    };
  }
}
