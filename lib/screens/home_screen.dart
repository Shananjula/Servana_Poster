import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:servana/models/task_model.dart';
import 'package:servana/providers/user_provider.dart';
import 'package:servana/screens/browse_screen.dart';
import 'package:servana/screens/post_task_screen.dart';
import 'package:servana/screens/profile_screen.dart';
import 'package:servana/screens/activity_screen.dart';
import 'package:flutter/services.dart';
import 'package:servana/screens/notifications_screen.dart';
import 'package:servana/screens/chat_list_screen.dart';
import 'package:servana/widgets/category_grid_view.dart';
import 'package:servana/widgets/ai_recommendation_section.dart';
import 'package:servana/dialogs/urgent_task_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';

// --- Main Home Screen Logic (Unchanged) ---
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
    final userProvider = context.watch<UserProvider>();
    final isRegisteredHelper = userProvider.user?.isHelper ?? false;
    final activeMode = userProvider.activeMode;
    final bool useHelperUI = isRegisteredHelper && activeMode == AppMode.helper;

    final List<Widget> posterScreens = [
      const _PosterDashboardView(),
      const BrowseScreen(key: ValueKey('poster_browse')),
      const ActivityScreen(),
      const ProfileScreen(),
    ];
    const List<BottomNavigationBarItem> posterNavItems = [
      BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
      BottomNavigationBarItem(icon: Icon(Icons.search_outlined), label: 'Find Help'),
      BottomNavigationBarItem(icon: Icon(Icons.list_alt_rounded), label: 'My Tasks'),
      BottomNavigationBarItem(icon: Icon(Icons.person_outline_rounded), label: 'Profile'),
    ];

    final List<Widget> helperScreens = [
      const PremiumHelperDashboard(),
      const BrowseScreen(key: ValueKey('helper_browse')),
      const ActivityScreen(),
      const ProfileScreen(),
    ];
    const List<BottomNavigationBarItem> helperNavItems = [
      BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
      BottomNavigationBarItem(icon: Icon(Icons.work_outline_rounded), label: 'Find Work'),
      BottomNavigationBarItem(icon: Icon(Icons.assignment_turned_in_outlined), label: 'My Jobs'),
      BottomNavigationBarItem(icon: Icon(Icons.person_outline_rounded), label: 'Profile'),
    ];

    final screens = useHelperUI ? helperScreens : posterScreens;
    final navItems = useHelperUI ? helperNavItems : posterNavItems;

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

// =========================================================================
// --- PREMIUM HELPER DASHBOARD (Polished UI & Layout Fixed) ---
// =========================================================================
class PremiumHelperDashboard extends StatelessWidget {
  const PremiumHelperDashboard({super.key});

