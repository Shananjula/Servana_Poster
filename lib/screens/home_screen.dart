import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:helpify/models/user_model.dart';
import 'package:helpify/providers/user_provider.dart';
import 'package:helpify/screens/browse_screen.dart';
import 'package:helpify/screens/post_task_screen.dart';
import 'package:helpify/screens/profile_screen.dart';
import 'package:helpify/screens/activity_screen.dart';
import 'package:helpify/screens/helper_discovery_screen.dart';
import 'package:helpify/screens/verification_center_screen.dart';
import 'package:helpify/widgets/category_grid_view.dart';
import 'package:helpify/widgets/ai_recommendation_section.dart';
import 'package:helpify/dialogs/urgent_task_dialog.dart';

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
    HelperDiscoveryScreen(),
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
          BottomNavigationBarItem(icon: Icon(Icons.search_outlined), label: 'Browse Tasks'),
          BottomNavigationBarItem(icon: Icon(Icons.people_alt_outlined), label: 'Find Helpers'),
          BottomNavigationBarItem(icon: Icon(Icons.list_alt_rounded), label: 'Activity'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline_rounded), label: 'Profile'),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

enum AppMode { poster, helper }

class _HomeDashboardView extends StatefulWidget {
  const _HomeDashboardView();

  @override
  State<_HomeDashboardView> createState() => _HomeDashboardViewState();
}

class _HomeDashboardViewState extends State<_HomeDashboardView> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<AlignmentGeometry> _alignAnimation;
  AppMode _currentMode = AppMode.poster;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _alignAnimation = AlignmentTween(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleMode(HelpifyUser? user) {
    if (user == null) return;
    if (_currentMode == AppMode.poster) {
      if (user.isHelper != true) {
        _showVerificationPopup();
        return;
      }
      setState(() {
        _currentMode = AppMode.helper;
        _animationController.forward();
      });
    } else {
      setState(() {
        _currentMode = AppMode.poster;
        _animationController.reverse();
      });
    }
  }

  void _setHelperLiveStatus(bool isLive, HelpifyUser user) {
    FirebaseFirestore.instance.collection('users').doc(user.id).update({'isLive': isLive});
  }

  void _showVerificationPopup() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Become a Helper'),
      content: const Text('To start offering your services and accept tasks, you need to complete our one-time verification.'),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          if (user != null && user.isHelper == true && _currentMode == AppMode.helper)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Row(
                children: [
                  const Text("Go Live"),
                  Switch(
                    value: user.isLive,
                    onChanged: (value) => _setHelperLiveStatus(value, user),
                    activeTrackColor: Colors.greenAccent,
                    activeColor: Colors.green,
                  ),
                ],
              ),
            )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => setState(() {}),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildModeToggle(theme, user),
              const SizedBox(height: 24),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                child: _currentMode == AppMode.poster
                    ? _posterHeroSection(theme, key: const ValueKey("poster"))
                    : _helperHeroSection(theme, key: const ValueKey("helper")),
              ),
              const SizedBox(height: 24),
              Text("Popular Categories", style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              CategoryGridView(
                onCategoryTap: (category) => Navigator.push(context, MaterialPageRoute(builder: (_) => BrowseScreen(initialCategory: category))),
              ),
              const SizedBox(height: 24),
              Text( _currentMode == AppMode.poster ? "Featured Helpers" : "Recommended Tasks", style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              if(user != null)
                AiRecommendationSection(
                  key: ValueKey(_currentMode),
                  currentMode: _currentMode,
                  user: user,
                )
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDialog(context: context, builder: (ctx) => const UrgentTaskDialog()),
        label: const Text('Urgent Task'),
        icon: const Icon(Icons.flash_on_rounded),
      ),
    );
  }

  Widget _buildModeToggle(ThemeData theme, HelpifyUser? user) {
    return GestureDetector(
      onTap: () => _toggleMode(user),
      child: Container(
        height: 58,
        decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(50), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
        padding: const EdgeInsets.all(5.0),
        child: Stack(
          children: [
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) => Align(
                alignment: _alignAnimation.value,
                child: Container(
                  height: 48, width: (MediaQuery.of(context).size.width - 42) / 2,
                  decoration: BoxDecoration(color: theme.primaryColor.withOpacity(0.15), borderRadius: BorderRadius.circular(50)),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(child: Container(height: 48, alignment: Alignment.center, child: Text('I Need Help', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)))),
                Expanded(child: Container(height: 48, alignment: Alignment.center, child: Text('I Can Help', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _posterHeroSection(ThemeData theme, {Key? key}) {
    return Column(key: key, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Get Anything Done,\nFast & Easy.', style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
      const SizedBox(height: 12),
      ElevatedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PostTaskScreen())), icon: const Icon(Icons.add_circle_outline), label: const Text('Post a New Task')),
    ]);
  }

  Widget _helperHeroSection(ThemeData theme, {Key? key}) {
    return Column(key: key, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Your Skills,\nYour Earnings.', style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.secondary)),
      const SizedBox(height: 12),
      ElevatedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BrowseScreen())), icon: const Icon(Icons.search), label: const Text('Browse Available Tasks')),
    ]);
  }
}
