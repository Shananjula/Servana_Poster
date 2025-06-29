import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/leaderboard_model.dart';
import '../widgets/empty_state_widget.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("🏆 Helpify Heroes"),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('leaderboards')
            .orderBy('rank', descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.leaderboard_outlined,
              title: 'Leaderboard is Empty',
              message: 'Complete tasks to become a Helpify Hero! The leaderboard updates weekly.',
            );
          }
          final entries = snapshot.data!.docs.map((doc) => LeaderboardEntry.fromFirestore(doc)).toList();

          return ListView.builder(
            itemCount: entries.length,
            itemBuilder: (context, index) {
              return LeaderboardCard(entry: entries[index]);
            },
          );
        },
      ),
    );
  }
}

class LeaderboardCard extends StatelessWidget {
  final LeaderboardEntry entry;
  const LeaderboardCard({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTopThree = entry.rank <= 3;
    final color = isTopThree ? Colors.amber.shade100 : Colors.white;
    final rankIcon = _getRankIcon(entry.rank);

    return Card(
      color: color,
      elevation: isTopThree ? 4 : 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        leading: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if(rankIcon != null)
              Icon(rankIcon, color: _getRankColor(entry.rank), size: 30)
            else
              Text('#${entry.rank}', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
        title: Text(entry.userName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${entry.score} tasks completed'),
        trailing: CircleAvatar(
          radius: 25,
          backgroundImage: entry.userAvatarUrl != null ? NetworkImage(entry.userAvatarUrl!) : null,
          child: entry.userAvatarUrl == null ? const Icon(Icons.person) : null,
        ),
      ),
    );
  }

  IconData? _getRankIcon(int rank) {
    switch (rank) {
      case 1: return Icons.emoji_events;
      case 2: return Icons.military_tech;
      case 3: return Icons.workspace_premium;
      default: return null;
    }
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1: return Colors.amber.shade700;
      case 2: return Colors.grey.shade600;
      case 3: return Colors.brown.shade400;
      default: return Colors.transparent;
    }
  }
}
