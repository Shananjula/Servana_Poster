// lib/screens/task_details_screen.dart
//
// TaskDetailsScreen (Poster)
// - Shows task details & timeline
// - Actions by status:
//   offer* -> Accept/Counter (opens booking sheet)
//   booked  -> Chat • Start (PIN) • Cancel
//   ongoing -> Chat • Finish (PIN) • Dispute
//   completed -> Rate/Review • Rebook
//   cancelled -> Reopen task • Rebook
//   disputed -> View dispute
//
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:servana/screens/conversation_screen.dart';
import 'package:servana/screens/dispute_center_screen.dart';
import 'package:servana/screens/rating_screen.dart';
import 'package:servana/screens/post_task_screen.dart';

import 'package:servana/widgets/booking_sheet.dart';
import 'package:servana/widgets/cancel_sheet.dart';
import 'package:servana/widgets/pin_sheet.dart';
import 'package:servana/services/chat_service.dart';
import 'package:servana/utils/chat_id.dart';
import 'package:servana/screens/chat_thread_screen.dart';


class TaskDetailsScreen extends StatelessWidget {
  const TaskDetailsScreen({super.key, required this.taskId});
  final String taskId;

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance.collection('tasks').doc(taskId);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Task details')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: ref.snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final t = snap.data!.data() ?? {};
          final title = (t['title'] ?? 'Task').toString();
          final status = (t['status'] ?? t['state'] ?? 'unknown').toString();
          final helperId = (t['helperId'] ?? '').toString();
          final helperName = (t['helperName'] ?? '').toString();
          final category = (t['category'] ?? 'General').toString();
          final total = (t['total'] as num?)?.toDouble() ?? ((t['price'] as num?)?.toDouble() ?? 0.0);
          final scheduledAt = _toDate(t['scheduledAt']);
          final createdAt = _toDate(t['createdAt']);
          final locationText = (t['locationText'] ?? '').toString();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
                  _StatusPill(status: status),
                ],
              ),
              const SizedBox(height: 8),
              if (locationText.isNotEmpty) Row(children: [const Icon(Icons.place_rounded, size: 18), const SizedBox(width: 6), Expanded(child: Text(locationText))]),
              if (scheduledAt != null) ...[
                const SizedBox(height: 6),
                Row(children: [const Icon(Icons.event_rounded, size: 18), const SizedBox(width: 6), Text('Scheduled: ${scheduledAt.toString()}')]),
              ],
              const SizedBox(height: 12),
              _Timeline(status: status, createdAt: createdAt, scheduledAt: scheduledAt, startedAt: _toDate(t['startedAt']), finishedAt: _toDate(t['finishedAt'])),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              _ActionsRow(
                status: status,
                taskId: taskId,
                helperId: helperId,
                helperName: helperName,
                category: category,
                total: total,
              ),
              const SizedBox(height: 24),
              // Notes / attachments (optional placeholders)
              if ((t['notes'] ?? '').toString().isNotEmpty) ...[
                const Text('Notes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text((t['notes'] ?? '').toString()),
                const SizedBox(height: 16),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = status.toLowerCase();
    Color bg = cs.surfaceVariant, fg = cs.onSurfaceVariant;
    if (s.contains('offer')) { bg = cs.secondaryContainer; fg = cs.onSecondaryContainer; }
    else if (s.contains('book')) { bg = cs.tertiaryContainer; fg = cs.onTertiaryContainer; }
    else if (s.contains('route') || s.contains('progress') || s.contains('ongoing') || s.contains('start')) { bg = cs.primaryContainer; fg = cs.onPrimaryContainer; }
    else if (s.contains('complete') || s.contains('done') || s.contains('finish')) { bg = Colors.green.withOpacity(0.18); fg = Colors.green.shade900; }
    else if (s.contains('cancel')) { bg = cs.errorContainer; fg = cs.onErrorContainer; }
    else if (s.contains('disput')) { bg = Colors.orange.withOpacity(0.18); fg = Colors.orange.shade900; }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(32), border: Border.all(color: cs.outline.withOpacity(0.12))),
      child: Text(status, style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.status, this.createdAt, this.scheduledAt, this.startedAt, this.finishedAt});
  final String status;
  final DateTime? createdAt, scheduledAt, startedAt, finishedAt;

  Widget _row(IconData icon, String title, String subtitle, {bool done = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: done ? Colors.green : null),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          if (subtitle.isNotEmpty) Text(subtitle),
        ])),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _row(Icons.post_add_rounded, 'Created', createdAt?.toString() ?? '', done: true),
        if (scheduledAt != null) ...[
          const SizedBox(height: 8),
          _row(Icons.event_rounded, 'Booked', scheduledAt!.toString(), done: s=='booked' || s=='ongoing' || s.contains('progress') || s.contains('complete')),
        ],
        if (startedAt != null) ...[
          const SizedBox(height: 8),
          _row(Icons.play_circle_fill_rounded, 'Started', startedAt!.toString(), done: true),
        ],
        if (finishedAt != null) ...[
          const SizedBox(height: 8),
          _row(Icons.check_circle_rounded, 'Finished', finishedAt!.toString(), done: true),
        ],
      ],
    );
  }
}

