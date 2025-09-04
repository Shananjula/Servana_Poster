// lib/screens/manage_offers_screen.dart
//
// Manage offers for a task (Poster) + see/withdraw your offers (Helper).
// - If taskId is provided → show offers for THAT task (poster-focused).
// - If no taskId → show relevant offers grouped by task (role-aware).
// - Actions (Poster): Accept · Decline · Counter · Contact (fee-gated).
// - Actions (Helper): Edit · Withdraw.
// - Direct-contact fee: guarded with a Cloud Function 'chargeDirectContactFee'.
//   The function should:
//     * check if poster has previously contacted this helper (direct or via past task)
//     * if not, charge a fee percentage (decided server-side)
//     * return { ok: true, channelId: '...' } on success
// - Safe fallbacks if your schema differs (top-level 'offers' or subcollection 'tasks/{id}/offers').
//
// Assumed fields (aligns with your offer_model.dart / task_model.dart):
//   offers: {
//     id, taskId, posterId, helperId, price, message, status('pending'|'accepted'|'declined'|'withdrawn'|'counter'),
//     createdAt, updatedAt
//   }
//   tasks: { title, category, price, status, posterId, helperId? }
//
// NOTE: Security & payments must be enforced server-side (Cloud Functions + Firestore rules).
//       Client only calls functions and writes minimal status transitions.

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:servana/screens/conversation_screen.dart';
import 'package:servana/screens/task_details_screen.dart';
import 'package:servana/screens/chat_list_screen.dart';

class ManageOffersScreen extends StatefulWidget {
  const ManageOffersScreen({super.key, this.taskId, this.task, this.currentUser});
  final String? taskId;
  final dynamic task;          // keep it flexible (Task? if you imported)
  final dynamic currentUser;   // HelpifyUser? if you imported

  @override
  State<ManageOffersScreen> createState() => _ManageOffersScreenState();
}

