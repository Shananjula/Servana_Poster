// lib/screens/manage_offers_screen_v2.dart — resilient + clear errors
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/offer_actions.dart';

class ManageOffersScreenV2 extends StatefulWidget {
  final String? taskId;
  final String? taskTitle;
  final FutureOr<void> Function(String? helperId, {String? taskId})? onOpenChat;

  // Legacy style accepted (ignored unless taskId missing)
  final dynamic task;
  final dynamic currentUser;

  const ManageOffersScreenV2({
    super.key,
    this.taskId,
    this.taskTitle,
    this.onOpenChat,
    this.task,
    this.currentUser,
  });

  @override
  State<ManageOffersScreenV2> createState() => _ManageOffersScreenV2State();
}

class _ManageOffersScreenV2State extends State<ManageOffersScreenV2> {
  final _money = NumberFormat.currency(locale: 'en_US', symbol: 'LKR ');
  bool _busy = false;

  String get _tid {
    if ((widget.taskId ?? '').isNotEmpty) return widget.taskId!;
    final t = widget.task;
    if (t != null) {
      try { final v = t.id?.toString(); if (v != null && v.isNotEmpty) return v; } catch (_) {}
      try { final v = t['id']?.toString(); if (v != null && v.isNotEmpty) return v; } catch (_) {}
    }
    throw StateError('Offers: missing taskId');
  }

  String? get _title {
    if ((widget.taskTitle ?? '').isNotEmpty) return widget.taskTitle;
    final t = widget.task;
    if (t != null) {
      try { final v = t.title?.toString(); if (v != null && v.isNotEmpty) return v; } catch (_) {}
      try { final v = t['title']?.toString(); if (v != null && v.isNotEmpty) return v; } catch (_) {}
    }
    return null;
  }

  CollectionReference<Map<String, dynamic>> _offersCol(String taskId) =>
      FirebaseFirestore.instance
          .collection('tasks')
          .doc(taskId)
          .collection('offers')
          .withConverter<Map<String, dynamic>>(
            fromFirestore: (snap, _) => snap.data() ?? <String, dynamic>{},
            toFirestore: (data, _) => data,
          );

  @override
  Widget build(BuildContext context) {
    final tid = _tid;
    final title = _title;
    return Scaffold(
      appBar: AppBar(title: Text(title == null ? 'Offers' : 'Offers — $title')),
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _offersCol(tid).orderBy('createdAt', descending: true).snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                return _error('Failed to load offers: ${snap.error}');
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snap.data!.docs;
              if (docs.isEmpty) {
                return _empty('No offers yet. Check back soon.');
              }
              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemBuilder: (_, i) => _OfferCard(
                  taskId: tid,
                  taskTitle: title,
                  offerId: docs[i].id,
                  offer: docs[i].data(),
                  money: _money,
                  onOpenChat: widget.onOpenChat,
                  onBusy: (v) => setState(() => _busy = v),
                ),
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemCount: docs.length,
              );
            },
          ),
          if (_busy)
            Container(color: Colors.black26, child: const Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }

  Widget _empty(String text) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.inbox, size: 56, color: Colors.grey),
              const SizedBox(height: 12),
              Text(text, textAlign: TextAlign.center),
            ],
          ),
        ),
      );

  Widget _error(String text) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(text, textAlign: TextAlign.center),
        ),
      );
}

class _OfferCard extends StatelessWidget {
  final String taskId;
  final String? taskTitle;
  final String offerId;
  final Map<String, dynamic> offer;
  final NumberFormat money;
  final FutureOr<void> Function(String? helperId, {String? taskId})? onOpenChat;
  final ValueChanged<bool>? onBusy;

  const _OfferCard({
    required this.taskId,
    required this.taskTitle,
    required this.offerId,
    required this.offer,
    required this.money,
    this.onOpenChat,
    this.onBusy,
  });

