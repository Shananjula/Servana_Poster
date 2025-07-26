import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:servana/models/app_notification_model.dart';
import 'package:servana/services/notification_service.dart';
import 'package:servana/widgets/empty_state_widget.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _currentUser = FirebaseAuth.instance.currentUser;

  Future<void> _markAllAsRead() async {
    if (_currentUser == null) return;
    final batch = FirebaseFirestore.instance.batch();
    final notificationsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser!.uid)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .get();

    for (var doc in notificationsSnapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_currentUser == null) {
      return const Scaffold(body: Center(child: Text("Please log in to see notifications.")));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.mark_chat_read_outlined),
            tooltip: 'Mark all as read',
            onPressed: _markAllAsRead,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUser!.uid)
            .collection('notifications')
            .orderBy('timestamp', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.notifications_off_outlined,
              title: 'All Caught Up!',
              message: 'Important updates and messages will appear here.',
            );
          }
          final notifications = snapshot.data!.docs
              .map((doc) => AppNotification.fromFirestore(doc))
              .toList();

          return ListView.separated(
            itemCount: notifications.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return NotificationTile(notification: notification);
            },
          );
        },
      ),
    );
  }
}

class NotificationTile extends StatelessWidget {
  final AppNotification notification;
  const NotificationTile({super.key, required this.notification});

  Future<void> _handleTap() async {
    // Mark as read in Firestore
    if (!notification.isRead) {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        FirebaseFirestore.instance
            .collection('users').doc(userId)
            .collection('notifications').doc(notification.id)
            .update({'isRead': true});
      }
    }
    // Use the centralized navigation service
    NotificationService().handleNotificationClick({
      'type': notification.type,
      'relatedId': notification.relatedId
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: notification.isRead ? theme.canvasColor : theme.colorScheme.primaryContainer.withOpacity(0.3),
      child: ListTile(
        leading: CircleAvatar(child: Icon(_getIconForType(notification.type))),
        title: Text(notification.title, style: TextStyle(fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold)),
        subtitle: Text(notification.body),
        trailing: Text(DateFormat.yMd().add_jm().format(notification.timestamp.toDate()), style: theme.textTheme.labelSmall),
        onTap: _handleTap,
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'task_offer': return Icons.local_offer;
      case 'task_assigned': return Icons.assignment_turned_in;
      case 'task_finished': return Icons.check_circle;
      case 'new_badge': return Icons.emoji_events;
      case 'verification_approved': return Icons.verified_user;
      case 'verification_rejected': return Icons.gpp_bad;
      case 'chat': return Icons.message;
      default: return Icons.notifications;
    }
  }
}