class _ManageOffersScreenState extends State<ManageOffersScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab;
  String _sort = 'recent'; // 'recent' | 'price_low' | 'price_high'
  final _counterCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _counterCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isScopedToTask = widget.taskId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isScopedToTask ? 'Offers for Task' : 'Offers'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Incoming'), // for posters: offers to your tasks; for helpers: offers you received (rare)
            Tab(text: 'Sent'),     // for helpers: offers you sent; for posters: counters you sent
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Sort',
            onSelected: (v) => setState(() => _sort = v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'recent', child: Text('Recent')),
              PopupMenuItem(value: 'price_low', child: Text('Price · Low → High')),
              PopupMenuItem(value: 'price_high', child: Text('Price · High → Low')),
            ],
            icon: const Icon(Icons.sort),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _OffersTab(
            scopeTaskId: widget.taskId,
            incoming: true,
            sort: _sort,
            onAccept: _handleAccept,
            onDecline: _handleDecline,
            onCounter: _handleCounter,
            onContact: _handleContactFeeGated,
          ),
          _OffersTab(
            scopeTaskId: widget.taskId,
            incoming: false,
            sort: _sort,
            onAccept: _handleAccept,
            onDecline: _handleDecline,
            onCounter: _handleCounter,
            onContact: _handleContactFeeGated,
          ),
        ],
      ),
    );
  }

  // ---------------- Poster Actions ----------------

  Future<void> _handleAccept(OfferDoc offer) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    // Confirm
    final ok = await _confirm(context, title: 'Accept offer', message: 'Accept this offer and assign the task?');
    if (ok != true) return;

    try {
      // Transaction to mark offer accepted and task assigned.
      await FirebaseFirestore.instance.runTransaction((trx) async {
        final taskRef = FirebaseFirestore.instance.collection('tasks').doc(offer.taskId);
        final offerRef = FirebaseFirestore.instance.collection('offers').doc(offer.id);

        final taskSnap = await trx.get(taskRef);
        if (!taskSnap.exists) throw Exception('Task not found');
        final task = taskSnap.data() as Map<String, dynamic>;

        // Only poster can accept for their task
        if (task['posterId'] != uid) throw Exception('Not authorized');

        // Update offer + task
        trx.update(offerRef, {'status': 'accepted', 'updatedAt': FieldValue.serverTimestamp()});
        trx.update(taskRef, {
          'status': 'assigned',
          'helperId': offer.helperId,
          'price': offer.price ?? task['price'],
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Optional: decline other pending offers for this task
        final others = await FirebaseFirestore.instance
            .collection('offers')
            .where('taskId', isEqualTo: offer.taskId)
            .where('status', isEqualTo: 'pending')
            .get();
        for (final o in others.docs) {
          if (o.id == offer.id) continue;
          trx.update(o.reference, {'status': 'declined', 'updatedAt': FieldValue.serverTimestamp()});
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Offer accepted and task assigned.')));
        Navigator.push(context, MaterialPageRoute(builder: (_) => TaskDetailsScreen(taskId: offer.taskId)));
      }
    } catch (e) {
      _err(context, 'Could not accept offer: $e');
    }
  }

  Future<void> _handleDecline(OfferDoc offer) async {
    final ok = await _confirm(context, title: 'Decline offer', message: 'Decline this offer?');
    if (ok != true) return;
    try {
      await FirebaseFirestore.instance.collection('offers').doc(offer.id).update({
        'status': 'declined',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _ok(context, 'Offer declined.');
    } catch (e) {
      _err(context, 'Could not decline: $e');
    }
  }

  Future<void> _handleCounter(OfferDoc offer) async {
    final txt = await _promptCounter(context, initial: offer.price?.toString() ?? '');
    if (txt == null) return;

    final newPrice = num.tryParse(txt);
    if (newPrice == null) {
      _err(context, 'Invalid price');
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('offers').doc(offer.id).update({
        'status': 'counter',
        'counterPrice': newPrice,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _ok(context, 'Counter sent.');
    } catch (e) {
      _err(context, 'Could not send counter: $e');
    }
  }

  // ---------------- Direct Contact (Fee-Gated) ----------------

  Future<void> _handleContactFeeGated(OfferDoc offer) async {
    try {
      final fn = FirebaseFunctions.instance.httpsCallable('chargeDirectContactFee');
      final res = await fn.call(<String, dynamic>{
        'posterId': offer.posterId,
        'helperId': offer.helperId,
        'taskId': offer.taskId,
        // server decides fee %, checks previous contact/previous tasks,
        // charges if needed, and returns chat channel id.
      });
      final data = res.data as Map;
      if (data['ok'] == true && data['channelId'] is String) {
        _openChat(context, data['channelId'] as String);
        return;
      }
      _err(context, data['message']?.toString() ?? 'Payment check failed');
    } catch (e) {
      // Fallback: if your backend isn’t ready, route to chat list with a warning
      _warn(context, 'Contact fee backend not configured. Opening chat list.');
      if (mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatListScreen()));
      }
    }
  }

  void _openChat(BuildContext context, String channelId) {
    try {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ConversationScreen(channelId: channelId)));
    } catch (_) {
      // If ConversationScreen signature differs, fall back
      Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatListScreen()));
    }
  }
}

// ===================== TAB =====================

class _OffersTab extends StatelessWidget {
  const _OffersTab({
    required this.scopeTaskId,
    required this.incoming,
    required this.sort,
    required this.onAccept,
    required this.onDecline,
    required this.onCounter,
    required this.onContact,
  });

  final String? scopeTaskId;
  final bool incoming; // true = offers "to me" (poster); false = offers I sent (helper)
  final String sort;
  final Future<void> Function(OfferDoc offer) onAccept;
  final Future<void> Function(OfferDoc offer) onDecline;
  final Future<void> Function(OfferDoc offer) onCounter;
  final Future<void> Function(OfferDoc offer) onContact;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Center(child: Text('Please sign in.'));

    // We try top-level 'offers' first; if your schema is subcollection, adapt q2 below.
    Query q = FirebaseFirestore.instance.collection('offers');

    if (scopeTaskId != null) {
      q = q.where('taskId', isEqualTo: scopeTaskId);
    }

    // Role-aware filtering
    if (incoming) {
      // Incoming to poster’s tasks OR to me in general (if you support helper receives)
      q = q.where('posterId', isEqualTo: uid);
    } else {
      // Sent by me (helper)
      q = q.where('helperId', isEqualTo: uid);
    }

    // Sort
    if (sort == 'recent') {
      q = q.orderBy('createdAt', descending: true);
    } else if (sort == 'price_low') {
      q = q.orderBy('price', descending: false);
    } else if (sort == 'price_high') {
      q = q.orderBy('price', descending: true);
    }

