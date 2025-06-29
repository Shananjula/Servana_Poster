import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapPickerScreen extends StatefulWidget {
  final LatLng initialLocation;

  const MapPickerScreen({
    Key? key,
    this.initialLocation = const LatLng(6.9271, 79.8612), // Default to Colombo
  }) : super(key: key);

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  LatLng? _pickedLocation;

  void _selectLocation(LatLng position) {
    setState(() {
      _pickedLocation = position;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Location'),
        actions: [
          if (_pickedLocation != null)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: () {
                // This returns the selected coordinates back to the PostTaskScreen
                Navigator.of(context).pop(_pickedLocation);
              },
            )
        ],
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: widget.initialLocation,
          zoom: 16,
        ),
        onTap: _selectLocation,
        markers: (_pickedLocation == null)
            ? {} // If no location is picked, show no markers
            : {
          // If a location is picked, show a marker there
          Marker(
            markerId: const MarkerId('m1'),
            position: _pickedLocation!,
          ),
        },
      ),
    );
  }
}
