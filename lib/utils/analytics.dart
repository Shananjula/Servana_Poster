import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Analytics {
  static final _db = FirebaseFirestore.instance;
  static Future<void> log(String name, {Map<String, dynamic>? params}) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anon';
      await _db.collection('analytics').doc(uid).collection('events').add({
        'name': name,
        'params': params ?? const {},
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }
}
