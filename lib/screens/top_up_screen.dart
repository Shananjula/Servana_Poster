import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class TopUpScreen extends StatefulWidget {
  const TopUpScreen({super.key});

  @override
  State<TopUpScreen> createState() => _TopUpScreenState();
}

class _TopUpScreenState extends State<TopUpScreen> {
  final List<int> _topUpAmounts = [500, 1000, 2000, 5000];
  int? _selectedAmount;
  bool _isProcessing = false;

  Future<void> _processTopUp() async {
    if (_selectedAmount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a top-up amount.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isProcessing = true);

    // --- MOCK PAYMENT GATEWAY ---
    // In a real app, you would integrate the Payhere SDK here.
    // We will simulate a successful payment after a 3-second delay.
    await Future.delayed(const Duration(seconds: 3));

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("You are not logged in.");

      final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

      // Use FieldValue.increment to safely add to the user's balance.
      await userDocRef.update({
        'coinWalletBalance': FieldValue.increment(_selectedAmount!),
      });

      // TODO: Create a document in a `transactions` collection for accounting.

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully topped up ${_selectedAmount!} Coins!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An error occurred: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyFormat = NumberFormat("#,##0", "en_US");

    return Scaffold(
      appBar: AppBar(
        title: const Text('Top Up Wallet'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.account_balance_wallet_outlined, size: 60, color: Colors.blue),
            const SizedBox(height: 16),
            Text(
              'Select Top-Up Amount',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '1 LKR = 1 Helpify Coin. Your wallet balance is used to pay platform commissions.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12.0,
              runSpacing: 12.0,
              children: _topUpAmounts.map((amount) {
                final isSelected = _selectedAmount == amount;
                return ChoiceChip(
                  label: Text('LKR ${currencyFormat.format(amount)}'),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedAmount = amount);
                    }
                  },
                  labelStyle: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : theme.primaryColor,
                  ),
                  selectedColor: theme.primaryColor,
                  backgroundColor: theme.primaryColor.withOpacity(0.1),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                );
              }).toList(),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _isProcessing ? null : _processTopUp,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: _isProcessing
                  ? const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white))
                  : Text(_selectedAmount == null ? 'Select an Amount' : 'Proceed to Pay LKR ${currencyFormat.format(_selectedAmount)}'),
            ),
          ],
        ),
      ),
    );
  }
}
