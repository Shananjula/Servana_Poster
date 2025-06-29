import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../providers/user_provider.dart';

class SkillQuest {
  final String title;
  final String description;
  final IconData icon;
  final String badgeName;
  final bool Function(HelpifyUser) isCompleted;

  SkillQuest({
    required this.title,
    required this.description,
    required this.icon,
    required this.badgeName,
    required this.isCompleted,
  });
}

class SkillQuestsScreen extends StatelessWidget {
  const SkillQuestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context).user;

    // Define the quests available in the app
    final List<SkillQuest> quests = [
      SkillQuest(
        title: "Reliability Rockstar",
        description: "Complete 10 tasks to show your commitment and reliability.",
        icon: Icons.star_rounded,
        badgeName: "Reliability Rockstar",
        isCompleted: (u) => u.ratingCount >= 10,
      ),
      SkillQuest(
        title: "Top Rated",
        description: "Achieve an average rating of 4.8 or higher after 5 reviews.",
        icon: Icons.thumb_up_alt_rounded,
        badgeName: "Top Rated",
        isCompleted: (u) => u.ratingCount >= 5 && u.averageRating >= 4.8,
      ),
      SkillQuest(
        title: "Community Builder",
        description: "Receive 5 reviews with written feedback.",
        icon: Icons.groups_rounded,
        badgeName: "Community Builder",
        isCompleted: (u) => u.ratingCount >= 5, // This is a simplified check
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Skill Quests & Badges'),
      ),
      body: user == null
          ? const Center(child: Text("Please log in to see your quests."))
          : ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: quests.length,
        itemBuilder: (context, index) {
          final quest = quests[index];
          final bool isCompleted = quest.isCompleted(user);
          return QuestCard(
            quest: quest,
            isCompleted: isCompleted,
          );
        },
      ),
    );
  }
}

class QuestCard extends StatelessWidget {
  final SkillQuest quest;
  final bool isCompleted;

  const QuestCard({super.key, required this.quest, required this.isCompleted});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: isCompleted ? Colors.green.shade50 : Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
              color: isCompleted ? Colors.green.shade200 : Colors.grey.shade200,
              width: 1.5
          )
      ),
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(quest.icon, size: 40, color: isCompleted ? Colors.green : theme.primaryColor),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(quest.title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(quest.description, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600])),
                ],
              ),
            ),
            const SizedBox(width: 16),
            if(isCompleted)
              const Icon(Icons.check_circle, color: Colors.green, size: 30)
            else
              const Icon(Icons.lock_outline, color: Colors.grey, size: 30),
          ],
        ),
      ),
    );
  }
}
