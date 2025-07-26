import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:servana/models/task_model.dart';
import 'package:servana/models/user_model.dart';
import 'package:servana/providers/user_provider.dart';
import 'package:servana/widgets/empty_state_widget.dart';
import 'package:intl/intl.dart';
import 'active_task_screen.dart';
import 'manage_offers_screen.dart';
import 'conversation_screen.dart';

enum TaskRole { poster, helper }

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> with TickerProviderStateMixin {
  late TabController _mainTabController;

  // --- UPDATED: Statuses are now grouped more logically ---

  // For Helpers
  final List<String> helperNegotiationStatuses = ['negotiating'];
  final List<String> helperOngoingStatuses = ['assigned', 'en_route', 'arrived', 'in_progress', 'pending_completion', 'pending_payment', 'pending_rating'];

  // For Posters
  final List<String> posterOpenStatuses = ['open', 'negotiating'];
  final List<String> posterInProgressStatuses = ['assigned', 'en_route', 'arrived', 'in_progress', 'pending_completion', 'pending_payment', 'pending_rating'];

  // Common Statuses
  final List<String> completedStatuses = ['closed', 'rated'];
  final List<String> cancelledStatuses = ['cancelled'];
  final List<String> disputeStatuses = ['in_dispute'];

  @override
  void initState() {
    super.initState();
    _mainTabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _mainTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final HelpifyUser? currentUser = userProvider.user;
    final User? firebaseUser = FirebaseAuth.instance.currentUser;

    if (firebaseUser == null || currentUser == null) {
      return Scaffold(
          appBar: AppBar(title: const Text("My Tasks")),
          body: const Center(child: Text("Please log in to see your activity.")));
    }

    if (currentUser.isHelper == true) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('My Tasks'),
          bottom: TabBar(
            controller: _mainTabController,
            tabs: const [
              Tab(text: 'I\'m the Poster'),
              Tab(text: 'I\'m the Helper'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _mainTabController,
          children: [
            _RoleSpecificTaskView(
              key: const ValueKey('poster_tasks'),
              userId: firebaseUser.uid,
              role: TaskRole.poster,
              openStatuses: posterOpenStatuses,
              inProgressStatuses: posterInProgressStatuses,
              completedStatuses: completedStatuses,
              cancelledStatuses: cancelledStatuses,
              disputeStatuses: disputeStatuses,
            ),
            _RoleSpecificTaskView(
              key: const ValueKey('helper_jobs'),
              userId: firebaseUser.uid,
              role: TaskRole.helper,
              negotiationStatuses: helperNegotiationStatuses,
              ongoingStatuses: helperOngoingStatuses,
              completedStatuses: completedStatuses,
              cancelledStatuses: cancelledStatuses,
              disputeStatuses: disputeStatuses,
            ),
          ],
        ),
      );
    } else {
      return Scaffold(
        appBar: AppBar(
          title: const Text('My Posted Tasks'),
        ),
        body: _RoleSpecificTaskView(
          userId: firebaseUser.uid,
          role: TaskRole.poster,
          openStatuses: posterOpenStatuses,
          inProgressStatuses: posterInProgressStatuses,
          completedStatuses: completedStatuses,
          cancelledStatuses: cancelledStatuses,
          disputeStatuses: disputeStatuses,
        ),
      );
    }
  }
}

class _RoleSpecificTaskView extends StatelessWidget {
  final String userId;
  final TaskRole role;
  // --- UPDATED: Status lists are now named more clearly based on role ---
  final List<String>? negotiationStatuses; // Nullable for Poster
  final List<String>? ongoingStatuses;     // Nullable for Poster
  final List<String>? openStatuses;        // Nullable for Helper
  final List<String>? inProgressStatuses;  // Nullable for Helper
  final List<String> completedStatuses;
  final List<String> cancelledStatuses;
  final List<String> disputeStatuses;

  const _RoleSpecificTaskView({
    super.key,
    required this.userId,
    required this.role,
    this.negotiationStatuses,
    this.ongoingStatuses,
    this.openStatuses,
    this.inProgressStatuses,
    required this.completedStatuses,
    required this.cancelledStatuses,
    required this.disputeStatuses,
  });

