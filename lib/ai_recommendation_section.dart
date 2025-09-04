import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:servana/models/user_model.dart';
import 'package:servana/widgets/recommended_helper_card.dart';

class AiRecommendationSection extends StatefulWidget {
  final HelpifyUser user;

  const AiRecommendationSection({
    super.key,
    required this.user,
  });

  @override
  State<AiRecommendationSection> createState() => _AiRecommendationSectionState();
}

class _AiRecommendationSectionState extends State<AiRecommendationSection> {
  late Future<List<HelpifyUser>> _recommendationsFuture;

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  void _loadRecommendations() {
    setState(() {
      _recommendationsFuture = _fetchAIHelperRecommendations(widget.user);
    });
  }

  /// Fetches a list of verified helpers to recommend to the user.
  Future<List<HelpifyUser>> _fetchAIHelperRecommendations(HelpifyUser user) async {
    // In a real app, this would call your AI service to get a list of helper IDs.
    // For now, it fetches some of the latest verified helpers as a demonstration.
    final helpersSnapshot = await FirebaseFirestore.instance.collection('users')
        .where('isHelper', isEqualTo: true)
        .where('verificationStatus', isEqualTo: 'verified')
        .limit(10).get();
    return helpersSnapshot.docs.map((doc) => HelpifyUser.fromFirestore(doc)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<HelpifyUser>>(
      future: _recommendationsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(32.0), child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return const Card(child: Padding(padding: EdgeInsets.all(20.0), child: Center(child: Text("Could not load recommendations."))));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
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
              return RecommendedHelperCard(helper: item);
            },
          ),
        );
      },
    );
  }
}
