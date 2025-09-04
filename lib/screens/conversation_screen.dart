// lib/screens/conversation_screen.dart
//
// Works with EITHER:
//   ConversationScreen(helperId: 'H123', helperName: 'Alex')
// or
//   ConversationScreen(channelId: 'poster_helper')   // e.g., "uidA_uidB" or a doc id in pairs/
//
// It resolves the helper id/name when only channelId is given, and uses pairs/{id}/messages.
// Also guards Firestore calls and uses a clean Column → Expanded → ListView layout.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:servana/services/intro_fee_service.dart';

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({
    super.key,
    this.helperId,
    this.helperName,
    this.channelId,
  });

  /// Provide these when opening from a helper card/profile.
  final String? helperId;
  final String? helperName;

  /// Provide this when opening from a notification or a chat list
  /// that only knows the channel id (pair id).
  final String? channelId;

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  bool _loading = true;
  bool _unlocked = false;

  String _posterId = '';
  String _helperId = '';
  String _helperName = 'Conversation';
  String _pairId = ''; // pairs/{_pairId}

  final _msgCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      _posterId = user?.uid ?? '';

      // Resolve ids
      if ((widget.helperId ?? '').isNotEmpty) {
        _helperId = widget.helperId!;
        _helperName = (widget.helperName ?? 'Conversation').trim().isEmpty
            ? 'Conversation'
            : widget.helperName!.trim();
        _pairId = _pairKey(_posterId, _helperId);
      } else if ((widget.channelId ?? '').isNotEmpty) {
        _pairId = widget.channelId!.trim();

        // If it looks like "uidA_uidB", derive helperId from it:
        if (_pairId.contains('_')) {
          final parts = _pairId.split('_')..sort();
          // Poster is current user; helper is the other one
          if (parts.length == 2 && _posterId.isNotEmpty) {
            _helperId = (parts[0] == _posterId) ? parts[1] : parts[0];
          }
        }

        // If helperId still unknown, try reading pairs/{pairId}
        if (_helperId.isEmpty) {
          try {
            final p = await FirebaseFirestore.instance
                .collection('pairs')
                .doc(_pairId)
                .get();
            final data = p.data() ?? {};
            final members = (data['members'] as List?)?.map((e) => e.toString()).toList() ?? const [];
            if (members.isNotEmpty && _posterId.isNotEmpty) {
              _helperId = members.firstWhere(
                    (m) => m != _posterId,
                orElse: () => members.first,
              );
            }
            // Try a name on the header: otherName/helperName/displayName
            final hdrName = (data['otherName'] ?? data['helperName'] ?? data['displayName'] ?? '').toString().trim();
            if (hdrName.isNotEmpty) _helperName = hdrName;
          } catch (_) {
            // tolerate missing/permission errors
          }
        }

        // If we STILL don't know helper name, leave generic
      } else {
        // Neither helperId nor channelId given — keep screen benign
        _helperId = '';
        _pairId = '';
      }

      // Unlock state (safe)
      _unlocked = await IntroFeeService.isPairUnlocked(
        posterId: _posterId,
        helperId: _helperId,
      );
    } catch (_) {
      _unlocked = false;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _pairKey(String a, String b) {
    final list = [a, b]..sort();
    return '${list[0]}_${list[1]}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = (_helperName.isEmpty ? 'Conversation' : _helperName);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        centerTitle: false,
      ),
      backgroundColor: cs.background,
      body: Column(
        children: [
          if (_loading) const LinearProgressIndicator(),
          if (!_loading && !_unlocked)
            _LockedBanner(helperName: _helperName),

          Expanded(
            child: _MessagesList(
              posterId: _posterId,
              helperId: _helperId,
              pairId: _pairId.isNotEmpty
                  ? _pairId
                  : (_helperId.isNotEmpty ? _pairKey(_posterId, _helperId) : ''),
            ),
          ),

          _Composer(
            enabled: !_loading && _unlocked && _posterId.isNotEmpty && (_helperId.isNotEmpty || _pairId.isNotEmpty),
            controller: _msgCtrl,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    final effectivePairId = _pairId.isNotEmpty
        ? _pairId
        : (_helperId.isNotEmpty ? _pairKey(_posterId, _helperId) : '');

    if (effectivePairId.isEmpty) {
      // Nothing we can do without ids
      return;
    }

    try {
      final ref = FirebaseFirestore.instance
          .collection('pairs')
          .doc(effectivePairId)
          .collection('messages');

      await ref.add({
        'from': _posterId,
        'to': _helperId, // may be empty if unknown; tolerated
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Header
      await FirebaseFirestore.instance.collection('pairs').doc(effectivePairId).set({
        'members': _helperId.isNotEmpty ? [_posterId, _helperId] : [_posterId],
        'lastMessage': text,
        'updatedAt': FieldValue.serverTimestamp(),
        if (_helperName.isNotEmpty) 'otherName': _helperName,
      }, SetOptions(merge: true));

      _msgCtrl.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send: $e')),
      );
    }
  }
}

class _LockedBanner extends StatelessWidget {
  const _LockedBanner({required this.helperName});
  final String helperName;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          bottom: BorderSide(color: cs.outline.withOpacity(0.12)),
        ),
      ),
      child: Text(
        'Chat is locked. Unlock from the helper card/profile to start messaging ${helperName.isEmpty ? '' : helperName}.',
        style: TextStyle(color: cs.onSurfaceVariant),
      ),
    );
  }
}

class _MessagesList extends StatelessWidget {
  const _MessagesList({
    required this.posterId,
    required this.helperId,
    required this.pairId,
  });

  final String posterId;
  final String helperId;
  final String pairId;

  @override
  Widget build(BuildContext context) {
    // If we still don't have an id, show friendly message
    if ((pairId.isEmpty) && (posterId.isEmpty || helperId.isEmpty)) {
      return const Center(child: Text('Missing chat IDs.'));
    }

    final effectivePairId =
    pairId.isNotEmpty ? pairId : _pairKey(posterId, helperId);

    final q = FirebaseFirestore.instance
        .collection('pairs')
        .doc(effectivePairId)
        .collection('messages')
        .orderBy('createdAt', descending: true);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text('Say hi 👋'));
        }
        return ListView.builder(
          reverse: true,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final m = docs[i].data();
            final from = (m['from'] ?? '').toString();
            final text = (m['text'] ?? '').toString();
            final mine = from == posterId;
            return Align(
              alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: mine
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .outline
                        .withOpacity(0.12),
                  ),
                ),
                child: Text(text),
              ),
            );
          },
        );
      },
    );
  }

  String _pairKey(String a, String b) {
    final list = [a, b]..sort();
    return '${list[0]}_${list[1]}';
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.enabled,
    required this.controller,
    required this.onSend,
  });

  final bool enabled;
  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outline.withOpacity(0.12))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              enabled: enabled,
              controller: controller,
              minLines: 1,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Type a message…',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: enabled ? onSend : null,
            icon: const Icon(Icons.send_rounded),
            label: const Text('Send'),
          ),
        ],
      ),
    );
  }
}
