import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:servana/models/user_model.dart';
import 'package:servana/screens/profile_screen.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/services.dart';

class MapViewScreen extends StatefulWidget {
  const MapViewScreen({super.key});

  @override
  State<MapViewScreen> createState() => _MapViewScreenState();
}

class _MapViewScreenState extends State<MapViewScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  Set<Marker> _markers = {};

  // Default camera position (e.g., Colombo, Sri Lanka)
  static const CameraPosition _kInitialPosition = CameraPosition(
    target: LatLng(6.9271, 79.8612),
    zoom: 12,
  );

  @override
  void initState() {
    super.initState();
    _determinePositionAndFetchHelpers();
  }

  // Helper method to create custom markers from an asset image
  Future<BitmapDescriptor> _getMarkerIcon(String path, int size) async {
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(), targetWidth: size);
    ui.FrameInfo fi = await codec.getNextFrame();
    return BitmapDescriptor.fromBytes((await fi.image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List());
  }

  Future<void> _determinePositionAndFetchHelpers() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location services are disabled.')));
      _fetchHelpers(); // Fetch helpers without a central point
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permissions are denied.')));
        _fetchHelpers(); // Fetch helpers without a central point
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permissions are permanently denied, we cannot request permissions.')));
      _fetchHelpers(); // Fetch helpers without a central point
      return;
    }

    final position = await Geolocator.getCurrentPosition();
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(target: LatLng(position.latitude, position.longitude), zoom: 14)
    ));
    _fetchHelpers(center: LatLng(position.latitude, position.longitude));
  }

  Future<void> _fetchHelpers({LatLng? center}) async {
    // For now, we fetch all helpers. For a large-scale app, you'd use a geo-query.
    final querySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('isHelper', isEqualTo: true)
        .where('verificationStatus', isEqualTo: 'verified')
        .where('workLocation', isNotEqualTo: null) // Only get helpers with a location set
        .get();

    final customIcon = await _getMarkerIcon('assets/logo.png', 120); // Using your app logo as a marker

    var markers = <Marker>{};
    for (var doc in querySnapshot.docs) {
      final helper = HelpifyUser.fromFirestore(doc);
      if (helper.workLocation != null) {
        markers.add(
          Marker(
            markerId: MarkerId(helper.id),
            position: LatLng(helper.workLocation!.latitude, helper.workLocation!.longitude),
            icon: customIcon,
            infoWindow: InfoWindow(
              title: helper.displayName ?? 'Servana Helper',
              snippet: 'Tap to view profile',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ProfileScreen(userId: helper.id)),
                );
              },
            ),
          ),
        );
      }
    }
    setState(() {
      _markers = markers;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Helpers Near You'),
      ),
      body: GoogleMap(
        mapType: MapType.normal,
        initialCameraPosition: _kInitialPosition,
        onMapCreated: (GoogleMapController controller) {
          _controller.complete(controller);
        },
        markers: _markers,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
      ),
    );
  }
}
