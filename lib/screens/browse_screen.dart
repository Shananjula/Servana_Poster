import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:servana/models/user_model.dart';
import 'package:servana/providers/user_provider.dart';
import 'package:servana/screens/conversation_screen.dart';
import 'package:servana/screens/filter_screen.dart';
import 'package:servana/screens/verification_status_screen.dart';
import 'package:servana/services/ai_service.dart';
// Firestore service now provides the TaskSortOption enum
import 'package:servana/services/firestore_service.dart';
import '../models/task_model.dart';
import 'task_details_screen.dart';
import 'helper_public_profile_screen.dart';
import '../widgets/empty_state_widget.dart';

enum ViewMode { list, map }
enum HelperSortOption { proFirst, newest, highestRated, mostReviews }
// The 'TaskSortOption' enum has been REMOVED from this file. It will now be
// imported from 'firestore_service.dart' to resolve the error.

class BrowseScreen extends StatefulWidget {
  final String? initialCategory;
  const BrowseScreen({super.key, this.initialCategory});

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  final TextEditingController _searchController = TextEditingController();
  Map<String, dynamic> _filters = {};
  String _searchTerm = '';
  ViewMode _viewMode = ViewMode.list;
  HelperSortOption _helperSortOption = HelperSortOption.proFirst;
  TaskSortOption _taskSortOption = TaskSortOption.newest;
  bool _isAiSearching = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    if (widget.initialCategory != null) {
      _filters['category'] = widget.initialCategory;
    }
    _searchController.addListener(() {
      if (_debounce?.isActive ?? false) _debounce!.cancel();
      _debounce = Timer(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _searchTerm = _searchController.text;
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _performAiSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    FocusScope.of(context).unfocus();
    setState(() => _isAiSearching = true);

    try {
      final aiFilters = await AiService.parseSearchQuery(query);
      if (mounted && aiFilters != null) {
        setState(() {
          _filters.addAll(aiFilters);
          if (aiFilters.containsKey('searchTerm')) {
            _searchController.text = aiFilters['searchTerm'];
          }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("AI filters applied!"), backgroundColor: Colors.green),
          );
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("AI search failed: ${e.toString()}"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAiSearching = false);
      }
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
              ButtonSegment(
                  value: ViewMode.list,
                  icon: Icon(Icons.view_list_rounded, size: 20)),
              ButtonSegment(
                  value: ViewMode.map,
                  icon: Icon(Icons.map_outlined, size: 20)),
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search for tasks (e.g., "urgent cleaning")...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[200],
                    contentPadding: EdgeInsets.zero,
                    suffixIcon: _isAiSearching
                        ? const Padding(padding: EdgeInsets.all(12.0), child: CircularProgressIndicator(strokeWidth: 2))
                        : IconButton(
                      icon: const Icon(Icons.auto_awesome),
                      tooltip: 'Search with AI',
                      onPressed: _performAiSearch,
                    ),
                  ),
                  onSubmitted: (_) => _performAiSearch(),
                ),
                const SizedBox(height: 8),
                _buildSortDropdown(showHelperUI),
              ],
            ),
          ),
          Expanded(
            child: showHelperUI
                ? (isRegisteredHelper && !isVerified)
                ? const VerificationPrompt()
                : TasksView(filters: _filters, viewMode: _viewMode, searchTerm: _searchTerm, sortOption: _taskSortOption)
                : HelpersView(filters: _filters, viewMode: _viewMode, searchTerm: _searchTerm, sortOption: _helperSortOption),
          ),
        ],
      ),
    );
  }

  Widget _buildSortDropdown(bool isHelperView) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: DropdownButton<Enum>(
          value: isHelperView ? _taskSortOption : _helperSortOption,
          underline: const SizedBox(),
          isDense: true,
          items: isHelperView
              ? TaskSortOption.values.map((option) {
            return DropdownMenuItem<Enum>(
              value: option,
              child: Text(_getTaskSortOptionName(option)),
            );
          }).toList()
              : HelperSortOption.values.map((option) {
            return DropdownMenuItem<Enum>(
              value: option,
              child: Text(_getHelperSortOptionName(option)),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              if (isHelperView && value is TaskSortOption) {
                _taskSortOption = value;
              } else if (!isHelperView && value is HelperSortOption) {
                _helperSortOption = value;
              }
            });
          },
        ),
      ),
    );
  }

  String _getHelperSortOptionName(HelperSortOption option) {
    switch (option) {
      case HelperSortOption.proFirst: return 'Sort by: Pro Helpers First';
      case HelperSortOption.highestRated: return 'Sort by: Highest Rated';
      case HelperSortOption.mostReviews: return 'Sort by: Most Reviews';
      case HelperSortOption.newest: return 'Sort by: Newest';
    }
  }

  String _getTaskSortOptionName(TaskSortOption option) {
    switch (option) {
      case TaskSortOption.highestBudget: return 'Sort by: Highest Budget';
      case TaskSortOption.newest: return 'Sort by: Newest';
    }
  }
}

