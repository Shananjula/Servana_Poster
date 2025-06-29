import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/community_post_model.dart';
import '../widgets/empty_state_widget.dart';

class CommunityFeedScreen extends StatelessWidget {
  const CommunityFeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Feed'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('feed_posts')
            .orderBy('timestamp', descending: true)
            .limit(20)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.groups_outlined,
              title: 'Nothing Here Yet',
              message: 'Be the first to share a success story to the community feed!',
            );
          }

          final posts = snapshot.data!.docs
              .map((doc) => CommunityPost.fromFirestore(doc))
              .toList();

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              return CommunityPostCard(post: posts[index]);
            },
          );
        },
      ),
    );
  }
}

class CommunityPostCard extends StatelessWidget {
  final CommunityPost post;

  const CommunityPostCard({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: post.posterAvatarUrl != null ? NetworkImage(post.posterAvatarUrl!) : null,
                  child: post.posterAvatarUrl == null ? const Icon(Icons.person) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Text.rich(
                      TextSpan(
                          style: theme.textTheme.bodyLarge,
                          children: [
                            TextSpan(
                              text: post.posterName,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            if (post.helperName != null) ...[
                              const TextSpan(text: ' with '),
                              TextSpan(
                                text: post.helperName!,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ]
                          ]
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    )
                ),
              ],
            ),
          ),
          // Image
          Image.network(
            post.imageUrl,
            height: 300,
            width: double.infinity,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Container(
                height: 300,
                color: Colors.grey[200],
                child: const Center(child: CircularProgressIndicator()),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Container(
                height: 300,
                color: Colors.grey[200],
                child: const Icon(Icons.error_outline, color: Colors.grey, size: 50),
              );
            },
          ),
          // Caption
          if(post.caption != null && post.caption!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(post.caption!, style: theme.textTheme.bodyLarge),
            ),
          // Actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.favorite_border),
                      onPressed: () { /* TODO: Implement liking logic */ },
                    ),
                    if(post.likeCount > 0)
                      Text('${post.likeCount} likes'),
                  ],
                ),
                Text(
                  DateFormat.yMMMd().format(post.timestamp.toDate()),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
