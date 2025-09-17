// lib/services/offer_actions.dart
import 'package:cloud_functions/cloud_functions.dart';

/// Thin wrapper over Cloud Functions for offer negotiation flows.
/// Keep client logic minimal; server enforces permissions/fees.
class OfferActions {
  OfferActions._();
  static final OfferActions instance = OfferActions._();

  HttpsCallable get _proposeCounterFn =>
      FirebaseFunctions.instance.httpsCallable('proposeCounter');
  HttpsCallable get _rejectOfferFn =>
      FirebaseFunctions.instance.httpsCallable('rejectOffer');
  HttpsCallable get _withdrawOfferFn =>
      FirebaseFunctions.instance.httpsCallable('withdrawOffer');
  HttpsCallable get _agreeToCounterFn =>
      FirebaseFunctions.instance.httpsCallable('agreeToCounter');
  HttpsCallable get _helperCounterFn =>
      FirebaseFunctions.instance.httpsCallable('helperCounter');
  HttpsCallable get _acceptOfferFn =>
      FirebaseFunctions.instance.httpsCallable('acceptOffer');

  /// Poster proposes a counter price.
  Future<void> proposeCounter({
    required String offerId,
    required num price,
    String? note,
  }) async {
    await _proposeCounterFn.call({
      'offerId': offerId,
      'price': price,
      if (note != null && note.isNotEmpty) 'note': note,
    });
  }

  /// Poster rejects an offer.
  Future<void> rejectOffer({
    required String offerId,
    String? reason,
  }) async {
    await _rejectOfferFn.call({
      'offerId': offerId,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    });
  }

  /// Helper withdraws their offer.
  Future<void> withdrawOffer({
    required String offerId,
  }) async {
    await _withdrawOfferFn.call({'offerId': offerId});
  }

  /// Helper agrees to the poster's counter.
  Future<void> agreeToCounter({
    required String offerId,
  }) async {
    await _agreeToCounterFn.call({'offerId': offerId});
  }

  /// Helper counters back with a new price.
  Future<void> helperCounter({
    required String offerId,
    required num price,
  }) async {
    await _helperCounterFn.call({
      'offerId': offerId,
      'price': price,
    });
  }

  /// Poster accepts an offer (origin-aware fee + assignment handled server-side).
  Future<void> acceptOffer({
    required String offerId,
  }) async {
    await _acceptOfferFn.call({'offerId': offerId});
  }
}
