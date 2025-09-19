// lib/screens/chat_list_screen.dart — Auth-wired, model-free
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'conversation_screen.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  Query<Map<String, dynamic>> _queryForUser(String uid) {
    return FirebaseFirestore.instance
        .collection('chats')
        .where('participantIds', arrayContains: uid)
        .orderBy('lastMessageTimestamp', descending: true)
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snap, _) => snap.data() ?? <String, dynamic>{},
          toFirestore: (data, _) => data,
        );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _queryForUser(uid).snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Failed to load: ${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) return _empty();

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final id = docs[i].id;
              final ch = docs[i].data();
              if (ch.isEmpty) return const SizedBox.shrink();

              final parts = (ch['participantIds'] is List)
                  ? List<String>.from(ch['participantIds'])
                  : <String>[];
              final otherId = parts.where((p) => p != uid).isNotEmpty
                  ? parts.firstWhere((p) => p != uid, orElse: () => '')
                  : (ch['otherUserId'] ?? ch['helperId'] ?? '').toString();

              final namesRaw = (ch['participantNames'] is Map)
                  ? Map<String, dynamic>.from(ch['participantNames'])
                  : const <String, dynamic>{};
              String otherName = (namesRaw[otherId]?.toString().trim() ?? '');
              if (otherName.isEmpty) {
                otherName = (ch['otherUserName'] ?? ch['helperName'] ?? 'Chat').toString();
              }

              final title = (ch['taskTitle'] ?? '').toString().trim();
              final taskId = (ch['taskId'] ?? '').toString().trim();

              final last = (ch['lastMessage'] ?? '').toString();
              final ts = ch['lastMessageTimestamp'] as Timestamp?;

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                title: Text(title.isNotEmpty ? title : otherName, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(last, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                trailing: Text(_formatTime(ts), style: Theme.of(context).textTheme.bodySmall),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ConversationScreen(
                    chatChannelId: id,
                    otherUserId: otherId.isEmpty ? null : otherId,
                    taskId: taskId.isEmpty ? null : taskId,
                    taskTitle: title.isEmpty ? null : title,
                    otherUserName: otherName.isEmpty ? null : otherName,
                  ),
                )),
              );
            },
          );
        },
      ),
    );
  }

  Widget _empty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.forum_outlined, size: 56, color: Colors.grey),
              SizedBox(height: 12),
              Text('No messages yet.'),
            ],
          ),
        ),
      );

  static String _formatTime(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    final now = DateTime.now();
    final sameDay = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    if (sameDay) {
      final hh = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final mm = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return '$hh:$mm $ampm';
    }
    return '${dt.month}/${dt.day}/${dt.year % 100}';
  }
}
