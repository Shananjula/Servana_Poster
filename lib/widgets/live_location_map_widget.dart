import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:servana/models/task_model.dart';

class LiveLocationMap extends StatefulWidget {
  final Task task;
  const LiveLocationMap({Key? key, required this.task}) : super(key: key);

  @override
  State<LiveLocationMap> createState() => _LiveLocationMapState();
}

class _LiveLocationMapState extends State<LiveLocationMap> {
  final Completer<GoogleMapController> _mapController = Completer();
  Marker? _helperMarker;
  Marker? _destinationMarker;

  @override
  void initState() {
    super.initState();
    _setInitialMarkers();
  }

  void _setInitialMarkers() {
    // Set the destination marker (task location)
    if (widget.task.location != null) {
      _destinationMarker = Marker(
        markerId: const MarkerId('destination'),
        position: LatLng(widget.task.location!.latitude, widget.task.location!.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(title: 'Task Location'),
      );
    }

    // Set the initial helper marker if location exists
    if (widget.task.helperLastLocation != null) {
      _updateHelperMarker(LatLng(
        widget.task.helperLastLocation!.latitude,
        widget.task.helperLastLocation!.longitude,
      ));
    }
  }

  void _updateHelperMarker(LatLng position) {
    setState(() {
      _helperMarker = Marker(
        markerId: const MarkerId('helper'),
        position: position,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: InfoWindow(title: widget.task.assignedHelperName ?? 'Helper'),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // The StreamBuilder listens to the same task document stream as the parent screen,
    // but we only care about the helperLastLocation field.
    return StreamBuilder<Task>(
      // Re-map the snapshot from the parent to a Task object
      stream: Stream.value(widget.task),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final task = snapshot.data!;
          if (task.helperLastLocation != null) {
            final newPosition = LatLng(
              task.helperLastLocation!.latitude,
              task.helperLastLocation!.longitude,
            );
            // Animate camera to the new position
            _mapController.future.then((controller) {
              controller.animateCamera(CameraUpdate.newLatLng(newPosition));
            });
            _updateHelperMarker(newPosition);
          }
        }

        final allMarkers = <Marker>{
          if (_destinationMarker != null) _destinationMarker!,
          if (_helperMarker != null) _helperMarker!,
        };

        return Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                child: Row(
                  children: [
                    Icon(Icons.route_outlined, color: Theme.of(context).primaryColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Helper is on the way!", style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Theme.of(context).primaryColor)),
                          const Text("You can track their progress below."),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 300,
                child: GoogleMap(
                  mapType: MapType.normal,
                  initialCameraPosition: CameraPosition(
                    target: LatLng(
                      widget.task.location?.latitude ?? 6.9271,
                      widget.task.location?.longitude ?? 79.8612,
                    ),
                    zoom: 14,
                  ),
                  markers: allMarkers,
                  onMapCreated: (GoogleMapController controller) {
                    if (!_mapController.isCompleted) {
                      _mapController.complete(controller);
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
