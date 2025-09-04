// lib/widgets/cancel_sheet.dart
//
// Cancel Sheet — fee preview + optional admin override
// - Reads config:
//    * config/fees.cancelFeePct (default 0.05)
//    * config/fees.cancelWindowHours (default 2)
// - If an escrow exists and is funded, shows refund math (refund = total - fee unless override)
// - Writes to task: status 'cancelled' + cancel{by,reason,fee,refund,adminOverride,at}
// - Updates escrow: status 'cancelled', refundAmount
//
import 'package:flutter/material.dart';
import 'package:servana/utils/analytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';


Future<void> showCancelSheet(
  BuildContext context, {
  required String taskId,
  required String helperId,
  required double total, // expected booking total
  String initiator = 'poster', // or 'helper'
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _CancelSheet(taskId: taskId, helperId: helperId, total: total, initiator: initiator),
  );
}

class _CancelSheet extends StatefulWidget {
  const _CancelSheet({required this.taskId, required this.helperId, required this.total, required this.initiator});
  final String taskId;
  final String helperId;
  final double total;
  final String initiator;

  @override
  State<_CancelSheet> createState() => _CancelSheetState();
}

class _CancelSheetState extends State<_CancelSheet> {
  final _reason = TextEditingController();
  bool _adminOverride = false;
  bool _loading = true;
  double _cancelFeePct = 0.05;
  int _windowHours = 2;
  double _refund = 0.0;
  String? _escrowId;
  double _escrowAmount = 0.0;
  bool _escrowFunded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // fee config
      try {
        final cfg = await FirebaseFirestore.instance.collection('config').doc('fees').get();
        final pct = cfg.data()?['cancelFeePct'];
        final win = cfg.data()?['cancelWindowHours'];
        if (pct is num) _cancelFeePct = pct.toDouble();
        if (win is num) _windowHours = win.toInt();
      } catch (_) {}
      // escrow (optional)
      try {
        final es = await FirebaseFirestore.instance
            .collection('escrows')
            .where('taskId', isEqualTo: widget.taskId)
            .limit(1)
            .get();
        if (es.docs.isNotEmpty) {
          final d = es.docs.first;
          _escrowId = d.id;
          final data = d.data();
          _escrowAmount = (data['amount'] as num?)?.toDouble() ?? 0.0;
          _escrowFunded = (data['status'] ?? '') == 'funded' || (data['status'] ?? '') == 'hold';
        }
      } catch (_) {}
    } finally {
      _recompute();
      if (mounted) setState(() => _loading = false);
    }
  }

  void _recompute() {
    final now = DateTime.now();
    // In a full app, compare with scheduledAt & current time to apply window logic.
    final fee = _adminOverride ? 0.0 : (widget.total * _cancelFeePct);
    final base = _escrowFunded ? (_escrowAmount == 0 ? widget.total : _escrowAmount) : widget.total;
    _refund = (base - fee).clamp(0.0, base);
  }

  Future<void> _confirm() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _loading = true);

    try {
      final db = FirebaseFirestore.instance;
      final taskRef = db.collection('tasks').doc(widget.taskId);
      final cancelInfo = {
        'by': widget.initiator,
        'reason': _reason.text.trim().isEmpty ? null : _reason.text.trim(),
        'fee': _adminOverride ? 0.0 : widget.total * _cancelFeePct,
        'refund': _refund,
        'adminOverride': _adminOverride,
        'at': FieldValue.serverTimestamp(),
      };
      final batch = db.batch();
      batch.set(taskRef, {'status': 'cancelled', 'cancel': cancelInfo, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      if (_escrowId != null) {
        final escRef = db.collection('escrows').doc(_escrowId);
        batch.set(escRef, {'status': 'cancelled', 'refundAmount': _refund, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      }
      await batch.commit();
      Analytics.log('cancel_confirm', params: {'taskId': widget.taskId, 'feePct': _cancelFeePct, 'refund': _refund, 'adminOverride': _adminOverride});
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cancelled. Refund/fee applied.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cancel failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Cancel booking', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('Total: LKR ${widget.total.toStringAsFixed(0)}', style: TextStyle(color: cs.onSurfaceVariant)),
            const SizedBox(height: 12),
            TextField(
              controller: _reason,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Reason (optional)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            if (_loading) const LinearProgressIndicator(),
            if (!_loading) ...[
              Row(
                children: [
                  const Expanded(child: Text('Cancellation fee')),
                  Text('${(_cancelFeePct * 100).toStringAsFixed(0)}%'),
                ],
              ),
              const SizedBox(height: 6),
              if (_escrowFunded) Row(
                children: [
                  const Expanded(child: Text('Escrow amount')),
                  Text('LKR ${_escrowAmount.toStringAsFixed(0)}'),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Expanded(child: Text('Refund to you')),
                  Text('LKR ${_refund.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                value: _adminOverride,
                title: const Text('Admin override (waive fee)'),
                subtitle: const Text('For ops/admin use only'),
                onChanged: (v) => setState(() { _adminOverride = v; _recompute(); }),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.cancel_rounded),
                      label: const Text('Confirm cancel'),
                      onPressed: _confirm,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
