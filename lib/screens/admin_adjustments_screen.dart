// lib/screens/admin_adjustments_screen.dart
//
// Admin Adjustments — fee/refund overrides
// - Only visible if current user has users/{uid}.isAdmin == true
// - Lists recent tasks with cancelled/dispute/completed states
// - Allows setting adminAdjustment { feeDelta, refundDelta, note } which updates the task and (if present) escrow
//
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdminAdjustmentsScreen extends StatelessWidget {
  const AdminAdjustmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, snap) {
        final isAdmin = (snap.data?.data()?['isAdmin'] ?? false) == true;
        if (!isAdmin) {
          return Scaffold(appBar: AppBar(title: const Text('Admin adjustments')), body: const Center(child: Text('Admins only')));
        }
        final q = FirebaseFirestore.instance
            .collection('tasks')
            .where('status', whereIn: ['cancelled','completed','disputed'])
            .orderBy('updatedAt', descending: true)
            .limit(50)
            .snapshots();
        return Scaffold(
          appBar: AppBar(title: const Text('Admin adjustments')),
          body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: q,
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snap.data!.docs;
              if (docs.isEmpty) return const Center(child: Text('Nothing to adjust.'));
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (ctx, i) {
                  final d = docs[i];
                  final data = d.data();
                  return _AdjustTile(taskId: d.id, data: data);
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _AdjustTile extends StatefulWidget {
  const _AdjustTile({required this.taskId, required this.data});
  final String taskId;
  final Map<String, dynamic> data;

  @override
  State<_AdjustTile> createState() => _AdjustTileState();
}

class _AdjustTileState extends State<_AdjustTile> {
  final _note = TextEditingController();
  double _feeDelta = 0.0;
  double _refundDelta = 0.0;
  bool _loading = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      final db = FirebaseFirestore.instance;
      final taskRef = db.collection('tasks').doc(widget.taskId);
      final adj = {
        'feeDelta': _feeDelta,
        'refundDelta': _refundDelta,
        'note': _note.text.trim().isEmpty ? null : _note.text.trim(),
        'at': FieldValue.serverTimestamp(),
      };
      await taskRef.set({'adminAdjustment': adj, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      // If escrow exists, apply deltas
      try {
        final es = await db.collection('escrows').where('taskId', isEqualTo: widget.taskId).limit(1).get();
        if (es.docs.isNotEmpty) {
          final ref = db.collection('escrows').doc(es.docs.first.id);
          await ref.set({'adminAdjustment': adj, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
        }
      } catch (_) {}
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Adjustment saved.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = (widget.data['title'] ?? 'Task').toString();
    final status = (widget.data['status'] ?? 'unknown').toString();
    final total = (widget.data['total'] as num?)?.toDouble() ?? 0.0;
    final fee = (widget.data['fee'] as num?)?.toDouble() ?? 0.0;
    final refund = (widget.data['cancel']?['refund'] as num?)?.toDouble() ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Status: $status — Total: LKR ${total.toStringAsFixed(0)} — Fee: LKR ${fee.toStringAsFixed(0)} — Refund: LKR ${refund.toStringAsFixed(0)}',
              style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Fee delta (LKR)'),
                  onChanged: (v) => _feeDelta = double.tryParse(v) ?? 0.0,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Refund delta (LKR)'),
                  onChanged: (v) => _refundDelta = double.tryParse(v) ?? 0.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _note,
            decoration: const InputDecoration(labelText: 'Note (optional)'),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              icon: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_rounded),
              label: const Text('Save'),
              onPressed: _loading ? null : _save,
            ),
          )
        ],
      ),
    );
  }
}
