// lib/widgets/chat/offer_message_card.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:servana/services/offer_actions.dart';

class OfferMessageCard extends StatefulWidget {
  final Map message; // chats/{cid}/messages doc data
  const OfferMessageCard({super.key, required this.message});

  @override
  State createState() => _OfferMessageCardState();
}

class _OfferMessageCardState extends State<OfferMessageCard> {
  bool _busy = false;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    final m = widget.message;
    final theme = Theme.of(context);
    final type = (m['type'] ?? '').toString();
    final offerId = (m['offerId'] ?? '').toString();
    final status = (m['status'] ?? '').toString();
    final amount = m['amount'];
    final counterPrice = m['counterPrice'];
    final helperCounterPrice = m['helperCounterPrice'];
    final origin = (m['origin'] ?? 'public').toString();
    final posterId = (m['posterId'] ?? '').toString();
    final helperId = (m['helperId'] ?? '').toString();
    final isPoster = _uid == posterId;
    final isHelper = _uid == helperId;

    final title = _titleFor(type, status);
    final rows = <Widget>[];

    rows.add(Text(title, style: theme.textTheme.titleMedium));
    rows.add(const SizedBox(height: 4));
    if (amount != null) rows.add(Text('Offer: $amount'));
    if (counterPrice != null) rows.add(Text('Counter: $counterPrice'));
    if (helperCounterPrice != null) rows.add(Text('Helper counter: $helperCounterPrice'));
    if (origin == 'public' && isPoster) {
      rows.add(Text('Helper pays acceptance fee on Accept', style: theme.textTheme.bodySmall));
    } else if (origin == 'direct' && isPoster) {
      rows.add(Text('No helper fee on Accept (direct invite path)', style: theme.textTheme.bodySmall));
    }

