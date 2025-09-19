// lib/services/offer_actions.dart — callables with region + name fallback
import 'package:cloud_functions/cloud_functions.dart';

class OfferActions {
  OfferActions._();
  static final OfferActions instance = OfferActions._();

  /// Set once at startup (e.g., in main.dart) to your Cloud Functions region.
  /// Example for Sri Lanka: 'asia-south1'.
  String? preferredRegion;

  // If your server used different callable names, list them here.
  // First match that exists will be used automatically.
  final Map<String, List<String>> _nameMap = const {
    'proposeCounter': ['proposeCounter', 'offersProposeCounter', 'counterOffer', 'propose_counter'],
    'rejectOffer':    ['rejectOffer', 'offersReject', 'reject_offer'],
    'acceptOffer':    ['acceptOffer', 'offersAccept', 'accept_offer'],
  };

  List<String> get _regions {
    final pref = preferredRegion?.trim();
    final base = <String>[
      if (pref != null && pref.isNotEmpty) pref,
      // Common Firebase regions
      'asia-south1',
      'us-central1',
      'europe-west1',
    ];
    final seen = <String>{};
    return base.where(seen.add).toList();
  }

  HttpsCallable _fn(String region, String name) =>
      FirebaseFunctions.instanceFor(region: region).httpsCallable(name);

  Future<T> _callWithFallback<T>(String name, Map<String, dynamic> data) async {
    dynamic lastErr;
    for (final r in _regions) {
      try {
        final res = await _fn(r, name).call(data);
        return res.data as T;
      } catch (e) {
        lastErr = e;
      }
    }
    // Also try the default instance (no region), in case project default works.
    try {
      final res = await FirebaseFunctions.instance.httpsCallable(name).call(data);
      return res.data as T;
    } catch (_) {
      throw lastErr ?? Exception('Callable $name failed in all regions');
    }
  }

  Future<T> _callAny<T>(List<String> names, Map<String, dynamic> data) async {
    dynamic last;
    for (final n in names) {
      try { return await _callWithFallback<T>(n, data); } catch (e) { last = e; }
    }
    throw last ?? Exception('Callable not found. Tried: ${names.join(", ")}');
  }

  Future<void> proposeCounter({
    String? taskId,
    required String offerId,
    required num price,
    String? note,
  }) async {
    await _callAny<void>(_nameMap['proposeCounter']!, {
      'offerId': offerId,
      if (taskId?.isNotEmpty == true) 'taskId': taskId,
      'price': price,
      if (note?.isNotEmpty == true) 'note': note,
    });
  }

  Future<void> rejectOffer({
    String? taskId,
    required String offerId,
    String? reason,
  }) async {
    await _callAny<void>(_nameMap['rejectOffer']!, {
      'offerId': offerId,
      if (taskId?.isNotEmpty == true) 'taskId': taskId,
      if (reason?.isNotEmpty == true) 'reason': reason,
    });
  }

  Future<void> acceptOffer({
    String? taskId,
    required String offerId,
  }) async {
    await _callAny<void>(_nameMap['acceptOffer']!, {
      'offerId': offerId,
      if (taskId?.isNotEmpty == true) 'taskId': taskId,
    });
  }
}
