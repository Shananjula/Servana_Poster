import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:servana/widgets/status_chip.dart';
import 'package:servana/widgets/amount_pill.dart';
import 'package:servana/screens/task_details_screen.dart';

class MyPostsScreen extends StatelessWidget {
  const MyPostsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My posts')),
        body: const Center(child: Text('Sign in to view your posts')),
      );
    }

    Query<Map<String, dynamic>> q =
    FirebaseFirestore.instance.collection('tasks').where('posterId', isEqualTo: uid);
    try {
      q = q.orderBy('createdAt', descending: true);
    } catch (_) {}

    return Scaffold(
      appBar: AppBar(title: const Text('My posts')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: q.limit(50).snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          }
          final docs = snap.data?.docs ?? const [];
          if (docs.isEmpty) return const Center(child: Text('No posts yet'));

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final d = docs[i];
              final t = d.data();
              final title = (t['title'] as String?)?.trim().isNotEmpty == true
                  ? (t['title'] as String).trim()
                  : 'Task';
              final status = (t['status'] as String?) ?? 'open';
              final city = (t['city'] as String?)?.trim();

              final num? amount = (t['finalAmount'] as num?) ?? (t['budget'] as num?);
              final String? amountText =
              amount == null ? _rangeText((t['budgetMin'] as num?), (t['budgetMax'] as num?)) : null;

              return Material(
                color: Theme.of(context).colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Theme.of(context).colorScheme.outline.withOpacity(0.12)),
                ),
                child: ListTile(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TaskDetailsScreen(taskId: d.id))),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.work_outline_rounded),
                  ),
                  title: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  subtitle: city != null && city.isNotEmpty
                      ? Text(
                    city,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  )
                      : null,
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      AmountPill(amount: amount, text: amountText),
                      const SizedBox(height: 6),
                      StatusChip(status),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String? _rangeText(num? min, num? max) {
    if (min == null && max == null) return null;
    if (min != null && max != null) return '${_fmt(min)}–${_fmt(max)}';
    if (min != null) return 'From ${_fmt(min)}';
    return 'Up to ${_fmt(max!)}';
  }

  String _fmt(num n) {
    final negative = n < 0;
    final abs = n.abs();
    final s = abs.toStringAsFixed(abs % 1 == 0 ? 0 : 2);
    final parts = s.split('.');
    String whole = parts[0];
    final reg = RegExp(r'\B(?=(\d{3})+(?!\d))');
    whole = whole.replaceAllMapped(reg, (m) => ',');
    final prefix = negative ? '−' : '';
    return parts.length == 1 ? 'LKR $prefix$whole' : 'LKR $prefix$whole.${parts[1]}';
  }
}
