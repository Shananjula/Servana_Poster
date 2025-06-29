import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

import 'package:helpify/providers/user_provider.dart';
import 'package:helpify/screens/filter_screen.dart';
import 'package:helpify/screens/verification_center_screen.dart';
import '../models/task_model.dart';
import '../models/service_model.dart';
import 'task_details_screen.dart';
import 'service_booking_screen.dart';
import '../widgets/empty_state_widget.dart';

// Enum to manage the current view state
enum ViewMode { list, map }

class BrowseScreen extends StatefulWidget {
  final String? initialCategory;
  const BrowseScreen({super.key, this.initialCategory});

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  Map<String, dynamic> _filters = {};
  ViewMode _viewMode = ViewMode.list; // Default to list view

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
    final userProvider = Provider.of<UserProvider>(context);
    final isVerified = userProvider.isVerifiedHelper;
    final isHelper = userProvider.user?.isHelper ?? false;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Browse Marketplace"),
          actions: [
            IconButton(
              icon: const Icon(Icons.filter_list_rounded),
              onPressed: _openFilterScreen,
              tooltip: 'Filter',
            ),
            // --- NEW: View Mode Toggle ---
            SegmentedButton<ViewMode>(
              segments: const [
                ButtonSegment(value: ViewMode.list, icon: Icon(Icons.list_rounded, size: 20)),
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
          bottom: const TabBar(
            tabs: [Tab(text: 'TASKS'), Tab(text: 'SERVICES')],
          ),
        ),
        body: TabBarView(
          children: [
            (isHelper && !isVerified)
                ? const VerificationPrompt()
                : TasksView(filters: _filters, viewMode: _viewMode),
            ServicesView(filters: _filters, viewMode: _viewMode),
          ],
        ),
      ),
    );
  }
}

// --- TASKS VIEW (UPGRADED FOR MAP VIEW) ---
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
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const EmptyStateWidget(icon: Icons.search_off_rounded, title: "No Tasks Found", message: "Try adjusting your filters.");
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
      itemBuilder: (context, index) => TaskCard(task: tasks[index]),
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
      initialCameraPosition: const CameraPosition(
        target: LatLng(6.9271, 79.8612), // Default to Colombo
        zoom: 12,
      ),
      markers: markers,
    );
  }
}

// --- SERVICES VIEW (UPGRADED FOR MAP VIEW) ---
class ServicesView extends StatelessWidget {
  final Map<String, dynamic> filters;
  final ViewMode viewMode;
  const ServicesView({super.key, required this.filters, required this.viewMode});

  @override
  Widget build(BuildContext context) {
    Query query = FirebaseFirestore.instance.collection('services').where('isActive', isEqualTo: true);

    filters.forEach((key, value) {
      if (value != null && value != 'All' && value.toString().isNotEmpty) {
        if (key == 'category') {
          query = query.where(key, isEqualTo: value);
        }
      }
    });

    // NOTE: For map view to work with services, your 'services' collection
    // documents MUST have a 'location' GeoPoint field.
    query = query.orderBy('category');

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const EmptyStateWidget(icon: Icons.design_services_outlined, title: "No Services Found", message: "Try adjusting your filters.");
        }

        final services = snapshot.data!.docs.map((doc) => Service.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>, null)).toList();
        // final physicalServices = services.where((service) => service.location != null).toList();

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          // For now, only showing list view for services. Map view can be added similarly.
          child: _buildListView(services),
        );
      },
    );
  }

  Widget _buildListView(List<Service> services) {
    return ListView.builder(
      key: const ValueKey('service_list'),
      padding: const EdgeInsets.all(16.0),
      itemCount: services.length,
      itemBuilder: (context, index) => ServiceDiscoveryCard(service: services[index]),
    );
  }
}

// --- WIDGET SHOWN TO UNVERIFIED HELPERS ---
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
            builder: (_) => const VerificationCenterScreen(),
          ));
        },
      ),
    );
  }
}

// --- TASK CARD WIDGET (FULL IMPLEMENTATION FROM YOUR FILE) ---
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

// --- SERVICE CARD WIDGET (FULL IMPLEMENTATION FROM YOUR FILE) ---
class ServiceDiscoveryCard extends StatelessWidget {
  final Service service;
  const ServiceDiscoveryCard({Key? key, required this.service}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(service.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('${service.category} Service', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('LKR ${service.rate.toStringAsFixed(0)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.teal)),
                Text(service.rateType, style: const TextStyle(fontSize: 16, color: Colors.black54)),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => ServiceBookingScreen(service: service)));
              },
              icon: const Icon(Icons.calendar_today_outlined, size: 18),
              label: const Text('Book Now'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
                backgroundColor: Colors.teal.withOpacity(0.9),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
