// lib/screens/conversation_screen.dart — Back-compat, model-free (fixed braces)
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/chat_service_compat.dart';
import '../services/offer_actions.dart';

class ConversationScreen extends StatefulWidget {
  // New-style params
  final String? chatChannelId;
  final String? otherUserId;
  final String? otherUserName;
  final String? taskId;
  final String? taskTitle;

  // Legacy params (still honored)
  final String? helperId;    // maps to otherUserId
  final String? helperName;  // optional display

  const ConversationScreen({
    super.key,
    this.chatChannelId,
    this.otherUserId,
    this.otherUserName,
    this.taskId,
    this.taskTitle,
    // legacy
    this.helperId,
    this.helperName,
  });

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final TextEditingController _msgCtl = TextEditingController();
  final ScrollController _scrollCtl = ScrollController();
  bool _busy = false;

  String? _channelId;    // resolved channel id
  String? _counterpart;  // resolved other user id

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // Resolve other user id from new or legacy field
    final other = widget.otherUserId ?? widget.helperId;
    _counterpart = other;

    // Resolve channel id: use provided or create one
    if ((widget.chatChannelId ?? '').isNotEmpty) {
      setState(() => _channelId = widget.chatChannelId);
      return;
    }

    if ((other ?? '').isEmpty) return;

