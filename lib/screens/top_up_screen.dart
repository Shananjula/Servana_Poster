// lib/screens/top_up_screen.dart
//
// Poster — Top Up Screen (self-contained dev credit)
// ---------------------------------------------------
// • Shows current wallet balance
// • Preset amounts + custom amount
// • Payment method picker (placeholder)
// • DEV ONLY (kDebugMode): credits wallet directly using Firestore
//   and writes a transactions row (type: 'topup_debug').
// • RELEASE: shows a notice that real payments aren't integrated.
//
// Deps: firebase_auth, cloud_firestore, flutter/material, foundation

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TopUpScreen extends StatefulWidget {
  const TopUpScreen({super.key});

  @override
  State<TopUpScreen> createState() => _TopUpScreenState();
}

class _TopUpScreenState extends State<TopUpScreen> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  // Amount model
  final List<int> _presets = const [500, 1000, 2000, 5000];
  int? _selectedPreset = 1000;
  final TextEditingController _customCtrl = TextEditingController(text: '1000');

  // Payment method (placeholder)
  // 0=card, 1=bank, 2=other
  int _method = 0;

  bool _busy = false;

  String? get _uid => _auth.currentUser?.uid;

  int get _effectiveAmount {
    final t = _customCtrl.text.trim();
    if (t.isNotEmpty) {
      final v = int.tryParse(t);
      if (v != null && v > 0) return v;
    }
    return _selectedPreset ?? 0;
  }

  Future<void> _handleTopUp() async {
    final uid = _uid;
    if (uid == null) {
      _snack('Please sign in.');
      return;
    }

    final amount = _effectiveAmount;
    if (amount <= 0) {
      _snack('Enter a valid amount.');
      return;
    }

    setState(() => _busy = true);
    try {
      if (!kDebugMode) {
        _snack('Real payment not yet integrated.');
        return;
      }

      // -------- DEV CREDIT (no service dependency) --------
      final userRef = _db.collection('users').doc(uid);
      final txRef = _db.collection('transactions').doc();

      await _db.runTransaction((trx) async {
        // Increment wallet
        trx.set(userRef, {
          'walletBalance': FieldValue.increment(amount),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Transaction log
        trx.set(txRef, {
          'userId': uid,
          'type': 'topup_debug',
          'amount': amount,
          'status': 'ok',
          'note': 'DEV quick top-up (method=$_method)',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      _snack('Credited LKR $amount (dev).');
      // Optionally: Navigator.of(context).pop();
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Top up')),
      body: uid == null
          ? const Center(child: Text('Please sign in to top up.'))
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _db.collection('users').doc(uid).snapshots(),
        builder: (context, snap) {
          final m = snap.data?.data();
          final balance = (m?['walletBalance'] is num)
              ? (m!['walletBalance'] as num).toInt()
              : 0;

          return AbsorbPointer(
            absorbing: _busy,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _BalanceTile(balance: balance),

                const SizedBox(height: 24),
                Text('Amount', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _presets.map((v) {
                    final selected = int.tryParse(_customCtrl.text.trim()) == v;
                    return ChoiceChip(
                      label: Text('LKR $v'),
                      selected: selected,
                      onSelected: (s) {
                        setState(() {
                          _selectedPreset = v;
                          _customCtrl.text = v.toString();
                        });
                      },
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),
                Text('Custom amount (LKR)', style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 8),
                TextField(
                  controller: _customCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: 'e.g. 1000',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),

                const SizedBox(height: 24),
                Text('Payment method', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                _PaymentMethodTile(
                  title: 'Card (Visa/Master)',
                  icon: Icons.credit_card,
                  value: 0,
                  groupValue: _method,
                  onChanged: (v) => setState(() => _method = v),
                ),
                _PaymentMethodTile(
                  title: 'Bank transfer',
                  icon: Icons.account_balance,
                  value: 1,
                  groupValue: _method,
                  onChanged: (v) => setState(() => _method = v),
                ),
                _PaymentMethodTile(
                  title: 'Other',
                  icon: Icons.account_balance_wallet_outlined,
                  value: 2,
                  groupValue: _method,
                  onChanged: (v) => setState(() => _method = v),
                ),

                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _busy ? null : _handleTopUp,
                  icon: Icon(kDebugMode ? Icons.lock_open : Icons.lock_outline),
                  label: const Text('Top up now'),
                ),

                if (kDebugMode) ...[
                  const SizedBox(height: 16),
                  const Center(
                    child: Text(
                      'DEV: credit instantly (no payment)',
                      style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                    ),
                  ),
                ],

                if (_busy) ...[
                  const SizedBox(height: 16),
                  const Center(child: CircularProgressIndicator()),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BalanceTile extends StatelessWidget {
  final int balance;
  const _BalanceTile({required this.balance});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
              child: const Icon(Icons.account_balance_wallet_outlined, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Current balance', style: t.labelMedium),
                  const SizedBox(height: 4),
                  Text(
                    'LKR $balance',
                    style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentMethodTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final int value;
  final int groupValue;
  final ValueChanged<int> onChanged;

  const _PaymentMethodTile({
    required this.title,
    required this.icon,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return InkWell(
      onTap: () => onChanged(value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).dividerColor,
          ),
        ),
        child: Row(
          children: [
            Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off),
            const SizedBox(width: 12),
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(child: Text(title)),
          ],
        ),
      ),
    );
  }
}
