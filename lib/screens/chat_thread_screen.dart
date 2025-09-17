// lib/screens/chat_thread_screen.dart (ALT with relative import)
// Use this if your package import can't find offer_message_card.dart.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../widgets/chat/offer_message_card.dart'; // <-- relative import

class ChatThreadScreen extends StatefulWidget {
  final String chatId;
  final String? highlightOfferId;
  const ChatThreadScreen({super.key, required this.chatId, this.highlightOfferId});

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen> {
  final _listCtrl = ScrollController();

  @override
  void dispose() {
    _listCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cid = widget.chatId;
    final stream = FirebaseFirestore.instance
        .collection('chats/$cid/messages')
        .orderBy('createdAt')
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (_, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No messages yet.'));
          }

          int? highlightIndex;
          if (widget.highlightOfferId != null) {
            for (var i = 0; i < docs.length; i++) {
              final m = docs[i].data();
              if ((m['offerId']?.toString() ?? '') == widget.highlightOfferId) {
                highlightIndex = i; break;
              }
            }
          }

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (highlightIndex != null && _listCtrl.hasClients) {
              final offset = (48.0 * highlightIndex!.clamp(0, docs.length)) - 24.0;
              _listCtrl.animateTo(offset, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
            }
          });

          return ListView.builder(
            controller: _listCtrl,
            padding: const EdgeInsets.all(8),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final m = docs[i].data();
              final type = (m['type'] ?? '').toString();
              final isOffer = type.startsWith('offer.');
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: isOffer
                    ? OfferMessageCard(message: m)
                    : Align(
                        alignment: Alignment.centerLeft,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Text((m['text'] ?? '').toString()),
                          ),
                        ),
                      ),
              );
            },
          );
        },
      ),
    );
  }
}
