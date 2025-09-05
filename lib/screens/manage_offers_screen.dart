// lib/screens/manage_offers_screen.dart — Poster app
// Reads offers from tasks/{taskId}/offers, accepts via CF,
// tolerant phone read for helper, task-bound chat uses canonical ID.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../services/chat_service.dart';

class ManageOffersScreen extends StatefulWidget {
  final String taskId;
  final String helperId; // when previewing a specific offer; optional flows may ignore this.

  const ManageOffersScreen({
    super.key,
    required this.taskId,
    required this.helperId,
  });

  @override
  State<ManageOffersScreen> createState() => _ManageOffersScreenState();
}

class _ManageOffersScreenState extends State<ManageOffersScreen> {
  final _fs = FirestoreService();
  final _chat = ChatService();

  Future<void> _acceptOffer(String offerId) async {
    await _fs.acceptOffer(taskId: widget.taskId, offerId: offerId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Offer accepted')),
      );
    }
  }

  Future<void> _openTaskChat(String otherUid) async {
    final channelId =
    await _chat.createOrGetChannel(otherUid, taskId: widget.taskId);
    if (!mounted) return;
    // TODO: push your ChatScreen with channelId
  }

  Future<void> _callHelper(String helperUid) async {
    final phone = await _fs.getUserPhone(helperUid); // tolerant read
    if (phone == null || phone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number found')),
      );
      return;
    }
    // TODO: launchUrl(Uri.parse('tel:$phone'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Offers to your task')),
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
              final offer = offerDoc.data();
              final offerId = offerDoc.id;
              final helperId = offer['createdBy'] as String?;
              final price = offer['price'];
              final message = offer['note'] ?? offer['message'] ?? '';

              return ListTile(
                title: Text('Offer: ${price ?? '-'}'),
                subtitle: Text(message.toString()),
                trailing: Wrap(
                  spacing: 8,
                  children: [
                    ElevatedButton(
                      onPressed: () => _acceptOffer(offerId),
                      child: const Text('Accept'),
                    ),
                    OutlinedButton(
                      onPressed: helperId == null
                          ? null
                          : () => _openTaskChat(helperId),
                      child: const Text('Chat'),
                    ),
                  ],
                ),
                onTap: helperId == null ? null : () => _callHelper(helperId),
              );
            },
          );
        },
      ),
    );
  }
}
