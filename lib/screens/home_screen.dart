import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:helpify/widgets/category_grid_view.dart';
import 'package:helpify/models/task_model.dart';
import 'package:helpify/models/user_model.dart';
import 'package:helpify/providers/user_provider.dart';
import 'package:helpify/services/ai_service.dart';
import 'package:helpify/widgets/empty_state_widget.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

// --- Screen Imports for Navigation ---
import './post_task_screen.dart';
import './browse_screen.dart';
import './profile_screen.dart';
import './notifications_screen.dart';
import './verification_center_screen.dart';
import './community_feed_screen.dart';
import './activity_screen.dart';
import 'active_task_screen.dart';
import 'task_details_screen.dart';

// Main screen that holds the bottom navigation bar
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _widgetOptions = <Widget>[
    _HomeDashboardView(),
    BrowseScreen(),
    CommunityFeedScreen(),
    ActivityScreen(),
    ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.search_outlined), label: 'Browse'),
          BottomNavigationBarItem(icon: Icon(Icons.groups_outlined), label: 'Community'),
          BottomNavigationBarItem(icon: Icon(Icons.list_alt_rounded), label: 'Activity'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline_rounded), label: 'Profile'),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

// The view for the "Home" tab, containing all your original features and new ones
enum AppMode { poster, helper }

class _HomeDashboardView extends StatefulWidget {
  const _HomeDashboardView();

  @override
  State<_HomeDashboardView> createState() => _HomeDashboardViewState();
}

