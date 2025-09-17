// lib/screens/manage_offers_screen.dart — Poster app
// Reads offers for a task, shows origin-based fee note, and calls the
// updated Cloud Function via FirestoreService.acceptOffer().
//
// Fee note logic (from SERVANA flow):
//   origin == 'direct'  → "No helper fee (direct invite)"
//   origin == 'public'  → "Helper pays acceptance fee at accept"
//
// This screen expects a taskId (whose offers we list). helperId is kept for
// parity with older callsites and for potential pre-filtering; it's optional.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firestore_service.dart';
import '../services/chat_service.dart';

class ManageOffersScreen extends StatefulWidget {
  const ManageOffersScreen({
    super.key,
    required this.taskId,
    required this.helperId,
  });

  final String taskId;
  final String helperId; // kept for compatibility (may be unused)

  @override
  State<ManageOffersScreen> createState() => _ManageOffersScreenState();
}

class _ManageOffersScreenState extends State<ManageOffersScreen> {
  final _fs = FirestoreService();
  final _chat = ChatService();

  Future<void> _acceptOffer(String offerId) async {
    try {
      await _fs.acceptOffer(taskId: widget.taskId, offerId: offerId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Offer accepted')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not accept: $e')),
      );
    }
  }

  Future<void> _openTaskChat(String otherUid) async {
    final channelId = await _chat.createOrGetChannel(otherUid, taskId: widget.taskId);
    if (!mounted) return;
    // TODO: Navigate to your ConversationScreen using channelId
    // Navigator.push(context, MaterialPageRoute(builder: (_) => ConversationScreen(channelId: channelId)));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Offers')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _fs.streamOffersForTask(widget.taskId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final docs = snap.data?.docs ?? const [];
          if (docs.isEmpty) {
            return const Center(child: Text('No offers yet'));
          }

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final offerDoc = docs[i];
              final m = offerDoc.data();
              final offerId = offerDoc.id;

              final String origin = (m['origin'] as String?)?.toLowerCase().trim() ?? 'public';
              final bool isDirect = origin == 'direct';
              final num? price = (m['price'] as num?);
              final String message = (m['note'] ?? m['message'] ?? '').toString();
              final String? helperId = (m['helperId'] ?? m['createdBy']) as String?;

              // Info line: fee note under price (origin-aware)
              final String feeNote = isDirect
                  ? 'No helper fee (direct invite)'
                  : 'Helper pays acceptance fee at accept';

              return ListTile(
                isThreeLine: message.isNotEmpty,
                title: Text(
                  price == null ? 'Offer' : 'Offer: LKR ${price.toStringAsFixed(0)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (message.isNotEmpty) ...[
                      Text(message),
                      const SizedBox(height: 4),
                    ],
                    Text(feeNote, style: TextStyle(color: cs.onSurfaceVariant)),
                  ],
                ),
                trailing: Wrap(
                  spacing: 8,
                  children: [
                    ElevatedButton(
                      onPressed: () => _acceptOffer(offerId),
                      child: const Text('Accept'),
                    ),
                    OutlinedButton(
                      onPressed: helperId == null ? null : () => _openTaskChat(helperId),
                      child: const Text('Chat'),
                    ),
                  ],
                ),
                // Optional quick action: tap to call helper (if you add a phone read)
                // onTap: helperId == null ? null : () => _callHelper(helperId),
              );
            },
          );
        },
      ),
    );
  }
}
