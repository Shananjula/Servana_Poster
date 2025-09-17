// Servana_Poster/lib/screens/manage_offers_screen.dart
// Poster side — Manage Offers for a specific task.
// Shows all offers received, helper mini-profile, and actions: Chat / Counter / Reject / Accept.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:servana/services/offer_actions.dart';
import 'package:servana/services/chat_navigation.dart';

class ManageOffersScreen extends StatefulWidget {
  final String taskId;
  final String? taskTitle;

  const ManageOffersScreen({super.key, required this.taskId, this.taskTitle});

  @override
  State<ManageOffersScreen> createState() => _ManageOffersScreenState();
}

class _ManageOffersScreenState extends State<ManageOffersScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final q = FirebaseFirestore.instance
        .collection('tasks/${widget.taskId}/offers')
        .orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.taskTitle ?? 'Offers for task'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: q.snapshots(),
        builder: (_, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const _EmptyState(
              title: 'No offers yet',
              hint: 'Invite helpers or wait for new offers.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final d = docs[i];
              return _OfferRow(
                offer: d,
                taskId: widget.taskId,
                onAnyActionStart: () => setState(() => _busy = true),
                onAnyActionEnd:   () => setState(() => _busy = false),
              );
            },
          );
        },
      ),
      bottomNavigationBar: _busy
          ? const SafeArea(
              child: LinearProgressIndicator(minHeight: 2),
            )
          : null,
    );
  }
}

class _OfferRow extends StatefulWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> offer;
  final String taskId;
  final VoidCallback onAnyActionStart;
  final VoidCallback onAnyActionEnd;

  const _OfferRow({
    required this.offer,
    required this.taskId,
    required this.onAnyActionStart,
    required this.onAnyActionEnd,
  });

  @override
  State<_OfferRow> createState() => _OfferRowState();
}

class _OfferRowState extends State<_OfferRow> {
  bool _working = false;

  String get _posterId => FirebaseAuth.instance.currentUser?.uid ?? '';

  Map<String, dynamic> get data => widget.offer.data();
  String get offerId => widget.offer.id;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final helperId = (data['helperId'] ?? '').toString();
    final price = data['amount'] ?? data['price'];
    final note = (data['message'] ?? data['note'] ?? '').toString();
    final status = (data['status'] ?? '').toString();
    final origin = (data['origin'] ?? 'public').toString();
    final agreed = data['helperAgreed'] == true;
    final createdAt = data['createdAt'];
    final timeText = _timeAgo(createdAt);

    final canAct = ['pending', 'negotiating', 'counter'].contains(status);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row: helper mini profile
            FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              future: FirebaseFirestore.instance.doc('users/$helperId').get(),
              builder: (_, usnap) {
                final u = usnap.data?.data() ?? const {};
                final name = (u['displayName'] ?? u['name'] ?? helperId).toString();
                final rating = (u['rating'] ?? u['averageRating'] ?? 0).toString();
                final jobs = (u['jobsDone'] ?? u['completedCount'] ?? 0).toString();
                final avatar = (u['photoURL'] ?? u['avatar'] ?? '').toString();

                return Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: cs.primaryContainer,
                      backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                      child: avatar.isEmpty ? const Icon(Icons.person) : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          Row(
                            children: [
                              Icon(Icons.star, size: 14, color: cs.tertiary),
                              const SizedBox(width: 4),
                              Text(rating),
                              const SizedBox(width: 12),
                              const Icon(Icons.check_circle, size: 14),
                              const SizedBox(width: 4),
                              Text('$jobs jobs'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Status chip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: cs.surfaceVariant,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(status.isEmpty ? '—' : status),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),

            // Row: price & note
            Row(
              children: [
                if (price != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('LKR $price', style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                const SizedBox(width: 8),
                if (agreed)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: cs.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Helper agreed'),
                  ),
                const Spacer(),
                Text(timeText, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            if (note.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(note),
            ],
            const SizedBox(height: 12),

            // Fee hint
            if (origin == 'public')
              Text('On Accept: helper pays acceptance fee', style: Theme.of(context).textTheme.bodySmall)
            else
              Text('Direct invite path — no helper fee on Accept', style: Theme.of(context).textTheme.bodySmall),

            const SizedBox(height: 8),

            // Action buttons
            Wrap(
              spacing: 8,
              runSpacing: -6,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.message_outlined),
                  label: const Text('Chat'),
                  onPressed: () => openChatWith(
                    context: context,
                    posterId: _posterId,
                    helperId: (data['helperId'] ?? '').toString(),
                    taskId: widget.taskId,
                    highlightOfferId: offerId,
                  ),
                ),
                if (canAct) ...[
                  OutlinedButton.icon(
                    icon: const Icon(Icons.swap_horiz),
                    label: const Text('Counter'),
                    onPressed: _working ? null : () => _counterDialog(offerId),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.close),
                    label: const Text('Reject'),
                    onPressed: _working ? null : () => _reject(offerId),
                  ),
                  FilledButton.icon(
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Accept'),
                    onPressed: _working ? null : () => _accept(offerId),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _counterDialog(String offerId) async {
    final controller = TextEditingController();
    final noteCtrl = TextEditingController();
    final res = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Counter offer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: controller, decoration: const InputDecoration(labelText: 'Counter price'), keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'Note (optional)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, {'p': controller.text, 'n': noteCtrl.text}), child: const Text('Send'))
        ],
      ),
    );
    if (res != null && res['p'] != null && res['p']!.trim().isNotEmpty) {
      final price = num.tryParse(res['p']!.trim());
      final note  = res['n']!.trim();
      if (price != null && price > 0) {
        setState(() { _working = true; });
        widget.onAnyActionStart();
        try {
          await OfferActions.instance.proposeCounter(offerId: offerId, price: price, note: note.isEmpty ? null : note);
        } finally {
          if (mounted) setState(() { _working = false; });
          widget.onAnyActionEnd();
        }
      }
    }
  }

  Future<void> _reject(String offerId) async {
    setState(() { _working = true; });
    widget.onAnyActionStart();
    try {
      await OfferActions.instance.rejectOffer(offerId: offerId);
    } finally {
      if (mounted) setState(() { _working = false; });
      widget.onAnyActionEnd();
    }
  }

  Future<void> _accept(String offerId) async {
    setState(() { _working = true; });
    widget.onAnyActionStart();
    try {
      await OfferActions.instance.acceptOffer(offerId: offerId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Offer accepted.')));
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Accept failed: ${e.message}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Accept failed: $e')));
      }
    } finally {
      if (mounted) setState(() { _working = false; });
      widget.onAnyActionEnd();
    }
  }

  String _timeAgo(dynamic ts) {
    try {
      final dt = (ts is Timestamp) ? ts.toDate() : DateTime.tryParse(ts?.toString() ?? '');
      if (dt == null) return '';
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) { return ''; }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.hint});
  final String title;
  final String hint;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(hint, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
