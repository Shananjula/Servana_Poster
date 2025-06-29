import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Import your centralized models
import '../models/task_model.dart';
import '../models/offer_model.dart';

// Import for navigation after payment
import 'active_task_screen.dart';

// --- The Payment Screen Widget ---
class PaymentScreen extends StatefulWidget {
  final Task task;
  final Offer offer;

  const PaymentScreen({
    Key? key,
    required this.task,
    required this.offer,
  }) : super(key: key);

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _isProcessing = false;

  // --- Mock Payment Processing ---
  Future<void> _processPayment() async {
    setState(() => _isProcessing = true);

    // In a real app, this is where you would integrate with PayHere or another payment gateway.
    await Future.delayed(const Duration(seconds: 3));

    if (mounted) {
      // FIX: The constructor for ActiveTaskScreen only takes 'initialTask'.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => ActiveTaskScreen(
          initialTask: widget.task,
        )),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment Successful! Your task is now active.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalAmount = widget.offer.amount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm & Pay'),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order Summary', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildSummaryRow('Task:', widget.task.title),
                    const Divider(height: 24),
                    _buildSummaryRow('Helper:', widget.offer.helperName),
                    const Divider(height: 24),
                    _buildSummaryRow('Offer Amount:', 'LKR ${NumberFormat("#,##0.00").format(widget.offer.amount)}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text('Payment Details', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildPaymentForm(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(totalAmount, theme),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 16, color: Colors.grey[600])),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentForm() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(decoration: InputDecoration(labelText: 'Card Number', hintText: '**** **** **** ****')),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: TextField(decoration: InputDecoration(labelText: 'Expiry Date', hintText: 'MM/YY'))),
                  const SizedBox(width: 16),
                  Expanded(child: TextField(decoration: InputDecoration(labelText: 'CVV', hintText: '***'))),
                ],
              ),
            ],
          )
      ),
    );
  }

  Widget _buildBottomBar(double totalAmount, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), spreadRadius: 0, blurRadius: 10)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total to Pay:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              Text(
                'LKR ${NumberFormat("#,##0.00").format(totalAmount)}',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.primaryColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text('Your payment is held securely in escrow.', style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isProcessing ? null : _processPayment,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isProcessing
                ? const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white))
                : const Text('Pay Now', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
