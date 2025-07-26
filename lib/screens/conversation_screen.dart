import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:firebase_storage/firebase_storage.dart' hide Task;
import 'package:servana/providers/user_provider.dart';
import 'package:servana/services/ai_service.dart';
import 'package:servana/services/firestore_service.dart';
import 'package:image_picker/image_picker.dart';
import '../models/chat_message_model.dart';
import '../models/task_model.dart';

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
  final FirestoreService _firestoreService = FirestoreService();

  Map<String, dynamic>? _smartAction;
  bool _isUploadingFile = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      if (_messageController.text.trim().length > 10) {
        _checkForSmartActions();
      } else if (_smartAction != null) {
        setState(() => _smartAction = null);
      }
    });
  }

  Future<void> _checkForSmartActions() async {
    final action = await AiService.getSmartChatAction(_messageController.text.trim());
    if (mounted && action != null) {
      setState(() => _smartAction = action);
    }
  }

  Future<void> _sendMessage({String? imageUrl}) async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty && imageUrl == null) return;

    final message = {
      'text': messageText,
      'senderId': _currentUserId,
      'timestamp': FieldValue.serverTimestamp(),
      'type': imageUrl != null ? 'image' : 'text',
      'imageUrl': imageUrl,
    };

    final messagesRef = FirebaseFirestore.instance.collection('chats').doc(widget.chatChannelId).collection('messages');
    final channelRef = FirebaseFirestore.instance.collection('chats').doc(widget.chatChannelId);

    final batch = FirebaseFirestore.instance.batch();
    batch.set(messagesRef.doc(), message);
    batch.update(channelRef, {
      'lastMessage': imageUrl != null ? 'Photo' : messageText,
      'lastMessageTimestamp': FieldValue.serverTimestamp(),
      'lastMessageSenderId': _currentUserId,
    });
    await batch.commit();

    _messageController.clear();
    if (mounted) setState(() => _smartAction = null);
  }

  Future<void> _shareFile() async {
    if (_isUploadingFile) return;
    setState(() => _isUploadingFile = true);
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file == null) {
      if (mounted) setState(() => _isUploadingFile = false);
      return;
    }
    try {
      final fileName = '${_currentUserId}-${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref('chat_attachments').child(fileName);
      await ref.putFile(File(file.path));
      final imageUrl = await ref.getDownloadURL();
      _sendMessage(imageUrl: imageUrl);
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("File sharing failed.")));
    } finally {
      if (mounted) setState(() => _isUploadingFile = false);
    }
  }

  void _executeSmartAction() {
    if (_smartAction == null) return;
    final actionType = _smartAction!['action'];
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Executing AI Action: $actionType")));
    setState(() => _smartAction = null);
  }

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

  void _showCounterOfferDialog() {
    final amountController = TextEditingController();
    final messageController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Make a Counter-Offer"),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "New Offer Amount (LKR)"),
                validator: (val) => (val == null || val.isEmpty || double.tryParse(val) == null) ? "Invalid amount" : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: messageController,
                decoration: const InputDecoration(labelText: "Optional Message"),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final amount = double.parse(amountController.text);
                final message = messageController.text.trim();

                _firestoreService.sendOfferInChat(
                  chatChannelId: widget.chatChannelId,
                  senderId: _currentUserId,
                  text: message.isNotEmpty ? message : "I'd like to make a new offer.",
                  offerAmount: amount,
                );
                Navigator.of(context).pop();
              }
            },
            child: const Text("Send Offer"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        elevation: 1,
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: widget.otherUserAvatarUrl != null ? NetworkImage(widget.otherUserAvatarUrl!) : null,
              child: widget.otherUserAvatarUrl == null ? const Icon(Icons.person) : null,
            ),
            const SizedBox(width: 12),
            Text(widget.otherUserName),
          ],
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('chats').doc(widget.chatChannelId).snapshots(),
        builder: (context, channelSnapshot) {
          if (!channelSnapshot.hasData) return const Center(child: CircularProgressIndicator());
          final taskId = channelSnapshot.data!.get('taskId');

          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('tasks').doc(taskId).snapshots(),
            builder: (context, taskSnapshot) {
              if (!taskSnapshot.hasData) return const Center(child: CircularProgressIndicator());
              final task = Task.fromFirestore(taskSnapshot.data! as DocumentSnapshot<Map<String, dynamic>>);

              return Column(
                children: [
                  _buildNegotiationBar(context, task),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance.collection('chats').doc(widget.chatChannelId).collection('messages').orderBy('timestamp').snapshots(),
                      builder: (context, messageSnapshot) {
                        if (messageSnapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (!messageSnapshot.hasData || messageSnapshot.data!.docs.isEmpty) {
                          return const Center(child: Text("Say hello!"));
                        }
                        _scrollToBottom();
                        return ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(12),
                          itemCount: messageSnapshot.data!.docs.length,
                          itemBuilder: (context, index) {
                            final messageDoc = messageSnapshot.data!.docs[index];
                            final message = ChatMessage.fromFirestore(messageDoc);

                            if (message.type == 'offer') {
                              return _OfferMessageBubble(
                                key: ValueKey(message.id), // Add a key for better performance
                                message: message,
                                task: task,
                                currentUserId: _currentUserId,
                                chatChannelId: widget.chatChannelId,
                                onCounterOffer: _showCounterOfferDialog,
                              );
                            }
                            return _MessageBubble(
                                key: ValueKey(message.id), // Add a key for better performance
                                message: message,
                                isSentByMe: message.senderId == _currentUserId
                            );
                          },
                        );
                      },
                    ),
                  ),
                  if (_smartAction != null) _buildSmartActionButton(theme),
                  if (task.status == 'negotiating')
                    _MessageInputField(
                      controller: _messageController,
                      onSend: _sendMessage,
                      onAttach: _shareFile,
                      isUploading: _isUploadingFile,
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildNegotiationBar(BuildContext context, Task task) {
    String statusText;
    Color statusColor;
    IconData statusIcon;

    switch (task.status) {
      case 'negotiating':
        statusText = 'Negotiation in progress for "${task.title}"';
        statusColor = Colors.orange.shade700;
        statusIcon = Icons.hourglass_bottom_rounded;
        break;
      case 'assigned':
        statusText = 'Task assigned! Final price: LKR ${NumberFormat("#,##0.00").format(task.finalAmount)}';
        statusColor = Colors.green.shade700;
        statusIcon = Icons.check_circle_outline_rounded;
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: statusColor.withOpacity(0.1),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildSmartActionButton(ThemeData theme) {
    IconData icon = Icons.lightbulb_outline;
    String text = _smartAction!['details'] ?? "Smart Action";
    if (_smartAction!['action'] == 'schedule') icon = Icons.calendar_today_outlined;
    if (_smartAction!['action'] == 'request_location') icon = Icons.location_on_outlined;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: theme.primaryColor.withOpacity(0.1),
      child: TextButton.icon(
        style: TextButton.styleFrom(foregroundColor: theme.primaryColor, alignment: Alignment.centerLeft),
        onPressed: _executeSmartAction,
        icon: Icon(icon, size: 20),
        label: Text(text, overflow: TextOverflow.ellipsis,),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isSentByMe;

  const _MessageBubble({Key? key, required this.message, required this.isSentByMe}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isImage = message.type == 'image';
    return Align(
      alignment: isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: isImage ? const EdgeInsets.all(4) : const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          color: isSentByMe ? theme.primaryColor : Colors.grey[200],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isSentByMe ? 20 : 4),
            bottomRight: Radius.circular(isSentByMe ? 4 : 20),
          ),
        ),
        child: isImage
            ? ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.network(
            message.imageUrl!,
            height: 200,
            width: 200,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) => progress == null ? child : const SizedBox(height: 200, width: 200, child: Center(child: CircularProgressIndicator())),
          ),
        )
            : Text(message.text, style: TextStyle(color: isSentByMe ? Colors.white : Colors.black87)),
      ),
    );
  }
}

