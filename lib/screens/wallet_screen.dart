// lib/screens/wallet_screen.dart
//
// Wallet for both roles
// • Live balance (from users/{uid}.walletBalance or 0 if missing)
// • Transactions list (transactions where userId == current uid), newest first
// • Top Up button → TopUpScreen (your existing screen)
// • Handles common transaction types: topup, post_gate, direct_contact_fee, commission,
//   milestone, refund, payout
//
// Safe fallbacks: if fields are missing, UI stays graceful.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:servana/screens/top_up_screen.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to view your wallet.')),
      );
    }

    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final txQuery = FirebaseFirestore.instance
        .collection('transactions')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(200);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet'),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: userRef.snapshots(),
        builder: (context, userSnap) {
          final balance = _readBalance(userSnap.data?.data());

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            children: [
              _BalanceCard(
                balance: balance,
                onTopUp: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TopUpScreen()),
                  );
                },
              ),
              const SizedBox(height: 16),
              Text('Transactions', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: txQuery.snapshots(),
                builder: (context, txSnap) {
                  if (txSnap.connectionState == ConnectionState.waiting) {
                    return const _LoadingList();
                  }
                  final docs = txSnap.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Card(
                      child: ListTile(
                        leading: Icon(Icons.receipt_long_outlined),
                        title: Text('No transactions yet'),
                        subtitle: Text('Top up or complete a task to see activity here.'),
                      ),
                    );
                  }

                  return Card(
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final m = docs[i].data();
                        return _TxTile(m: m);
                      },
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  int _readBalance(Map<String, dynamic>? m) {
    if (m == null) return 0;
    final b = m['walletBalance'];
    if (b is int) return b;
    if (b is num) return b.toInt();
    if (b is String) {
      final n = int.tryParse(b);
      if (n != null) return n;
    }
    return 0;
  }
}

// ---------------- Balance Card ----------------

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance, required this.onTopUp});
  final int balance;
  final VoidCallback onTopUp;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current balance', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  'LKR ${_fmt(balance)}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: onTopUp,
                  icon: const Icon(Icons.add),
                  label: const Text('Top up'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Use your balance for posting tasks, direct contacts, or milestone payments.',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- Transaction Tile ----------------

class _TxTile extends StatelessWidget {
  const _TxTile({required this.m});
  final Map<String, dynamic> m;

  @override
  Widget build(BuildContext context) {
    final type = (m['type'] ?? 'unknown') as String;
    final createdAt = m['createdAt'] is Timestamp ? (m['createdAt'] as Timestamp).toDate() : null;
    final amount = (m['amount'] is num) ? (m['amount'] as num).toDouble() : 0.0;
    final status = (m['status'] ?? 'ok') as String; // ok|pending|failed|refunded
    final note = (m['note'] ?? '') as String;

    final (icon, title, tone) = _meta(type, status, amount);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: tone.withOpacity(0.12),
        foregroundColor: tone,
        child: Icon(icon),
      ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('LKR ${_fmtD(amount)} • ${_statusLabel(status)}'),
          if (note.isNotEmpty) Text(note),
          if (createdAt != null)
            Text(
              _timeAgo(createdAt),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
        ],
      ),
      trailing: Text(
        (amount >= 0 ? '+ ' : '- ') + 'LKR ${_fmtD(amount.abs())}',
        style: TextStyle(
          color: amount >= 0 ? Colors.green : Colors.red,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  (IconData, String, Color) _meta(String type, String status, double amount) {
    switch (type) {
      case 'topup':
        return (Icons.account_balance_wallet_outlined, 'Top up', Colors.blue);
      case 'post_gate':
        return (Icons.post_add_outlined, 'Posting gate', Colors.indigo);
      case 'direct_contact_fee':
        return (Icons.chat_bubble_outline, 'Direct contact fee', Colors.purple);
      case 'commission':
        return (Icons.price_check_outlined, 'Platform commission', Colors.orange);
      case 'milestone':
        return (Icons.flag_outlined, 'Milestone payment', Colors.teal);
      case 'refund':
        return (Icons.refresh_outlined, 'Refund', Colors.green);
      case 'payout':
        return (Icons.payments_outlined, 'Payout', Colors.brown);
      default:
        return (Icons.receipt_long_outlined, 'Transaction', Colors.blueGrey);
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'ok':
        return 'Completed';
      case 'pending':
        return 'Pending';
      case 'failed':
        return 'Failed';
      case 'refunded':
        return 'Refunded';
      default:
        return s;
    }
  }
}

// ---------------- Loading ----------------

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        itemCount: 6,
        itemBuilder: (_, i) => const ListTile(
          leading: CircleAvatar(child: Icon(Icons.receipt_long_outlined)),
          title: _ShimmerLine(width: 120),
          subtitle: _ShimmerLine(width: 160),
        ),
      ),
    );
  }
}

class _ShimmerLine extends StatelessWidget {
  const _ShimmerLine({required this.width});
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 10,
      width: width,
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

// ---------------- Utils ----------------

String _fmt(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    final idx = s.length - i;
    buf.write(s[i]);
    if (idx > 1 && idx % 3 == 1) buf.write(',');
  }
  return buf.toString();
}

String _fmtD(double n) => n.toStringAsFixed(2);

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}
