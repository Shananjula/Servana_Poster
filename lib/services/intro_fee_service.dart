// lib/services/intro_fee_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class IntroFeeService {
  static final _db = FirebaseFirestore.instance;

  /// Returns true if chat is already unlocked for this poster/helper pair.
  /// Safely returns false if ids are missing OR Firestore throws (rules/offline).
  static Future<bool> isPairUnlocked({
    required String posterId,
    required String helperId,
  }) async {
    try {
      if (posterId.isEmpty || helperId.isEmpty) return false;
      final ref = _db
          .collection('chatUnlocks')
          .doc(posterId)
          .collection('helpers')
          .doc(helperId);
      final snap = await ref.get();
      return snap.exists;
    } catch (_) {
      // Permission/invalid path/offline → treat as locked
      return false;
    }
  }

  /// Debits wallet and marks unlocked. Returns true on success.
  /// This is tolerant; it won't throw to the UI.
  static Future<bool> unlockPair({
    required String posterId,
    required String helperId,
    required int feeCoins,
  }) async {
    try {
      if (posterId.isEmpty || helperId.isEmpty || feeCoins <= 0) return false;
      final batch = _db.batch();
      final walletRef = _db.collection('wallets').doc(posterId);
      final unlockRef = _db
          .collection('chatUnlocks')
          .doc(posterId)
          .collection('helpers')
          .doc(helperId);

      batch.set(
        unlockRef,
        {
          'helperId': helperId,
          'unlockedAt': FieldValue.serverTimestamp(),
          'fee': feeCoins,
        },
        SetOptions(merge: true),
      );
      batch.set(
        walletRef,
        {'coins': FieldValue.increment(-feeCoins)},
        SetOptions(merge: true),
      );

      await batch.commit();
      return true;
    } catch (_) {
      return false;
    }
  }
}
