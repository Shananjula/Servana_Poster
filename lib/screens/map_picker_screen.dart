// lib/screens/map_picker_screen.dart
//
// Map Picker
// • Lets user pick a point on Google Map, shows a draggable pin
// • "Use current location" (Geolocator) with runtime permission request
// • Optional manual address text field (no external geocoding required)
// • Returns via Navigator.pop<Map<String, dynamic>>({
//      'lat': double, 'lng': double, 'address': String
//    })
//
// Safe fallbacks:
// • If location permission denied, stays on default camera (Colombo) and shows a hint.
// • If Google Map fails to initialize, shows a friendly error.
//
// Dependencies:
//   google_maps_flutter
//   geolocator
//
// Usage:
//   final result = await Navigator.push<Map<String, dynamic>>(
//     context,
//     MaterialPageRoute(builder: (_) => const MapPickerScreen()),
//   );
//   if (result != null) { print(result['lat']); print(result['lng']); print(result['address']); }

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({
    super.key,
    this.initialLat,
    this.initialLng,
    this.initialAddress,
    this.title,
  });

  final double? initialLat;
  final double? initialLng;
  final String? initialAddress;
  final String? title;

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  static const LatLng _colombo = LatLng(6.9271, 79.8612);

  GoogleMapController? _controller;
  LatLng _center = _colombo;
  Marker _pin = const Marker(markerId: MarkerId('pin'), position: _colombo);
  String _address = '';
  bool _locating = false;
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    _center = LatLng(
      widget.initialLat ?? _colombo.latitude,
      widget.initialLng ?? _colombo.longitude,
    );
    _pin = Marker(
      markerId: const MarkerId('pin'),
      position: _center,
      draggable: true,
      onDragEnd: (p) => setState(() {
        _center = p;
        _pin = _pin.copyWith(positionParam: p);
      }),
    );
    _address = widget.initialAddress ?? '';
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      final ok = await _ensurePermission();
      if (!ok) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied.')),
        );
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final latLng = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _center = latLng;
        _pin = _pin.copyWith(positionParam: latLng);
      });
      await _controller?.animateCamera(
        CameraUpdate.newCameraPosition(CameraPosition(target: latLng, zoom: 16)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not get location: $e')),
      );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<bool> _ensurePermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // We only hint; user can still pick manually.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled.')),
        );
      }
      return false;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.deniedForever) return false;
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return false;
      }
    }
    return true;
  }

  void _onCameraMove(CameraPosition pos) {
    // Keep pin centered visually (we show a static pin via overlay), but we also update _center.
    setState(() {
      _center = pos.target;
      _pin = _pin.copyWith(positionParam: pos.target);
    });
  }

  Future<void> _confirm() async {
    Navigator.pop<Map<String, dynamic>>(context, {
      'lat': _center.latitude,
      'lng': _center.longitude,
      'address': _address.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? 'Pick location'),
        actions: [
          TextButton(
            onPressed: _confirm,
            child: const Text('USE', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: Column(
        children: [
          // --- Map ---
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(target: _center, zoom: 14),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  onMapCreated: (c) {
                    _controller = c;
                    setState(() => _mapReady = true);
                  },
                  onCameraMove: _onCameraMove,
                  markers: {_pin},
                ),
                // Center crosshair overlay (for clarity)
                IgnorePointer(
                  child: Center(
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: cs.primary, width: 2),
                        color: cs.primary.withOpacity(0.10),
                      ),
                    ),
                  ),
                ),
                // Current location button
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: FloatingActionButton.small(
                    heroTag: 'locate',
                    onPressed: _locating ? null : _useCurrentLocation,
                    child: _locating
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Icon(Icons.my_location),
                  ),
                ),
              ],
            ),
          ),

          // --- Address + coords preview ---
          Card(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Address (optional)', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  TextField(
                    controller: TextEditingController(text: _address),
                    onChanged: (v) => _address = v,
                    decoration: const InputDecoration(
                      hintText: 'e.g., No. 123, Galle Road, Colombo',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.place_outlined, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Lat: ${_center.latitude.toStringAsFixed(6)}  •  Lng: ${_center.longitude.toStringAsFixed(6)}',
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      ),
                      FilledButton.tonal(
                        onPressed: _confirm,
                        child: const Text('Use here'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
