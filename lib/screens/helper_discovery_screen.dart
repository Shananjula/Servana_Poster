import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:servana/models/user_model.dart';
import 'package:servana/screens/helper_public_profile_screen.dart';
import 'package:servana/widgets/empty_state_widget.dart';
import 'package:servana/widgets/helper_card.dart'; // This is the supporting widget

// Enum to switch between List and Map views
enum ViewMode { list, map }

class HelperDiscoveryScreen extends StatefulWidget {
  const HelperDiscoveryScreen({super.key});

  @override
  State<HelperDiscoveryScreen> createState() => _HelperDiscoveryScreenState();
}

class _HelperDiscoveryScreenState extends State<HelperDiscoveryScreen> {
  ViewMode _viewMode = ViewMode.list;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Find a Helper"),
        actions: [
          // View Mode Toggle Button
          SegmentedButton<ViewMode>(
            segments: const [
              ButtonSegment(value: ViewMode.list, icon: Icon(Icons.list_rounded), label: Text("List")),
              ButtonSegment(value: ViewMode.map, icon: Icon(Icons.map_outlined), label: Text("Map")),
            ],
            selected: {_viewMode},
            onSelectionChanged: (newSelection) {
              setState(() {
                _viewMode = newSelection.first;
              });
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        // Query to get all verified helpers
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('isHelper', isEqualTo: true)
            .where('verificationStatus', isEqualTo: 'verified')
            .limit(50) // Limit to avoid performance issues
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.people_outline,
              title: "No Helpers Available",
              message: "There are currently no verified helpers in your area. Check back later!",
            );
          }

          final helpers = snapshot.data!.docs.map((doc) => HelpifyUser.fromFirestore(doc)).toList();

          // Animate the switch between List and Map views
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: _viewMode == ViewMode.list
                ? _buildListView(helpers)
                : _buildMapView(helpers),
          );
        },
      ),
    );
  }

  // Builds the list view of helpers
  Widget _buildListView(List<HelpifyUser> helpers) {
    return ListView.builder(
      key: const ValueKey('list'), // Key for AnimatedSwitcher
      padding: const EdgeInsets.all(16),
      itemCount: helpers.length,
      itemBuilder: (context, index) {
        return HelperCard(helper: helpers[index]);
      },
    );
  }

  // Builds the map view showing helper locations
  Widget _buildMapView(List<HelpifyUser> helpers) {
    final Set<Marker> markers = helpers
        .where((helper) => helper.workLocation != null) // Only include helpers with a location
        .map((helper) {
      return Marker(
        markerId: MarkerId(helper.id),
        position: LatLng(helper.workLocation!.latitude, helper.workLocation!.longitude),
        infoWindow: InfoWindow(
          title: helper.displayName,
          snippet: "Tap to view profile",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => HelperPublicProfileScreen(helperId: helper.id)),
            );
          },
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      );
    }).toSet();

    return GoogleMap(
      key: const ValueKey('map'), // Key for AnimatedSwitcher
      initialCameraPosition: const CameraPosition(
        target: LatLng(6.9271, 79.8612), // Default to Colombo, Sri Lanka
        zoom: 11,
      ),
      markers: markers,
    );
  }
}
