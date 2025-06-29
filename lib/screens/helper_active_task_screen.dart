import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:helpify/models/task_model.dart';
import 'package:url_launcher/url_launcher.dart';

/// A screen for the Helper to view their assigned task and broadcast their location.
class HelperActiveTaskScreen extends StatefulWidget {
  final Task task;

  const HelperActiveTaskScreen({Key? key, required this.task}) : super(key: key);

  @override
  _HelperActiveTaskScreenState createState() => _HelperActiveTaskScreenState();
}

class _HelperActiveTaskScreenState extends State<HelperActiveTaskScreen> {
  // This will hold the subscription to the location stream
  StreamSubscription<Position>? _positionStreamSubscription;
  bool _isSharingLocation = false;
  String _statusMessage = "Start sharing your location when you are on your way.";

  @override
  void dispose() {
    // IMPORTANT: Always cancel the stream subscription when the screen is disposed
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  /// Toggles the location sharing on and off.
  void _toggleLocationSharing() {
    if (_isSharingLocation) {
      _stopLocationUpdates();
    } else {
      _startLocationUpdates();
    }
  }

  /// Starts listening to the device's location and updating Firestore.
  void _startLocationUpdates() async {
    // First, check for location permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _updateStatus("Location permission denied. Cannot share location.", isError: true);
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      _updateStatus("Location permissions are permanently denied. Please enable them in your device settings.", isError: true);
      return;
    }

    // Settings for how often to get updates
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Update every 10 meters
    );

    // Subscribe to the position stream
    _positionStreamSubscription = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
        print('Updating location: ${position.latitude}, ${position.longitude}');
        // Get a reference to the task document
        final taskRef = FirebaseFirestore.instance.collection('tasks').doc(widget.task.id);

        // Update the helper's location in Firestore
        taskRef.update({
          'helperLastLocation': GeoPoint(position.latitude, position.longitude),
        });
      },
      onError: (error) {
        print("Error getting location: $error");
        _updateStatus("Error getting location. Sharing has stopped.", isError: true);
        _stopLocationUpdates();
      },
    );

    _updateStatus("Live location is now ON.", isError: false);
    setState(() {
      _isSharingLocation = true;
    });
  }

  /// Stops the location updates and cancels the stream subscription.
  void _stopLocationUpdates() {
    _positionStreamSubscription?.cancel();
    _updateStatus("Location sharing is now OFF.");
    setState(() {
      _isSharingLocation = false;
    });
  }

  void _updateStatus(String message, {bool isError = false}) {
    if(mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ));
      setState(() {
        _statusMessage = message;
      });
    }
  }

  /// Launches Google Maps for navigation to the task destination.
  Future<void> _launchMapsNavigation() async {
    if (widget.task.location == null) return;

    final lat = widget.task.location!.latitude;
    final lng = widget.task.location!.longitude;
    final url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open maps application.'))
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Task'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTaskInfoCard(),
            const SizedBox(height: 24),
            _buildLocationCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskInfoCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.task.title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(widget.task.description, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey[700])),
            const Divider(height: 32),
            _buildInfoRow(Icons.person_outline, 'Task Poster', widget.task.posterName),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.account_balance_wallet_outlined, 'Your Earnings', 'LKR ${widget.task.finalAmount?.toStringAsFixed(2) ?? widget.task.budget.toStringAsFixed(2)}'),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Task Location", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildInfoRow(Icons.location_on_outlined, 'Address', widget.task.locationAddress ?? 'Not specified'),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _launchMapsNavigation,
              icon: const Icon(Icons.navigation_outlined),
              label: const Text("Get Directions"),
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
            ),
            const Divider(height: 40),
            Center(child: Text(_statusMessage, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]), textAlign: TextAlign.center,)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _toggleLocationSharing,
              icon: Icon(_isSharingLocation ? Icons.stop_circle_outlined : Icons.my_location),
              label: Text(_isSharingLocation ? 'Stop Sharing Location' : 'Start Sharing Location'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: _isSharingLocation ? Colors.red : Theme.of(context).primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.grey[600], size: 20),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        )
      ],
    );
  }
}
