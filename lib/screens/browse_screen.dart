import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:geolocator/geolocator.dart';
import 'package:servana/models/user_model.dart';

import 'package:servana/providers/user_provider.dart';
import 'package:servana/screens/filter_screen.dart';
import 'package:servana/screens/verification_status_screen.dart';
import '../models/task_model.dart';
import 'task_details_screen.dart';
import 'profile_screen.dart';
import '../widgets/empty_state_widget.dart';

enum ViewMode { list, map }

class BrowseScreen extends StatefulWidget {
  final String? initialCategory;
  const BrowseScreen({super.key, this.initialCategory});

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  Map<String, dynamic> _filters = {};
  ViewMode _viewMode = ViewMode.list;

  @override
  void initState() {
    super.initState();
    if (widget.initialCategory != null) {
      setState(() {
        _filters['category'] = widget.initialCategory;
      });
    }
  }

  void _openFilterScreen() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => FilterScreen(
          scrollController: controller,
          initialFilters: _filters,
        ),
      ),
    );
    if (result != null) {
      setState(() => _filters = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final activeMode = userProvider.activeMode;
    final isVerified = userProvider.isVerifiedHelper;
    final isRegisteredHelper = userProvider.user?.isHelper ?? false;

    final bool showHelperUI = activeMode == AppMode.helper;

    return Scaffold(
      appBar: AppBar(
        title: Text(showHelperUI ? "Find Work" : "Find Help"),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: _openFilterScreen,
            tooltip: 'Filter',
          ),
          SegmentedButton<ViewMode>(
            segments: const [
              ButtonSegment(value: ViewMode.list, icon: Icon(Icons.view_list_rounded, size: 20)),
              ButtonSegment(value: ViewMode.map, icon: Icon(Icons.map_outlined, size: 20)),
            ],
            selected: {_viewMode},
            onSelectionChanged: (Set<ViewMode> newSelection) {
              setState(() => _viewMode = newSelection.first);
            },
            style: SegmentedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.surface,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: showHelperUI
          ? (isRegisteredHelper && !isVerified)
          ? const VerificationPrompt()
          : TasksView(filters: _filters, viewMode: _viewMode)
          : HelpersView(filters: _filters, viewMode: _viewMode), // Updated to HelpersView
    );
  }
}

// --- TASKS VIEW (For Helpers to find work) ---
class TasksView extends StatelessWidget {
  final Map<String, dynamic> filters;
  final ViewMode viewMode;
  const TasksView({super.key, required this.filters, required this.viewMode});

  @override
  Widget build(BuildContext context) {
    Query query = FirebaseFirestore.instance.collection('tasks').where('status', isEqualTo: 'open');
    filters.forEach((key, value) {
      if (value != null && value != 'All' && value.toString().isNotEmpty) {
        if (key == 'rate_min') {
          query = query.where('budget', isGreaterThanOrEqualTo: value);
        } else if (key == 'rate_max') {
          query = query.where('budget', isLessThanOrEqualTo: value);
        } else {
          query = query.where(key, isEqualTo: value);
        }
      }
    });
    query = query.orderBy('timestamp', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildSkeletonListView(_TaskCardSkeleton());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const EmptyStateWidget(icon: Icons.search_off_rounded, title: "No Tasks Found", message: "Try adjusting your filters or check back later.");
        }

        final tasks = snapshot.data!.docs.map((doc) => Task.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>)).toList();
        final physicalTasks = tasks.where((task) => task.location != null && task.taskType == 'physical').toList();

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: (viewMode == ViewMode.list || physicalTasks.isEmpty)
              ? _buildListView(tasks)
              : _buildMapView(context, physicalTasks),
        );
      },
    );
  }

  Widget _buildListView(List<Task> tasks) {
    return ListView.builder(
      key: const ValueKey('list'),
      padding: const EdgeInsets.all(16.0),
      itemCount: tasks.length,
      itemBuilder: (context, index) => TaskCard(task: tasks[index]).animate()
          .fadeIn(duration: 500.ms, delay: (100 * index).ms, curve: Curves.easeOut)
          .slideY(begin: 0.2, curve: Curves.easeOut),
    );
  }

  Widget _buildMapView(BuildContext context, List<Task> tasks) {
    final Set<Marker> markers = tasks.map((task) {
      return Marker(
        markerId: MarkerId(task.id),
        position: LatLng(task.location!.latitude, task.location!.longitude),
        infoWindow: InfoWindow(
          title: task.title,
          snippet: 'Budget: LKR ${NumberFormat("#,##0").format(task.budget)}',
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => TaskDetailsScreen(task: task)));
          },
        ),
      );
    }).toSet();

    return GoogleMap(
      key: const ValueKey('map'),
      initialCameraPosition: const CameraPosition(target: LatLng(6.9271, 79.8612), zoom: 12),
      markers: markers,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
    );
  }
}

