import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:servana/models/task_model.dart';
import 'package:servana/services/firestore_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// A simplified screen for the Helper, focusing on location sharing and navigation.
/// The main task flow logic is handled by ActiveTaskScreen.
class HelperActiveTaskScreen extends StatefulWidget {
  final Task task;

  const HelperActiveTaskScreen({Key? key, required this.task}) : super(key: key);

  @override
  _HelperActiveTaskScreenState createState() => _HelperActiveTaskScreenState();
}

class _HelperActiveTaskScreenState extends State<HelperActiveTaskScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  StreamSubscription<Position>? _positionStreamSubscription;
  bool _isSharingLocation = false;

  @override
  void initState() {
    super.initState();
    // Automatically start sharing location if the journey is already in progress
    if (widget.task.status == 'en_route') {
      _startLocationUpdates();
    }
  }

  @override
  void dispose() {
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
    // Check if location is already being shared
    if (_isSharingLocation) return;

    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showError("Location services are disabled.");
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showError("Location permissions are denied.");
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showError("Location permissions are permanently denied.");
      return;
    }

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Update every 10 meters
    );

    _positionStreamSubscription = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
        FirebaseFirestore.instance.collection('tasks').doc(widget.task.id).update({
          'helperLastLocation': GeoPoint(position.latitude, position.longitude),
        });
      },
      onError: (error) {
        _showError("Error getting location. Sharing stopped.");
        _stopLocationUpdates();
      },
    );

    if(mounted) setState(() => _isSharingLocation = true);
  }

  void _stopLocationUpdates() {
    _positionStreamSubscription?.cancel();
    if(mounted) setState(() => _isSharingLocation = false);
  }

  void _showError(String message) {
    if(mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ));
    }
  }

  Future<void> _launchMapsNavigation() async {
    if (widget.task.location == null) return;
    final lat = widget.task.location!.latitude;
    final lng = widget.task.location!.longitude;
    final url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      _showError('Could not open maps application.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Active Task'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTaskInfoCard(),
            const SizedBox(height: 24),
            _buildLocationAndActionCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.task.title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.person_outline, 'Task Poster', widget.task.posterName),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.account_balance_wallet_outlined, 'Your Earnings', 'LKR ${widget.task.finalAmount?.toStringAsFixed(2) ?? widget.task.budget.toStringAsFixed(2)}'),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationAndActionCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text("Task Location", style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            _buildInfoRow(Icons.location_on_outlined, 'Address', widget.task.locationAddress ?? 'Not specified'),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _launchMapsNavigation,
              icon: const Icon(Icons.navigation_outlined),
              label: const Text("Get Directions"),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            ),
            const Divider(height: 40),
            // --- This section now calls the FirestoreService ---
            if (widget.task.status == 'assigned')
              ElevatedButton.icon(
                onPressed: () {
                  _firestoreService.helperStartsJourney(widget.task.id);
                  _startLocationUpdates(); // Start sharing location when journey begins
                },
                icon: const Icon(Icons.route_outlined),
                label: const Text('Start Journey'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              ),
            if (widget.task.status == 'en_route')
              ElevatedButton.icon(
                onPressed: () {
                  _firestoreService.helperArrives(widget.task.id);
                  _stopLocationUpdates(); // Stop sharing location on arrival
                },
                icon: const Icon(Icons.pin_drop_outlined),
                label: const Text('I Have Arrived'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              ),
            const SizedBox(height: 16),
            // --- Location Sharing Toggle ---
            Text(
              _isSharingLocation ? "Live location is ON" : "Live location is OFF",
              textAlign: TextAlign.center,
              style: TextStyle(color: _isSharingLocation ? Colors.green : Colors.grey, fontWeight: FontWeight.bold),
            ),
            SwitchListTile(
              title: const Text('Share Live Location'),
              value: _isSharingLocation,
              onChanged: (bool value) {
                _toggleLocationSharing();
              },
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
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.grey[600])),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
        )
      ],
    );
  }
}
