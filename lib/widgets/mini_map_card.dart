import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:servana/screens/helper_public_profile_screen.dart';
import 'package:servana/screens/task_details_screen.dart';

/// MiniMapCard
///
/// Lightweight map preview card with markers:
///   • mode == 'poster' → show Helpers (/users where isHelper==true)
///   • mode == 'helper' → show OPEN Tasks (/tasks where status=='open')
///
/// - 200dp tall card, rounded radius 16
/// - Android: liteModeEnabled = true for performance
/// - Overlay chips: distance (2/5/10 km) + category quick filter
/// - Tap anywhere to open full map via [onOpenFull]
/// - Schema tolerant (missing fields won’t crash)
class MiniMapCard extends StatefulWidget {
  const MiniMapCard({
    super.key,
    required this.mode, // 'poster' | 'helper'
    this.initialRadiusKm = 5,
    this.category,
    this.onOpenFull,
  });

  final String mode;
  final double initialRadiusKm;
  final String? category;
  final VoidCallback? onOpenFull;

  @override
  State<MiniMapCard> createState() => _MiniMapCardState();
}

class _MiniMapCardState extends State<MiniMapCard> {
  static const LatLng _fallbackCenter = LatLng(6.9271, 79.8612); // Colombo (safe default)

  double _radiusKm = 5;
  String? _category;
  GoogleMapController? _ctrl;
  LatLng _center = _fallbackCenter;

  // Streams
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _helpers$;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _tasks$;

