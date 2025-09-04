// lib/screens/browse_screen.dart
//
// Browse helpers (poster)
// - AppBar: "Browse helpers" + subtitle (category • mode • Open now • radius)
// - List/Map toggle ONLY for Physical
// - Reads route args: {'serviceMode': 'Physical'|'Online', 'openNow': bool}
// - Search, Category chips, Quick filters, Sort menu
// - "Clear all" button resets every filter
// - Radius chips (2/5/10/20 km, All) for Physical; tolerant filtering
// - Keeps state alive across tab switches (AutomaticKeepAliveClientMixin)

import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:servana/l10n/i18n.dart';
import 'package:servana/screens/map_view_screen.dart';
import 'package:servana/screens/notifications_screen.dart';
import 'package:servana/widgets/helper_card.dart';

class BrowseScreen extends StatefulWidget {
  const BrowseScreen({super.key, this.initialCategory});
  final String? initialCategory;

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen>
    with AutomaticKeepAliveClientMixin {
  // View state
  bool _mapMode = false; // respected only for Physical
  bool _openNow = false;
  String _serviceMode = 'Physical'; // 'Online' | 'Physical'
  String _sort = 'Best match';
  String _query = '';
  String? _category;

  // Quick filters
  bool _verifiedOnly = false;
  bool _invoiceOnly = false;
  bool _topRated = false; // >= 4.7

  // Radius (km) for Physical; null = All
  int? _radiusKm;

  // Poster location (loaded once, tolerant schema)
  double? _myLat, _myLng;

  bool _appliedRouteArgs = false;
  final _searchCtrl = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory;
    _loadMyLocation();
  }

  Future<void> _loadMyLocation() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final d = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final m = d.data() ?? {};
      double? lat, lng;

      // Try common nests
      lat = _asDouble(_drill(m, ['location', 'lat'])) ??
          _asDouble(_drill(m, ['geo', 'lat'])) ??
          _asDouble(_drill(m, ['lastKnownLocation', 'lat']));
      lng = _asDouble(_drill(m, ['location', 'lng'])) ??
          _asDouble(_drill(m, ['geo', 'lng'])) ??
          _asDouble(_drill(m, ['lastKnownLocation', 'lng']));