    final actions = _actions(
      type: type,
      status: status,
      isPoster: isPoster,
      isHelper: isHelper,
      offerId: offerId,
    );

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...rows,
            if (actions.isNotEmpty) const SizedBox(height: 8),
            if (actions.isNotEmpty)
              Wrap(
                spacing: 8, runSpacing: -6,
                children: actions.map((a) => a).toList(),
              ),
            if (_busy) const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(minHeight: 2),
            )
          ],
        ),
      ),
    );
  }

  String _titleFor(String type, String status) {
    switch (type) {
      case 'offer.created': return 'Offer submitted';
      case 'offer.counter.poster': return 'Poster countered';
      case 'offer.counter.helper': return 'Helper countered';
      case 'offer.agreed': return 'Helper agreed to counter';
      case 'offer.rejected': return 'Offer rejected';
      case 'offer.withdrawn': return 'Offer withdrawn';
      case 'offer.accepted': return 'Offer accepted';
      default:
        return status.isNotEmpty ? 'Offer $status' : 'Offer update';
    }
  }

  List<Widget> _actions({
    required String type,
    required String status,
    required bool isPoster,
    required bool isHelper,
    required String offerId,
  }) {
    final a = <Widget>[];

    // Poster actions
    if (isPoster) {
      if (status == 'pending' || status == 'negotiating' || status == 'counter') {
        a.add(OutlinedButton.icon(
          icon: const Icon(Icons.swap_horiz),
          label: const Text('Counter'),
          onPressed: _busy ? null : () => _counterDialog(offerId),
        ));
        a.add(OutlinedButton.icon(
          icon: const Icon(Icons.close),
          label: const Text('Reject'),
          onPressed: _busy ? null : () => _reject(offerId),
        ));
        a.add(FilledButton.icon(
          icon: const Icon(Icons.check_circle),
          label: const Text('Accept'),
          onPressed: _busy ? null : () => _accept(offerId),
        ));
      }
    }

    // Helper actions
    if (isHelper) {
      if (status == 'pending' || status == 'negotiating' || status == 'counter') {
        if (status == 'counter') {
          a.add(FilledButton.icon(
            icon: const Icon(Icons.check_circle),
            label: const Text('Agree'),
            onPressed: _busy ? null : () => _agree(offerId),
          ));
        }
        a.add(OutlinedButton.icon(
          icon: const Icon(Icons.swap_horiz),
          label: const Text('Counter back'),
          onPressed: _busy ? null : () => _helperCounterDialog(offerId),
        ));
        a.add(OutlinedButton.icon(
          icon: const Icon(Icons.logout),
          label: const Text('Withdraw'),
          onPressed: _busy ? null : () => _withdraw(offerId),
        ));
      }
    }

    return a;
  }

  Future<void> _counterDialog(String offerId) async {
    if (!mounted) return;
    final controller = TextEditingController();
    final noteCtrl = TextEditingController();
    final res = await showDialog<Map<String,String>?>(
      context: context,
      builder: (ctx) => AlertDialog(
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
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop({'p': controller.text, 'n': noteCtrl.text}), child: const Text('Send'))
        ],
      ),
    );
    if (!mounted) return;
    if (res == null) return;
    final raw = (res['p'] ?? '').trim();
    if (raw.isEmpty) return;
    final price = num.tryParse(raw);
    if (price == null || price <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid price')));
      return;
    }

    setState(() => _busy = true);
    try {
      // Prefer taskId from the message, fallback to top-level offer doc
      String? taskId = (widget.message['taskId'] ?? widget.message['task_id'])?.toString();
      if (taskId == null || taskId.isEmpty) {
        final doc = await FirebaseFirestore.instance.collection('offers').doc(offerId).get();
        if (doc.exists && doc.data()?['taskId'] != null) {
          taskId = doc.data()!['taskId'].toString();
        }
      }

      if (!mounted) return;
      await OfferActions.instance.proposeCounter(
        offerId: offerId,
        price: price,
        note: (res['n'] ?? '').toString().trim(),
        taskId: taskId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Counter sent')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Counter failed: $e')));
    } finally {
      if (!mounted) return;
      setState(() => _busy = false);
    }
  }

  Future<void> _helperCounterDialog(String offerId) async {
    if (!mounted) return;
    final controller = TextEditingController();
    final res = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Your counter price'),
        content: TextField(controller: controller, keyboardType: TextInputType.number),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(controller.text), child: const Text('Send')),
        ],
      ),
    );
    if (!mounted) return;
    if (res == null || res.trim().isEmpty) return;
    final price = num.tryParse(res.trim());
    if (price == null || price <= 0) return;

    setState(() => _busy = true);
    try {
      String? taskId = (widget.message['taskId'] ?? widget.message['task_id'])?.toString();
      if (taskId == null || taskId.isEmpty) {
        final doc = await FirebaseFirestore.instance.collection('offers').doc(offerId).get();
        if (doc.exists && doc.data()?['taskId'] != null) {
          taskId = doc.data()!['taskId'].toString();
        }
      }
      if (!mounted) return;
      await OfferActions.instance.helperCounter(offerId: offerId, price: price, taskId: taskId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Counter sent')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Counter failed: $e')));
    } finally {
      if (!mounted) return;
      setState(() => _busy = false);
    }
  }

  Future<void> _reject(String offerId) async {
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      String? taskId = (widget.message['taskId'] ?? widget.message['task_id'])?.toString();
      await OfferActions.instance.rejectOffer(offerId: offerId, taskId: taskId);
    } finally {
      if (!mounted) return;
      setState(() => _busy = false);
    }
  }

  Future<void> _withdraw(String offerId) async {
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      String? taskId = (widget.message['taskId'] ?? widget.message['task_id'])?.toString();
      await OfferActions.instance.withdrawOffer(offerId: offerId, taskId: taskId);
    } finally {
      if (!mounted) return;
      setState(() => _busy = false);
    }
  }

  Future<void> _agree(String offerId) async {
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      String? taskId = (widget.message['taskId'] ?? widget.message['task_id'])?.toString();
      await OfferActions.instance.agreeToCounter(offerId: offerId, taskId: taskId);
    } finally {
      if (!mounted) return;
      setState(() => _busy = false);
    }
  }

  Future<void> _accept(String offerId) async {
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      String? taskId = (widget.message['taskId'] ?? widget.message['task_id'])?.toString();
      if (taskId == null || taskId.isEmpty) {
        final doc = await FirebaseFirestore.instance.collection('offers').doc(offerId).get();
        final data = doc.data();
        final foundTaskId = (data != null && data['taskId'] != null) ? data['taskId'].toString() : '';
        taskId = foundTaskId;
      }
      if (!mounted) return;
      await OfferActions.instance.acceptOffer(offerId: offerId, taskId: taskId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Accept failed: $e')));
    } finally {
      if (!mounted) return;
      setState(() => _busy = false);
    }
  }
}
