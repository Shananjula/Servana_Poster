// lib/services/offer_accept_service.dart
//
// Poster-side helper: accept an offer. Uses callable first,
// falls back to client-side updates so UX never stalls.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class OfferAcceptService {
  static const _region = 'us-central1'; // change if your CF region differs

  static Future<void> acceptOffer({
    required String taskId,
    required String offerId,
  }) async {
    try {
      final fn = FirebaseFunctions.instanceFor(region: _region).httpsCallable('acceptOffer');
      await fn.call(<String, dynamic>{'taskId': taskId, 'offerId': offerId});
    } catch (e, st) {
      debugPrint('[acceptOffer] callable failed → fallback: $e\n$st');
      final db = FirebaseFirestore.instance;
      final offerRef = db.collection('tasks').doc(taskId).collection('offers').doc(offerId);
      final taskRef  = db.collection('tasks').doc(taskId);
      final now = FieldValue.serverTimestamp();
      await db.runTransaction((tx) async {
        tx.update(offerRef, {'status': 'accepted', 'updatedAt': now});
        tx.update(taskRef,  {'acceptedOfferId': offerId, 'status': 'assigned', 'updatedAt': now});
      });
    }
  }
}