class _OfferMessageBubble extends StatelessWidget {
  final ChatMessage message;
  final Task task;
  final String currentUserId;
  final String chatChannelId;
  final VoidCallback onCounterOffer;

  const _OfferMessageBubble({
    Key? key,
    required this.message,
    required this.task,
    required this.currentUserId,
    required this.chatChannelId,
    required this.onCounterOffer,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final FirestoreService firestoreService = FirestoreService();
    final theme = Theme.of(context);

    final bool isMyOffer = message.senderId == currentUserId;
    final offerAmount = message.offerAmount ?? 0.0;

    final bool isPending = message.offerStatus == 'pending';
    final bool canTakeAction = isPending && !isMyOffer;

    String title;
    Color cardColor;
    Color borderColor;

    if (isMyOffer) {
      title = "You sent an offer:";
      cardColor = Colors.blue.shade50;
      borderColor = Colors.blue.shade200;
    } else {
      title = "You received an offer:";
      cardColor = Colors.green.shade50;
      borderColor = Colors.green.shade200;
    }

    if (!isPending) {
      cardColor = Colors.grey.shade200;
      borderColor = Colors.grey.shade300;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.labelLarge?.copyWith(color: Colors.black87)),
          const SizedBox(height: 8),
          Text(
            'LKR ${NumberFormat("#,##0.00").format(offerAmount)}',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          if (message.text.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('"${message.text}"', style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
          ],
          const Divider(height: 24),

          if (canTakeAction)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: onCounterOffer,
                  child: const Text("Counter-Offer"),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    firestoreService.sendActionableChatMessage(
                      chatChannelId: chatChannelId,
                      taskId: task.id,
                      senderId: currentUserId,
                      helperId: message.senderId,
                      text: 'I have accepted your offer of LKR $offerAmount.',
                      actionType: 'poster_accept',
                      offerAmount: offerAmount,
                    );
                  },
                  child: const Text("Accept Offer"),
                ),
              ],
            )
          else if (isPending && isMyOffer)
            const Text("Waiting for a response...", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey))
          else
            Text(
              "Offer Status: ${message.offerStatus?.toUpperCase()}",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700),
            )
        ],
      ),
    );
  }
}

class _MessageInputField extends StatelessWidget {
  final TextEditingController controller;
  final Function({String? imageUrl}) onSend;
  final VoidCallback? onAttach;
  final bool isUploading;

  const _MessageInputField({Key? key, required this.controller, required this.onSend, this.onAttach, this.isUploading = false}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 8,
      color: theme.cardColor,
      child: Padding(
        padding: EdgeInsets.only(left: 8, right: 8, top: 8, bottom: MediaQuery.of(context).padding.bottom + 8),
        child: Row(
          children: [
            IconButton(
              icon: isUploading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2,)) : const Icon(Icons.attach_file_outlined),
              onPressed: onAttach,
              tooltip: "Attach Image",
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(24)
                ),
                child: TextField(
                  controller: controller,
                  decoration: const InputDecoration(hintText: 'Type a message...', border: InputBorder.none),
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => onSend(),
                  minLines: 1,
                  maxLines: 5,
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.send_rounded, color: theme.primaryColor),
              onPressed: () => onSend(),
              tooltip: "Send",
            ),
          ],
        ),
      ),
    );
  }
}