class _ActionsRow extends StatelessWidget {
  const _ActionsRow({
    required this.status,
    required this.taskId,
    required this.helperId,
    required this.helperName,
    required this.category,
    required this.total,
  });
  final String status, taskId, helperId, helperName, category;
  final double total;

  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase();
    List<Widget> buttons = [];

    void addPrimary(IconData icon, String label, VoidCallback onPressed) {
      buttons.add(Expanded(child: FilledButton.icon(icon: Icon(icon), label: Text(label), onPressed: onPressed)));
      buttons.add(const SizedBox(width: 8));
    }
    void addSecondary(IconData icon, String label, VoidCallback onPressed) {
      buttons.add(OutlinedButton.icon(icon: Icon(icon), label: Text(label), onPressed: onPressed));
      buttons.add(const SizedBox(width: 8));
    }

    if (helperId.isNotEmpty) {
      addPrimary(Icons.chat_bubble_rounded, 'Chat', () {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => ConversationScreen(helperId: helperId, helperName: helperName.isEmpty ? 'Helper' : helperName)));
      });
    }

    if (s.contains('offer')) {
      addPrimary(Icons.check_circle_rounded, 'Accept / Counter', () {
        showBookingSheet(context, helperId: helperId, helperName: helperName.isEmpty ? 'Helper' : helperName, category: category, priceFrom: total.toInt(), hourly: false);
      });
    } else if (s == 'booked' || s == 'scheduled') {
      addPrimary(Icons.play_circle_fill_rounded, 'Start (PIN)', () async {
        final ok = await showPinSheet(context, mode: PinMode.start, taskId: taskId);
        if (ok == true && context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Job started')));
      });
      addSecondary(Icons.cancel_rounded, 'Cancel', () => showCancelSheet(context, taskId: taskId, helperId: helperId, total: total, initiator: 'poster'));
    } else if (s.contains('ongoing') || s.contains('progress') || s == 'started') {
      addPrimary(Icons.check_circle_rounded, 'Finish (PIN)', () async {
        final ok = await showPinSheet(context, mode: PinMode.finish, taskId: taskId);
        if (ok == true && context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Job finished')));
      });
      addSecondary(Icons.report_gmailerrorred_rounded, 'Dispute', () {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DisputeCenterScreen()));
      });
    } else if (s.contains('complete') || s == 'done' || s == 'finished') {
      addPrimary(Icons.star_rate_rounded, 'Rate & review', () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => RatingScreen(revieweeId: helperId)),
        );
      });
      addSecondary(Icons.replay_rounded, 'Rebook', () {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => PostTaskScreen(initialCategory: category)));
      });
    } else if (s.contains('cancel')) {
      addPrimary(Icons.replay_rounded, 'Reopen task', () async {
        final db = FirebaseFirestore.instance;
        final doc = await db.collection('tasks').doc(taskId).get();
        final data = doc.data() ?? {};
        data['status'] = 'open';
        data['createdAt'] = FieldValue.serverTimestamp();
        data['updatedAt'] = FieldValue.serverTimestamp();
        await db.collection('tasks').add(data);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task reopened as new post.')));
        }
      });
      addSecondary(Icons.replay_circle_filled_rounded, 'Rebook', () {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => PostTaskScreen(initialCategory: category)));
      });
    } else if (s.contains('disput')) {
      addPrimary(Icons.visibility_rounded, 'View dispute', () {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DisputeCenterScreen()));
      });
    }

    if (buttons.isNotEmpty) buttons.removeLast();
    return Wrap(spacing: 8, runSpacing: 8, children: buttons);
  }
}

DateTime? _toDate(dynamic ts) {
  if (ts == null) return null;
  if (ts is Timestamp) return ts.toDate();
  if (ts is DateTime) return ts;
  try { final i = int.parse(ts.toString()); return DateTime.fromMillisecondsSinceEpoch(i); } catch (_) {}
  return null;
}