  @override
  Widget build(BuildContext context) {
    // --- DYNAMIC TABS BASED ON ROLE ---
    final List<Tab> tabs = (role == TaskRole.poster)
        ? [
      const Tab(text: 'Open for Offers'),
      const Tab(text: 'In Progress'),
      const Tab(text: 'Completed'),
      const Tab(text: 'Cancelled'),
      const Tab(text: 'Disputes'),
    ]
        : [
      const Tab(text: 'Negotiations'),
      const Tab(text: 'Ongoing Jobs'),
      const Tab(text: 'Completed'),
      const Tab(text: 'Cancelled'),
      const Tab(text: 'Disputes'),
    ];

    final List<Widget> tabViews = (role == TaskRole.poster)
        ? [
      _ActivityList(userId: userId, statuses: openStatuses!, role: role),
      _ActivityList(userId: userId, statuses: inProgressStatuses!, role: role),
      _ActivityList(userId: userId, statuses: completedStatuses, role: role),
      _ActivityList(userId: userId, statuses: cancelledStatuses, role: role),
      _ActivityList(userId: userId, statuses: disputeStatuses, role: role),
    ]
        : [
      _ActivityList(userId: userId, statuses: negotiationStatuses!, role: role),
      _ActivityList(userId: userId, statuses: ongoingStatuses!, role: role),
      _ActivityList(userId: userId, statuses: completedStatuses, role: role),
      _ActivityList(userId: userId, statuses: cancelledStatuses, role: role),
      _ActivityList(userId: userId, statuses: disputeStatuses, role: role),
    ];

    return DefaultTabController(
      length: 5,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            tabs: tabs,
          ),
          Expanded(
            child: TabBarView(
              children: tabViews,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityList extends StatelessWidget {
  final String userId;
  final List<String> statuses;
  final TaskRole role;

  const _ActivityList({required this.userId, required this.statuses, required this.role});

  @override
  Widget build(BuildContext context) {
    if (statuses.isEmpty) {
      return const EmptyStateWidget(icon: Icons.inbox_outlined, title: "Nothing Here", message: "Tasks in this category will appear here.");
    }

    Query query;
    if (role == TaskRole.poster) {
      query = FirebaseFirestore.instance
          .collection('tasks')
          .where('posterId', isEqualTo: userId)
          .where('status', whereIn: statuses);
    } else {
      query = FirebaseFirestore.instance
          .collection('tasks')
          .where('participantIds', arrayContains: userId)
          .where('status', whereIn: statuses);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.orderBy('timestamp', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const EmptyStateWidget(icon: Icons.error, title: "Error", message: "Could not load tasks.");
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return EmptyStateWidget(icon: Icons.inbox_outlined, title: "Nothing Here", message: "Tasks in this category will appear here.");
        }

        var tasks = snapshot.data!.docs
            .map((doc) => Task.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
            .toList();

        if (role == TaskRole.helper) {
          tasks.removeWhere((task) => task.posterId == userId);
        }

        if (tasks.isEmpty) {
          return const EmptyStateWidget(icon: Icons.inbox_outlined, title: "Nothing Here", message: "Tasks in this category will appear here.");
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8.0),
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            return TaskActivityCard(task: tasks[index], currentUserId: userId, role: role);
          },
        );
      },
    );
  }
}

class TaskActivityCard extends StatelessWidget {
  final Task task;
  final String currentUserId;
  final TaskRole role;

  const TaskActivityCard({super.key, required this.task, required this.currentUserId, required this.role});

  @override
  Widget build(BuildContext context) {
    final String roleText = role == TaskRole.poster ? "You are the Poster" : "You are the Helper";
    final theme = Theme.of(context);
    final userProvider = context.read<UserProvider>();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: ListTile(
        title: Text(task.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(roleText),
            const SizedBox(height: 4),
            Chip(
              label: Text(task.status, style: const TextStyle(fontSize: 10)),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
              visualDensity: VisualDensity.compact,
            )
          ],
        ),
        trailing: Text(
          'LKR ${NumberFormat('#,##0').format(task.finalAmount ?? task.budget)}',
          style: TextStyle(fontWeight: FontWeight.bold, color: theme.primaryColor, fontSize: 16),
        ),
        onTap: () {
          if (role == TaskRole.poster && (task.status == 'open' || task.status == 'negotiating')) {
            Navigator.push(context, MaterialPageRoute(
                builder: (_) => ManageOffersScreen(
                  task: task,
                  currentUser: userProvider.user!,
                )
            ));
          } else if (role == TaskRole.helper && task.status == 'negotiating') {
            final List<String> ids = [currentUserId, task.posterId];
            ids.sort();
            final chatChannelId = ids.join('_${task.id}');

            Navigator.push(context, MaterialPageRoute(
              builder: (_) => ConversationScreen(
                chatChannelId: chatChannelId,
                otherUserName: task.posterName,
                otherUserAvatarUrl: task.posterAvatarUrl,
              ),
            ));
          } else {
            Navigator.push(context, MaterialPageRoute(
                builder: (_) => ActiveTaskScreen(taskId: task.id)
            ));
          }
        },
      ),
    );
  }
}
