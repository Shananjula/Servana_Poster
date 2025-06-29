import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// *** UPDATED: Importing the centralized Service model ***
import '../models/service_model.dart';

// Standalone testing code
void main() {
  runApp(const HelpifyApp());
}

class HelpifyApp extends StatelessWidget {
  const HelpifyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(body: Center(child: Text("Navigate from Browse screen to test"))),
    );
  }
}


// --- The Service Booking Screen Widget ---
class ServiceBookingScreen extends StatefulWidget {
  final Service service;

  const ServiceBookingScreen({Key? key, required this.service}) : super(key: key);

  @override
  State<ServiceBookingScreen> createState() => _ServiceBookingScreenState();
}

class _ServiceBookingScreenState extends State<ServiceBookingScreen> {
  DateTime? _selectedDate;
  String? _selectedTimeSlot;
  bool _isLoading = false;
  final List<String> _timeSlots = ['Morning (9am - 12pm)', 'Afternoon (1pm - 4pm)', 'Evening (5pm - 8pm)'];

  void _presentDatePicker() {
    showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    ).then((pickedDate) {
      if (pickedDate == null) {
        return;
      }
      setState(() {
        _selectedDate = pickedDate;
      });
    });
  }

  // *** UPDATED: Connects to Firestore to save the booking ***
  Future<void> _confirmBooking() async {
    if (_selectedDate == null || _selectedTimeSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date and time slot.'), backgroundColor: Colors.red),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to book a service.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Save to a new top-level 'bookings' collection
      await FirebaseFirestore.instance.collection('bookings').add({
        'serviceId': widget.service.id,
        'serviceTitle': widget.service.title,
        'serviceRate': widget.service.rate,
        'serviceRateType': widget.service.rateType,
        'bookerId': user.uid,
        'bookerName': user.displayName ?? 'Anonymous User',
        'bookingDate': Timestamp.fromDate(_selectedDate!),
        'bookingTimeSlot': _selectedTimeSlot,
        'status': 'pending', // Initial status
        'createdAt': FieldValue.serverTimestamp(),
      });

      Navigator.of(context).pop(); // Go back to the browse screen
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Service booked successfully!'), backgroundColor: Colors.green),
      );

    } catch (e) {
      print("Failed to confirm booking: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to book service. Please try again.'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Book a Service'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.service.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('LKR ${widget.service.rate.toStringAsFixed(0)} ${widget.service.rateType}', style: TextStyle(fontSize: 20, color: Theme.of(context).primaryColor, fontWeight: FontWeight.w600)),
            const Divider(height: 40),
            const Text('1. Select a Date', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedDate == null ? 'No Date Chosen' : 'Selected: ${DateFormat.yMMMd().format(_selectedDate!)}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                TextButton(onPressed: _presentDatePicker, child: const Text('Choose Date')),
              ],
            ),
            const SizedBox(height: 32),
            const Text('2. Select a Time Slot', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8.0,
              children: _timeSlots.map((slot) {
                return ChoiceChip(
                  label: Text(slot),
                  selected: _selectedTimeSlot == slot,
                  onSelected: (selected) {
                    setState(() {
                      _selectedTimeSlot = selected ? slot : null;
                    });
                  },
                  selectedColor: Colors.teal[100],
                  labelStyle: TextStyle(color: _selectedTimeSlot == slot ? Colors.teal[900] : Colors.black54),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(24.0),
        child: ElevatedButton(
          onPressed: _isLoading ? null : _confirmBooking,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isLoading
              ? const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white))
              : const Text('Confirm Booking', style: TextStyle(fontSize: 18)),
        ),
      ),
    );
  }
}
