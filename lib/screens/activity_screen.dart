import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:helpify/models/task_model.dart';
import 'package:helpify/widgets/empty_state_widget.dart';
import 'package:intl/intl.dart';
import 'active_task_screen.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
          appBar: AppBar(title: const Text("My Activity")),
          body: const Center(child: Text("Please log in to see your activity.")));
    }

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Your Activities'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Ongoing'),
              Tab(text: 'Completed'),
              Tab(text: 'Cancelled'),
              Tab(text: 'Disputes'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ActivityList(userId: user.uid, statuses: const ['assigned', 'in_progress', 'finished']),
            _ActivityList(userId: user.uid, statuses: const ['completed', 'rated']),
            _ActivityList(userId: user.uid, statuses: const ['cancelled']),
            const EmptyStateWidget(icon: Icons.gavel, title: "No Disputes", message: "Issues with tasks will appear here.")
          ],
        ),
      ),
    );
  }
}

class _ActivityList extends StatelessWidget {
  final String userId;
  final List<String> statuses;

  const _ActivityList({required this.userId, required this.statuses});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tasks')
          .where('participantIds', arrayContains: userId)
          .where('status', whereIn: statuses)
          .orderBy('timestamp', descending: true)
          .snapshots(),
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

        final tasks = snapshot.data!.docs
            .map((doc) => Task.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
            .toList();

        return ListView.builder(
          padding: const EdgeInsets.all(8.0),
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            return TaskActivityCard(task: tasks[index], currentUserId: userId);
          },
        );
      },
    );
  }
}

class TaskActivityCard extends StatelessWidget {
  final Task task;
  final String currentUserId;
  const TaskActivityCard({super.key, required this.task, required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    final bool isMyTaskAsPoster = task.posterId == currentUserId;
    final String role = isMyTaskAsPoster ? "You are the Poster" : "You are the Helper";
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: ListTile(
        title: Text(task.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(role),
        trailing: Text(
          'LKR ${NumberFormat('#,##0').format(task.finalAmount ?? task.budget)}',
          style: TextStyle(fontWeight: FontWeight.bold, color: theme.primaryColor, fontSize: 16),
        ),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => ActiveTaskScreen(initialTask: task)));
        },
      ),
    );
  }
}