class _HomeDashboardViewState extends State<_HomeDashboardView> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<AlignmentGeometry> _alignAnimation;
  late Animation<Color?> _colorAnimation;
  AppMode _currentMode = AppMode.poster;
  Future<List<dynamic>>? _recommendationsFuture;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _alignAnimation = AlignmentTween(begin: Alignment.centerLeft, end: Alignment.centerRight)
        .animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOutCubic));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final theme = Theme.of(context);
    _colorAnimation = ColorTween(
      begin: theme.colorScheme.primaryContainer.withOpacity(0.5),
      end: theme.colorScheme.secondaryContainer.withOpacity(0.5),
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOutCubic));
    if (_recommendationsFuture == null) {
      _loadInitialData();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final user = Provider.of<UserProvider>(context, listen: false).user;
    if (user == null) {
      if (mounted) setState(() => _recommendationsFuture = Future.value([]));
      return;
    }
    if (mounted) {
      setState(() {
        _recommendationsFuture = _currentMode == AppMode.helper
            ? _fetchAIRecommendationsForHelper(user)
            : _fetchAIRecommendationsForPoster(user);
      });
    }
  }

  void _toggleMode() {
    final helpifyUser = Provider.of<UserProvider>(context, listen: false).user;
    if (helpifyUser == null) return;
    if (_currentMode == AppMode.poster) {
      switch (helpifyUser.verificationStatus) {
        case 'verified':
          setState(() {
            _currentMode = AppMode.helper;
            _animationController.forward();
            _loadInitialData();
          });
          break;
        case 'pending':
          _showStatusDialog('Verification Pending', 'Your documents are under review. We will notify you once complete.');
          break;
        case 'rejected':
          _showVerificationPopup('Verification Rejected', 'There was an issue with your previous submission. Please try again.');
          break;
        default:
          _showVerificationPopup('Become a Trusted Helper', 'To offer your skills, please complete our one-time verification.');
          break;
      }
    } else {
      setState(() {
        _currentMode = AppMode.poster;
        _animationController.reverse();
        _loadInitialData();
      });
    }
  }

  // --- FULL AI RECOMMENDATION LOGIC ---
  Future<List<Task>> _fetchAIRecommendationsForHelper(HelpifyUser helpifyUser) async {
    try {
      final helperProfile = "Bio: ${helpifyUser.bio ?? ''}. Skills: ${helpifyUser.skills.join(', ')}. Qualifications: ${helpifyUser.qualifications ?? ''}.";
      final tasksSnapshot = await FirebaseFirestore.instance.collection('tasks').where('status', isEqualTo: 'open').limit(20).get();
      if (tasksSnapshot.docs.isEmpty) return [];

      final tasksList = tasksSnapshot.docs.map((doc) => "ID: ${doc.id}, Title: ${doc.data()['title']}, Description: ${doc.data()['description']}, Budget: LKR ${doc.data()['budget']}").join("\n---\n");
      final prompt = 'You are an expert recruiter. Based on this Helper Profile: \n"$helperProfile"\n\nWhich of the following tasks are the best matches? Return ONLY a comma-separated list of the best matching task IDs. For example: id1,id2,id3.';
      final responseText = await AiService.generateTaskDescription(prompt);
      if (responseText == null || responseText.isEmpty) return [];

      final recommendedIds = responseText.split(',').where((id) => id.isNotEmpty).toList();
      if (recommendedIds.isEmpty) return [];

      final recommendedTasksSnapshot = await FirebaseFirestore.instance.collection('tasks').where(FieldPath.documentId, whereIn: recommendedIds).get();
      return recommendedTasksSnapshot.docs.map((doc) => Task.fromFirestore(doc)).toList();
    } catch (e) {
      print("Error fetching AI recommendations for helper: $e");
      return [];
    }
  }

  Future<List<HelpifyUser>> _fetchAIRecommendationsForPoster(HelpifyUser user) async {
    try {
      final tasksSnapshot = await FirebaseFirestore.instance.collection('tasks').where('posterId', isEqualTo: user.id).orderBy('timestamp', descending: true).limit(5).get();
      if (tasksSnapshot.docs.isEmpty) return [];

      final userTaskHistory = tasksSnapshot.docs.map((doc) => "Category: ${doc.data()['category']}, Title: ${doc.data()['title']}").join("\n");
      final helpersSnapshot = await FirebaseFirestore.instance.collection('users').where('isHelper', isEqualTo: true).limit(20).get();
      if (helpersSnapshot.docs.isEmpty) return [];

      final helpersList = helpersSnapshot.docs.map((doc) => "ID: ${doc.id}, Name: ${doc.data()['displayName']}, Skills: ${(doc.data()['skills'] as List?)?.join(', ')}, Bio: ${doc.data()['bio']}").join("\n---\n");
      final prompt = 'A user has this task posting history: \n"$userTaskHistory"\n\nBased on their past tasks, which of the following helpers would be the best recommendations for their NEXT task? Return ONLY a comma-separated list of the best matching helper IDs. For example: id1,id2,id3.';
      final responseText = await AiService.generateTaskDescription(prompt);
      if (responseText == null || responseText.isEmpty) return [];

      final ids = responseText.split(',').where((id) => id.isNotEmpty).toList();
      if (ids.isEmpty) return [];

      final recommendedUsersSnapshot = await FirebaseFirestore.instance.collection('users').where(FieldPath.documentId, whereIn: ids).get();
      return recommendedUsersSnapshot.docs.map((doc) => HelpifyUser.fromFirestore(doc)).toList();
    } catch (e) {
      print("Error fetching AI recommendations for poster: $e");
      return [];
    }
  }

  void _showUrgentTaskDialog() {
    showDialog(context: context, builder: (ctx) => const UrgentTaskDialog());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Helpify', style: theme.textTheme.headlineSmall?.copyWith(color: theme.primaryColor, fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: RefreshIndicator(
        onRefresh: _loadInitialData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              _buildModeToggle(theme),
              const SizedBox(height: 24),
              _buildHeroSection(theme),
              const SizedBox(height: 24),
              Text("Popular Categories", style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              CategoryGridView(
                onCategoryTap: (category) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => BrowseScreen(initialCategory: category)));
                },
              ),
              const SizedBox(height: 24),
              Text( _currentMode == AppMode.poster ? "Featured Helpers" : "Recommended Tasks", style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              _buildRecommendations(theme),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showUrgentTaskDialog,
        label: const Text('Urgent'),
        icon: const Icon(Icons.flash_on_rounded),
        backgroundColor: theme.colorScheme.tertiary,
        foregroundColor: Colors.black,
      ),
    );
  }

  Widget _buildModeToggle(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(50),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(5.0),
      child: Stack(
        children: [
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) => Align(
              alignment: _alignAnimation.value,
              child: Container(
                height: 48,
                width: (MediaQuery.of(context).size.width - 42) / 2,
                decoration: BoxDecoration(color: _colorAnimation.value, borderRadius: BorderRadius.circular(50)),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(child: GestureDetector(onTap: _currentMode == AppMode.helper ? _toggleMode : null, behavior: HitTestBehavior.opaque, child: Container(height: 48, alignment: Alignment.center, child: Text('I Need Help', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))))),
              Expanded(child: GestureDetector(onTap: _currentMode == AppMode.poster ? _toggleMode : null, behavior: HitTestBehavior.opaque, child: Container(height: 48, alignment: Alignment.center, child: Text('I Can Help', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection(ThemeData theme) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
      child: _currentMode == AppMode.poster
          ? _posterHeroSection(theme, key: const ValueKey("posterHero"))
          : _helperHeroSection(theme, key: const ValueKey("helperHero")),
    );
  }

  Widget _posterHeroSection(ThemeData theme, {Key? key}) {
    return Column(key: key, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Get Anything Done,\nFast & Easy.', style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
      const SizedBox(height: 12),
      ElevatedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PostTaskScreen())), icon: const Icon(Icons.add), label: const Text('Post a New Task')),
    ]);
  }

  Widget _helperHeroSection(ThemeData theme, {Key? key}) {
    return Column(key: key, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Your Skills,\nYour Earnings.', style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.secondary)),
      const SizedBox(height: 12),
      ElevatedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BrowseScreen())), icon: const Icon(Icons.search), label: const Text('Browse Available Tasks')),
    ]);
  }

  Widget _buildPosterContent(ThemeData theme) {
    return _buildRecommendations(theme);
  }

  Widget _buildHelperContent(ThemeData theme) {
    return _buildRecommendations(theme);
  }

  Widget _buildRecommendations(ThemeData theme) {
    return FutureBuilder<List<dynamic>>(
      future: _recommendationsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: Padding(padding: EdgeInsets.all(32.0), child: CircularProgressIndicator()));
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const Card(child: Padding(padding: EdgeInsets.all(20.0), child: Center(child: Text("No recommendations available right now."))));
        }
        final items = snapshot.data!;
        return SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              if (item is Task) return _buildRecommendedTaskCard(item, theme);
              if (item is HelpifyUser) return _buildRecommendedHelperCard(item, theme);
              return const SizedBox.shrink();
            },
          ),
        );
      },
    );
  }

  Widget _buildRecommendedTaskCard(Task task, ThemeData theme) {
    return SizedBox(
      width: 220,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TaskDetailsScreen(task: task))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if(task.imageUrl != null)
                Image.network(task.imageUrl!, height: 80, width: double.infinity, fit: BoxFit.cover, errorBuilder: (c, o, s) => Container(height: 80, color: theme.colorScheme.secondaryContainer, child: const Center(child: Icon(Icons.work_outline))))
              else
                Container(height: 80, color: theme.colorScheme.secondaryContainer, child: const Center(child: Icon(Icons.work_outline))),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(task.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text('LKR ${NumberFormat("#,##0").format(task.budget)}', style: theme.textTheme.titleMedium?.copyWith(color: theme.primaryColor, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildRecommendedHelperCard(HelpifyUser helper, ThemeData theme) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: helper.id))),
        child: Container(
            width: 150,
            padding: const EdgeInsets.all(12),
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(radius: 35, backgroundImage: helper.photoURL != null ? NetworkImage(helper.photoURL!) : null, child: helper.photoURL == null ? const Icon(Icons.person) : null),
                  const SizedBox(height: 12),
                  Text(helper.displayName ?? '', textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(helper.skills.isNotEmpty ? helper.skills.first : "Skilled Helper", style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis)
                ]
            )
        ),
      ),
    );
  }

  void _showVerificationPopup(String title, String message) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text(title), content: Text(message),
      actions: [
        TextButton(child: const Text('Later'), onPressed: () => Navigator.of(ctx).pop()),
        ElevatedButton(
          child: const Text('Start Verification'),
          onPressed: () {
            Navigator.of(ctx).pop();
            Navigator.push(context, MaterialPageRoute(builder: (_) => const VerificationCenterScreen()));
          },
        ),
      ],
    ));
  }

  void _showStatusDialog(String title, String message) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text(title), content: Text(message),
      actions: [ElevatedButton(child: const Text('OK'), onPressed: () => Navigator.of(ctx).pop())],
    ));
  }
}

