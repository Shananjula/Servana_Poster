// lib/services/firestore_service.dart — Poster app
// -----------------------------------------------------------------------------
// Backward-compatible + unified cross-app contract.
// • Offers: canonical tasks/{taskId}/offers, but legacy top-level stream kept.
// • Accept Offer: via CF 'acceptOffer' with a safe fallback.
// • Disputes helpers present.
// • Phone reads tolerant.
// • Chats: canonical IDs via ChatId; legacy helper provided.
// -----------------------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../utils/chat_id.dart';

class FirestoreService {
  FirestoreService._();
  static final FirestoreService _instance = FirestoreService._();
  factory FirestoreService() => _instance;

  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  // ---------- USERS ----------------------------------------------------------

  Future<Map<String, dynamic>?> getUser(String uid) async {
    final snap = await _db.collection('users').doc(uid).get();
    return snap.data();
  }

  Future<String?> getUserPhone(String uid) async {
    final data = await getUser(uid);
    if (data == null) return null;
    return (data['phone'] as String?) ?? (data['phoneNumber'] as String?);
  }

  // ---------- OFFERS (canonical + legacy-safe) -------------------------------

  CollectionReference<Map<String, dynamic>> _offersCol(String taskId) =>
      _db.collection('tasks').doc(taskId).collection('offers');

  Stream<QuerySnapshot<Map<String, dynamic>>> streamOffersForTask(
      String taskId,
      ) {
    return _offersCol(taskId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Back-compat alias used by older widgets
  Stream<QuerySnapshot<Map<String, dynamic>>> streamOffers(String taskId) =>
      streamOffersForTask(taskId);

  // Legacy top-level path (if still in your DB): /offers filtered by taskId
  Stream<QuerySnapshot<Map<String, dynamic>>> streamOffersTopLevelLegacy(
      String taskId,
      ) {
    return _db
        .collection('offers')
        .where('taskId', isEqualTo: taskId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<String> submitOffer({
    required String taskId,
    required Map<String, dynamic> offerData,
  }) async {
    // Poster typically reviews, not submits, but keep for tests/tools.
    final uid = _auth.currentUser?.uid;
    final payload = <String, dynamic>{
      ...offerData,
      'taskId': taskId,
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'status': offerData['status'] ?? 'submitted',
    };
    final ref = await _offersCol(taskId).add(payload);
    return ref.id;
  }

  Future<void> updateOffer({
    required String taskId,
    required String offerId,
    required Map<String, dynamic> data,
  }) {
    return _offersCol(taskId).doc(offerId).set(data, SetOptions(merge: true));
  }

  // ---------- ACCEPT OFFER (primary CF + safe fallback) ----------------------

  Future<void> acceptOffer({
    required String taskId,
    required String offerId,
  }) async {
    try {
      final callable = _functions.httpsCallable('acceptOffer');
      await callable.call({'taskId': taskId, 'offerId': offerId});
    } catch (e) {
      if (kDebugMode) {
        debugPrint('acceptOffer CF failed, using fallback: $e');
      }
      await _db.collection('tasks').doc(taskId).set({
        'acceptedOfferId': offerId,
        'status': 'in_progress',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  // Back-compat: chat-message accept path supported (routes to CF)
  Future<void> acceptOfferFromChatMessage({
    required String taskId,
    required String offerMessageId,
  }) async {
    try {
      final callable = _functions.httpsCallable('acceptOffer');
      await callable.call({
        'taskId': taskId,
        'offerMessageId': offerMessageId,
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            'acceptOfferFromChatMessage CF failed; manual mapping required: $e');
      }
    }
  }

  // ---------- CHATS (canonical IDs + legacy helper) --------------------------

  CollectionReference<Map<String, dynamic>> get _chats =>
      _db.collection('chats');

  Future<String> createOrGetTaskChannel({
    required String otherUid,
    required String taskId,
  }) async {
    final me = _auth.currentUser?.uid;
    if (me == null) throw StateError('Not signed in');

    final channelId = ChatId.forTask(uidA: me, uidB: otherUid, taskId: taskId);
    final now = FieldValue.serverTimestamp();

    await _chats.doc(channelId).set({
      'id': channelId,
      'members': [me, otherUid],
      'taskId': taskId,
      'type': 'task',
      'createdAt': now,
      'updatedAt': now,
    }, SetOptions(merge: true));

    return channelId;
  }

  Future<String> createOrGetDirectChannel({
    required String otherUid,
  }) async {
    final me = _auth.currentUser?.uid;
    if (me == null) throw StateError('Not signed in');

    final channelId = ChatId.forDirect(uidA: me, uidB: otherUid);
    final now = FieldValue.serverTimestamp();

    await _chats.doc(channelId).set({
      'id': channelId,
      'members': [me, otherUid],
      'type': 'direct',
      'createdAt': now,
      'updatedAt': now,
    }, SetOptions(merge: true));

    return channelId;
  }

  String buildChannelId({required String a, required String b, String? taskId}) {
    return taskId == null
        ? ChatId.forDirect(uidA: a, uidB: b)
        : ChatId.forTask(uidA: a, uidB: b, taskId: taskId);
  }

  // ---------- DISPUTES -------------------------------------------------------

  Future<void> addEvidenceToDispute(String disputeId, String url) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Not signed in');

    final evidenceCol =
    _db.collection('disputes').doc(disputeId).collection('evidence');

    await evidenceCol.add({
      'url': url,
      'addedBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _db.collection('disputes').doc(disputeId).set({
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> resolveDispute(
      String disputeId, {
        required String resolution,
        String? notes,
        int? posterCoinDelta,
        int? helperCoinDelta,
      }) async {
    try {
      final callable = _functions.httpsCallable('resolveDispute');
      await callable.call({
        'disputeId': disputeId,
        'resolution': resolution,
        'notes': notes,
        'posterCoinDelta': posterCoinDelta,
        'helperCoinDelta': helperCoinDelta,
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('resolveDispute CF failed, falling back: $e');
      }
      await _db.collection('disputes').doc(disputeId).set({
        'status': 'resolved',
        'resolution': resolution,
        if (notes != null) 'notes': notes,
        'resolvedAt': FieldValue.serverTimestamp(),
        'resolvedBy': _auth.currentUser?.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }
}