    final ch = await ChatServiceCompat.instance.createOrGetChannel(
      other!,
      taskId: widget.taskId,
      taskTitle: widget.taskTitle,
      participantNames: {
        other: widget.otherUserName ?? widget.helperName ?? 'User',
      },
    );
    if (mounted) setState(() => _channelId = ch);
  }

  @override
  void dispose() {
    _msgCtl.dispose();
    _scrollCtl.dispose();
    super.dispose();
  }

  CollectionReference<Map<String, dynamic>> _msgs(String channelId) =>
      FirebaseFirestore.instance
          .collection('chats')
          .doc(channelId)
          .collection('messages')
          .withConverter<Map<String, dynamic>>(
            fromFirestore: (snap, _) => snap.data() ?? <String, dynamic>{},
            toFirestore: (data, _) => data,
          );

  DocumentReference<Map<String, dynamic>> _channel(String channelId) =>
      FirebaseFirestore.instance
          .collection('chats')
          .doc(channelId)
          .withConverter<Map<String, dynamic>>(
            fromFirestore: (snap, _) => snap.data() ?? <String, dynamic>{},
            toFirestore: (data, _) => data,
          );

  @override
  Widget build(BuildContext context) {
    final title = widget.taskTitle ?? widget.otherUserName ?? widget.helperName ?? 'Conversation';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Counter offer',
            icon: const Icon(Icons.swap_horiz),
            onPressed: _onCounterFromChat,
          ),
        ],
      ),
      body: (_channelId == null)
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _msgs(_channelId!).orderBy('timestamp').snapshots(),
                    builder: (context, snap) {
                      if (snap.hasError) {
                        return Center(child: Text('Failed to load: ${snap.error}'));
                      }
                      if (!snap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final docs = snap.data!.docs;
                      return ListView.builder(
                        controller: _scrollCtl,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        itemCount: docs.length,
                        itemBuilder: (_, i) {
                          final m = docs[i].data();
                          final me = m['senderId'] == _currentUid();
                          final text = (m['text'] ?? '') as String;
                          return Align(
                            alignment: me ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 2),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: me ? Colors.blue.shade100 : Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(text),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                if (_busy) const LinearProgressIndicator(minHeight: 2),
                _Composer(controller: _msgCtl, onSend: _sendMessage),
              ],
            ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _msgCtl.text.trim();
    if (text.isEmpty || _channelId == null) return;

    final msg = <String, dynamic>{
      'text': text,
      'senderId': _currentUid(),
      'timestamp': FieldValue.serverTimestamp(),
    };

    _msgCtl.clear();
    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final mref = _msgs(_channelId!).doc();
        tx.set(mref, msg);
        tx.update(_channel(_channelId!), {
          'lastMessage': text,
          'lastMessageSenderId': _currentUid(),
          'lastMessageTimestamp': FieldValue.serverTimestamp(),
        });
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtl.hasClients) {
          _scrollCtl.animateTo(
            _scrollCtl.position.maxScrollExtent + 60,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send: $e')));
      }
    }
  }

  Future<void> _onCounterFromChat() async {
    if ((widget.taskId ?? '').isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This chat is not linked to a task.')));
      return;
    }
    final other = _counterpart;
    if ((other ?? '').isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Missing other user id.')));
      return;
    }

    final data = await showDialog<_CounterData>(
      context: context,
      builder: (ctx) => const _CounterDialog(),
    );
    if (data == null) return;

    try {
      setState(() => _busy = true);

      // Find latest negotiable offer (pending/negotiating/counter) for this helper on this task.
      final offerId = await _findLatestNegotiableOffer(taskId: widget.taskId!, helperId: other!);
      if (offerId == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No negotiable offer found for this helper.')));
        return;
      }

      // Update canonical offer (not just a chat bubble).
      await OfferActions.instance.proposeCounter(
        taskId: widget.taskId!,
        offerId: offerId,
        price: data.amount,
        note: data.note,
      );

      // Also drop a small system message for context.
      final text = 'Counter proposed: LKR ${data.amount.toStringAsFixed(0)}'
          '${(data.note?.isNotEmpty ?? false) ? ' — ${data.note}' : ''}';
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final mref = _msgs(_channelId!).doc();
        tx.set(mref, {
          'text': text,
          'senderId': _currentUid(),
          'timestamp': FieldValue.serverTimestamp(),
          'kind': 'system.counter',
          'offerId': offerId,
          'taskId': widget.taskId,
          'amount': data.amount,
        });
        tx.update(_channel(_channelId!), {
          'lastMessage': text,
          'lastMessageSenderId': _currentUid(),
          'lastMessageTimestamp': FieldValue.serverTimestamp(),
        });
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Counter sent')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to counter: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _findLatestNegotiableOffer({
    required String taskId,
    required String helperId,
  }) async {
    final q = await FirebaseFirestore.instance
        .collection('tasks')
        .doc(taskId)
        .collection('offers')
        .where('helperId', isEqualTo: helperId)
        .where('status', whereIn: ['pending', 'negotiating', 'counter'])
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();
    if (q.docs.isEmpty) return null;
    return q.docs.first.id;
  }

  String _currentUid() => FirebaseAuth.instance.currentUser!.uid;
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;

  const _Composer({required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 12, right: 8, bottom: 8),
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Message...',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8, bottom: 8),
            child: FilledButton.icon(
              onPressed: onSend,
              icon: const Icon(Icons.send),
              label: const Text('Send'),
            ),
          ),
        ],
      ),
    );
  }
}

// === Counter dialog ===========================================================

class _CounterDialog extends StatefulWidget {
  const _CounterDialog();

  @override
  State<_CounterDialog> createState() => _CounterDialogState();
}

class _CounterDialogState extends State<_CounterDialog> {
  final TextEditingController _amountCtl = TextEditingController();
  final TextEditingController _noteCtl = TextEditingController();
  final GlobalKey<FormState> _form = GlobalKey<FormState>();

  @override
  void dispose() {
    _amountCtl.dispose();
    _noteCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Counter offer'),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _amountCtl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount (LKR)',
                prefixIcon: Icon(Icons.currency_exchange),
              ),
              validator: (v) {
                final x = num.tryParse(v ?? '');
                if (x == null || x <= 0) return 'Enter a positive number';
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
            final amt = num.parse(_amountCtl.text);
            Navigator.pop(context, _CounterData(amount: amt, note: _noteCtl.text.trim().isEmpty ? null : _noteCtl.text.trim()));
          },
          child: const Text('Send'),
        ),
      ],
    );
  }
}

class _CounterData {
  final num amount;
  final String? note;
  _CounterData({required this.amount, this.note});
}