  TextStyle _getTextStyle(
      {double fontSize = 16,
        FontWeight fontWeight = FontWeight.normal,
        Color color = Colors.white,
        double letterSpacing = 0.5}) {
    return GoogleFonts.poppins(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      shadows: [
        Shadow(
          color: Colors.black.withOpacity(0.25),
          offset: const Offset(0, 1),
          blurRadius: 4,
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF005C97), Color(0xFF363795)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                systemOverlayStyle: SystemUiOverlayStyle.light,
                title: Text(
                  'Welcome, ${user.displayName ?? 'Helper'}!',
                  style: _getTextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                actions: [
                  _buildGlassmorphicIconButton(
                    context,
                    icon: Icons.chat_bubble_outline_rounded,
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChatListScreen())),
                  ),
                  _buildGlassmorphicIconButton(
                    context,
                    icon: Icons.notifications_outlined,
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen())),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      _buildSectionTitle("At a Glance"),
                      const SizedBox(height: 16),
                      _buildStatsCarousel(),
                      const SizedBox(height: 32),
                      _buildGamificationCard(),
                      const SizedBox(height: 32),
                      _buildSectionTitle("My Skill Categories"),
                      const SizedBox(height: 16),
                      _buildSkillsCarousel(context, user.skills),
                      const SizedBox(height: 32),
                      _buildSectionTitle("Recommended For You"),
                      const SizedBox(height: 16),
                      _buildRecommendedTasksSection(user.skills),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ).animate().fadeIn(duration: 500.ms),
        ],
      ),
    );
  }

  Widget _buildGlassmorphicIconButton(BuildContext context, {required IconData icon, required VoidCallback onPressed}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          margin: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: IconButton(
            icon: Icon(icon, color: Colors.white),
            onPressed: onPressed,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: _getTextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white.withOpacity(0.9)),
    ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.2);
  }

  Widget _buildStatsCarousel() {
    final stats = [
      {'icon': Icons.inbox_rounded, 'value': '3', 'label': 'New Invites', 'color': Colors.amber.shade300},
      {'icon': Icons.construction_rounded, 'value': '2', 'label': 'Active Jobs', 'color': Colors.lightBlueAccent.shade100},
      {'icon': Icons.assignment_turned_in_rounded, 'value': '12', 'label': 'Completed', 'color': Colors.greenAccent.shade200},
    ];

    return SizedBox(
      height: 130,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: stats.length,
        itemBuilder: (context, index) {
          final stat = stats[index];
          return _GlassmorphicCard(
            width: 130,
            margin: const EdgeInsets.only(right: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(stat['icon'] as IconData, color: stat['color'] as Color, size: 32),
                const SizedBox(height: 8),
                Text(
                  stat['value'] as String,
                  style: _getTextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                // FINAL FIX: Use Expanded and FittedBox to ensure text never overflows.
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      stat['label'] as String,
                      style: _getTextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8)),
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: (300 + index * 100).ms).slideX(begin: -0.5);
        },
      ),
    );
  }

  Widget _buildGamificationCard() {
    const double weeklyGoal = 25000.0;
    const double currentEarnings = 18500.0;
    final double progress = (currentEarnings / weeklyGoal).clamp(0.0, 1.0);

    return _GlassmorphicCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Weekly Goal", style: _getTextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  "You're ${((1 - progress) * 100).toStringAsFixed(0)}% away from your goal of LKR ${weeklyGoal.toStringAsFixed(0)}!",
                  style: _getTextStyle(fontSize: 14, color: Colors.white.withOpacity(0.8)).copyWith(height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 8,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                ),
                Center(
                  child: Text(
                    "${(progress * 100).toStringAsFixed(0)}%",
                    style: _getTextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.5);
  }

  Widget _buildSkillsCarousel(BuildContext context, List<String> skills) {
    if (skills.isEmpty) {
      return _GlassmorphicCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24.0),
          child: Column(
            children: [
              const Icon(Icons.add_circle_outline, size: 40, color: Colors.white70),
              const SizedBox(height: 16),
              Text("Add skills to find jobs!", style: _getTextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                "Go to your profile to add the services you offer.",
                textAlign: TextAlign.center,
                style: _getTextStyle(fontSize: 14, color: Colors.white.withOpacity(0.7)),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 130,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: skills.length,
        itemBuilder: (context, index) {
          final skill = skills[index];
          return GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BrowseScreen(initialCategory: skill))),
            child: _GlassmorphicCard(
              width: 120,
              margin: const EdgeInsets.only(right: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_getIconForCategory(skill), color: Colors.white, size: 40),
                  const SizedBox(height: 16),
                  Text(
                    skill,
                    textAlign: TextAlign.center,
                    style: _getTextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(delay: (600 + index * 100).ms).slideX(begin: -0.5);
        },
      ),
    );
  }

  Widget _buildRecommendedTasksSection(List<String> skills) {
    if (skills.isEmpty) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('tasks')
          .where('category', whereIn: skills)
          .where('status', isEqualTo: 'open')
          .orderBy('timestamp', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.white));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _GlassmorphicCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.task_alt_rounded, color: Colors.white70, size: 30),
                  const SizedBox(width: 16),
                  Text(
                    "No new tasks match your skills.",
                    style: _getTextStyle(color: Colors.white.withOpacity(0.8)),
                  ),
                ],
              ),
            ),
          );
        }
        final tasks = snapshot.data!.docs.map((doc) => Task.fromFirestore(doc)).toList();
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            return _PremiumTaskCard(task: tasks[index])
                .animate()
                .fadeIn(delay: (800 + index * 100).ms)
                .slideY(begin: 0.5);
          },
        );
      },
    );
  }

  IconData _getIconForCategory(String categoryName) {
    switch (categoryName.toLowerCase()) {
      case 'home tutor': return Icons.menu_book_rounded;
      case 'rider': return Icons.delivery_dining_rounded;
      case 'cleaning': return Icons.cleaning_services_rounded;
      case 'handyman': return Icons.build_circle_outlined;
      case 'moving': return Icons.local_shipping_outlined;
      case 'gardening': return Icons.yard_outlined;
      case 'appliance': return Icons.electrical_services_rounded;
      case 'assembly': return Icons.add_box_outlined;
      case 'home repair & maintenance': return Icons.home_repair_service_rounded;
      case 'pick up driver': return Icons.airport_shuttle_rounded;
      case 'cleaner': return Icons.clean_hands_rounded;
      default: return Icons.work_outline_rounded;
    }
  }
}

