// lib/services/chat_navigation.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'chat_id.dart';
import 'package:servana/screens/chat_thread_screen.dart';

Future<void> openChatWith({
  required BuildContext context,
  String? chatId,
  String? posterId,
  String? helperId,
  String? taskId,
  String? highlightOfferId,
}) async {
  String? cid = chatId;

  // Resolve missing pieces
  if (cid == null) {
    if (taskId == null || helperId == null || posterId == null || posterId.isEmpty) {
      // Try to infer posterId from task
      if (taskId != null && (posterId == null || posterId.isEmpty)) {
        final tSnap = await FirebaseFirestore.instance.doc('tasks/$taskId').get();
        posterId = (tSnap.data() ?? const {})['posterId']?.toString();
      }
    }
    if (taskId == null || helperId == null || posterId == null || posterId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing identifiers for chat')),
      );
      return;
    }
    cid = chatIdFor(posterId: posterId, helperId: helperId, taskId: taskId);
    // Ensure chat exists
    await FirebaseFirestore.instance.doc('chats/$cid').set({
      'chatId': cid, 'taskId': taskId, 'posterId': posterId, 'helperId': helperId,
      'members': [posterId, helperId],
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  if (!context.mounted) return;
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => ChatThreadScreen(chatId: cid!, highlightOfferId: highlightOfferId),
  ));
}

/// Open chat using only offerId (and optionally taskId). Good for deep-links from push.
Future<void> openChatForOffer({
  required BuildContext context,
  required String offerId,
  String? taskId,
}) async {
  String? t = taskId;
  Map<String, dynamic>? offer;
  // Prefer top-level /offers mirror if present
  final top = await FirebaseFirestore.instance.doc('offers/$offerId').get();
  if (top.exists) {
    offer = top.data();
    t = (offer?['taskId'] ?? t)?.toString();
  }
  // Fall back to subcollection if we were given taskId
  if (offer == null && t != null) {
    final sub = await FirebaseFirestore.instance.doc('tasks/$t/offers/$offerId').get();
    if (sub.exists) offer = sub.data();
  }
  if (offer == null || t == null) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Offer not found')));
    return;
  }
  final posterId = (offer['posterId'] ?? '').toString();
  final helperId = (offer['helperId'] ?? '').toString();
  if (posterId.isEmpty || helperId.isEmpty) {
    // Resolve missing poster from task
    final tSnap = await FirebaseFirestore.instance.doc('tasks/$t').get();
    final p = (tSnap.data() ?? const {})['posterId']?.toString();
    await openChatWith(context: context, posterId: p, helperId: helperId, taskId: t, highlightOfferId: offerId);
    return;
  }
  await openChatWith(context: context, posterId: posterId, helperId: helperId, taskId: t, highlightOfferId: offerId);
}