// --- TASKS VIEW (UPDATED) ---
class TasksView extends StatefulWidget {
  final Map<String, dynamic> filters;
  final ViewMode viewMode;
  final String searchTerm;
  final TaskSortOption sortOption;
  const TasksView({super.key, required this.filters, required this.viewMode, required this.searchTerm, required this.sortOption});

  @override
  State<TasksView> createState() => _TasksViewState();
}

class _TasksViewState extends State<TasksView> {
  Position? _currentPosition;
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;
      final position = await Geolocator.getCurrentPosition();
      if (mounted) setState(() => _currentPosition = position);
    } catch (e) {
      print("Could not get user location for filtering: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final currentUser = userProvider.user;

    if (currentUser == null) return const Center(child: Text("Please log in."));

    List<String> keywordsForQuery;
    if (widget.searchTerm.isNotEmpty) {
      keywordsForQuery = widget.searchTerm.toLowerCase().split(' ').where((s) => s.length > 1).toList();
    } else {
      keywordsForQuery = currentUser.skills;
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestoreService.getTasksByKeywords(
        keywords: keywordsForQuery,
        currentUserId: currentUser.id,
        // The error is fixed because widget.sortOption is now the same type
        // as the one expected by the getTasksByKeywords method.
        sortOption: widget.sortOption,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildSkeletonListView(_TaskCardSkeleton());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}\n\nNote: This might be a missing Firestore index. Check your debug console for a link to create it.'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const EmptyStateWidget(
              icon: Icons.search_off_rounded,
              title: "No Tasks Found",
              message: "Try adjusting your filters or search terms. Your skills might not match any open tasks right now.");
        }

        final tasks = snapshot.data!.docs.map((doc) => Task.fromFirestore(doc)).toList();

        final double maxDistance = (widget.filters['distance'] as num? ?? 50.0).toDouble();
        List<Task> distanceFilteredTasks = tasks;

        if (_currentPosition != null && maxDistance < 50) {
          distanceFilteredTasks = tasks.where((task) {
            if (task.location == null) return true; // Always include online tasks
            final distanceInMeters = Geolocator.distanceBetween(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
              task.location!.latitude,
              task.location!.longitude,
            );
            return (distanceInMeters / 1000) <= maxDistance;
          }).toList();
        }

        // Additional client-side filtering from the filter screen
        final filteredTasks = distanceFilteredTasks.where((task) {
          final categoryFilter = widget.filters['category'];
          final subCategoryFilter = widget.filters['subCategory'];
          final minBudget = widget.filters['rate_min'];
          final maxBudget = widget.filters['rate_max'];

          if (categoryFilter != null && categoryFilter != 'All' && task.category != categoryFilter) return false;
          if (subCategoryFilter != null && subCategoryFilter != 'All' && task.subCategory != subCategoryFilter) return false;
          if (minBudget != null && task.budget < minBudget) return false;
          if (maxBudget != null && task.budget > maxBudget) return false;

          return true;
        }).toList();


        if (filteredTasks.isEmpty) {
          return const EmptyStateWidget(
              icon: Icons.filter_alt_off_outlined,
              title: "No Matching Tasks",
              message: "No tasks match your current search and filter combination. Try adjusting them.");
        }

        final physicalTasks = filteredTasks.where((task) => task.location != null && task.taskType == 'physical').toList();

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: (widget.viewMode == ViewMode.list || physicalTasks.isEmpty)
              ? _buildTaskListView(filteredTasks)
              : _buildTaskMapView(context, physicalTasks),
        );
      },
    );
  }

  Widget _buildTaskListView(List<Task> tasks) {
    return ListView.builder(
      key: const ValueKey('task_list'),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: tasks.length,
      itemBuilder: (context, index) => TaskCard(task: tasks[index]),
    );
  }

  Widget _buildTaskMapView(BuildContext context, List<Task> tasks) {
    final Set<Marker> markers = tasks.map((task) {
      return Marker(
        markerId: MarkerId(task.id),
        position: LatLng(task.location!.latitude, task.location!.longitude),
        infoWindow: InfoWindow(
          title: task.title,
          snippet: 'Budget: LKR ${NumberFormat("#,##0").format(task.budget)}',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => TaskDetailsScreen(task: task))),
        ),
      );
    }).toSet();

    return GoogleMap(
      key: const ValueKey('task_map'),
      initialCameraPosition: CameraPosition(target: _currentPosition != null ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude) : const LatLng(6.9271, 79.8612), zoom: 12),
      markers: markers,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
    );
  }
}