class UrgentTaskDialog extends StatefulWidget {
  const UrgentTaskDialog({super.key});
  @override
  State<UrgentTaskDialog> createState() => _UrgentTaskDialogState();
}

class _UrgentTaskDialogState extends State<UrgentTaskDialog> {
  final _titleController = TextEditingController();
  GeoPoint? _currentLocation;
  String _currentAddress = "Fetching location...";
  bool _isLocating = true;
  bool _isPosting = false;

  @override
  void initState() {
    super.initState();
    _fetchCurrentLocation();
  }

  Future<void> _fetchCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('Location services are disabled.');
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw Exception('Location permissions are denied');
      }
      if (permission == LocationPermission.deniedForever) throw Exception('Location permissions are permanently denied.');

      final position = await Geolocator.getCurrentPosition();
      final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (mounted) {
        setState(() {
          _currentLocation = GeoPoint(position.latitude, position.longitude);
          _currentAddress = placemarks.isNotEmpty ? (placemarks.first.street ?? placemarks.first.name ?? 'Unknown Location') : 'Unknown Location';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _currentAddress = "Could not get location.");
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _postUrgentTask() async {
    if (_titleController.text.trim().isEmpty || _currentLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all fields.")));
      return;
    }
    setState(() => _isPosting = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isPosting = false);
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('tasks').add({
        'title': _titleController.text.trim(),
        'description': 'URGENT TASK',
        'category': 'Urgent',
        'isUrgent': true,
        'budget': 0.0,
        'location': _currentLocation,
        'locationAddress': _currentAddress,
        'status': 'open',
        'posterId': user.uid,
        'posterName': user.displayName ?? 'Helpify User',
        'posterAvatarUrl': user.photoURL,
        'timestamp': FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Urgent task posted!"), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Post an Urgent Task"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _titleController, decoration: const InputDecoration(labelText: "Task Title")),
          const SizedBox(height: 16),
          Row(children: [
            const Icon(Icons.location_on),
            const SizedBox(width: 8),
            Expanded(child: Text(_currentAddress)),
            if (_isLocating) const Padding(padding: EdgeInsets.only(left: 8.0), child: SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))),
          ]),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancel")),
        ElevatedButton(onPressed: _isPosting || _isLocating ? null : _postUrgentTask, child: const Text("Post Now")),
      ],
    );
  }
}
