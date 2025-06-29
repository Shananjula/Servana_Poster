import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:helpify/models/user_model.dart';
import 'package:helpify/models/task_model.dart';
import 'package:helpify/screens/home_screen.dart'; // For AppMode enum
import 'package:helpify/widgets/recommended_task_card.dart';
import 'package:helpify/widgets/recommended_helper_card.dart';

class AiRecommendationSection extends StatefulWidget {
  final AppMode currentMode;
  final HelpifyUser user;

  const AiRecommendationSection({
    super.key,
    required this.currentMode,
    required this.user,
  });

  @override
  State<AiRecommendationSection> createState() => _AiRecommendationSectionState();
}

class _AiRecommendationSectionState extends State<AiRecommendationSection> {
  late Future<List<dynamic>> _recommendationsFuture;

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  // This allows the widget to refresh when the parent calls setState
  @override
  void didUpdateWidget(covariant AiRecommendationSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if(widget.currentMode != oldWidget.currentMode) {
      _loadRecommendations();
    }
  }

  void _loadRecommendations() {
    setState(() {
      _recommendationsFuture = widget.currentMode == AppMode.helper
          ? _fetchAIRecommendationsForHelper(widget.user)
          : _fetchAIRecommendationsForPoster(widget.user);
    });
  }

  Future<List<Task>> _fetchAIRecommendationsForHelper(HelpifyUser helpifyUser) async {
    // In a real app, this would call your AI service to get a list of task IDs
    // For now, we'll fetch the latest tasks as a demonstration
    final tasksSnapshot = await FirebaseFirestore.instance.collection('tasks')
        .where('status', isEqualTo: 'open').limit(10).get();
    return tasksSnapshot.docs.map((doc) => Task.fromFirestore(doc)).toList();
  }

  Future<List<HelpifyUser>> _fetchAIRecommendationsForPoster(HelpifyUser user) async {
    // In a real app, this would call your AI service to get a list of helper IDs
    // For now, it fetches some verified helpers.
    final helpersSnapshot = await FirebaseFirestore.instance.collection('users')
        .where('isHelper', isEqualTo: true)
        .where('verificationStatus', isEqualTo: 'verified')
        .limit(10).get();
    return helpersSnapshot.docs.map((doc) => HelpifyUser.fromFirestore(doc)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _recommendationsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(32.0), child: CircularProgressIndicator()));
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const Card(child: Padding(padding: EdgeInsets.all(20.0), child: Center(child: Text("No recommendations available right now."))));
        }
        final items = snapshot.data!;
        return SizedBox(
          height: 190,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              if (item is Task) return RecommendedTaskCard(task: item);
              if (item is HelpifyUser) return RecommendedHelperCard(helper: item);
              return const SizedBox.shrink();
            },
          ),
        );
      },
    );
  }
}
