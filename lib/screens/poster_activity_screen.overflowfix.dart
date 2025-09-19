
// lib/screens/activity_screen.dart — Poster app
// -----------------------------------------------------------------------------
// Poster’s activity hub: lists poster-owned tasks with a tiny inline ribbon
// showing the next action. For marketplace states (open/negotiating) it offers
// a "See offers" button that routes to ManageOffersScreen with task context.
// For execution states, it routes to TaskDetailsScreen.
// -----------------------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'manage_offers_screen.dart';
import 'task_details_screen.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  Query<Map<String, dynamic>> _posterTasks(String posterUid) {
    return FirebaseFirestore.instance
        .collection('tasks')
        .where('posterId', isEqualTo: posterUid)
        .orderBy('createdAt', descending: true)
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snap, _) => snap.data() ?? <String, dynamic>{},
          toFirestore: (data, _) => data,
        );
  }

  @override
  Widget build(BuildContext context) {
    final uid = _currentUid();
    return Scaffold(
      appBar: AppBar(title: const Text('My Tasks')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _posterTasks(uid).snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Failed to load: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return _empty();
          }
          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final id = docs[i].id;
              final t = docs[i].data();
              final title = (t['title'] ?? 'Task').toString();
              final city = (t['city'] ?? t['addressShort'] ?? '').toString();
              final status = (t['status'] ?? 'open').toString();
              final price = t['price'] ?? t['budgetMax'] ?? t['amount'];
              final ts = t['createdAt'] as Timestamp?;

              return ListTile(
                isThreeLine: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (city.isNotEmpty)
                      Row(
                        children: [
                          const Icon(Icons.place_outlined, size: 14),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(city, maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    const SizedBox(height: 6),
                    _Ribbon(status: status, onManage: () {
                      if (status == 'open' || status == 'negotiating') {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => ManageOffersScreen(taskId: id, taskTitle: title),
                        ));
                      } else {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => TaskDetailsScreen(taskId: id),
                        ));
                      }
                    }),
                  ],
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _StatusChip(status: status),
                    const SizedBox(height: 6),
                    if (price is num) Text('LKR ${price.toStringAsFixed(0)}',
                        style: Theme.of(context).textTheme.bodySmall),
                    if (ts != null) Text(_short(ts), style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
                onTap: () {
                  if (status == 'open' || status == 'negotiating') {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ManageOffersScreen(taskId: id, taskTitle: title),
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
      ),
    );
  }

  Widget _empty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.work_outline, size: 56, color: Colors.grey),
              SizedBox(height: 12),
              Text('You have no tasks yet.'),
            ],
          ),
        ),
      );

  static String _short(Timestamp ts) {
    final dt = ts.toDate();
    return '${dt.month}/${dt.day}';
  }

  String _currentUid() {
    // Replace with your auth provider.
    // Example:
    // return FirebaseAuth.instance.currentUser!.uid;
    throw UnimplementedError('Wire _currentUid() to your auth layer.');
  }
}

class _Ribbon extends StatelessWidget {
  final String status;
  final VoidCallback onManage;
  const _Ribbon({required this.status, required this.onManage});

  @override
  Widget build(BuildContext context) {
    final isMarketplace = status == 'open' || status == 'negotiating';
    return Container(
      decoration: BoxDecoration(
        color: isMarketplace ? Colors.blue.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          Icon(isMarketplace ? Icons.handshake_outlined : Icons.playlist_add_check_outlined, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              isMarketplace
                  ? 'Offers are coming in — review & counter.'
                  : 'Task in progress — open details.',
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
            onPressed: onManage,
            child: Text(isMarketplace ? 'See offers' : 'Open task'),
          ),
        ],
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