    // Limit
    q = q.limit(200);

    return StreamBuilder<QuerySnapshot>(
      stream: q.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _LoadingList();
        }

        var docs = snap.data?.docs ?? <QueryDocumentSnapshot>[];

        // If you store offers under /tasks/{id}/offers, try pulling those instead.
        if (docs.isEmpty && scopeTaskId != null) {
          return _TaskOffersSubcollection(
            taskId: scopeTaskId!,
            incoming: incoming,
            sort: sort,
            onAccept: onAccept,
            onDecline: onDecline,
            onCounter: onCounter,
            onContact: onContact,
          );
        }

        if (docs.isEmpty) return const _EmptyState();

        final offers = docs.map((d) => OfferDoc.from(d.id, d.data() as Map<String, dynamic>)).toList();

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          itemCount: offers.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _OfferCard(
            offer: offers[i],
            incoming: incoming,
            onAccept: onAccept,
            onDecline: onDecline,
            onCounter: onCounter,
            onContact: onContact,
          ),
        );
      },
    );
  }
}

// Fallback to a subcollection structure: tasks/{taskId}/offers
class _TaskOffersSubcollection extends StatelessWidget {
  const _TaskOffersSubcollection({
    required this.taskId,
    required this.incoming,
    required this.sort,
    required this.onAccept,
    required this.onDecline,
    required this.onCounter,
    required this.onContact,
  });

  final String taskId;
  final bool incoming;
  final String sort;
  final Future<void> Function(OfferDoc offer) onAccept;
  final Future<void> Function(OfferDoc offer) onDecline;
  final Future<void> Function(OfferDoc offer) onCounter;
  final Future<void> Function(OfferDoc offer) onContact;

  @override
  Widget build(BuildContext context) {
    Query q = FirebaseFirestore.instance.collection('tasks').doc(taskId).collection('offers');

    if (sort == 'recent') {
      q = q.orderBy('createdAt', descending: true);
    } else if (sort == 'price_low') {
      q = q.orderBy('price', descending: false);
    } else if (sort == 'price_high') {
      q = q.orderBy('price', descending: true);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: q.limit(200).snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const _LoadingList();
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return const _EmptyState();
        final offers = docs.map((d) => OfferDoc.from(d.id, d.data() as Map<String, dynamic>, taskId: taskId)).toList();
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          itemCount: offers.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _OfferCard(
            offer: offers[i],
            incoming: incoming,
            onAccept: onAccept,
            onDecline: onDecline,
            onCounter: onCounter,
            onContact: onContact,
          ),
        );
      },
    );
  }
}