      if (lat != null && lng != null && mounted) {
        setState(() {
          _myLat = lat;
          _myLng = lng;
        });
      }
    } catch (_) {}
  }

  dynamic _drill(Map<String, dynamic> m, List<String> keys) {
    dynamic cur = m;
    for (final k in keys) {
      if (cur is Map && cur.containsKey(k)) {
        cur = cur[k];
      } else {
        return null;
      }
    }
    return cur;
  }

  double? _asDouble(dynamic v) {
    if (v is num) return v.toDouble();
    try {
      return double.parse(v.toString());
    } catch (_) {
      return null;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_appliedRouteArgs) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map) {
        final svc = args['serviceMode'];
        final on = args['openNow'];
        if (svc is String && (svc == 'Online' || svc == 'Physical')) {
          _serviceMode = svc;
        }
        if (on is bool) _openNow = on;
      }
      _appliedRouteArgs = true;
      setState(() {});
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _setServiceMode(String v) {
    // Online forces List
    if (v == 'Online' && _mapMode) _mapMode = false;
    setState(() => _serviceMode = v);
  }

  void _clearAll() {
    setState(() {
      _searchCtrl.clear();
      _query = '';
      _category = null;
      _openNow = false;
      _serviceMode = 'Physical';
      _mapMode = false;
      _verifiedOnly = false;
      _invoiceOnly = false;
      _topRated = false;
      _radiusKm = null;
      _sort = 'Best match';
    });
  }

  String _subtitle() {
    final parts = <String>[];
    parts.add(_category ?? 'All categories');
    parts.add(_serviceMode);
    if (_openNow) parts.add('Open now');
    if (_serviceMode == 'Physical' && _radiusKm != null) {
      parts.add('≤ $_radiusKm km');
    }
    return parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;
    final showMapToggle = _serviceMode == 'Physical';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t(context, 'Browse helpers')),
            const SizedBox(height: 2),
            Text(_subtitle(),
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          ],
        ),
        centerTitle: false,
        actions: [
          if (showMapToggle)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                      value: false,
                      label: Text('List'),
                      icon: Icon(Icons.view_list_rounded)),
                  ButtonSegment(
                      value: true,
                      label: Text('Map'),
                      icon: Icon(Icons.map_rounded)),
                ],
                selected: {_mapMode},
                onSelectionChanged: (s) => setState(() => _mapMode = s.first),
              ),
            ),
          TextButton(
            onPressed: _clearAll,
            child: const Text('Clear'),
          ),
          IconButton(
            tooltip: 'Notifications',
            icon: const Icon(Icons.notifications_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v.trim()),
              decoration: InputDecoration(
                hintText: t(context, 'Search helpers'),
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: cs.surface,
                border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),

          // Service mode + Open now
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(value: 'Physical', label: Text(t(context, 'Physical'))),
                    ButtonSegment(value: 'Online', label: Text(t(context, 'Online'))),
                  ],
                  selected: {_serviceMode},
                  onSelectionChanged: (s) => _setServiceMode(s.first),
                ),
                const Spacer(),
                FilterChip(
                  label: Text(t(context, 'Open now')),
                  selected: _openNow,
                  onSelected: (b) => setState(() => _openNow = b),
                  side: BorderSide(color: cs.outline.withOpacity(0.12)),
                ),
              ],
            ),
          ),

          // Category chips (pre-select if passed)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _CategoryChips(
              selected: _category,
              onPick: (label) => setState(() => _category = label),
              onClear: () => setState(() => _category = null),
            ),
          ),

          // Quick filters + Sort + Clear (Clear also in AppBar; kept here compact)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilterChip(
                        label: Text(t(context, 'Verified only')),
                        selected: _verifiedOnly,
                        onSelected: (b) =>
                            setState(() => _verifiedOnly = b),
                        side: BorderSide(
                            color: cs.outline.withOpacity(0.12)),
                      ),
                      FilterChip(
                        label: Text(t(context, 'Top rated (4.7+)')),
                        selected: _topRated,
                        onSelected: (b) => setState(() => _topRated = b),
                        side: BorderSide(
                            color: cs.outline.withOpacity(0.12)),
                      ),
                      FilterChip(
                        label: Text(t(context, 'Invoice available')),
                        selected: _invoiceOnly,
                        onSelected: (b) => setState(() => _invoiceOnly = b),
                        side: BorderSide(
                            color: cs.outline.withOpacity(0.12)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  tooltip: 'Sort',
                  onSelected: (s) => setState(() => _sort = s),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                        value: 'Best match', child: Text('Best match')),
                    PopupMenuItem(value: 'Nearest', child: Text('Nearest')),
                    PopupMenuItem(
                        value: 'Price: low to high',
                        child: Text('Price: low to high')),
                    PopupMenuItem(
                        value: 'Rating: high to low',
                        child: Text('Rating: high to low')),
                    PopupMenuItem(
                        value: 'Most booked', child: Text('Most booked')),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(10),
                      border:
                      Border.all(color: cs.outline.withOpacity(0.12)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.sort_rounded, size: 18),
                        const SizedBox(width: 6),
                        Text(_sort),
                        const SizedBox(width: 2),
                        const Icon(Icons.expand_more_rounded, size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Radius chips (Physical only)
          if (_serviceMode == 'Physical')
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: _RadiusChips(
                selectedKm: _radiusKm,
                onPick: (km) => setState(() => _radiusKm = km),
              ),
            ),

          const SizedBox(height: 8),
          Expanded(
            child: (_serviceMode == 'Physical' && _mapMode)
                ? BrowseMapView(
              category: _category,
              query: _query,
              serviceMode: _serviceMode,
              openNow: _openNow,
            )
                : _HelperList(
              category: _category,
              query: _query,
              serviceMode: _serviceMode,
              openNow: _openNow,
              sort: _sort,
              verifiedOnly: _verifiedOnly,
              invoiceOnly: _invoiceOnly,
              topRated: _topRated,
              myLat: _myLat,
              myLng: _myLng,
              radiusKm: _radiusKm,
            ),
          ),
        ],
      ),
    );
  }
}

// ===== Category chips (inline) =====

