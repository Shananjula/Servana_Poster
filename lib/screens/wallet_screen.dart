import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:servana/models/transaction_model.dart';
import 'package:servana/models/user_model.dart';
import 'package:servana/screens/top_up_screen.dart';
import 'package:intl/intl.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text("Please log in to view your wallet.")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Serv Wallet'),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').doc(currentUser.uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final user = HelpifyUser.fromFirestore(snapshot.data!);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildBalanceCard(context, user),
                const SizedBox(height: 24),
                _buildActions(context, user),
                const SizedBox(height: 24),
                // --- This now points to the real-time widget ---
                _TransactionHistory(userId: currentUser.uid),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBalanceCard(BuildContext context, HelpifyUser user) {
    final theme = Theme.of(context);
    final numberFormat = NumberFormat("#,##0.00 'Serv Coins'", 'en_US');

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: theme.colorScheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Text(
              'Available Balance',
              style: theme.textTheme.titleMedium?.copyWith(color: Colors.white.withOpacity(0.8)),
            ),
            const SizedBox(height: 8),
            Text(
              numberFormat.format(user.servCoinBalance),
              style: theme.textTheme.headlineLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.white24),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.health_and_safety_outlined, color: Colors.white70, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Credit Balance: ${NumberFormat("#,##0.00 'Serv Coins'", 'en_US').format(user.creditCoinBalance)}',
                  style: theme.textTheme.titleMedium?.copyWith(color: Colors.white),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context, HelpifyUser user) {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: () {
            Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => const TopUpScreen()));
          },
          icon: const Icon(Icons.add_card_outlined),
          label: const Text('Top Up Serv Coins'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
            backgroundColor: Theme.of(context).colorScheme.secondary,
          ),
        ),
        if (user.isHelper == true) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Withdrawal functionality coming soon!')));
            },
            icon: const Icon(Icons.account_balance_outlined),
            label: const Text('Withdraw Earnings'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
        ]
      ],
    );
  }
}

// --- Widget for Real-time Transaction History ---
class _TransactionHistory extends StatelessWidget {
  final String userId;
  const _TransactionHistory({required this.userId});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Transaction History',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('transactions')
              .orderBy('timestamp', descending: true)
              .limit(20)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Card(
                child: ListTile(
                  title: Text('No transactions yet.'),
                  subtitle: Text('Your transaction history will appear here.'),
                ),
              );
            }

            final transactions = snapshot.data!.docs
                .map((doc) => TransactionModel.fromFirestore(doc))
                .toList();

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: transactions.length,
              itemBuilder: (context, index) {
                final tx = transactions[index];
                return _TransactionCard(transaction: tx);
              },
            );
          },
        )
      ],
    );
  }
}

// --- Widget to Display a Single Transaction Card ---
class _TransactionCard extends StatelessWidget {
  final TransactionModel transaction;
  const _TransactionCard({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final isCredit = transaction.amount >= 0;
    final color = isCredit ? Colors.green : Colors.red;
    final icon = isCredit ? Icons.arrow_downward : Icons.arrow_upward;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color,
          child: Icon(icon, color: Colors.white),
        ),
        title: Text(transaction.description),
        subtitle: Text(DateFormat.yMMMd().add_jm().format(transaction.timestamp.toDate())),
        trailing: Text(
          '${isCredit ? '+' : ''}${NumberFormat("#,##0").format(transaction.amount)} Coins',
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}