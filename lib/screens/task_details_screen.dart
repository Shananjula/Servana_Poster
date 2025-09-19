
// lib/screens/task_details_screen.dart — Poster app (updated to use ManageOffersScreenV2)
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/chat_service_compat.dart';
import 'manage_offers_screen_v2.dart';

class TaskDetailsScreen extends StatelessWidget {
  final String taskId;

  const TaskDetailsScreen({super.key, required this.taskId});

  DocumentReference<Map<String, dynamic>> get _doc =>
      FirebaseFirestore.instance.collection('tasks').doc(taskId).withConverter(
            fromFirestore: (snap, _) => snap.data() ?? <String, dynamic>{},
            toFirestore: (data, _) => data,
          );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Task details')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _doc.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Failed to load: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.data!.exists) {
            return const Center(child: Text('Task not found'));
          }
          final t = snap.data!.data()!;
          final title = (t['title'] ?? 'Task').toString();
          final desc = (t['description'] ?? '').toString();
          final city = (t['city'] ?? t['addressShort'] ?? '').toString();
          final status = (t['status'] ?? 'open').toString();
          final helperId = (t['helperId'] ?? '').toString();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              if (city.isNotEmpty)
                Row(
                  children: [
                    const Icon(Icons.place_outlined, size: 18),
                    const SizedBox(width: 6),
                    Text(city),
                  ],
                ),
              const SizedBox(height: 12),
              Text(desc),
              const SizedBox(height: 16),
              _StatusPill(status: status),
              const SizedBox(height: 16),
              if (status == 'open' || status == 'negotiating') ...[
                FilledButton.icon(
                  icon: const Icon(Icons.handshake_outlined),
                  label: const Text('See Offers'),
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ManageOffersScreenV2(
                        taskId: taskId,
                        taskTitle: title,
                        onOpenChat: (hid, {taskId}) async {
                          if (hid == null || hid.isEmpty) return;
                          final chId = await ChatServiceCompat.instance.createOrGetChannel(
                            hid,
                            taskId: this.taskId,
                            taskTitle: title,
                          );
                          if (!context.mounted) return;
                          Navigator.of(context).pushNamed('/conversation', arguments: {
                            'chatChannelId': chId,
                            'otherUserId': hid,
                            'taskId': this.taskId,
                            'taskTitle': title,
                          });
                        },
                      ),
                    ));
                  },
                ),
              ] else if (helperId.isNotEmpty &&
                  (status == 'assigned' ||
                      status == 'en_route' ||
                      status == 'arrived' ||
                      status == 'in_progress' ||
                      status == 'pending_completion' ||
                      status == 'pending_payment' ||
                      status == 'pending_rating')) ...[
                OutlinedButton.icon(
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Message Helper'),
                  onPressed: () async {
                    final chId = await ChatServiceCompat.instance.createOrGetChannel(
                      helperId,
                      taskId: taskId,
                      taskTitle: title,
                    );
                    if (!context.mounted) return;
                    Navigator.of(context).pushNamed('/conversation', arguments: {
                      'chatChannelId': chId,
                      'otherUserId': helperId,
                      'taskId': taskId,
                      'taskTitle': title,
                    });
                  },
                ),
              ],
              const SizedBox(height: 30),
            ],
          );
        },
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    switch (status) {
      case 'open':
      case 'negotiating':
        bg = Colors.blueGrey.shade100;
        break;
      case 'assigned':
      case 'en_route':
      case 'arrived':
      case 'in_progress':
        bg = Colors.orange.shade100;
        break;
      case 'pending_completion':
      case 'pending_payment':
      case 'pending_rating':
        bg = Colors.amber.shade100;
        break;
      case 'closed':
      case 'rated':
        bg = Colors.green.shade100;
        break;
      case 'cancelled':
      case 'in_dispute':
        bg = Colors.red.shade100;
        break;
      default:
        bg = Colors.grey.shade300;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(status),
    );
  }
}