  @override
  void initState() {
    super.initState();
    _radiusKm = widget.initialRadiusKm.clamp(2, 20);
    _category = widget.category;

    _helpers$ = FirebaseFirestore.instance
        .collection('users')
        .where('isHelper', isEqualTo: true)
        .limit(300)
        .snapshots();

    final col = FirebaseFirestore.instance.collection('tasks');
    try {
      _tasks$ = col
          .where('status', isEqualTo: 'open')
          .orderBy('createdAt', descending: true)
          .limit(300)
          .snapshots();
    } catch (_) {
      _tasks$ = col.where('status', isEqualTo: 'open').limit(300).snapshots();
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;

    // Use a static camera for card; user can open full screen to interact more.
    final camera = CameraPosition(target: _center, zoom: _zoomForRadius(_radiusKm));

    final border = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
    return Material(
      color: Theme.of(context).colorScheme.surface,
      shape: border,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onOpenFull,
        child: SizedBox(
          height: 200,
          child: Stack(
            children: [
              Positioned.fill(
                child: widget.mode == 'helper'
                    ? StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _tasks$,
                  builder: (context, snap) {
                    final markers = _buildTaskMarkers(snap.data);
                    return _map(camera, markers, isAndroid);
                  },
                )
                    : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _helpers$,
                  builder: (context, snap) {
                    final markers = _buildHelperMarkers(snap.data);
                    return _map(camera, markers, isAndroid);
                  },
                ),
              ),

              // Controls (bottom-left)
              Positioned(
                left: 12,
                bottom: 12,
                child: Row(
                  children: [
                    _chip(
                      context,
                      label: '2 km',
                      selected: (_radiusKm - 2).abs() < 0.5,
                      onTap: () => _setRadius(2),
                    ),
                    const SizedBox(width: 8),
                    _chip(
                      context,
                      label: '5 km',
                      selected: (_radiusKm - 5).abs() < 0.5,
                      onTap: () => _setRadius(5),
                    ),
                    const SizedBox(width: 8),
                    _chip(
                      context,
                      label: '10 km',
                      selected: (_radiusKm - 10).abs() < 0.5,
                      onTap: () => _setRadius(10),
                    ),
                    const SizedBox(width: 8),
                    _chip(
                      context,
                      label: _category == null ? 'All' : _category!,
                      selected: _category != null,
                      onTap: () => _openCategorySheet(),
                      icon: Icons.filter_list_rounded,
                    ),
                  ],
                ),
              ),

              // Empty state overlay hint
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.2)),
                  ),
                  child: Text(
                    widget.mode == 'helper' ? 'Open tasks near you' : 'Helpers near you',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _map(CameraPosition camera, Set<Marker> markers, bool isAndroid) {
    return GoogleMap(
      initialCameraPosition: camera,
      mapType: MapType.normal,
      tiltGesturesEnabled: false,
      zoomControlsEnabled: false,
      scrollGesturesEnabled: false,
      rotateGesturesEnabled: false,
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      liteModeEnabled: isAndroid, // PERF on Android
      markers: markers,
      onMapCreated: (c) => _ctrl = c,
    );
  }

  // ---- markers --------------------------------------------------------------

  Set<Marker> _buildHelperMarkers(QuerySnapshot<Map<String, dynamic>>? snap) {
    final markers = <Marker>{};
    if (snap == null) return markers;

    var anyPlotted = false;
    for (final d in snap.docs) {
      final u = d.data();
      if (u['isHelper'] != true) continue;

      // Find a location to use
      GeoPoint? gp;
      final presence = (u['presence'] is Map<String, dynamic>) ? u['presence'] as Map<String, dynamic> : null;
      if (presence?['currentLocation'] is GeoPoint) {
        gp = presence!['currentLocation'] as GeoPoint;
      } else if (u['workLocation'] is GeoPoint) {
        gp = u['workLocation'] as GeoPoint;
      } else if (u['homeLocation'] is GeoPoint) {
        gp = u['homeLocation'] as GeoPoint;
      }
      if (gp == null) continue;

      // Category filter (best effort)
      if (_category != null && _category!.trim().isNotEmpty) {
        final lc = _category!.trim().toLowerCase();
        final lists = [u['serviceCategories'], u['categories'], u['skills'], u['services']];
        final has = lists.any((v) => v is List && v.whereType<String>().any((e) => e.toLowerCase() == lc));
        if (!has) continue;
      }

      final pos = LatLng(gp.latitude, gp.longitude);
      final dist = _distanceKm(_center, pos);
      if (dist > _radiusKm + 0.01) continue;

      final name = (u['displayName'] as String?)?.trim().isNotEmpty == true
          ? (u['displayName'] as String).trim()
          : 'Helper';
      final live = presence?['isLive'] == true;

      anyPlotted = true;
      markers.add(
        Marker(
          markerId: MarkerId('h_${d.id}'),
          position: pos,
          icon: BitmapDescriptor.defaultMarkerWithHue(live ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueAzure),
          infoWindow: InfoWindow(
            title: name,
            snippet: live ? 'Live · ${dist.toStringAsFixed(1)} km' : '${dist.toStringAsFixed(1)} km',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => HelperPublicProfileScreen(helperId: d.id)),
              );
            },
          ),
        ),
      );
    }

    // Center map if we found any
    if (anyPlotted && markers.isNotEmpty) {
      _center = markers.first.position;
    }