  @override
  Widget build(BuildContext context) {
    final helperName = (offer['helperName'] ?? offer['helper_display_name'] ?? offer['helperDisplayName'] ?? 'Helper').toString();
    final helperId = (offer['helperId'] ?? offer['helper_id'] ?? offer['uid'] ?? offer['userId'] ?? '').toString();
    final price = _bestPrice(offer);
    final msg = (offer['message'] ?? offer['note'] ?? '').toString();
    final status = (offer['status'] ?? 'pending').toString();
    final createdAt = (offer['createdAt'] as Timestamp?)?.toDate() ?? (offer['created_at'] as Timestamp?)?.toDate();
    final updatedAt = (offer['updatedAt'] as Timestamp?)?.toDate() ?? (offer['updated_at'] as Timestamp?)?.toDate();

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(child: Icon(Icons.person)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(helperName, style: const TextStyle(fontWeight: FontWeight.w600)),
                      if (createdAt != null)
                        Text('Offered ${_rel(createdAt)}', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                _StatusChip(status: status),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text('Price:', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(width: 6),
                Text(
                  price != null ? money.format(price) : '—',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (offer['counterPrice'] != null) ...[
                  const SizedBox(width: 10),
                  const Icon(Icons.swap_horiz, size: 16),
                  const SizedBox(width: 4),
                  Text('Counter: ${_fmt(money, offer['counterPrice'])}'),
                ],
              ],
            ),
            if (msg.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(msg),
            ],
            if (updatedAt != null) ...[
              const SizedBox(height: 8),
              Text('Updated ${_rel(updatedAt)}', style: Theme.of(context).textTheme.bodySmall),
            ],
            const Divider(height: 20),
            _ActionRow(
              taskId: taskId,
              offerId: offerId,
              offer: offer,
              money: money,
              onOpenChat: onOpenChat,
              onBusy: onBusy,
              taskTitle: taskTitle,
              helperId: helperId.isEmpty ? null : helperId,
            ),
          ],
        ),
      ),
    );
  }

  static String _fmt(NumberFormat n, dynamic v) {
    if (v is num) return n.format(v);
    final x = num.tryParse('$v'); return x == null ? '$v' : n.format(x);
  }

  static String _rel(DateTime when) {
    final now = DateTime.now();
    final d = now.difference(when);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} h ago';
    return '${d.inDays} d ago';
  }

  static num? _bestPrice(Map<String, dynamic> o) {
    final cp = o['counterPrice'];
    if (cp is num) return cp;
    final p = o['price'] ?? o['amount'] ?? o['offerPrice'];
    return p is num ? p : null;
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    switch (status) {
      case 'counter':
        bg = Colors.orange.shade100;
        break;
      case 'accepted':
      case 'assigned':
        bg = Colors.green.shade100;
        break;
      case 'rejected':
      case 'withdrawn':
        bg = Colors.red.shade100;
        break;
      default:
        bg = Colors.blueGrey.shade100;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(status),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final String taskId;
  final String offerId;
  final Map<String, dynamic> offer;
  final NumberFormat money;
  final FutureOr<void> Function(String? helperId, {String? taskId})? onOpenChat;
  final ValueChanged<bool>? onBusy;
  final String? taskTitle;
  final String? helperId;

  const _ActionRow({
    required this.taskId,
    required this.offerId,
    required this.offer,
    required this.money,
    this.onOpenChat,
    this.onBusy,
    this.taskTitle,
    this.helperId,
  });

  @override
  Widget build(BuildContext context) {
    final status = (offer['status'] ?? 'pending').toString();
    final canNegotiate = status == 'pending' || status == 'negotiating' || status == 'counter';
    final canAccept = canNegotiate;
    final canReject = canNegotiate;

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        if (canNegotiate)
          OutlinedButton.icon(
            icon: const Icon(Icons.swap_horiz),
            label: const Text('Counter'),
            onPressed: () => _onCounter(context),
          ),
        if (canReject)
          OutlinedButton.icon(
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Reject'),
            onPressed: () => _onReject(context),
          ),
        if (canAccept)
          FilledButton.icon(
            icon: const Icon(Icons.check_circle),
            label: const Text('Accept'),
            onPressed: () => _onAccept(context, helperId),
          ),
        if ((helperId ?? '').isNotEmpty)
          TextButton.icon(
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('Chat'),
            onPressed: () => _openChat(context, helperId!),
          ),
      ],
    );
  }

  Future<void> _onCounter(BuildContext context) async {
    final result = await showDialog<_CounterPayload>(
      context: context,
      builder: (ctx) => _CounterDialog(money: money),
    );
    if (result == null) return;

    try {
      onBusy?.call(true);
      await OfferActions.instance.proposeCounter(
        taskId: taskId,
        offerId: offerId,
        price: result.amount,
        note: result.note?.trim(),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Counter proposed at ${money.format(result.amount)}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to counter: $e')),
      );
    } finally {
      onBusy?.call(false);
    }
  }

  Future<void> _onReject(BuildContext context) async {
    final reason = await showDialog<String?>(
      context: context,
      builder: (ctx) => _RejectDialog(),
    );
    if (reason == null) return;

    try {
      onBusy?.call(true);
      await OfferActions.instance.rejectOffer(
        taskId: taskId,
        offerId: offerId,
        reason: reason.trim().isEmpty ? null : reason.trim(),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Offer rejected')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to reject: $e')),
      );
    } finally {
      onBusy?.call(false);
    }
  }

  Future<void> _onAccept(BuildContext context, String? helperId) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Accept offer?'),
        content: const Text('This will assign the task and notify the helper.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Accept')),
        ],
      ),
    );
    if (yes != true) return;

    try {
      onBusy?.call(true);
      await OfferActions.instance.acceptOffer(taskId: taskId, offerId: offerId);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Offer accepted')));
      }

      if (onOpenChat != null) {
        await onOpenChat!(helperId, taskId: taskId);
      } else if (context.mounted) {
        Navigator.of(context).pushNamed('/conversation', arguments: {
          'otherUserId': helperId,
          'helperId': helperId,
          'taskId': taskId,
          'taskTitle': taskTitle,
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to accept: $e')),
      );
    } finally {
      onBusy?.call(false);
    }
  }

  Future<void> _openChat(BuildContext context, String helperId) async {
    try {
      if (onOpenChat != null) {
        await onOpenChat!(helperId, taskId: taskId);
      } else {
        Navigator.of(context).pushNamed('/conversation', arguments: {
          'otherUserId': helperId,
          'helperId': helperId,
          'taskId': taskId,
          'taskTitle': taskTitle,
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open chat: $e')),
      );
    }
  }
}

class _CounterDialog extends StatefulWidget {
  final NumberFormat money;
  const _CounterDialog({required this.money});

  @override
  State<_CounterDialog> createState() => _CounterDialogState();
}

class _CounterDialogState extends State<_CounterDialog> {
  final _priceCtl = TextEditingController();
  final _noteCtl = TextEditingController();
  final _form = GlobalKey<FormState>();

  @override
  void dispose() {
    _priceCtl.dispose();
    _noteCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Propose counter'),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _priceCtl,
              decoration: const InputDecoration(
                labelText: 'Counter amount (LKR)',
                prefixIcon: Icon(Icons.currency_exchange),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                final x = num.tryParse(v ?? '');
                if (x == null || x <= 0) return 'Enter a positive amount';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _noteCtl,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                prefixIcon: Icon(Icons.sticky_note_2_outlined),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (!_form.currentState!.validate()) return;
            final amt = num.parse(_priceCtl.text);
            Navigator.pop(context, _CounterPayload(amount: amt, note: _noteCtl.text));
          },
          child: const Text('Counter'),
        ),
      ],
    );
  }
}

class _RejectDialog extends StatefulWidget {
  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final _reasonCtl = TextEditingController();

  @override
  void dispose() {
    _reasonCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reject offer'),
      content: TextField(
        controller: _reasonCtl,
        decoration: const InputDecoration(
          labelText: 'Reason (optional)',
          hintText: 'e.g., price too high, timing mismatch',
        ),
        maxLines: 2,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(context, _reasonCtl.text.trim()),
          child: const Text('Reject'),
        ),
      ],
    );
  }
}

class _CounterPayload {
  final num amount;
  final String? note;
  _CounterPayload({required this.amount, this.note});
}