// ===================== OFFER CARD =====================

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.offer,
    required this.incoming,
    required this.onAccept,
    required this.onDecline,
    required this.onCounter,
    required this.onContact,
  });

  final OfferDoc offer;
  final bool incoming;
  final Future<void> Function(OfferDoc offer) onAccept;
  final Future<void> Function(OfferDoc offer) onDecline;
  final Future<void> Function(OfferDoc offer) onCounter;
  final Future<void> Function(OfferDoc offer) onContact;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: price + status chip
            Row(
              children: [
                Text(
                  offer.price != null ? 'LKR ${offer.price}' : 'No price',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(width: 8),
                _StatusChip(offer.status),
                const Spacer(),
                IconButton(
                  tooltip: 'Open task',
                  icon: const Icon(Icons.open_in_new),
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => TaskDetailsScreen(taskId: offer.taskId)));
                  },
                ),
              ],
            ),
            if ((offer.message ?? '').isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(offer.message!, style: TextStyle(color: cs.onSurfaceVariant)),
            ],
            const SizedBox(height: 8),

            // Actions (role-aware)
            Row(
              children: [
                if (incoming) ...[
                  FilledButton.icon(
                    onPressed: () => onAccept(offer),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Accept'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => onDecline(offer),
                    icon: const Icon(Icons.close),
                    label: const Text('Decline'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => onCounter(offer),
                    icon: const Icon(Icons.swap_vert),
                    label: const Text('Counter'),
                  ),
                ] else ...[
                  OutlinedButton.icon(
                    onPressed: offer.status == 'pending'
                        ? () => _editOffer(context, offer)
                        : null,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: offer.status == 'pending'
                        ? () => _withdrawOffer(context, offer)
                        : null,
                    icon: const Icon(Icons.undo),
                    label: const Text('Withdraw'),
                  ),
                ],
                const Spacer(),
                TextButton.icon(
                  onPressed: () => onContact(offer),
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Contact'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editOffer(BuildContext context, OfferDoc offer) async {
    final ctrl = TextEditingController(text: offer.price?.toString() ?? '');
    final newText = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit offer price'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'Enter new price (LKR)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, ctrl.text), child: const Text('Save')),
        ],
      ),
    );
    if (newText == null) return;

    final newPrice = num.tryParse(newText);
    if (newPrice == null) {
      _err(context, 'Invalid price');
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('offers').doc(offer.id).update({
        'price': newPrice,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _ok(context, 'Offer updated.');
    } catch (e) {
      _err(context, 'Could not update: $e');
    }
  }

  Future<void> _withdrawOffer(BuildContext context, OfferDoc offer) async {
    final ok = await _confirm(context, title: 'Withdraw offer', message: 'Withdraw this offer?');
    if (ok != true) return;
    try {
      await FirebaseFirestore.instance.collection('offers').doc(offer.id).update({
        'status': 'withdrawn',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _ok(context, 'Offer withdrawn.');
    } catch (e) {
      _err(context, 'Could not withdraw: $e');
    }
  }
}

// ===================== MODELS & WIDGET HELPERS =====================

class OfferDoc {
  final String id;
  final String taskId;
  final String posterId;
  final String helperId;
  final num? price;
  final String? message;
  final String status; // 'pending'|'accepted'|'declined'|'withdrawn'|'counter'
  final DateTime? createdAt;

  OfferDoc({
    required this.id,
    required this.taskId,
    required this.posterId,
    required this.helperId,
    required this.price,
    required this.message,
    required this.status,
    required this.createdAt,
  });

  factory OfferDoc.from(String id, Map<String, dynamic> m, {String? taskId}) {
    return OfferDoc(
      id: id,
      taskId: taskId ?? (m['taskId'] as String? ?? ''),
      posterId: m['posterId'] as String? ?? '',
      helperId: m['helperId'] as String? ?? '',
      price: (m['price'] as num?),
      message: m['message'] as String?,
      status: m['status'] as String? ?? 'pending',
      createdAt: _asDate(m['createdAt']),
    );
  }
}

DateTime? _asDate(dynamic ts) {
  if (ts == null) return null;
  if (ts is Timestamp) return ts.toDate();
  if (ts is DateTime) return ts;
  return null;
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.status);
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = _statusTone(status);
    return Chip(
      label: Text(label),
      visualDensity: VisualDensity.compact,
      side: BorderSide(color: tone.withOpacity(0.25)),
      backgroundColor: tone.withOpacity(0.10),
    );
  }

  (String, Color) _statusTone(String s) {
    switch (s) {
      case 'pending':
        return ('Pending', Colors.blue);
      case 'accepted':
        return ('Accepted', Colors.green);
      case 'declined':
        return ('Declined', Colors.red);
      case 'withdrawn':
        return ('Withdrawn', Colors.grey);
      case 'counter':
        return ('Counter', Colors.amber);
      default:
        return (s, Colors.blueGrey);
    }
  }
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      itemCount: 6,
      itemBuilder: (_, i) {
        return Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Container(height: 12, width: 120, color: Colors.black12),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Container(height: 10, width: 60, color: Colors.black12),
                  const SizedBox(width: 8),
                  Container(height: 10, width: 80, color: Colors.black12),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 44, color: cs.outline),
            const SizedBox(height: 10),
            const Text('No offers here yet.'),
            const SizedBox(height: 4),
            const Text('Try switching tabs or broadening your filters.'),
          ],
        ),
      ),
    );
  }
}

// ---------------- Dialog helpers ----------------

Future<bool?> _confirm(BuildContext context, {required String title, required String message}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes')),
      ],
    ),
  );
}

Future<String?> _promptCounter(BuildContext context, {String? initial}) {
  final ctrl = TextEditingController(text: initial ?? '');
  return showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Counter price'),
      content: TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(hintText: 'Enter counter price (LKR)'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, ctrl.text), child: const Text('Send')),
      ],
    ),
  );
}

void _ok(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}

void _err(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
}

void _warn(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.orange));
}
