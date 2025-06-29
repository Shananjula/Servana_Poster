import 'package:cloud_firestore/cloud_firestore.dart';

class CommunityPost {
  final String id;
  final String posterId;
  final String posterName;
  final String? posterAvatarUrl;
  final String? helperId;
  final String? helperName;
  final String? caption;
  final String imageUrl;
  final String? relatedTaskId;
  final Timestamp timestamp;
  final int likeCount;

  CommunityPost({
    required this.id,
    required this.posterId,
    required this.posterName,
    this.posterAvatarUrl,
    this.helperId,
    this.helperName,
    this.caption,
    required this.imageUrl,
    this.relatedTaskId,
    required this.timestamp,
    this.likeCount = 0,
  });

  factory CommunityPost.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return CommunityPost(
      id: doc.id,
      posterId: data['posterId'] ?? '',
      posterName: data['posterName'] ?? 'A User',
      posterAvatarUrl: data['posterAvatarUrl'] as String?,
      helperId: data['helperId'] as String?,
      helperName: data['helperName'] as String?,
      caption: data['caption'] as String?,
      imageUrl: data['imageUrl'] ?? '',
      relatedTaskId: data['relatedTaskId'] as String?,
      timestamp: data['timestamp'] ?? Timestamp.now(),
      likeCount: data['likeCount'] as int? ?? 0,
    );
  }
}
