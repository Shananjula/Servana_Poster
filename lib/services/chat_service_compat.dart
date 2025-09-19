// lib/services/chat_service_compat.dart — deterministic channel + task context
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatServiceCompat {
  ChatServiceCompat._();
  static final ChatServiceCompat instance = ChatServiceCompat._();

  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser!.uid;

  /// Creates or fetches a deterministic channel between current user and [otherUserId].
  /// If [taskId] is provided, the channel id is namespaced to that task.
  Future<String> createOrGetChannel(
    String otherUserId, {
    String? taskId,
    String? taskTitle,
    Map<String, String>? participantNames,
  }) async {
    final a = _uid, b = otherUserId;
    final pair = [a, b]..sort();
    final baseId = '${pair[0]}__${pair[1]}';
    final channelId = (taskId == null || taskId.isEmpty) ? baseId : '${baseId}__task__$taskId';

    final cref = _db.collection('chats').doc(channelId);
    final snap = await cref.get();
    final now = FieldValue.serverTimestamp();

    final data = <String, dynamic>{
      'participantIds': [a, b],
      if (participantNames != null && participantNames.isNotEmpty) 'participantNames': participantNames,
      if (taskId != null && taskId.isNotEmpty) 'taskId': taskId,
      if (taskTitle != null && taskTitle.isNotEmpty) 'taskTitle': taskTitle,
      'updatedAt': now,
    };

    if (!snap.exists) {
      await cref.set({...data, 'createdAt': now}, SetOptions(merge: true));
    } else {
      await cref.set(data, SetOptions(merge: true));
    }
    return channelId;
  }
}