// --- HELPERS VIEW (For Users to find help) ---
class HelpersView extends StatefulWidget {
  final Map<String, dynamic> filters;
  final ViewMode viewMode;
  const HelpersView({super.key, required this.filters, required this.viewMode});

  @override
  State<HelpersView> createState() => _HelpersViewState();
}

class _HelpersViewState extends State<HelpersView> {
  final Completer<GoogleMapController> _mapController = Completer();
  Stream<QuerySnapshot>? _helpersStream;

  @override
  void initState() {
    super.initState();
    _buildQuery();
    _centerMapOnUserLocation();
  }

  @override
  void didUpdateWidget(covariant HelpersView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filters != widget.filters) {
      _buildQuery();
    }
  }

  void _buildQuery() {
    Query query = FirebaseFirestore.instance
        .collection('users')
        .where('isHelper', isEqualTo: true)
        .where('verificationStatus', isEqualTo: 'verified');

    widget.filters.forEach((key, value) {
      if (value != null && value != 'All' && value.toString().isNotEmpty) {
        if (key == 'category') {
          query = query.where('skills', arrayContains: value);
        } else if (key == 'isVerified' && value == true) {
          // This is already part of the base query, but good for explicit filtering
        } else if (key == 'minRating') {
          query = query.where('averageRating', isGreaterThanOrEqualTo: value);
        }
        // Location filtering would be more complex (geoquery) and is omitted for simplicity here
        // but could be added with a library like geoflutterfire.
      }
    });

    setState(() {
      _helpersStream = query.snapshots();
    });
  }

  Future<void> _centerMapOnUserLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      final controller = await _mapController.future;
      controller.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(target: LatLng(position.latitude, position.longitude), zoom: 12),
      ));
    } catch (e) {
      print("Could not get user location: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _helpersStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildSkeletonListView(_HelperCardSkeleton());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const EmptyStateWidget(icon: Icons.person_search_outlined, title: "No Helpers Found", message: "Try adjusting your filters or expanding your search area.");
        }

        final helpers = snapshot.data!.docs.map((doc) => HelpifyUser.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>)).toList();
        final helpersWithLocation = helpers.where((h) => h.workLocation != null).toList();

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
          child: (widget.viewMode == ViewMode.list || helpersWithLocation.isEmpty)
              ? _buildListView(helpers)
              : _buildMapView(context, helpersWithLocation),
        );
      },
    );
  }

  Widget _buildListView(List<HelpifyUser> helpers) {
    return ListView.builder(
      key: const ValueKey('helper_list'),
      padding: const EdgeInsets.all(16.0),
      itemCount: helpers.length,
      itemBuilder: (context, index) => HelperCard(helper: helpers[index]).animate()
          .fadeIn(duration: 500.ms, delay: (100 * index).ms, curve: Curves.easeOut)
          .slideY(begin: 0.2, curve: Curves.easeOut),
    );
  }

  Widget _buildMapView(BuildContext context, List<HelpifyUser> helpers) {
    final Set<Marker> markers = helpers.map((helper) {
      return Marker(
        markerId: MarkerId(helper.id),
        position: LatLng(helper.workLocation!.latitude, helper.workLocation!.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: InfoWindow(
          title: helper.displayName ?? 'Servana Helper',
          snippet: 'Rating: ${helper.averageRating.toStringAsFixed(1)} ★ (${helper.ratingCount})',
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileScreen(userId: helper.id)));
          },
        ),
      );
    }).toSet();

    return GoogleMap(
      key: const ValueKey('helper_map'),
      initialCameraPosition: const CameraPosition(target: LatLng(6.9271, 79.8612), zoom: 12),
      onMapCreated: (controller) {
        if (!_mapController.isCompleted) {
          _mapController.complete(controller);
        }
      },
      markers: markers,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
    );
  }
}

