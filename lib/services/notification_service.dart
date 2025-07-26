import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:servana/models/chat_channel_model.dart';
import 'package:servana/models/task_model.dart';
import 'package:servana/screens/conversation_screen.dart';
import 'package:servana/screens/active_task_screen.dart';
import 'package:servana/screens/verification_status_screen.dart'; // Corrected import for rejected status
import 'package:servana/screens/skill_quests_screen.dart';


class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  Future<void> initNotifications() async {
    await _fcm.requestPermission();
    final fcmToken = await _fcm.getToken();
    if (fcmToken != null) _saveTokenToDatabase(fcmToken);
    _fcm.onTokenRefresh.listen(_saveTokenToDatabase);
    await _initLocalNotifications();
    _setupMessageListeners();
  }

  Future<void> _saveTokenToDatabase(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'fcmTokens': FieldValue.arrayUnion([token])
    }, SetOptions(merge: true));
  }

  Future<void> _initLocalNotifications() async {
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();
    const InitializationSettings settings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        if (response.payload != null && response.payload!.isNotEmpty) {
          final parts = response.payload!.split(':');
          if (parts.length == 2) {
            handleNotificationClick({'type': parts[0], 'relatedId': parts[1]});
          }
        }
      },
    );
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    final type = message.data['type'] as String? ?? 'general';
    final relatedId = message.data['relatedId'] as String? ?? '';
    final payload = '$type:$relatedId';
    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(android: AndroidNotificationDetails('high_importance_channel', 'High Importance Notifications')),
      payload: payload,
    );
  }

  void _setupMessageListeners() {
    FirebaseMessaging.onMessage.listen(_showLocalNotification);
    FirebaseMessaging.onMessageOpenedApp.listen((message) => handleNotificationClick(message.data));
    _fcm.getInitialMessage().then((message) {
      if (message != null) handleNotificationClick(message.data);
    });
  }

  Future<void> handleNotificationClick(Map<String, dynamic> data) async {
    final String type = data['type'] ?? 'general';
    final String? id = data['relatedId'];
    final context = navigatorKey.currentContext;

    if (context == null) return;

    try {
      switch (type) {
        case 'chat':
          if (id == null) return;
          final doc = await FirebaseFirestore.instance.collection('chats').doc(id).get();
          if (doc.exists) {
            final channel = ChatChannel.fromFirestore(doc);
            final currentUserId = FirebaseAuth.instance.currentUser!.uid;
            final otherUserId = channel.participants.firstWhere((p) => p != currentUserId);
            Navigator.push(context, MaterialPageRoute(builder: (_) => ConversationScreen(
              chatChannelId: channel.id,
              otherUserName: channel.participantNames[otherUserId] ?? 'User',
              otherUserAvatarUrl: channel.participantAvatars[otherUserId],
            )));
          }
          break;

        case 'task_offer':
        case 'task_assigned':
        case 'task_finished':
          if (id == null) return;
          final doc = await FirebaseFirestore.instance.collection('tasks').doc(id).get();
          if(doc.exists) {
            // --- THIS IS THE FIX ---
            // We navigate using the task's ID, not the full object.
            Navigator.push(context, MaterialPageRoute(builder: (_) => ActiveTaskScreen(taskId: doc.id)));
          }
          break;

        case 'verification_approved':
        case 'new_badge':
          Navigator.push(context, MaterialPageRoute(builder: (_) => const SkillQuestsScreen()));
          break;

        case 'verification_rejected':
        // --- LOGICAL FIX ---
        // Navigate to the status screen so the user can see why they were rejected.
          Navigator.push(context, MaterialPageRoute(builder: (_) => const VerificationStatusScreen()));
          break;

        default:
          break;
      }
    } catch (e) {
      print("Error handling notification navigation: $e");
    }
  }
}
