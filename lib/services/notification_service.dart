// lib/services/notification_service.dart
//
// Firebase Cloud Messaging glue (with in-app banner for foreground messages)
// -------------------------------------------------------------------------
// What this provides:
// • navigatorKey  → used by MaterialApp for deep links
// • initNotifications()  → call after login (AuthWrapper already does this)
// • requestPermission()  → Settings screen can call politely
// • Token sync → users/{uid}.fcmTokens (array union), auto-refresh handling
// • Foreground banner (SnackBar) with OPEN action (chat/task/offer deep-link)
// • onMessageOpenedApp / getInitialMessage deep-link handling
//
// Expected FCM "data" payload keys (server-side):
//   type: 'chat' | 'task' | 'offer' | 'system'
//   channelId?: string     (for chat)
//   taskId?: string        (for task / offer)
//   title/body are optional if you send "notification" section too.
//
// Deep link rules:
//   chat  → ConversationScreen(channelId)
//   task  → TaskDetailsScreen(taskId)
//   offer → ManageOffersScreen(taskId)
//   else  → opens app (no-op here)

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'package:servana/screens/conversation_screen.dart';
import 'package:servana/screens/task_details_screen.dart';
import 'package:servana/screens/manage_offers_screen.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService _i = NotificationService._();
  factory NotificationService() => _i;

  // Use this in MaterialApp
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  StreamSubscription<String>? _tokenSub;

  // Call after login; safe to call multiple times.
  Future<void> initNotifications() async {
    
    await subscribeToUserTopic();
// Ask politely on first run (no-op if already granted)
    await requestPermission();

    // iOS foreground presentation (Android ignores)
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true, badge: true, sound: true,
    );

    // Sync FCM token now + on refresh
    await _syncTokenForCurrentUser();
    _tokenSub?.cancel();
    _tokenSub = _messaging.onTokenRefresh.listen(_addTokenToUser);

    // Foreground messages → show in-app banner
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // App brought to foreground by a tap on a notification
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpen);

    // App launched from terminated state by a notification
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageOpen(initialMessage);
    }
  }

  Future<void> requestPermission() async {
    try {
      await _messaging.requestPermission(
        alert: true, badge: true, sound: true, provisional: false,
      );
    } catch (_) {/* ignore */}
  }

  // ---------------- Token sync ----------------

  Future<void> _syncTokenForCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final token = await _messaging.getToken();
    if (token == null || token.isEmpty) return;
    await _addTokenToUser(token);
  }

  Future<void> _addTokenToUser(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {/* best-effort */}
  }

  // ---------------- Foreground banner ----------------

  void _handleForegroundMessage(RemoteMessage message) {
    final ctx = navigatorKey.currentState?.context;
    if (ctx == null) return;

    // Build title/body
    final data = message.data;
    final title = message.notification?.title ??
        (data['title']?.toString().isNotEmpty == true ? data['title'].toString() : _defaultTitleFor(data['type']));
    final body = message.notification?.body ?? (data['body']?.toString() ?? _defaultBodyFor(data));

    // Pick icon & tone by type
    final (icon, color) = _iconToneFor(data['type']?.toString());

    // Ensure we don’t stack banners endlessly
    final sm = ScaffoldMessenger.of(ctx);
    sm.removeCurrentSnackBar();

    sm.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 5),
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        content: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.12),
              foregroundColor: color,
              child: Icon(icon, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(ctx).textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(body, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                // Close the banner and deep-link
                sm.hideCurrentSnackBar();
                _handleMessageOpen(message);
              },
              child: const Text('OPEN'),
            ),
          ],
        ),
      ),
    );
  }

  String _defaultTitleFor(dynamic t) {
    switch (t?.toString()) {
      case 'chat': return 'New message';
      case 'offer': return 'New offer';
      case 'task': return 'Task update';
      default: return 'Notification';
    }
  }

  String _defaultBodyFor(Map<String, dynamic> data) {
    final type = data['type']?.toString();
    if (type == 'chat') {
      return 'You have a new chat message.';
    } else if (type == 'offer') {
      return 'You received a new offer.';
    } else if (type == 'task') {
      return 'There’s an update on your task.';
    }
    return 'Open to view details.';
  }

  (IconData, Color) _iconToneFor(String? type) {
    switch (type) {
      case 'chat':  return (Icons.chat_bubble_outline, Colors.teal);
      case 'offer': return (Icons.local_offer_outlined, Colors.orange);
      case 'task':  return (Icons.assignment_outlined, Colors.indigo);
      default:      return (Icons.notifications_outlined, Colors.blueGrey);
    }
  }

  // ---------------- Deep links ----------------

  void _handleMessageOpen(RemoteMessage message) {
    final data = message.data;
    final type = (data['type'] ?? '').toString();
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    switch (type) {
      case 'chat': {
        final channelId = (data['channelId'] ?? '').toString();
        if (channelId.isNotEmpty) {
          navigator.push(MaterialPageRoute(builder: (_) => ConversationScreen(channelId: channelId)));
          return;
        }
        break;
      }
      case 'task': {
        final taskId = (data['taskId'] ?? '').toString();
        if (taskId.isNotEmpty) {
          navigator.push(MaterialPageRoute(builder: (_) => TaskDetailsScreen(taskId: taskId)));
          return;
        }
        break;
      }
      case 'offer': {
        final taskId = (data['taskId'] ?? '').toString();
        if (taskId.isNotEmpty) {
          navigator.push(MaterialPageRoute(builder: (_) => ManageOffersScreen(taskId: taskId)));
          return;
        }
        break;
      }
      default:
      // 'system' or unknown → open app (home) implicitly
        break;
    }
  }


  // ---------------- User topic subscription ----------------
  Future<void> subscribeToUserTopic() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      await FirebaseMessaging.instance.subscribeToTopic('user_$uid');
    } catch (_) {}
  }

  
  // ---------------- Topic Preferences ----------------
  Future<void> refreshTopics({required bool general, required bool tasks, required bool marketing}) async {
    try {
      final topics = <String, bool>{'general': general, 'tasks': tasks, 'marketing': marketing};
      for (final e in topics.entries) {
        if (e.value) {
          await _messaging.subscribeToTopic(e.key);
        } else {
          await _messaging.unsubscribeFromTopic(e.key);
        }
      }
      await subscribeToUserTopic();
    } catch (_) {}
  }
// ---------------- Cleanup ----------------

  Future<void> dispose() async {
    await _tokenSub?.cancel();
    _tokenSub = null;
  }
}
