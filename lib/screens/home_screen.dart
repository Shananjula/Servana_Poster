// home_screen.dart - CORRECTED

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:servana/providers/user_provider.dart';
import 'package:servana/screens/browse_screen.dart';
import 'package:servana/screens/post_task_screen.dart';
import 'package:servana/screens/profile_screen.dart';
import 'package:servana/screens/activity_screen.dart';
// --- NEW: Import the screens we want to navigate to ---
import 'package:servana/screens/notifications_screen.dart';
import 'package:servana/screens/chat_list_screen.dart';
import 'package:servana/widgets/category_grid_view.dart';
import 'package:servana/widgets/ai_recommendation_section.dart';
import 'package:servana/dialogs/urgent_task_dialog.dart';

// FIX: Moved the enum definition to the top of the file
enum TaskMode { physical, online }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Listen to the provider to get the current mode and user role
    final userProvider = context.watch<UserProvider>();
    final isRegisteredHelper = userProvider.user?.isHelper ?? false;
    final activeMode = userProvider.activeMode;

    // --- Define UI components for Poster Mode ---
    const List<Widget> posterScreens = [
      _HomeDashboardView(), // Home dashboard
      BrowseScreen(key: ValueKey('poster_browse')), // Shows Services
      ActivityScreen(), // Shows tasks the user has posted
      ProfileScreen(),
    ];
    const List<BottomNavigationBarItem> posterNavItems = [
      BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
      BottomNavigationBarItem(icon: Icon(Icons.search_outlined), label: 'Find Help'),
      BottomNavigationBarItem(icon: Icon(Icons.list_alt_rounded), label: 'My Tasks'),
      BottomNavigationBarItem(icon: Icon(Icons.person_outline_rounded), label: 'Profile'),
    ];

    // --- Define UI components for Helper Mode ---
    const List<Widget> helperScreens = [
      _HomeDashboardView(), // Can be customized for helpers later
      BrowseScreen(key: ValueKey('helper_browse')), // Shows Tasks
      ActivityScreen(), // Shows tasks the helper has bid on/is doing
      ProfileScreen(),
    ];
    const List<BottomNavigationBarItem> helperNavItems = [
      BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
      BottomNavigationBarItem(icon: Icon(Icons.work_outline_rounded), label: 'Find Work'),
      BottomNavigationBarItem(icon: Icon(Icons.list_alt_rounded), label: 'My Jobs'),
      BottomNavigationBarItem(icon: Icon(Icons.person_outline_rounded), label: 'Profile'),
    ];

    // --- Determine which UI set to use based on the active mode ---
    final bool useHelperUI = isRegisteredHelper && activeMode == AppMode.helper;
    final screens = useHelperUI ? helperScreens : posterScreens;
    final navItems = useHelperUI ? helperNavItems : posterNavItems;

    // Ensure selectedIndex is valid if the number of tabs changes
    if (_selectedIndex >= screens.length) {
      _selectedIndex = 0;
    }

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: navItems,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}


// The Home Dashboard View can also be made mode-aware in the future
class _HomeDashboardView extends StatefulWidget {
  const _HomeDashboardView();

  @override
  State<_HomeDashboardView> createState() => _HomeDashboardViewState();
}
// In home_screen.dart, replace the existing _HomeDashboardViewState class

class _HomeDashboardViewState extends State<_HomeDashboardView> {
  TaskMode _currentTaskMode = TaskMode.physical;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.user;

    // Determine if we are in Helper mode
    final bool isHelperMode = userProvider.activeMode == AppMode.helper;

    // UI/UX: Define a new primary color for this screen
    final Color primaryColor = Colors.teal; // A more professional and modern color

    return Scaffold(
      // --- MODIFIED: Simplified AppBar with new action icons ---
      appBar: AppBar(
        title: Text(isHelperMode ? 'Helper Dashboard' : 'Servana', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0, // A flatter, more modern look
        // --- NEW: Action Icons for Chat & Notifications ---
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            onPressed: () {
              // Navigate to the Chat List Screen
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChatListScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              // Navigate to the Notifications Screen
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
            },
          ),
          const SizedBox(width: 8), // Add a little spacing
        ],
      ),
      backgroundColor: Colors.white, // Set a clean background
      body: RefreshIndicator(
        onRefresh: () async => setState(() {}),
        child: SingleChildScrollView(
          // UI/UX: Use symmetric padding for better balance
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16), // Add space at the top
              // UI/UX: More impactful headline
              Text(
                isHelperMode ? 'Welcome Back, Helper!' : 'Get Anything Done,\nFast & Easy.',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700, // Bolder for more impact
                  color: const Color(0xFF1A252D), // A dark, near-black color
                  height: 1.2, // Improved line spacing
                ),
              ),
              const SizedBox(height: 24),
              // UI/UX: More prominent "Post Task" button
              if (!isHelperMode)
                ElevatedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PostTaskScreen())),
                  icon: const Icon(Icons.add),
                  label: const Text('Post a New Task', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                ),
              const SizedBox(height: 32), // Increased spacing
              _buildTaskModeToggle(theme),
              const SizedBox(height: 32),
              // UI/UX: Cleaner section header
              Text("Popular Categories", style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              CategoryGridView(
                key: ValueKey(_currentTaskMode),
                taskMode: _currentTaskMode,
                onCategoryTap: (category) => Navigator.push(context, MaterialPageRoute(builder: (_) => BrowseScreen(initialCategory: category))),
              ),
              const SizedBox(height: 32),
              Text(
                  isHelperMode ? "Featured Tasks" : "Featured Helpers",
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              if (user != null && !isHelperMode)
                AiRecommendationSection(
                  user: user,
                ),
              const SizedBox(height: 100), // Extra space at the bottom for the FAB
            ],
          ),
        ),
      ),
      // UI/UX: Updated Floating Action Button style
      floatingActionButton: isHelperMode ? null : FloatingActionButton.extended(
        onPressed: () => showDialog(context: context, builder: (ctx) => const UrgentTaskDialog()),
        label: const Text('Urgent Task'),
        icon: const Icon(Icons.flash_on_rounded),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  Widget _buildTaskModeToggle(ThemeData theme) {
    // This widget is fine as is, no changes needed for now
    return SegmentedButton<TaskMode>(
      style: SegmentedButton.styleFrom(
        fixedSize: const Size.fromHeight(50),
      ),
      segments: const <ButtonSegment<TaskMode>>[
        ButtonSegment<TaskMode>(
          value: TaskMode.physical,
          label: Text('Physical'),
          icon: Icon(Icons.location_on_outlined),
        ),
        ButtonSegment<TaskMode>(
          value: TaskMode.online,
          label: Text('Online'),
          icon: Icon(Icons.language),
        ),
      ],
      selected: <TaskMode>{_currentTaskMode},
      onSelectionChanged: (Set<TaskMode> newSelection) {
        setState(() {
          _currentTaskMode = newSelection.first;
        });
      },
    );
  }
}