class _CategoryChips extends StatelessWidget {
  const _CategoryChips(
      {required this.selected, required this.onPick, required this.onClear});
  final String? selected;
  final void Function(String) onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const cats = <(String, IconData)>[
      ('Plumbing', Icons.plumbing_rounded),
      ('Cleaning', Icons.cleaning_services_rounded),
      ('Tutoring', Icons.menu_book_rounded),
      ('Electrical', Icons.electric_bolt_rounded),
      ('Painting', Icons.format_paint_rounded),
      ('Delivery', Icons.delivery_dining_rounded),
      ('Repairs', Icons.build_rounded),
      ('AC Service', Icons.ac_unit_rounded),
      ('Gardening', Icons.yard_rounded),
      ('IT Support', Icons.phonelink_setup_rounded),
      ('Moving', Icons.local_shipping_rounded),
      ('Carpentry', Icons.handyman_rounded),
    ];

    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cats.length + (selected != null ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          if (i == 0 && selected != null) {
            return InputChip(
              label: Text(selected!),
              onDeleted: onClear,
              side: BorderSide(color: cs.outline.withOpacity(0.12)),
            );
          }
          final idx = selected != null ? i - 1 : i;
          final (label, icon) = cats[idx];
          final sel = selected != null &&
              selected!.toLowerCase() == label.toLowerCase();
          return ChoiceChip(
            label: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            avatar: Icon(icon, size: 18),
            selected: sel,
            onSelected: (_) => onPick(label),
            side: BorderSide(color: cs.outline.withOpacity(0.12)),
            backgroundColor: cs.surface,
          );
        },
      ),
    );
  }
}

// ===== Radius chips =====

class _RadiusChips extends StatelessWidget {
  const _RadiusChips({required this.selectedKm, required this.onPick});
  final int? selectedKm;
  final void Function(int?) onPick;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final options = <int?>[2, 5, 10, 20, null]; // null = All
    final labels = <int?, String>{
      2: '2 km',
      5: '5 km',
      10: '10 km',
      20: '20 km',
      null: 'All'
    };

    return Wrap(
      spacing: 8,
      children: [
        for (final km in options)
          ChoiceChip(
            label: Text(labels[km]!,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            selected: selectedKm == km,
            onSelected: (_) => onPick(km),
            side: BorderSide(color: cs.outline.withOpacity(0.12)),
          ),
      ],
    );
  }
}

// ===== Helper list =====

class _HelperList extends StatelessWidget {
  const _HelperList({
    required this.category,
    required this.query,
    required this.serviceMode,
    required this.openNow,
    required this.sort,
    required this.verifiedOnly,
    required this.invoiceOnly,
    required this.topRated,
    required this.myLat,
    required this.myLng,
    required this.radiusKm,
  });

