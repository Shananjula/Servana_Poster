// lib/widgets/quick_contact_sheet.dart
//
// Quick Contact Sheet (Poster) — with soft Intro-Fee unlock + Top-up
// - Message + smart templates, photo/voice placeholders, share live location toggle
// - Reads wallet balance at wallets/{uid}.coins (fallback 0) and intro fee from config/introFee.fee (fallback 150)
// - Unlock writes to chatUnlocks/{uid}/helpers/{helperId} and decrements coins
// - If balance insufficient → navigate to TopUpScreen
// - After unlock (or if already unlocked) → open ConversationScreen(helperId, helperName)
//
import 'package:flutter/material.dart';
import 'package:servana/utils/analytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:servana/screens/conversation_screen.dart';
import 'package:servana/screens/top_up_screen.dart';

Future<void> showQuickContactSheet(
  BuildContext context, {
  required String helperId,
  required String helperName,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => _ContactSheet(helperId: helperId, helperName: helperName),
  );
}

class _ContactSheet extends StatefulWidget {
  const _ContactSheet({required this.helperId, required this.helperName});
  final String helperId;
  final String helperName;

  @override
  State<_ContactSheet> createState() => _ContactSheetState();
}

class _ContactSheetState extends State<_ContactSheet> {
  final _msg = TextEditingController(text: '');
  bool _shareLocation = false;
  bool _loading = true;
  bool _unlocked = false;
  int _coins = 0;
  int _fee = 150;

  final _templates = const [
    'Can you come today between 4–6 PM?',
    'What\'s your earliest availability this week?',
    'Please quote for 2 hours and parts included.',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final db = FirebaseFirestore.instance;
      // fee from config
      try {
        final cfg = await db.collection('config').doc('introFee').get();
        final f = cfg.data()?['fee'];
        if (f is int) _fee = f;
        if (f is num) _fee = f.toInt();
      } catch (_) {}
      // wallet
      try {
        final w = await db.collection('wallets').doc(uid).get();
        final c = w.data()?['coins'];
        if (c is int) _coins = c;
        if (c is num) _coins = c.toInt();
      } catch (_) {}
      // unlocked?
      try {
        final unlock = await db.collection('chatUnlocks').doc(uid).collection('helpers').doc(widget.helperId).get();
        _unlocked = unlock.exists;
      } catch (_) {}
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _msg.dispose();
    super.dispose();
  }

  Future<void> _ensureUnlocked() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    if (_unlocked) {
      Analytics.log('chat_unlocked', params: {'helperId': widget.helperId, 'fee': _fee});
      _openChat();
      return;
    }
    // Check balance
    if (_coins < _fee) {
      if (!mounted) return;
      Analytics.log('top_up_prompted', params: {'helperId': widget.helperId});
      final go = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Insufficient coins'),
          content: Text('You need $_fee coins to unlock chat.\nYour balance: $_coins coins.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Top up')),
          ],
        ),
      );
      if (go == true && mounted) {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TopUpScreen()));
      }
      return;
    }

    // Deduct + mark unlocked
    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      final walletRef = db.collection('wallets').doc(uid);
      final unlockRef = db.collection('chatUnlocks').doc(uid).collection('helpers').doc(widget.helperId);
      batch.set(unlockRef, {
        'helperId': widget.helperId,
        'unlockedAt': FieldValue.serverTimestamp(),
        'fee': _fee,
      }, SetOptions(merge: true));
      batch.set(walletRef, {'coins': FieldValue.increment(-_fee)}, SetOptions(merge: true));
      await batch.commit();
      setState(() {
        _unlocked = true;
        _coins -= _fee;
      });
      Analytics.log('chat_unlocked', params: {'helperId': widget.helperId, 'fee': _fee});
      _openChat();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unlock failed: $e')));
    }
  }

  void _openChat() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ConversationScreen(helperId: widget.helperId, helperName: widget.helperName),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.chat_bubble_rounded),
                const SizedBox(width: 8),
                Expanded(child: Text('Contact ${widget.helperName}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in _templates)
                  ActionChip(label: Text(t), onPressed: () => setState(() => _msg.text = t)),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _msg,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Write a message to the helper…',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                IconButton(tooltip: 'Attach photo', onPressed: () {}, icon: const Icon(Icons.photo_camera_rounded)),
                const SizedBox(width: 8),
                IconButton(tooltip: 'Record voice note', onPressed: () {}, icon: const Icon(Icons.mic_rounded)),
                const Spacer(),
                Row(
                  children: [
                    const Text('Share live location'),
                    Switch(value: _shareLocation, onChanged: (v) => setState(() => _shareLocation = v)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_loading) const LinearProgressIndicator(),
            if (!_loading) ...[
              if (!_unlocked)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cs.outline.withOpacity(0.12)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_rounded),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Unlock chat for $_fee coins — credited back if you book within 7 days.')),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text('$_coins coins'),
                      ),
                      const SizedBox(width: 8),
                      TextButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TopUpScreen())), child: const Text('Top up')),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      icon: Icon(_unlocked ? Icons.send_rounded : Icons.lock_open_rounded),
                      label: Text(_unlocked ? 'Send message' : 'Unlock & chat'),
                      onPressed: _loading ? null : () { Analytics.log('chat_unlock_attempt', params: {'helperId': widget.helperId, 'balance': _coins, 'fee': _fee}); _ensureUnlocked(); },
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
