import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_message_model.dart'; // Using your existing chat message model

/// A screen that displays a real-time conversation and allows sending messages.
class ConversationScreen extends StatefulWidget {
  final String chatChannelId;
  final String otherUserName;
  final String? otherUserAvatarUrl;

  const ConversationScreen({
    Key? key,
    required this.chatChannelId,
    required this.otherUserName,
    this.otherUserAvatarUrl,
  }) : super(key: key);

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final String _currentUserId = FirebaseAuth.instance.currentUser!.uid;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Sends a new message to the Firestore subcollection for this chat channel.
  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;

    final message = {
      'text': messageText,
      'senderId': _currentUserId,
      'timestamp': FieldValue.serverTimestamp(),
    };

    // Reference to the 'messages' subcollection within the chat channel
    final messagesRef = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatChannelId)
        .collection('messages');

    // Reference to the main chat channel document to update the 'lastMessage'
    final channelRef = FirebaseFirestore.instance.collection('chats').doc(widget.chatChannelId);

    // Use a batch write to perform both operations atomically
    final batch = FirebaseFirestore.instance.batch();
    batch.set(messagesRef.doc(), message); // Add new message
    batch.update(channelRef, { // Update last message details
      'lastMessage': messageText,
      'lastMessageTimestamp': FieldValue.serverTimestamp(),
      'lastMessageSenderId': _currentUserId,
    });

    await batch.commit();

    _messageController.clear();
    _scrollToBottom();
  }

  /// Scrolls to the bottom of the message list.
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 40,
        titleSpacing: 0,
        title: Row(
          children: [
            if (widget.otherUserAvatarUrl != null && widget.otherUserAvatarUrl!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: CircleAvatar(
                  backgroundImage: NetworkImage(widget.otherUserAvatarUrl!),
                  radius: 20,
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(Icons.person, color: theme.colorScheme.onPrimaryContainer),
                  radius: 20,
                ),
              ),
            Expanded(
              child: Text(
                widget.otherUserName,
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.call_outlined), onPressed: () {/* TODO */}),
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {/* TODO */}),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              // Listen to the 'messages' subcollection in real-time
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(widget.chatChannelId)
                  .collection('messages')
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No messages yet. Say hello!"));
                }
                if (snapshot.hasError) {
                  return const Center(child: Text("Could not load messages."));
                }

                final messages = snapshot.data!.docs
                    .map((doc) => ChatMessage.fromFirestore(doc))
                    .toList();

                // Scroll to bottom after the list builds
                _scrollToBottom();

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final bool isSentByMe = message.senderId == _currentUserId;
                    return _MessageBubble(message: message.text, isSentByMe: isSentByMe, timestamp: message.timestamp);
                  },
                );
              },
            ),
          ),
          _MessageInputField(
            controller: _messageController,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }
}

// --- UI Helper Widgets ---

class _MessageBubble extends StatelessWidget {
  final String message;
  final bool isSentByMe;
  final Timestamp? timestamp;

  const _MessageBubble({
    Key? key,
    required this.message,
    required this.isSentByMe,
    this.timestamp
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final alignment = isSentByMe ? Alignment.centerRight : Alignment.centerLeft;
    final bubbleColor = isSentByMe ? theme.colorScheme.primaryContainer : theme.colorScheme.secondaryContainer;
    final textColor = isSentByMe ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSecondaryContainer;
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(isSentByMe ? 18 : 4),
      bottomRight: Radius.circular(isSentByMe ? 4 : 18),
    );

    return Align(
      alignment: alignment,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: borderRadius,
        ),
        child: Text(
          message,
          style: theme.textTheme.bodyLarge?.copyWith(color: textColor),
        ),
      ),
    );
  }
}

class _MessageInputField extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;

  const _MessageInputField({
    Key? key,
    required this.controller,
    required this.onSend,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 5.0,
      color: theme.canvasColor,
      child: Padding(
        padding: EdgeInsets.only(
          left: 12.0,
          right: 8.0,
          top: 8.0,
          bottom: 8.0 + MediaQuery.of(context).padding.bottom,
        ),
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.add, color: theme.colorScheme.onSurfaceVariant),
              onPressed: () {},
              tooltip: "Attach file",
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(24.0),
                ),
                child: TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    hintText: 'Type a message...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    isCollapsed: true,
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 1,
                  maxLines: 5,
                  onSubmitted: (_) => onSend(),
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(Icons.send_rounded, color: theme.colorScheme.primary),
              onPressed: onSend,
              tooltip: "Send message",
            ),
          ],
        ),
      ),
    );
  }
}
