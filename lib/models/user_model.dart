// lib/models/user_model.dart
//
// HelpifyUser / ServanaUser
// • Unified user domain model that is tolerant to missing/legacy fields.
// • Includes fields referenced across the app: role/uiMode, verification,
//   ratings, wallet, categories, profile, portfolio, languages, etc.
// • Provides fromFirestore(...) and toMap(...), plus some handy computed getters.
//
// Firestore (superset; all fields optional):
// users/{uid} {
//   displayName, email, phone, photoURL,
//   role: 'poster'|'helper',
//   uiMode: 'poster'|'helper',              // view mode when role == 'helper'
//   isHelper: bool,
//   verificationStatus: 'not_started'|'pending'|'verified'|'needs_more_info'|'rejected',
//   walletBalance: number,
//   registeredCategories: [string],
//   averageRating: number, ratingCount: number, trustScore?: number,
//   portfolioImageUrls: [string], videoIntroUrl?: string,
//   hourlyRate?: number,
//   languages?: [string],
//   workLocationAddress?: string,
//   presence?: {isLive: bool, lat: number, lng: number, lastSeen: ts},
//   createdAt?: ts, updatedAt?: ts
// }

import 'package:cloud_firestore/cloud_firestore.dart';

class HelpifyUser {
  final String uid;

  // Identity
  final String? displayName;
  final String? email;
  final String? phone;
  final String? photoURL;

  // Roles & modes
  final String role;     // 'poster' | 'helper'
  final String uiMode;   // 'poster' | 'helper' (helpers can browse as poster)
  final bool isHelper;

  // Verification
  final String verificationStatus; // not_started | pending | verified | needs_more_info | rejected
  bool get isHelperVerified => verificationStatus == 'verified';

  // Money
  final int walletBalance;

  // Skills / categories
  final List<String> registeredCategories;

  // Ratings
  final double averageRating;
  final int ratingCount;
  final int? trustScore;

  // Profile extras
  final String? bio;
  final List<String> languages;
  final String? workLocationAddress;
  final double? hourlyRate;

  // Portfolio
  final List<String> portfolioImageUrls;
  final String? videoIntroUrl;

  // Presence (soft; not used for security)
  final bool isLive;
  final double? lat;
  final double? lng;

  // Timestamps
  final DateTime? createdAt;
  final DateTime? updatedAt;

  HelpifyUser({
    required this.uid,
    this.displayName,
    this.email,
    this.phone,
    this.photoURL,
    this.role = 'poster',
    this.uiMode = 'poster',
    this.isHelper = false,
    this.verificationStatus = 'not_started',
    this.walletBalance = 0,
    this.registeredCategories = const [],
    this.averageRating = 0.0,
    this.ratingCount = 0,
    this.trustScore,
    this.bio,
    this.languages = const [],
    this.workLocationAddress,
    this.hourlyRate,
    this.portfolioImageUrls = const [],
    this.videoIntroUrl,
    this.isLive = false,
    this.lat,
    this.lng,
    this.createdAt,
    this.updatedAt,
  });

  /// Friendly computed completion meter (0..1)
  double get profileCompletion {
    int have = 0, total = 5;
    if ((displayName ?? '').trim().isNotEmpty) have++;
    if ((photoURL ?? '').trim().isNotEmpty) have++;
    if (languages.isNotEmpty) have++;
    if ((workLocationAddress ?? '').trim().isNotEmpty) have++;
    if (portfolioImageUrls.isNotEmpty || (bio ?? '').trim().isNotEmpty) have++;
    return have / total;
  }

  /// Backwards compatibility for older code paths
  String get activeRole => role; // alias
  List<String>? get skills => registeredCategories; // alias
  List<String> get badges {
    // If you store badges elsewhere, wire them in; for now derive a couple
    final out = <String>[];
    if (isHelperVerified) out.add('Verified');
    if (ratingCount >= 50) out.add('Experienced');
    return out;
  }

  // -------- Factories --------

  factory HelpifyUser.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const <String, dynamic>{};

    double _asDouble(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }

    int _asInt(dynamic v) {
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    DateTime? _ts(dynamic t) {
      if (t is Timestamp) return t.toDate();
      if (t is DateTime) return t;
      return null;
    }

    List<String> _listStr(dynamic v) {
      if (v is List) {
        return v.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList();
      }
      return const <String>[];
    }

    final presence = (m['presence'] is Map) ? Map<String, dynamic>.from(m['presence']) : const <String, dynamic>{};

    return HelpifyUser(
      uid: doc.id,
      displayName: (m['displayName'] ?? m['name'])?.toString(),
      email: (m['email'] ?? '')?.toString(),
      phone: (m['phone'] ?? m['phoneNumber'])?.toString(),
      photoURL: (m['photoURL'] ?? m['avatarUrl'])?.toString(),
      role: (m['role'] ?? (m['isHelper'] == true ? 'helper' : 'poster'))?.toString() ?? 'poster',
      uiMode: (m['uiMode'] ?? ((m['role'] ?? '') == 'helper' ? 'helper' : 'poster'))?.toString() ?? 'poster',
      isHelper: (m['isHelper'] == true) || ((m['role'] ?? '') == 'helper'),
      verificationStatus: (m['verificationStatus'] ?? 'not_started')?.toString() ?? 'not_started',
      walletBalance: _asInt(m['walletBalance']),
      registeredCategories: _listStr(m['registeredCategories']),
      averageRating: _asDouble(m['averageRating']),
      ratingCount: _asInt(m['ratingCount']),
      trustScore: (m['trustScore'] is num) ? (m['trustScore'] as num).toInt() : null,
      bio: (m['bio'] ?? '')?.toString(),
      languages: _listStr(m['languages']),
      workLocationAddress: (m['workLocationAddress'] ?? '')?.toString(),
      hourlyRate: (m['hourlyRate'] is num) ? (m['hourlyRate'] as num).toDouble() : null,
      portfolioImageUrls: _listStr(m['portfolioImageUrls']),
      videoIntroUrl: (m['videoIntroUrl'] ?? '')?.toString(),
      isLive: (presence['isLive'] == true),
      lat: (presence['lat'] is num) ? (presence['lat'] as num).toDouble() : null,
      lng: (presence['lng'] is num) ? (presence['lng'] as num).toDouble() : null,
      createdAt: _ts(m['createdAt']),
      updatedAt: _ts(m['updatedAt']),
    );
  }

  factory HelpifyUser.fromMap(Map<String, dynamic> m, {required String uid}) {
    final fake = _FakeDoc(uid, m);
    return HelpifyUser.fromFirestore(fake);
  }

  Map<String, dynamic> toMap({bool includeTimestamps = true}) {
    final out = <String, dynamic>{
      'displayName': displayName,
      'email': email,
      'phone': phone,
      'photoURL': photoURL,
      'role': role,
      'uiMode': uiMode,
      'isHelper': isHelper,
      'verificationStatus': verificationStatus,
      'walletBalance': walletBalance,
      'registeredCategories': registeredCategories,
      'averageRating': averageRating,
      'ratingCount': ratingCount,
      if (trustScore != null) 'trustScore': trustScore,
      'bio': bio,
      'languages': languages,
      'workLocationAddress': workLocationAddress,
      if (hourlyRate != null) 'hourlyRate': hourlyRate,
      'portfolioImageUrls': portfolioImageUrls,
      'videoIntroUrl': videoIntroUrl,
      'presence': {
        'isLive': isLive,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
      },
    };
    if (includeTimestamps) {
      out['updatedAt'] = FieldValue.serverTimestamp();
      if (createdAt == null) out['createdAt'] = FieldValue.serverTimestamp();
    }
    return out;
  }
}

// Tiny adapter so we can reuse fromDoc for raw map inputs.
class _FakeDoc implements DocumentSnapshot<Map<String, dynamic>> {
  _FakeDoc(this._id, this._data);
  final String _id;
  final Map<String, dynamic> _data;

  @override
  String get id => _id;

  @override
  Map<String, dynamic>? data() => _data;

  @override
  bool get exists => true;

  // Unused members to satisfy the interface at compile time.
  @override
  SnapshotMetadata get metadata => throw UnimplementedError();

  @override
  DocumentReference<Map<String, dynamic>> get reference => throw UnimplementedError();

  @override
  dynamic operator [](Object field) => _data[field];

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
