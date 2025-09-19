
// lib/screens/activity_screen.dart — Poster app (Tabbed Activity, Firestore-backed)
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'manage_offers_screen_v2.dart';
import 'task_details_screen.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Activity'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Offers'),
              Tab(text: 'Ongoing'),
              Tab(text: 'Cancel'),
              Tab(text: 'Disputes'),
              Tab(text: 'Booked'),
              Tab(text: 'Completed'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _OffersTab(),
            _OngoingTab(),
            _CancelTab(),
            _DisputesTab(),
            _BookedTab(),
            _CompletedTab(),
          ],
        ),
      ),
    );
  }
}

// === Tabs =====================================================================

class _OffersTab extends StatelessWidget {
  const _OffersTab();

  @override
  Widget build(BuildContext context) {
    return _TaskList(
      emptyIcon: Icons.inbox_outlined,
      emptyTitle: 'No open posts',
      emptyBody: 'Tasks waiting for offers will appear here.',
      statusIn: const ['open', 'negotiating'],
    );
  }
}

class _OngoingTab extends StatelessWidget {
  const _OngoingTab();

  @override
  Widget build(BuildContext context) {
    return _TaskList(
      emptyIcon: Icons.work_outline,
      emptyTitle: 'No ongoing jobs',
      emptyBody: 'Accepted jobs that have started appear here. Open details to track progress.',
      statusIn: const [
        'assigned',
        'en_route',
        'arrived',
        'in_progress',
        'pending_completion',
        'pending_payment',
        'pending_rating',
      ],
    );
  }
}

class _CancelTab extends StatelessWidget {
  const _CancelTab();

  @override
  Widget build(BuildContext context) {
    return _TaskList(
      emptyIcon: Icons.cancel_outlined,
      emptyTitle: 'No cancellations',
      emptyBody: 'Cancelled tasks will show here for your records.',
      statusIn: const ['cancelled'],
    );
  }
}

class _DisputesTab extends StatelessWidget {
  const _DisputesTab();

  @override
  Widget build(BuildContext context) {
    return _TaskList(
      emptyIcon: Icons.gavel_outlined,
      emptyTitle: 'No disputes',
      emptyBody: 'Good news — there are no disputes at the moment.',
      statusIn: const ['in_dispute'],
    );
  }
}

class _BookedTab extends StatelessWidget {
  const _BookedTab();

  @override
  Widget build(BuildContext context) {
    // Some schemas use 'booked'; others consider 'assigned' as booked.
    // Try 'booked' first; if your data doesn’t use it, show nothing until assigned moves to Ongoing.
    return _TaskList(
      emptyIcon: Icons.event_available_outlined,
      emptyTitle: 'No booked jobs',
      emptyBody: 'When a helper is booked, the job appears here.',
      statusIn: const ['booked'],
    );
  }
}

class _CompletedTab extends StatelessWidget {
  const _CompletedTab();

  @override
  Widget build(BuildContext context) {
    return _TaskList(
      emptyIcon: Icons.task_alt_outlined,
      emptyTitle: 'No completed jobs',
      emptyBody: 'Completed and rated jobs will appear here.',
      statusIn: const ['closed', 'rated'],
    );
  }
}

// === Shared list widget =======================================================

class _TaskList extends StatelessWidget {
  final List<String> statusIn;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyBody;

  const _TaskList({
    required this.statusIn,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptyBody,
  });

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  Query<Map<String, dynamic>> _query() {
    final ref = FirebaseFirestore.instance.collection('tasks');
    // Use a composite query when possible; if `whereIn` is not indexed, Firestore will guide you to add it.
    if (statusIn.length == 1) {
      return ref
          .where('posterId', isEqualTo: _uid)
          .where('status', isEqualTo: statusIn.first)
          .orderBy('createdAt', descending: true)
          .withConverter<Map<String, dynamic>>(
            fromFirestore: (snap, _) => snap.data() ?? <String, dynamic>{},
            toFirestore: (data, _) => data,
          );
    }
    return ref
        .where('posterId', isEqualTo: _uid)
        .where('status', whereIn: statusIn)
        .orderBy('createdAt', descending: true)
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snap, _) => snap.data() ?? <String, dynamic>{},
          toFirestore: (data, _) => data,
        );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _query().snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return _centered(Text('Failed to load: ${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return _EmptyState(icon: emptyIcon, title: emptyTitle, body: emptyBody);
        }
        return ListView.separated(
          itemCount: docs.length,
          padding: const EdgeInsets.symmetric(vertical: 6),
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final id = docs[i].id;
            final t = docs[i].data();
            final title = (t['title'] ?? 'Task').toString();
            final city = (t['city'] ?? t['addressShort'] ?? '').toString();
            final status = (t['status'] ?? '').toString();
            final price = t['price'] ?? t['budgetMax'] ?? t['amount'];
            final ts = t['createdAt'] as Timestamp?;

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Row(
                children: [
                  if (city.isNotEmpty) ...[
                    const Icon(Icons.place_outlined, size: 14),
                    const SizedBox(width: 4),
                    Flexible(child: Text(city, maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ],
                ],
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _StatusChip(status: status),
                  const SizedBox(height: 6),
                  if (price is num)
                    Text('LKR ${price.toStringAsFixed(0)}', style: Theme.of(context).textTheme.bodySmall),
                  if (ts != null) Text(_short(ts), style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              onTap: () {
                if (status == 'open' || status == 'negotiating') {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ManageOffersScreenV2(taskId: id, taskTitle: title),
                  ));
                } else {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => TaskDetailsScreen(taskId: id),
                  ));
                }
              },
            );
          },
        );
      },
    );
  }

  static String _short(Timestamp ts) {
    final dt = ts.toDate();
    return '${dt.month}/${dt.day}/${dt.year % 100}';
    }

  Widget _centered(Widget child) => Center(
        child: Padding(padding: const EdgeInsets.all(24.0), child: child),
      );
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _EmptyState({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 72, color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(body, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

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
      case 'booked':
        bg = Colors.purple.shade100;
        break;
      default:
        bg = Colors.grey.shade300;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(status, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}
