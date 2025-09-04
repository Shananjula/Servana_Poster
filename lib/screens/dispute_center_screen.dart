import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:servana/services/firestore_service.dart';

class DisputeCenterScreen extends StatelessWidget {
  const DisputeCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Scaffold(body: Center(child: Text('Please sign in.')));
    return Scaffold(
      appBar: AppBar(title: const Text('Dispute Center')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('disputes').where('participants', arrayContains: uid).snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          }
          final docs = snap.data?.docs ?? const [];
          if (docs.isEmpty) return const Center(child: Text('No disputes.'));
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final d = docs[i];
              final m = d.data();
              final status = (m['status'] as String?) ?? 'open';
              final title = (m['title'] as String?) ?? 'Dispute';
              final resolution = (m['resolution'] as String?) ?? '';
              return ListTile(
                leading: const Icon(Icons.report_gmailerrorred_outlined),
                title: Text(title),
                subtitle: Text('Status: $status${resolution.isNotEmpty ? ' — $resolution' : ''}'),
                onTap: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  showDragHandle: true,
                  builder: (_) => _DisputeDetailSheet(disputeId: d.id),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _DisputeDetailSheet extends StatefulWidget {
  const _DisputeDetailSheet({required this.disputeId});
  final String disputeId;
  @override
  State<_DisputeDetailSheet> createState() => _DisputeDetailSheetState();
}

class _DisputeDetailSheetState extends State<_DisputeDetailSheet> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      initialChildSize: 0.86,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      expand: false,
      builder: (context, controller) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dispute', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton.icon(
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('Add evidence'),
                  onPressed: () async {
                    final url = await _promptText(context, 'Add evidence', 'Paste image/file URL');
                    if (url == null || url.isEmpty) return;
                    await FirestoreService().addEvidenceToDispute(widget.disputeId, url);
                  },
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.rule_folder_outlined),
                  label: const Text('Resolve / Adjust coins'),
                  onPressed: () async {
                    final choice = await _promptText(context, 'Resolution', 'upheld_poster | upheld_helper | partial | void');
                    if (choice == null || choice.isEmpty) return;
                    final posterDeltaStr = await _promptText(context, 'Poster coin Δ (e.g., -5, 0, +3)', '0');
                    final helperDeltaStr = await _promptText(context, 'Helper coin Δ (e.g., -5, 0, +3)', '0');
                    final notes = await _promptText(context, 'Notes (optional)', 'Reason / outcome');
                    final posterDelta = int.tryParse(posterDeltaStr ?? '0') ?? 0;
                    final helperDelta = int.tryParse(helperDeltaStr ?? '0') ?? 0;
                    await FirestoreService().resolveDispute(widget.disputeId, resolution: choice, notes: notes, posterCoinDelta: posterDelta, helperCoinDelta: helperDelta);
                    if (mounted) Navigator.pop(context);
                  },
                ),
              ],
            ),
            const SizedBox(height: 6),
            Expanded(
              child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance.collection('disputes').doc(widget.disputeId).snapshots(),
                builder: (context, snap) {
                  final data = snap.data?.data() ?? const <String, dynamic>{};
                  final urls = (data['evidenceUrls'] is List) ? List<String>.from(data['evidenceUrls']) : const <String>[];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Text('Evidence', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.separated(
                          controller: controller,
                          itemCount: urls.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) => SelectableText(urls[i], maxLines: 2),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _promptText(BuildContext context, String title, String hint) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(controller: ctrl, decoration: InputDecoration(hintText: hint)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('OK')),
        ],
      ),
    );
    if (ok != true) return null;
    return ctrl.text.trim();
  }
}