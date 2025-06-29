import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// Import the new models and the conversation screen
import '../models/chat_channel_model.dart';
import 'conversation_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({Key? key}) : super(key: key);

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final String _currentUserId = FirebaseAuth.instance.currentUser!.uid;

  void _navigateToConversation(BuildContext context, ChatChannel chatChannel) {
    // Determine the other user's details from the chat channel
    final otherUserId = chatChannel.participants.firstWhere((id) => id != _currentUserId, orElse: () => '');
    final otherUserName = chatChannel.participantNames[otherUserId] ?? 'Unknown User';
    final otherUserAvatar = chatChannel.participantAvatars[otherUserId];

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConversationScreen(
          chatChannelId: chatChannel.id,
          otherUserName: otherUserName,
          otherUserAvatarUrl: otherUserAvatar,
        ),
      ),
    );
  }

  /// Formats the timestamp for display on the chat list item.
  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final now = DateTime.now();
    final date = timestamp.toDate();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return DateFormat.jm().format(date); // e.g., 5:30 PM
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return DateFormat.E().format(date); // e.g., Mon, Tue
    } else {
      return DateFormat.yMd().format(date); // e.g., 6/23/2025
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Create a query to get all chat channels the current user is a part of
    final chatChannelsQuery = FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: _currentUserId)
        .orderBy('lastMessageTimestamp', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () { /* TODO: Implement search */ },
            tooltip: 'Search Chats',
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: chatChannelsQuery.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            print(snapshot.error);
            return const Center(child: Text("Error loading chats."));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState(theme);
          }

          final chatChannels = snapshot.data!.docs
              .map((doc) => ChatChannel.fromFirestore(doc))
              .toList();

          return ListView.separated(
            itemCount: chatChannels.length,
            separatorBuilder: (context, index) => const Divider(height: 0, indent: 88),
            itemBuilder: (context, index) {
              final channel = chatChannels[index];
              final otherUserId = channel.participants.firstWhere((id) => id != _currentUserId);
              final name = channel.participantNames[otherUserId] ?? 'Unknown User';
              final avatarUrl = channel.participantAvatars[otherUserId];
              final lastMessage = channel.lastMessage ?? 'No messages yet.';

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                leading: CircleAvatar(
                  radius: 28,
                  backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty) ? NetworkImage(avatarUrl) : null,
                  child: (avatarUrl == null || avatarUrl.isEmpty) ? const Icon(Icons.person) : null,
                ),
                title: Text(name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  lastMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                trailing: Text(
                  _formatTimestamp(channel.lastMessageTimestamp),
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                onTap: () => _navigateToConversation(context, channel),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline_rounded, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No Chats Yet',
              style: theme.textTheme.headlineSmall?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: Text(
                'Start a conversation with helpers or task posters. Your messages will appear here.',
                style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