  final String? category;
  final String query;
  final String serviceMode;
  final bool openNow;
  final String sort;
  final bool verifiedOnly;
  final bool invoiceOnly;
  final bool topRated;
  final double? myLat;
  final double? myLng;
  final int? radiusKm;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final base = FirebaseFirestore.instance
        .collection('users')
        .where('isHelper', isEqualTo: true)
        .limit(100);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: base.snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: 8,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => Container(
              height: 132,
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.outline.withOpacity(0.12)),
              ),
            ),
          );
        }

        var helpers =
        snap.data!.docs.map((d) => d.data()..['id'] = d.id).toList();

        // Category
        if (category != null && category!.isNotEmpty) {
          helpers = helpers.where((h) {
            final cats =
            (h['categories'] ?? h['primaryCategory'] ?? '')
                .toString()
                .toLowerCase();
            return cats.contains(category!.toLowerCase());
          }).toList();
        }
        // Search
        if (query.isNotEmpty) {
          helpers = helpers.where((h) {
            final hay =
            '${h['displayName'] ?? ''} ${h['bio'] ?? ''} ${h['categories'] ?? ''}'
                .toString()
                .toLowerCase();
            return hay.contains(query.toLowerCase());
          }).toList();
        }
        // Mode
        if (serviceMode == 'Online') {
          helpers = helpers
              .where((h) => (h['supportsOnline'] ?? false) == true)
              .toList();
        } else {
          helpers = helpers
              .where((h) => (h['supportsPhysical'] ?? true) == true)
              .toList();
        }
        // Open now
        if (openNow) {
          helpers = helpers
              .where((h) => (h['presence']?['isLive'] ?? false) == true)
              .toList();
        }
        // Verified / invoice / top rated
        if (verifiedOnly) {
          helpers =
              helpers.where((h) => (h['verifiedId'] ?? false) == true).toList();
        }
        if (invoiceOnly) {
          helpers = helpers
              .where((h) => (h['providesInvoice'] ?? false) == true)
              .toList();
        }
        if (topRated) {
          helpers = helpers.where((h) {
            final r = (h['rating'] is num)
                ? (h['rating'] as num).toDouble()
                : 0.0;
            return r >= 4.7;
          }).toList();
        }

        // Radius (if we know poster location)
        if (serviceMode == 'Physical' &&
            radiusKm != null &&
            myLat != null &&
            myLng != null) {
          helpers = helpers.where((h) {
            // If helper.distanceKm exists, use it directly
            final dk = (h['distanceKm'] is num)
                ? (h['distanceKm'] as num).toDouble()
                : null;
            if (dk != null) return dk <= radiusKm!;
            final lat = (h['location']?['lat'] is num)
                ? (h['location']['lat'] as num).toDouble()
                : null;
            final lng = (h['location']?['lng'] is num)
                ? (h['location']['lng'] as num).toDouble()
                : null;
            if (lat == null || lng == null) return true; // keep if no coords
            final distKm = _haversine(myLat!, myLng!, lat, lng);
            return distKm <= radiusKm!;
          }).toList();
        }

        // Sorting / scoring
        final lat0 = myLat ?? 0.0;
        final lng0 = myLng ?? 0.0;
        helpers.sort((a, b) {
          final sa = _score(a, lat0, lng0, sort);
          final sb = _score(b, lat0, lng0, sort);
          return sb.compareTo(sa);
        });

        if (helpers.isEmpty) {
          return Center(
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: cs.outline.withOpacity(0.12)),
              ),
              child: Text(t(context, 'No matching helpers')),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: helpers.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (ctx, i) {
            final h = helpers[i];
            return HelperCard(
              data: h,
              onViewProfile: null,
            );
          },
        );
      },
    );
  }
}

// ===== Utilities =====

double _haversine(double lat1, double lon1, double lat2, double lon2) {
  const R = 6371.0; // km
  double toRad(double d) => d * math.pi / 180.0;
  final dLat = toRad(lat2 - lat1);
  final dLon = toRad(lon2 - lon1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(toRad(lat1)) *
          math.cos(toRad(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return R * c;
}

double _score(Map<String, dynamic> h, double myLat, double myLng, String sort) {
  final rating =
  (h['rating'] is num) ? (h['rating'] as num).toDouble() : 4.6;
  final reviews = (h['reviewsCount'] is num)
      ? (h['reviewsCount'] as num).toDouble()
      : 0.0;
  final onTime =
  (h['onTimeRate'] is num) ? (h['onTimeRate'] as num).toDouble() : 0.95;
  final replyMins =
  (h['replyMins'] is num) ? (h['replyMins'] as num).toDouble() : 15.0;
  final booked = (h['bookedCount'] is num)
      ? (h['bookedCount'] as num).toDouble()
      : 0.0;
  final lat = (h['location']?['lat'] is num)
      ? (h['location']['lat'] as num).toDouble()
      : 0.0;
  final lng = (h['location']?['lng'] is num)
      ? (h['location']['lng'] as num).toDouble()
      : 0.0;
  final distKm = _haversine(myLat, myLng, lat, lng);

  switch (sort) {
    case 'Nearest':
      return -distKm;
    case 'Price: low to high':
      return -((h['priceFrom'] ?? 0) * 1.0);
    case 'Rating: high to low':
      return rating;
    case 'Most booked':
      return booked;
    default: // Best match (blend)
      final proximityScore = 1 / (1 + distKm);
      final replyScore = 1 / (1 + replyMins / 30);
      final reviewsBoost = reviews > 5 ? 0.1 : 0.0;
      return rating * 0.45 +
          onTime * 0.15 +
          proximityScore * 0.15 +
          replyScore * 0.15 +
          reviewsBoost;
  }
}
