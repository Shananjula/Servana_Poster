// lib/widgets/booking_sheet.dart
//
// Booking Sheet — price clarity + confirm
// - Packages: Basic/Standard/Premium with inclusions, or just a single "From" price
// - Fixed vs hourly flag
// - Travel fee policy text (up to 5 km included)
// - Fee preview (service fee %) and total
// - Confirm writes a task with status 'booked' to Firestore
//
import 'package:flutter/material.dart';
import 'package:servana/utils/analytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';


Future<void> showBookingSheet(
  BuildContext context, {
  required String helperId,
  required String helperName,
  String? category,
  int? priceFrom,
  bool hourly = false,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _BookingSheet(
      helperId: helperId,
      helperName: helperName,
      category: category,
      priceFrom: priceFrom,
      hourly: hourly,
    ),
  );
}

class _BookingSheet extends StatefulWidget {
  const _BookingSheet({
    required this.helperId,
    required this.helperName,
    this.category,
    this.priceFrom,
    this.hourly = false,
  });

  final String helperId;
  final String helperName;
  final String? category;
  final int? priceFrom;
  final bool hourly;

  @override
  State<_BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends State<_BookingSheet> {
  String _pkg = 'Basic';
  int _price = 0;
  double _feePct = 0.10;
  DateTime? _when;

  @override
  void initState() {
    super.initState();
    _price = widget.priceFrom ?? 0;
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      final cfg = await FirebaseFirestore.instance.collection('config').doc('fees').get();
      final p = cfg.data()?['serviceFeePct'];
      if (p is num) setState(() => _feePct = p.toDouble());
    } catch (_) {}
  }

  double get _fee => _price * _feePct;
  double get _total => _price + _fee;

  Future<void> _pickTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(context: context, firstDate: now, lastDate: now.add(const Duration(days: 30)), initialDate: now);
    if (date == null) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 2))));
    if (time == null) return;
    final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() => _when = dt);
  }

  Future<void> _confirm() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    if (_price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please set a price to continue.')));
      return;
    }
    final db = FirebaseFirestore.instance;
    try {
      final task = await db.collection('tasks').add({
        'posterId': uid,
        'helperId': widget.helperId,
        'title': '${widget.category ?? 'Service'} with ${widget.helperName}',
        'category': widget.category ?? 'General',
        'price': _price,
        'fee': _fee,
        'feePct': _feePct,
        'total': _total,
        'hourly': widget.hourly,
        'status': 'booked',
        'scheduledAt': _when == null ? null : Timestamp.fromDate(_when!),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      // Soft-create an escrow hold
      try {
        Analytics.log('book_confirm', params: {'helperId': widget.helperId, 'price': _price, 'fee': _fee, 'total': _total, 'hourly': widget.hourly});
      await db.collection('escrows').add({
          'taskId': task.id,
          'posterId': uid,
          'helperId': widget.helperId,
          'amount': _total,
          'status': 'hold',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}
      Navigator.pop(context); // close sheet
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking created. Check Activity → Booked.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Booking failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Book ${widget.helperName}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(widget.category ?? 'General', style: TextStyle(color: cs.onSurfaceVariant)),
            const SizedBox(height: 12),
            const Text('Package', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'Basic', label: Text('Basic')),
                ButtonSegment(value: 'Standard', label: Text('Standard')),
                ButtonSegment(value: 'Premium', label: Text('Premium')),
              ],
              selected: {_pkg},
              onSelectionChanged: (s) => setState(() => _pkg = s.first),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Price (LKR)'),
                    controller: TextEditingController(text: _price.toString()),
                    onChanged: (v) => setState(() => _price = int.tryParse(v) ?? 0),
                  ),
                ),
                const SizedBox(width: 12),
                if (widget.hourly) const Chip(label: Text('Hourly')) else const Chip(label: Text('Fixed')),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.local_shipping_rounded, size: 18),
                const SizedBox(width: 6),
                const Expanded(child: Text('Travel up to 5 km included. Parts policy may apply.')),
              ],
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('When'),
              subtitle: Text(_when == null ? 'Choose date & time' : _when!.toString()),
              trailing: OutlinedButton.icon(onPressed: _pickTime, icon: const Icon(Icons.event_rounded), label: const Text('Pick')),
            ),
            const Divider(),
            Row(
              children: [
                const Expanded(child: Text('Subtotal', style: TextStyle(fontWeight: FontWeight.w600))),
                Text('LKR ${_price.toStringAsFixed(0)}'),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(child: Text('Service fee (${(_feePct * 100).toStringAsFixed(0)}%)', style: TextStyle(color: cs.onSurfaceVariant))),
                Text('LKR ${_fee.toStringAsFixed(0)}', style: TextStyle(color: cs.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Expanded(child: Text('Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
                Text('LKR ${_total.toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.check_circle_rounded),
                    label: const Text('Confirm booking'),
                    onPressed: _confirm,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