// --- ALL OTHER WIDGETS AND CLASSES (HelpersView, TaskCard, etc.) ARE UNCHANGED ---
class HelpersView extends StatefulWidget {
  final Map<String, dynamic> filters;
  final ViewMode viewMode;
  final String searchTerm;
  final HelperSortOption sortOption;
  const HelpersView({super.key, required this.filters, required this.viewMode, required this.searchTerm, required this.sortOption});

  @override
  State<HelpersView> createState() => _HelpersViewState();
}

class _HelpersViewState extends State<HelpersView> {
  final Completer<GoogleMapController> _mapController = Completer();
  Stream<QuerySnapshot>? _helpersStream;
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _buildQuery();
    _getCurrentLocationAndCenterMap();
  }

  @override
  void didUpdateWidget(covariant HelpersView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filters != widget.filters || oldWidget.sortOption != widget.sortOption) {
      _buildQuery();
    }
  }

  Future<void> _getCurrentLocationAndCenterMap() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
        final controller = await _mapController.future;
        controller.animateCamera(CameraUpdate.newCameraPosition(
          CameraPosition(target: LatLng(position.latitude, position.longitude), zoom: 12),
        ));
      }
    } catch (e) {
      print("Could not get user location: $e");
    }
  }

  void _buildQuery() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    Query query = FirebaseFirestore.instance
        .collection('users')
        .where('isHelper', isEqualTo: true)
        .where('verificationStatus', isEqualTo: 'verified')
        .where(FieldPath.documentId, isNotEqualTo: currentUserId);

    widget.filters.forEach((key, value) {
      if (key != 'distance' && key != 'searchTerm' && value != null && value != 'All' && value.toString().isNotEmpty) {
        if (key == 'category') query = query.where('skills', arrayContains: value);
        else if (key == 'minRating') query = query.where('averageRating', isGreaterThanOrEqualTo: value);
      }
    });

    switch (widget.sortOption) {
      case HelperSortOption.proFirst:
        query = query.orderBy('isProMember', descending: true).orderBy('averageRating', descending: true);
        break;
      case HelperSortOption.highestRated:
        query = query.orderBy('averageRating', descending: true);
        break;
      case HelperSortOption.mostReviews:
        query = query.orderBy('ratingCount', descending: true);
        break;
      case HelperSortOption.newest:
      // You might need a 'createdAt' field on your user document for this to work
      // query = query.orderBy('createdAt', descending: true);
        break;
    }

    setState(() {
      _helpersStream = query.snapshots();
    });
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
          return Center(child: Text('Error: ${snapshot.error} \n\nNote: This might be due to a missing Firestore index. Check the debug console for a link to create it.'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const EmptyStateWidget(
              icon: Icons.person_search_outlined,
              title: "No Helpers Found",
              message: "Try adjusting your filters or expanding your search area.");
        }

        final helpers = snapshot.data!.docs
            .map((doc) => HelpifyUser.fromFirestore(
            doc as DocumentSnapshot<Map<String, dynamic>>))
            .toList();

        final double maxDistance = (widget.filters['distance'] as num? ?? 50.0).toDouble();
        List<HelpifyUser> distanceFilteredHelpers = helpers;

        if (_currentPosition != null && maxDistance < 50) {
          distanceFilteredHelpers = helpers.where((helper) {
            if (helper.workLocation == null) return false;
            final distanceInMeters = Geolocator.distanceBetween(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
              helper.workLocation!.latitude,
              helper.workLocation!.longitude,
            );
            return (distanceInMeters / 1000) <= maxDistance;
          }).toList();
        }

        final filteredHelpers = widget.searchTerm.isEmpty
            ? distanceFilteredHelpers
            : distanceFilteredHelpers.where((helper) {
          final searchTermLower = widget.searchTerm.toLowerCase();
          return (helper.displayName?.toLowerCase().contains(searchTermLower) ?? false) ||
              helper.skills.any((skill) => skill.toLowerCase().contains(searchTermLower));
        }).toList();

        if (filteredHelpers.isEmpty) {
          return const EmptyStateWidget(
              icon: Icons.person_search_outlined,
              title: "No Matching Helpers",
              message: "Try a different search term or adjust your filters.");
        }

        final helpersWithLocation =
        filteredHelpers.where((h) => h.workLocation != null).toList();

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (child, animation) =>
              FadeTransition(opacity: animation, child: child),
          child: (widget.viewMode == ViewMode.list || helpersWithLocation.isEmpty)
              ? _buildHelperListView(filteredHelpers)
              : _buildHelperMapView(context, helpersWithLocation),
        );
      },
    );
  }

  Widget _buildHelperListView(List<HelpifyUser> helpers) {
    return ListView.builder(
      key: const ValueKey('helper_list'),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: helpers.length,
      itemBuilder: (context, index) => HelperCard(helper: helpers[index]),
    );
  }

  Widget _buildHelperMapView(BuildContext context, List<HelpifyUser> helpers) {
    final Set<Marker> markers = helpers.map((helper) {
      return Marker(
        markerId: MarkerId(helper.id),
        position:
        LatLng(helper.workLocation!.latitude, helper.workLocation!.longitude),
        icon: helper.isProMember
            ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet)
            : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: InfoWindow(
          title: helper.displayName ?? 'Servana Helper',
          snippet:
          'Rating: ${helper.averageRating.toStringAsFixed(1)} ★ (${helper.ratingCount})',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => HelperPublicProfileScreen(helperId: helper.id))),
        ),
      );
    }).toSet();

    return GoogleMap(
      key: const ValueKey('helper_map'),
      initialCameraPosition:
      const CameraPosition(target: LatLng(6.9271, 79.8612), zoom: 12),
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
      message:
      'To ensure community safety, you must verify your profile before you can browse and accept tasks.',
      actionButton: ElevatedButton.icon(
        icon: const Icon(Icons.verified_user_outlined),
        label: const Text('Start Verification'),
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const VerificationStatusScreen(),
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
    final IconData locationIcon =
    isOnline ? Icons.language_rounded : Icons.location_on_outlined;
    final String locationText =
    isOnline ? 'Online / Remote' : task.locationAddress ?? 'Physical Location';

    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.only(bottom: 16.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => TaskDetailsScreen(task: task)));
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: theme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        '${task.category} ${task.subCategory != null ? "> ${task.subCategory}" : ""}'
                            .toUpperCase(),
                        style: TextStyle(
                            color: theme.primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  Text('LKR ${NumberFormat("#,##0").format(task.budget)}',
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87)),
                ],
              ),
              const SizedBox(height: 12),
              Text(task.title,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87)),
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

