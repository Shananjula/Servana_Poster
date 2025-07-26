import 'package:flutter/material.dart';
import 'package:servana/models/task_model.dart';
import 'package:servana/services/firestore_service.dart';
import 'package:intl/intl.dart';

/// A screen to handle the final payment for a task and allow for tipping.
/// This screen is triggered after the poster confirms the work is complete.
class PaymentScreen extends StatefulWidget {
  final Task task;
  const PaymentScreen({Key? key, required this.task}) : super(key: key);

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _isProcessing = false;
  double _tipAmount = 0.0;

  /// --- CORRECTED WORKFLOW LOGIC ---
  /// This function now correctly calls the FirestoreService to handle the post-payment flow.
  void _processPayment() async {
    setState(() => _isProcessing = true);

    // In a real app, this is where you would call your payment gateway (e.g., Stripe).
    // The gateway would handle the transaction for widget.task.finalAmount + _tipAmount.
    // For now, we'll just simulate a delay and a successful payment.
    await Future.delayed(const Duration(seconds: 2));

    // After the real payment is confirmed, call our service.
    // The service will update the task status to 'pending_rating' and navigate to the RatingScreen.
    if (mounted) {
      await _firestoreService.markTaskAsPaid(context, widget.task);
    }

    // No need to set _isProcessing back to false, as the screen will be replaced by the RatingScreen.
  }

  @override
  Widget build(BuildContext context) {
    final finalAmount = widget.task.finalAmount ?? widget.task.budget;
    final totalAmount = finalAmount + _tipAmount;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Payment'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.security_rounded, size: 60, color: Colors.green),
            const SizedBox(height: 16),
            Text(
              'Release Payment',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Your payment is held securely and will now be released to ${widget.task.assignedHelperName}.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey[700]),
            ),
            const SizedBox(height: 32),
            _buildSummaryCard(finalAmount, totalAmount, theme),
            const SizedBox(height: 32),
            _buildTipSelector(theme),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(totalAmount, theme),
    );
  }

  Widget _buildSummaryCard(double finalAmount, double totalAmount, ThemeData theme) {
    return Card(
      elevation: 0,
      color: Colors.grey.shade100,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildSummaryRow('Task Amount', finalAmount),
            const SizedBox(height: 12),
            _buildSummaryRow('Tip for Helper', _tipAmount),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total Payment', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                Text(
                  'LKR ${NumberFormat("#,##0.00").format(totalAmount)}',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.green),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[800], fontSize: 16)),
        Text('LKR ${NumberFormat("#,##0.00").format(amount)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildTipSelector(ThemeData theme) {
    final tipPercentages = [0.0, 0.10, 0.15, 0.20];
    final taskAmount = widget.task.finalAmount ?? widget.task.budget;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Add a Tip (Optional)', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text('Show your appreciation for a job well done!', style: TextStyle(color: Colors.grey[700])),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          children: tipPercentages.map((p) {
            final tipValue = taskAmount * p;
            final isSelected = _tipAmount == tipValue;
            return ChoiceChip(
              label: Text(p == 0 ? 'No Tip' : '${(p * 100).toInt()}%'),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _tipAmount = tipValue);
                }
              },
              selectedColor: theme.primaryColor.withOpacity(0.1),
              labelStyle: TextStyle(color: isSelected ? theme.primaryColor : Colors.black),
            );
          }).toList(),
        )
      ],
    );
  }

  Widget _buildBottomBar(double totalAmount, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30), // Added padding for bottom safe area
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), spreadRadius: 0, blurRadius: 10)],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: ElevatedButton(
        onPressed: _isProcessing ? null : _processPayment,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _isProcessing
            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white))
            : Text(
          'Pay LKR ${NumberFormat("#,##0.00").format(totalAmount)}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
