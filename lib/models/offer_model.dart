// lib/models/offer_model.dart
//
// Offer model (compatible with BOTH top-level /offers docs AND chat-based offers)
// ----------------------------------------------------------------------------
// Top-level Firestore (if you use /offers):
//   offers/{offerId} {
//     taskId: string,
//     posterId: string,
//     helperId: string,
//     price?: number,
//     message?: string,
//     status: 'pending'|'accepted'|'declined'|'withdrawn'|'counter',
//     createdAt: Timestamp,
//     updatedAt: Timestamp
//   }
//
// Chat-based offer (stored as a message in chats/{channelId}/messages/{msgId}):
//   type: 'offer',
//   senderId: <helperId>,
//   offerAmount?: number,
//   offerNote?: string,
//   offerStatus?: 'pending'|'accepted'|'declined'|'counter',
//   timestamp: Timestamp
//
// This model normalizes both into the same shape so the UI can consume uniformly.

import 'package:cloud_firestore/cloud_firestore.dart';

class OfferModel {
  final String id;

  final String taskId;
  final String posterId;
  final String helperId;

  final double? price;     // LKR
  final String? note;      // optional note/message
  final String status;     // pending | accepted | declined | withdrawn | counter

  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Chat context (only if derived from a chat message)
  final String? channelId; // chats/{channelId}
  final bool fromChatMessage;

  OfferModel({
    required this.id,
    required this.taskId,
    required this.posterId,
    required this.helperId,
    required this.status,
    this.price,
    this.note,
    this.createdAt,
    this.updatedAt,
    this.channelId,
    this.fromChatMessage = false,
  });

  // -------------------- Factories (top-level /offers) --------------------

  factory OfferModel.fromOfferDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const <String, dynamic>{};

    double? _asDouble(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    DateTime? _ts(dynamic t) {
      if (t is Timestamp) return t.toDate();
      if (t is DateTime) return t;
      return null;
    }

    return OfferModel(
      id: doc.id,
      taskId: (m['taskId'] ?? '').toString(),
      posterId: (m['posterId'] ?? '').toString(),
      helperId: (m['helperId'] ?? '').toString(),
      price: _asDouble(m['price']),
      note: (m['message'] as String?)?.toString(),
      status: (m['status'] ?? 'pending').toString(),
      createdAt: _ts(m['createdAt']),
      updatedAt: _ts(m['updatedAt']),
      channelId: null,
      fromChatMessage: false,
    );
  }

  // -------------------- Factories (chat-based offer message) --------------------
  //
  // Pass:
  //   msgId  = the message id in chats/{channelId}/messages/{msgId}
  //   channelId = chats doc id
  //   chatMsg  = message data map
  //   posterId = poster of the task (needed for normalized shape)
  //   taskId   = task linked to the chat (if known)
  //
  factory OfferModel.fromChatMessage({
    required String msgId,
    required String channelId,
    required Map<String, dynamic> chatMsg,
    required String posterId,
    required String taskId,
  }) {
    double? _asDouble(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    DateTime? _ts(dynamic t) {
      if (t is Timestamp) return t.toDate();
      if (t is DateTime) return t;
      return null;
    }

    return OfferModel(
      id: msgId,
      taskId: taskId,
      posterId: posterId,
      helperId: (chatMsg['senderId'] ?? '').toString(),
      price: _asDouble(chatMsg['offerAmount']),
      note: (chatMsg['offerNote'] as String?)?.toString(),
      status: (chatMsg['offerStatus'] ?? 'pending').toString(),
      createdAt: _ts(chatMsg['timestamp']),
      updatedAt: _ts(chatMsg['timestamp']),
      channelId: channelId,
      fromChatMessage: true,
    );
  }

  // -------------------- Serialization (top-level offers) --------------------

  Map<String, dynamic> toOfferMap({bool includeTimestamps = true}) {
    final out = <String, dynamic>{
      'taskId': taskId,
      'posterId': posterId,
      'helperId': helperId,
      'status': status,
      if (price != null) 'price': price,
      if (note != null && note!.isNotEmpty) 'message': note,
    };
    if (includeTimestamps) {
      out['updatedAt'] = FieldValue.serverTimestamp();
      if (createdAt == null) {
        out['createdAt'] = FieldValue.serverTimestamp();
      }
    }
    return out;
  }

  // -------------------- Helpers --------------------

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isDeclined => status == 'declined' || status == 'withdrawn';
  bool get isCounter => status == 'counter';
}
