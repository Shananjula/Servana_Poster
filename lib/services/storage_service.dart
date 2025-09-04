// lib/services/storage_service.dart
//
// StorageService — centralized Firebase Storage helpers
// -----------------------------------------------------
// What this covers (all paths namespaced, merge-safe):
// • uploadUserAvatar(uid, file)                → users/{uid}/avatar/{ts}.jpg
// • uploadUserPortfolio(uid, file)             → users/{uid}/portfolio/{ts}_{name}.jpg
// • uploadChatImage(channelId, uid, file)      → chat_attachments/{channelId}/{ts}_{uid}.jpg
// • uploadTaskProof(taskId, uid, file)         → tasks/{taskId}/proof/{ts}_{uid}.jpg
// • uploadServiceImage(serviceId, uid, file)   → services/{serviceId}/{ts}_{uid}.jpg
// • uploadVerificationDoc(uid, kind, file)     → verifications/{uid}/{kind}.jpg  (kind = selfie|nic_front|nic_back|police)
// • deleteByUrl(url)                           → best-effort delete if you have the gs/http URL
//
// Notes:
// • All methods return a HTTPS download URL (String).
// • File type is dynamic to avoid importing dart:io in consumer widgets; pass a
//   `File` on mobile or `Uint8List` on web (we detect and handle both).
// • If you want strict typing, you can overload methods for File/Uint8List.

import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:flutter/material.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

class StorageService {
  StorageService._();
  static final StorageService _i = StorageService._();
  factory StorageService() => _i;

  final FirebaseStorage _storage = FirebaseStorage.instance;

  // ---------- Public API ----------

  Future<String> uploadUserAvatar(String uid, dynamic file) async {
    final path = 'users/$uid/avatar/${_ts()}.jpg';
    return _putAndGetUrl(path, file);
  }

  Future<String> uploadUserPortfolio(String uid, dynamic file, {String? originalName}) async {
    final safeName = (originalName ?? 'img').replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_');
    final path = 'users/$uid/portfolio/${_ts()}_$safeName.jpg';
    return _putAndGetUrl(path, file);
  }

  Future<String> uploadChatImage(String channelId, String uid, dynamic file) async {
    final path = 'chat_attachments/$channelId/${_ts()}_$uid.jpg';
    return _putAndGetUrl(path, file);
  }

  Future<String> uploadTaskProof(String taskId, String uid, dynamic file) async {
    final path = 'tasks/$taskId/proof/${_ts()}_$uid.jpg';
    return _putAndGetUrl(path, file);
  }

  Future<String> uploadServiceImage(String serviceId, String uid, dynamic file) async {
    final path = 'services/$serviceId/${_ts()}_$uid.jpg';
    return _putAndGetUrl(path, file);
  }

  /// kind: 'selfie' | 'nic_front' | 'nic_back' | 'police'
  Future<String> uploadVerificationDoc(String uid, String kind, dynamic file) async {
    final safe = _normalizeKind(kind);
    final path = 'verifications/$uid/$safe.jpg';
    return _putAndGetUrl(path, file, overwrite: true);
  }

  /// Best-effort delete by download URL or gs:// URL.
  Future<void> deleteByUrl(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
    } catch (_) {
      // ignore — might be already deleted or URL not owned by this bucket
    }
  }

  // ---------- Internals ----------

  String _ts() => DateTime.now().millisecondsSinceEpoch.toString();

  String _normalizeKind(String k) {
    final s = k.toLowerCase();
    if (s.contains('front')) return 'nic_front';
    if (s.contains('back')) return 'nic_back';
    if (s.contains('self')) return 'selfie';
    if (s.contains('police')) return 'police';
    return s.replaceAll(RegExp(r'[^a-z0-9_]+'), '_');
  }

  Future<String> _putAndGetUrl(String path, dynamic file, {bool overwrite = false}) async {
    final ref = _storage.ref(path);
    final metadata = SettableMetadata(contentType: 'image/jpeg');

    if (!overwrite) {
      // If you don’t want accidental overwrites, we can append a suffix if object exists.
      try {
        final exists = await ref.getMetadata().then((_) => true).catchError((_) => false);
        if (exists) {
          final parts = path.split('.');
          final pfx = parts.first;
          final ext = parts.length > 1 ? parts.last : 'jpg';
          final alt = '$pfx_${_ts()}.$ext';
          return _putAndGetUrl(alt, file, overwrite: true);
        }
      } catch (_) {/* ignore */}
    }

    if (file is Uint8List) {
      await ref.putData(file, metadata);
    } else {
      // Assume dart:io File or XFile with `path` and `readAsBytes`
      try {
        // XFile
        final bytes = await file.readAsBytes();
        await ref.putData(bytes as Uint8List, metadata);
      } catch (_) {
        // File
        await ref.putFile(file, metadata);
      }
    }
    return await ref.getDownloadURL();
  }
}
