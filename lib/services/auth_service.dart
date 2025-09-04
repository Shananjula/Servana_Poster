// lib/services/auth_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Optional providers — include only the ones you actually use.
// If you don't use them, you can delete those imports & calls.
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

// Optional: if you use push notifications
import 'package:firebase_messaging/firebase_messaging.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();
  factory AuthService() => instance;

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  // Provider handles (safe to keep even if unused)
  final GoogleSignIn _google = GoogleSignIn();

  Future<void> signOut() async {
    final user = _auth.currentUser;

    // Best-effort cleanups that need the uid
    if (user != null) {
      final uid = user.uid;

      // mark presence offline
      try {
        await _db.collection('presence').doc(uid).set({
          'isLive': false,
          'lastSeen': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {}

      // remove current device's FCM token from user doc (if any)
      try {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          await _db.collection('users').doc(uid).update({
            'fcmTokens': FieldValue.arrayRemove([token]),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      } catch (_) {}
    }

    // Sign out 3rd-party providers first (ignore errors)
    try { await _google.signOut(); } catch (_) {}
    try { await _google.disconnect(); } catch (_) {}
    try { await FacebookAuth.instance.logOut(); } catch (_) {}

    // Now sign out FirebaseAuth (this will set currentUser = null and notify listeners)
    await _auth.signOut(); // SDK guarantees listeners fire on signOut. :contentReference[oaicite:1]{index=1}

    // Clear any local cache you keep
    try { final p = await SharedPreferences.getInstance(); await p.clear(); } catch (_) {}
  }
}