    return markers;
  }

  Set<Marker> _buildTaskMarkers(QuerySnapshot<Map<String, dynamic>>? snap) {
    final markers = <Marker>{};
    if (snap == null) return markers;

    var anyPlotted = false;
    for (final d in snap.docs) {
      final t = d.data();
      if ((t['status'] as String?)?.toLowerCase() != 'open') continue;

      final GeoPoint? gp = t['location'] is GeoPoint ? t['location'] as GeoPoint : null;
      if (gp == null) continue;

      // Category filter
      if (_category != null && _category!.trim().isNotEmpty) {
        final lc = _category!.trim().toLowerCase();
        final tc = (t['category'] as String?)?.toLowerCase();
        if (tc != lc) continue;
      }

      final pos = LatLng(gp.latitude, gp.longitude);
      final dist = _distanceKm(_center, pos);
      if (dist > _radiusKm + 0.01) continue;

      final title = (t['title'] as String?)?.trim().isNotEmpty == true ? (t['title'] as String).trim() : 'Task';
      final num? amount = (t['finalAmount'] as num?) ?? (t['budget'] as num?);
      final price = amount != null ? _fmtLkr(amount) : null;
      final snippet = [
        if (price != null) price,
        '${dist.toStringAsFixed(1)} km',
      ].join(' · ');

      anyPlotted = true;
      markers.add(
        Marker(
          markerId: MarkerId('t_${d.id}'),
          position: pos,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
          infoWindow: InfoWindow(
            title: title,
            snippet: snippet,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TaskDetailsScreen(taskId: d.id))),
          ),
        ),
      );
    }

    // Center map if we found any
    if (anyPlotted && markers.isNotEmpty) {
      _center = markers.first.position;
    }

    return markers;
  }

  

  // Small helper to render a compact choice chip used in controls
  Widget _chip(
    BuildContext context, {
    required String label,
    bool selected = false,
    VoidCallback? onTap,
    IconData? icon,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: ChoiceChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16),
              const SizedBox(width: 6),
            ],
            Text(label),
          ],
        ),
        selected: selected,
        onSelected: (_) => onTap?.call(),
        selectedColor: cs.primaryContainer,
        backgroundColor: cs.surfaceVariant.withOpacity(0.6),
        labelStyle: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
          height: 1.0,
        ),
        side: BorderSide(color: selected ? cs.primary : cs.outlineVariant),
        shape: const StadiumBorder(),
        showCheckmark: false,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
// ---- filters --------------------------------------------------------------

  void _setRadius(double km) {
    setState(() => _radiusKm = km);
    _ctrl?.moveCamera(CameraUpdate.newCameraPosition(CameraPosition(target: _center, zoom: _zoomForRadius(_radiusKm))));
  }

  Future<void> _openCategorySheet() async {
    const quick = ['Cleaning', 'Delivery', 'Repairs', 'Tutoring', 'Design', 'Writing'];
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        String? temp = _category;
        return StatefulBuilder(
          builder: (context, setSheet) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Category', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('All'),
                      selected: (temp ?? '').isEmpty,
                      onSelected: (_) => setSheet(() => temp = null),
                    ),
                    for (final c in quick)
                      ChoiceChip(
                        label: Text(c),
                        selected: temp == c,
                        onSelected: (_) => setSheet(() => temp = c),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      setState(() => _category = temp);
                      Navigator.pop(context);
                    },
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---- utils ---------------------------------------------------------------

  double _zoomForRadius(double km) {
    if (km <= 2) return 14;
    if (km <= 5) return 13;
    if (km <= 10) return 12;
    if (km <= 15) return 11.5;
    return 11;
  }

  double _distanceKm(LatLng a, LatLng b) {
    const R = 6371.0;
    final dLat = _deg2rad(b.latitude - a.latitude);
    final dLon = _deg2rad(b.longitude - a.longitude);
    final lat1 = _deg2rad(a.latitude);
    final lat2 = _deg2rad(b.latitude);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
    return R * c;
  }

  double _deg2rad(double d) => d * (math.pi / 180.0);

  /// Local LKR formatter (no external deps). Avoids `prefixLKR`.
  String _fmtLkr(num n) {
    final negative = n < 0;
    final abs = n.abs();
    final isWhole = abs % 1 == 0;
    final raw = isWhole ? abs.toStringAsFixed(0) : abs.toStringAsFixed(2);
    final parts = raw.split('.');
    String whole = parts[0];
    final reg = RegExp(r'\B(?=(\d{3})+(?!\d))');
    whole = whole.replaceAllMapped(reg, (m) => ',');
    final sign = negative ? '−' : '';
    return parts.length == 1 ? 'LKR $sign$whole' : 'LKR $sign$whole.${parts[1]}';
  }
}
