import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class UrgentTaskDialog extends StatefulWidget {
  const UrgentTaskDialog({super.key});
  @override
  State<UrgentTaskDialog> createState() => _UrgentTaskDialogState();
}

class _UrgentTaskDialogState extends State<UrgentTaskDialog> {
  final _titleController = TextEditingController();
  GeoPoint? _currentLocation;
  String _currentAddress = "Fetching location...";
  bool _isLocating = true;
  bool _isPosting = false;

  @override
  void initState() {
    super.initState();
    _fetchCurrentLocation();
  }

  Future<void> _fetchCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('Location services are disabled.');
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw Exception('Location permissions are denied');
      }
      if (permission == LocationPermission.deniedForever) throw Exception('Location permissions are permanently denied.');

      final position = await Geolocator.getCurrentPosition();
      final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (mounted) {
        setState(() {
          _currentLocation = GeoPoint(position.latitude, position.longitude);
          _currentAddress = placemarks.isNotEmpty ? (placemarks.first.street ?? placemarks.first.name ?? 'Unknown Location') : 'Unknown Location';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _currentAddress = "Could not get location.");
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _postUrgentTask() async {
    if (_titleController.text.trim().isEmpty || _currentLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all fields.")));
      return;
    }
    setState(() => _isPosting = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isPosting = false);
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('tasks').add({
        'title': _titleController.text.trim(),
        'description': 'URGENT TASK',
        'category': 'Urgent',
        'isUrgent': true, // This will trigger the cloud function
        'budget': 0.0,
        'location': _currentLocation,
        'locationAddress': _currentAddress,
        'status': 'open',
        'posterId': user.uid,
        'posterName': user.displayName ?? 'Helpify User',
        'posterAvatarUrl': user.photoURL,
        'timestamp': FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Urgent task posted! Nearby helpers have been notified."), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Post an Urgent Task"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _titleController, decoration: const InputDecoration(labelText: "What do you need, fast?")),
          const SizedBox(height: 16),
          Row(children: [
            const Icon(Icons.location_on),
            const SizedBox(width: 8),
            Expanded(child: Text(_currentAddress)),
            if (_isLocating) const Padding(padding: EdgeInsets.only(left: 8.0), child: SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))),
          ]),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancel")),
        ElevatedButton(onPressed: _isPosting || _isLocating ? null : _postUrgentTask, child: const Text("Post Now")),
      ],
    );
  }
}
