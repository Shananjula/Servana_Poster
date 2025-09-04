// lib/screens/notifications_screen.dart
//
// Modern notifications list with swipe-to-read and "Mark all read".
// Data shape (schema-tolerant):
//   /users/{uid}/notifications/* {
//     title: string,
//     body: string,
//     isRead: bool,
//     timestamp: Timestamp,
//     type?: string,           // e.g., 'task_details', 'verification_update', 'task_offer'
//     relatedId?: string,      // e.g., taskId or userId
//   }
//
// Invariants:
// • No role toggle here.
// • Uses only existing routes/screens (best-effort navigation).
// • Null-safe and defensive against missing fields.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:servana/l10n/i18n.dart';

// Optional destinations (best-effort)
import 'package:servana/screens/task_details_screen.dart';
import 'package:servana/screens/verification_center_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _markingAll = false;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Alerts')),
        body: const _Empty(message: 'Sign in to view alerts.'),
      );
    }

    final q = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .limit(120);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alerts'),
        actions: [
          TextButton(
            onPressed: _markingAll ? null : () => _markAllRead(uid),
            child: _markingAll
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Mark all read'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: q.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          }
          final docs = snap.data?.docs ?? const [];
          if (docs.isEmpty) {
            return const _Empty(message: 'No alerts yet.');
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final ref = docs[i].reference;
              final d = docs[i].data();

              final title = (d['title'] as String?)?.trim().isNotEmpty == true
                  ? (d['title'] as String).trim()
                  : 'Notification';
              final body = (d['body'] as String?)?.trim() ?? '';
              final isRead = d['isRead'] == true;
              final ts = d['timestamp'];
              String? timeAgo;
              if (ts is Timestamp) timeAgo = _timeAgo(ts.toDate());

              return Dismissible(
                key: ValueKey(ref.id),
                direction: DismissDirection.endToStart,
                background: _SwipeBg(label: isRead ? 'Mark unread' : 'Mark read', icon: Icons.done_all_rounded),
                confirmDismiss: (_) async {
                  await _toggleRead(ref, !isRead);
                  return false; // keep in list; we only update state
                },
                child: Material(
                  color: Theme.of(context).colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Theme.of(context).colorScheme.outline.withOpacity(0.12)),
                  ),
                  child: ListTile(
                    onTap: () => _openRelated(context, d),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    leading: Stack(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.notifications_rounded),
                        ),
                        if (!isRead)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                    title: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isRead ? null : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (body.isNotEmpty)
                          Text(
                            body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (timeAgo != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            timeAgo,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                    trailing: IconButton(
                      tooltip: isRead ? 'Mark unread' : 'Mark read',
                      icon: Icon(isRead ? Icons.mark_email_unread_rounded : Icons.mark_email_read_rounded),
                      onPressed: () => _toggleRead(ref, !isRead),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _toggleRead(DocumentReference<Map<String, dynamic>> ref, bool setRead) async {
    try {
      await ref.set({'isRead': setRead}, SetOptions(merge: true));
    } catch (_) {
      // ignore
    }
  }

  Future<void> _markAllRead(String uid) async {
    setState(() => _markingAll = true);
    try {
      final coll = FirebaseFirestore.instance.collection('users').doc(uid).collection('notifications');
      final unread = await coll.where('isRead', isEqualTo: false).limit(400).get();
      final batch = FirebaseFirestore.instance.batch();
      for (final d in unread.docs) {
        batch.set(d.reference, {'isRead': true}, SetOptions(merge: true));
      }
      await batch.commit();
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  void _openRelated(BuildContext context, Map<String, dynamic> d) {
    final type = (d['type'] as String?)?.toLowerCase() ?? '';
    final relatedId = (d['relatedId'] as String?) ?? '';

    switch (type) {
      case 'task_details':
      case 'task':
        if (relatedId.isNotEmpty) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => TaskDetailsScreen(taskId: relatedId)));
        }
        break;
      case 'verification_update':
      case 'verification_approved':
      case 'verification_rejected':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const VerificationCenterScreen()));
        break;
      case 'task_offer':
        if (relatedId.isNotEmpty) {
          // Open task; offers are visible inside details/manage offers
          Navigator.push(context, MaterialPageRoute(builder: (_) => TaskDetailsScreen(taskId: relatedId)));
        }
        break;
      default:
      // no-op
        break;
    }
  }
}

// ---------- UI bits ----------
class _SwipeBg extends StatelessWidget {
  const _SwipeBg({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: cs.primary.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.primary)),
          const SizedBox(width: 8),
          Icon(icon, color: cs.primary),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outline.withOpacity(0.12)),
        ),
        child: Text(message),
      ),
    );
  }
}

// ---------- utils ----------
String _timeAgo(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  final weeks = (diff.inDays / 7).floor();
  return '${weeks}w ago';
}