// --- SHARED WIDGETS ---

Widget _buildSkeletonListView(Widget skeletonCard) {
  return ListView.builder(
    padding: const EdgeInsets.all(16.0),
    itemCount: 5,
    itemBuilder: (context, index) => skeletonCard,
  );
}

class VerificationPrompt extends StatelessWidget {
  const VerificationPrompt({super.key});

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      icon: Icons.shield_outlined,
      title: 'Verification Required',
      message: 'To ensure community safety, you must verify your profile before you can browse and accept tasks.',
      actionButton: ElevatedButton.icon(
        icon: const Icon(Icons.verified_user_outlined),
        label: const Text('Start Verification'),
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const VerificationStatusScreen(), // Direct to status/re-upload screen
          ));
        },
      ),
    );
  }
}

class TaskCard extends StatelessWidget {
  final Task task;
  const TaskCard({Key? key, required this.task}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOnline = task.taskType == 'online';
    final IconData locationIcon = isOnline ? Icons.language_rounded : Icons.location_on_outlined;
    final String locationText = isOnline ? 'Online / Remote' : task.locationAddress ?? 'Physical Location';

    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.only(bottom: 16.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => TaskDetailsScreen(task: task)));
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: theme.primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        '${task.category} ${task.subCategory != null ? "> ${task.subCategory}" : ""}'.toUpperCase(),
                        style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  Text(
                      'LKR ${NumberFormat("#,##0").format(task.budget)}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(task.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black87)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(locationIcon, color: Colors.grey[600], size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      locationText,
                      style: TextStyle(color: Colors.grey[700], fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- NEW HELPER CARD WIDGET ---
class HelperCard extends StatelessWidget {
  final HelpifyUser helper;
  const HelperCard({Key? key, required this.helper}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.only(bottom: 16.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: helper.id))),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundImage: helper.photoURL != null ? NetworkImage(helper.photoURL!) : null,
                    child: helper.photoURL == null ? const Icon(Icons.person, size: 30) : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(helper.displayName ?? 'Servana Helper', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.star, color: Colors.amber, size: 16),
                            const SizedBox(width: 4),
                            Text('${helper.averageRating.toStringAsFixed(1)} (${helper.ratingCount} reviews)', style: theme.textTheme.bodyMedium),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 16),
                ],
              ),
              if (helper.skills.isNotEmpty) ...[
                const Divider(height: 24),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  children: helper.skills.take(3).map((skill) => Chip(
                    label: Text(skill),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    labelStyle: const TextStyle(fontSize: 12),
                    backgroundColor: theme.colorScheme.secondary.withOpacity(0.1),
                    side: BorderSide.none,
                  )).toList(),
                )
              ]
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskCardSkeleton extends StatelessWidget {
  const _TaskCardSkeleton();

  Widget _buildPlaceholder({double? width, double height = 16}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.only(bottom: 16.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildPlaceholder(width: 120, height: 24),
                _buildPlaceholder(width: 80, height: 24),
              ],
            ),
            const SizedBox(height: 12),
            _buildPlaceholder(height: 28),
            const SizedBox(height: 8),
            _buildPlaceholder(width: 200),
          ],
        ),
      ),
    );
  }
}

// --- NEW SKELETON FOR HELPER CARD ---
class _HelperCardSkeleton extends StatelessWidget {
  const _HelperCardSkeleton();

  Widget _buildPlaceholder({double? width, double height = 16}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.only(bottom: 16.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(radius: 30, backgroundColor: Colors.grey.shade200),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPlaceholder(width: 150, height: 20),
                  const SizedBox(height: 8),
                  _buildPlaceholder(width: 100),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
