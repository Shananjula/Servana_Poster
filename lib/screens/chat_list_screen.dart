// lib/screens/chat_list_screen.dart
//
// Chats (poster):
// - Merges channels from any of these collections (whichever exist / are readable):
//   chatChannels (members), channels (members), chats (participants), pairs (members)
// - Emits as soon as ANY stream produces (no more stuck skeletons)
// - Tolerant field names for title/preview/unread/helperId
//
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:servana/screens/conversation_screen.dart';
import 'package:servana/screens/notifications_screen.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Notifications',
            icon: const Icon(Icons.notifications_rounded),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const NotificationsScreen())),
          ),
        ],
      ),
      body: const _ChannelList(),
    );
  }
}

class _ChannelList extends StatelessWidget {
  const _ChannelList();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Center(child: Text('Sign in to view your chats.'));
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _channelItemsStream(uid),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const _SkeletonList();
        }

        // Merge + sort newest first
        var items = snap.data!;
        items.sort((a, b) {
          final aTs = a['updatedAt'] ?? a['lastMessageAt'] ?? a['createdAt'];
          final bTs = b['updatedAt'] ?? b['lastMessageAt'] ?? b['createdAt'];
          return _toMillis(bTs).compareTo(_toMillis(aTs));
        });

        if (items.isEmpty) {
          return const Center(
            child: Text('No chats yet. Start a conversation from a helper card.'),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (ctx, i) {
            final ch = items[i];

            // Title: try otherName/helperName/displayName then fallback
            final title = (ch['otherName'] ??
                ch['helperName'] ??
                ch['displayName'] ??
                'Conversation')
                .toString();

            // Preview: lastMessage/preview/snippet
            final preview =
            (ch['lastMessage'] ?? ch['preview'] ?? ch['snippet'] ?? '')
                .toString();

            // Unread count (various shapes)
            int unread = 0;
            final rawUnread = ch['unreadCount'] ?? ch['unread'] ?? 0;
            if (rawUnread is int) unread = rawUnread;
            if (rawUnread is num) unread = rawUnread.toInt();

            // Helper/other id: try helperId/otherId; else compute from members
            String helperId =
            (ch['helperId'] ?? ch['otherId'] ?? '').toString();
            if (helperId.isEmpty) {
              final mem = ch['members'];
              if (mem is List && mem.isNotEmpty) {
                helperId = mem.firstWhere(
                      (m) => m != FirebaseAuth.instance.currentUser?.uid,
                  orElse: () => mem.first.toString(),
                );
              }
            }

            return ListTile(
              tileColor: Theme.of(ctx).colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: Theme.of(ctx).colorScheme.outline.withOpacity(0.12),
                ),
              ),
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: unread > 0
                  ? CircleAvatar(radius: 12, child: Text('$unread'))
                  : const SizedBox.shrink(),
              onTap: () => Navigator.of(ctx).push(
                MaterialPageRoute(
                  builder: (_) =>
                      ConversationScreen(helperId: helperId, helperName: title),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Merge channels from multiple possible collections and emit on ANY update.
Stream<List<Map<String, dynamic>>> _channelItemsStream(String uid) {
  final sources = <Stream<QuerySnapshot<Map<String, dynamic>>>>[
    // adjust or remove ones you don't use:
    FirebaseFirestore.instance
        .collection('chatChannels')
        .where('members', arrayContains: uid)
        .snapshots(),
    FirebaseFirestore.instance
        .collection('channels')
        .where('members', arrayContains: uid)
        .snapshots(),
    FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: uid)
        .snapshots(),
    FirebaseFirestore.instance
        .collection('pairs')
        .where('members', arrayContains: uid)
        .snapshots(),
  ];

  final controller = StreamController<List<Map<String, dynamic>>>.broadcast();
  final latest = List<QuerySnapshot<Map<String, dynamic>>?>.filled(
      sources.length, null,
      growable: false);
  final subs = <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];

  void emit() {
    final mergedDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    for (final qs in latest) {
      if (qs == null) continue;
      mergedDocs.addAll(qs.docs);
    }
    final items = mergedDocs.map((d) {
      final m = Map<String, dynamic>.from(d.data());
      m['id'] = d.id;
      return m;
    }).toList();
    controller.add(items);
  }

  for (var i = 0; i < sources.length; i++) {
    final sub = sources[i].listen(
          (qs) {
        latest[i] = qs;
        emit();
      },
      onError: (_) {
        // Ignore this source if permission-denied/doesn't exist; still emit others
        latest[i] = null;
        emit();
      },
    );
    subs.add(sub);
  }

  controller.onCancel = () async {
    for (final s in subs) {
      await s.cancel();
    }
  };

  return controller.stream;
}

class _SkeletonList extends StatelessWidget {
  const _SkeletonList();
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => Container(
        height: 72,
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outline.withOpacity(0.12)),
        ),
      ),
    );
  }
}

int _toMillis(dynamic ts) {
  if (ts == null) return 0;
  if (ts is int) return ts;
  if (ts is Timestamp) return ts.millisecondsSinceEpoch;
  if (ts is DateTime) return ts.millisecondsSinceEpoch;
  try {
    return int.parse(ts.toString());
  } catch (_) {
    return 0;
  }
}
