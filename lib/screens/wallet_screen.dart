import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:servana/models/user_model.dart';
import 'package:servana/screens/top_up_screen.dart'; // Import the new screen
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
        title: const Text('My Wallet & Earnings'),
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
                _buildTransactionHistory(context),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBalanceCard(BuildContext context, HelpifyUser user) {
    final theme = Theme.of(context);
    final numberFormat = NumberFormat("#,##0.00 'Coins'", 'en_US');

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
              numberFormat.format(user.coinWalletBalance),
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
                  'Credit Balance: ${numberFormat.format(user.creditCoinBalance)}',
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
          // --- UPDATED: Navigate to the new TopUpScreen ---
          onPressed: () {
            Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => const TopUpScreen()));
          },
          icon: const Icon(Icons.add_card_outlined),
          label: const Text('Top Up Wallet'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
            backgroundColor: Theme.of(context).colorScheme.secondary,
          ),
        ),
        if (user.isHelper == true) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              // TODO: Navigate to Withdrawal Screen
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

  Widget _buildTransactionHistory(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Transaction History',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        // Placeholder. This will be replaced with a StreamBuilder on a 'transactions' subcollection.
        Card(
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.green,
              child: Icon(Icons.arrow_downward, color: Colors.white),
            ),
            title: const Text('Earnings from "Garden Cleanup"'),
            subtitle: Text(DateFormat.yMMMd().format(DateTime.now())),
            trailing: const Text(
              '+ 1,500 Coins',
              style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        Card(
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.red,
              child: Icon(Icons.arrow_upward, color: Colors.white),
            ),
            title: const Text('Commission for "Fix Leaky Pipe"'),
            subtitle: Text(DateFormat.yMMMd().format(DateTime.now().subtract(const Duration(days: 1)))),
            trailing: const Text(
              '- 75 Coins',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}