// --- GLASSMORPHIC CARD WIDGET ---
class _GlassmorphicCard extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry margin;

  const _GlassmorphicCard({
    required this.child,
    this.width,
    this.height,
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          width: width,
          height: height,
          margin: margin,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: child,
        ),
      ),
    );
  }
}

// --- PREMIUM TASK CARD WIDGET ---
class _PremiumTaskCard extends StatelessWidget {
  final Task task;
  const _PremiumTaskCard({required this.task});

  TextStyle _getTextStyle(
      {double fontSize = 16,
        FontWeight fontWeight = FontWeight.normal,
        Color color = Colors.white,
        double letterSpacing = 0.5}) {
    return GoogleFonts.poppins(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      shadows: [
        Shadow(
          color: Colors.black.withOpacity(0.25),
          offset: const Offset(0, 1),
          blurRadius: 4,
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return _GlassmorphicCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            task.title,
            style: _getTextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.pin_drop_outlined, size: 16, color: Colors.white.withOpacity(0.7)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  task.locationAddress ?? 'Online',
                  style: _getTextStyle(fontSize: 14, color: Colors.white.withOpacity(0.8)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Chip(
                label: Text(task.category),
                backgroundColor: Colors.white.withOpacity(0.2),
                labelStyle: _getTextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                side: BorderSide.none,
              ),
              Text(
                "LKR ${task.budget.toStringAsFixed(0)}",
                style: _getTextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.greenAccent.shade200),
              ),
            ],
          )
        ],
      ),
    );
  }
}

// =========================================================================
// --- ORIGINAL POSTER DASHBOARD (UNCHANGED) ---
// =========================================================================
class _PosterDashboardView extends StatefulWidget {
  const _PosterDashboardView();

  @override
  State<_PosterDashboardView> createState() => _PosterDashboardViewState();
}

class _PosterDashboardViewState extends State<_PosterDashboardView> {
  TaskMode _currentTaskMode = TaskMode.physical;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Servana', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChatListScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen())),
          ),
          const SizedBox(width: 8),
        ],
      ),
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        onRefresh: () async => setState(() {}),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Text(
                'Get Anything Done,\nFast & Easy.',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A252D),
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PostTaskScreen())),
                icon: const Icon(Icons.add),
                label: const Text('Post a New Task', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
              ),
              const SizedBox(height: 32),
              _buildTaskModeToggle(theme),
              const SizedBox(height: 32),
              Text("Popular Categories", style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              CategoryGridView(
                key: ValueKey(_currentTaskMode),
                taskMode: _currentTaskMode,
                onCategoryTap: (category) => Navigator.push(context, MaterialPageRoute(builder: (_) => BrowseScreen(initialCategory: category))),
              ),
              const SizedBox(height: 32),
              Text("Featured Helpers", style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              if (user != null) AiRecommendationSection(user: user),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDialog(context: context, builder: (ctx) => const UrgentTaskDialog()),
        label: const Text('Urgent Task'),
        icon: const Icon(Icons.flash_on_rounded),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  Widget _buildTaskModeToggle(ThemeData theme) {
    return SegmentedButton<TaskMode>(
      style: SegmentedButton.styleFrom(fixedSize: const Size.fromHeight(50)),
      segments: const <ButtonSegment<TaskMode>>[
        ButtonSegment(value: TaskMode.physical, label: Text('Physical'), icon: Icon(Icons.location_on_outlined)),
        ButtonSegment(value: TaskMode.online, label: Text('Online'), icon: Icon(Icons.language)),
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
