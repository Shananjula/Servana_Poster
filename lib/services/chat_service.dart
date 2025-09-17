// lib/services/chat_service.dart
//
// Hotfix: adds a public `resolveChatId(...)` so existing code like
//   _svc.resolveChatId(taskId: ..., posterId: ..., helperId: ...)
// compiles again. Also keeps `ensureChat(...)` and `sendText(...)`.
// The chat doc writes BOTH `participantIds` and `members` for
// Firestore rules compatibility.
//
// Drop into Servana_Poster at: lib/services/chat_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatService {
  ChatService({FirebaseFirestore? db, FirebaseAuth? auth})
      : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  String get uid {
    final u = _auth.currentUser?.uid;
    if (u == null) throw StateError('Not signed in');
    return u;
  }

  // Stable deterministic chat id for a (taskId, posterId, helperId) pair.
  String resolveChatId({
    required String taskId,
    required String posterId,
    required String helperId,
  }) {
    final ids = [posterId, helperId]..sort();
    return 't:$taskId:${ids[0]}_${ids[1]}';
  }

  /// Ensure a chat doc exists (id derived from resolveChatId) and return its id.
  Future<String> ensureChat({
    required String taskId,
    required String posterId,
    required String helperId,
    Map<String, dynamic>? taskPreview,
  }) async {
    final chatId = resolveChatId(taskId: taskId, posterId: posterId, helperId: helperId);
    final ref = _db.collection('chats').doc(chatId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        tx.set(ref, {
          'taskId': taskId,
          'posterId': posterId,
          'helperId': helperId,
          // Write BOTH fields to satisfy any rule variants
          'participantIds': [posterId, helperId],
          'members': [posterId, helperId],
          'createdAt': FieldValue.serverTimestamp(),
          'lastMsgAt': FieldValue.serverTimestamp(),
          if (taskPreview != null) 'taskPreview': taskPreview,
        });
      } else {
        // Merge any missing compatibility fields, without clobbering other data
        final data = (snap.data() as Map<String, dynamic>?) ?? const {};
        final Map<String, dynamic> patch = {};
        if (data['participantIds'] is! List) {
          patch['participantIds'] = [posterId, helperId];
        }
        if (data['members'] is! List) {
          patch['members'] = [posterId, helperId];
        }
        if (patch.isNotEmpty) {
          tx.set(ref, patch, SetOptions(merge: true));
        }
      }
    });

    return chatId;
  }

  Future<void> sendText(String chatId, String text) async {
    final chatRef = _db.collection('chats').doc(chatId);
    final msgRef = chatRef.collection('messages').doc();
    await _db.runTransaction((tx) async {
      tx.set(msgRef, {
        'type': 'text',
        'text': text,
        'authorId': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.set(chatRef, {
        'lastMsg': text,
        'lastMsgAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }
}