class HelperCard extends StatefulWidget {
  final HelpifyUser helper;
  const HelperCard({Key? key, required this.helper}) : super(key: key);

  @override
  State<HelperCard> createState() => _HelperCardState();
}

class _HelperCardState extends State<HelperCard> {
  bool _isContacting = false;
  final FirestoreService _firestoreService = FirestoreService();

  void _onContactPressed(BuildContext context) async {
    if (_isContacting) return;

    setState(() => _isContacting = true);

    try {
      final currentUser = context.read<UserProvider>().user;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You must be logged in to contact a helper.")),
        );
        return;
      }

      final existingChannelId = await _firestoreService.getDirectChatChannelId(currentUser.id, widget.helper.id);

      if (!context.mounted) return;

      if (existingChannelId != null) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (ctx) => ConversationScreen(
            chatChannelId: existingChannelId,
            otherUserName: widget.helper.displayName ?? 'Helper',
            otherUserAvatarUrl: widget.helper.photoURL,
            taskTitle: "Direct Inquiry",
          ),
        ));
      } else {
        final bool? confirmPayment = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text("Contact ${widget.helper.displayName}?"),
            content: const Text(
                "A one-time fee of 20 Serv Coins will be deducted to start a private chat. Do you want to continue?"),
            actions: [
              TextButton(
                child: const Text("Cancel"),
                onPressed: () => Navigator.of(dialogContext).pop(false),
              ),
              ElevatedButton(
                child: const Text("Confirm & Pay"),
                onPressed: () => Navigator.of(dialogContext).pop(true),
              ),
            ],
          ),
        );

        if (confirmPayment == true) {
          final String newChatChannelId = await _firestoreService.initiateDirectContact(
            currentUser: currentUser,
            helper: widget.helper,
          );

          if (!context.mounted) return;

          Navigator.of(context).push(MaterialPageRoute(
            builder: (ctx) => ConversationScreen(
              chatChannelId: newChatChannelId,
              otherUserName: widget.helper.displayName ?? 'Helper',
              otherUserAvatarUrl: widget.helper.photoURL,
              taskTitle: "Direct Inquiry",
            ),
          ));
        }
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isContacting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.only(bottom: 16.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              HelperPublicProfileScreen(helperId: widget.helper.id))),
                  child: CircleAvatar(
                    radius: 30,
                    backgroundImage:
                    widget.helper.photoURL != null ? NetworkImage(widget.helper.photoURL!) : null,
                    child: widget.helper.photoURL == null
                        ? const Icon(Icons.person, size: 30)
                        : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => HelperPublicProfileScreen(
                                helperId: widget.helper.id))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(widget.helper.displayName ?? 'Servana Helper',
                                style: theme.textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (widget.helper.isProMember)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.purple,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'PRO',
                                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              )
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 16),
                            const SizedBox(width: 4),
                            Text(
                                '${widget.helper.averageRating.toStringAsFixed(1)} (${widget.helper.ratingCount} reviews)',
                                style: theme.textTheme.bodyMedium),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                _isContacting
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                    : IconButton(
                  icon: Icon(Icons.chat_bubble_outline_rounded,
                      color: theme.primaryColor),
                  onPressed: () => _onContactPressed(context),
                  tooltip: "Contact Helper",
                ),
              ],
            ),
            if (widget.helper.skills.isNotEmpty) ...[
              const Divider(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  children: widget.helper.skills
                      .take(3)
                      .map((skill) => Chip(
                    label: Text(skill),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    labelStyle: const TextStyle(fontSize: 12),
                    backgroundColor:
                    theme.colorScheme.secondary.withOpacity(0.1),
                    side: BorderSide.none,
                  ))
                      .toList(),
                ),
              )
            ]
          ],
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