import 'package:cloud_firestore/cloud_firestore.dart';

class LeaderboardEntry {
  final String userId;
  final String userName;
  final String? userAvatarUrl;
  final int rank;
  final int score; // e.g., number of completed tasks
  final String region; // e.g., 'Colombo', 'Kandy'

  LeaderboardEntry({
    required this.userId,
    required this.userName,
    this.userAvatarUrl,
    required this.rank,
    required this.score,
    required this.region,
  });

  factory LeaderboardEntry.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return LeaderboardEntry(
      userId: doc.id, // The doc id is the user's id
      userName: data['userName'] ?? 'Unknown Hero',
      userAvatarUrl: data['userAvatarUrl'] as String?,
      rank: data['rank'] as int? ?? 0,
      score: data['score'] as int? ?? 0,
      region: data['region'] as String? ?? 'Sri Lanka',
    );
  }
}
