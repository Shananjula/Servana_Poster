import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:firebase_storage/firebase_storage.dart' hide Task;
import 'package:servana/models/user_model.dart';
import 'package:servana/services/ai_service.dart';
import 'package:servana/services/firestore_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/chat_message_model.dart';
import '../models/task_model.dart';

class ConversationScreen extends StatefulWidget {
  final String chatChannelId;
  final String otherUserName;
  final String? otherUserAvatarUrl;
  final String taskTitle;

  const ConversationScreen({
    Key? key,
    required this.chatChannelId,
    required this.otherUserName,
    this.otherUserAvatarUrl,
    required this.taskTitle,
  }) : super(key: key);

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final String _currentUserId = FirebaseAuth.instance.currentUser!.uid;
  final FirestoreService _firestoreService = FirestoreService();

  HelpifyUser? _otherUser;
  bool _isUploadingFile = false;
  Map<String, dynamic>? _smartAction;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fetchOtherUserData();
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

  void _executeSmartAction() {
    if (_smartAction == null) return;
    final actionType = _smartAction!['action'];
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Executing AI Action: $actionType")));
    setState(() => _smartAction = null);
  }

  Future<void> _fetchOtherUserData() async {
    try {
      final participantIds = widget.chatChannelId.split('_');
      final otherUserId =
      participantIds.firstWhere((id) => id != _currentUserId, orElse: () => '');

      if (otherUserId.isNotEmpty) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(otherUserId)
            .get();
        if (userDoc.exists && mounted) {
          setState(() {
            _otherUser = HelpifyUser.fromFirestore(userDoc);
          });
        }
      }
    } catch (e) {
      print("Error fetching other user's data: $e");
    }
  }

  Future<void> _sendMessage({String? imageUrl}) async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty && imageUrl == null) return;

    setState(() {
      _isUploadingFile = false;
    });

    final message = {
      'text': messageText,
      'senderId': _currentUserId,
      'timestamp': FieldValue.serverTimestamp(),
      'type': imageUrl != null ? 'image' : 'text',
      'imageUrl': imageUrl,
    };

    final messagesRef = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatChannelId)
        .collection('messages');
    final channelRef =
    FirebaseFirestore.instance.collection('chats').doc(widget.chatChannelId);

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
    _scrollToBottom();
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () {
                  Navigator.of(context).pop();
                  _shareFile(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.of(context).pop();
                  _shareFile(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _shareFile(ImageSource source) async {
    if (_isUploadingFile) return;
    setState(() => _isUploadingFile = true);
    final picker = ImagePicker();
    final file = await picker.pickImage(source: source, imageQuality: 80);
    if (file == null) {
      if (mounted) setState(() => _isUploadingFile = false);
      return;
    }
    try {
      final fileName =
          '${_currentUserId}-${DateTime.now().millisecondsSinceEpoch}.jpg';

      final String filePath = 'chat_attachments/${widget.chatChannelId}/$fileName';

      final ref = FirebaseStorage.instance.ref(filePath);

      await ref.putFile(File(file.path));
      final imageUrl = await ref.getDownloadURL();
      await _sendMessage(imageUrl: imageUrl);

    } on FirebaseException catch (e) {
      print("File upload failed. Error: ${e.toString()}");
      print("Firebase Storage Error Code: ${e.code}");
      print("Firebase Storage Error Message: ${e.message}");
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("File sharing failed. Please check permissions.")));
      }
    } catch (e) {
      print("An unexpected error occurred during file upload: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isUploadingFile = false);
    }
  }

  // --- UPDATED: This function now uses 'phone' instead of 'phoneNumber' ---
  void _showContactInfoDialog() {
    if (_otherUser?.phone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("This user has not provided a phone number.")),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Contact Information"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_otherUser!.displayName ?? 'No Name',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text("Phone: ${_otherUser!.phone!}"),
          ],
        ),
        actions: [
          TextButton(
            child: const Text("Close"),
            onPressed: () => Navigator.of(context).pop(),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.call),
            label: const Text("Call"),
            onPressed: () async {
              final Uri phoneUri = Uri(scheme: 'tel', path: _otherUser!.phone!);
              if (await canLaunchUrl(phoneUri)) {
                await launchUrl(phoneUri);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Could not place the call.")),
                );
              }
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
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

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 1,
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: _otherUser?.photoURL != null
                  ? NetworkImage(_otherUser!.photoURL!)
                  : (widget.otherUserAvatarUrl != null && widget.otherUserAvatarUrl!.isNotEmpty
                  ? NetworkImage(widget.otherUserAvatarUrl!)
                  : null),
              child: _otherUser?.photoURL == null && (widget.otherUserAvatarUrl == null || widget.otherUserAvatarUrl!.isEmpty)
                  ? const Icon(Icons.person)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _otherUser?.displayName ?? widget.otherUserName,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          if (_otherUser != null)
            IconButton(
              icon: const Icon(Icons.call_outlined),
              onPressed: _showContactInfoDialog,
              tooltip: 'View Contact Info',
            ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('chats').doc(widget.chatChannelId).snapshots(),
        builder: (context, channelSnapshot) {
          if (!channelSnapshot.hasData || !channelSnapshot.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = channelSnapshot.data!.data();
          final String? taskId = data != null && data.containsKey('taskId') ? data['taskId'] : null;

          if (taskId == null) {
            return Column(
              children: [
                Expanded(child: _buildChatMessages(null)),
                if (_smartAction != null) _buildSmartActionButton(Theme.of(context)),
                _MessageInputField(
                  controller: _messageController,
                  onSend: _sendMessage,
                  onAttach: _showAttachmentMenu,
                  isUploading: _isUploadingFile,
                ),
              ],
            );
          }

          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('tasks').doc(taskId).snapshots(),
            builder: (context, taskSnapshot) {
              if (taskSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final task = taskSnapshot.hasData && taskSnapshot.data!.exists
                  ? Task.fromFirestore(taskSnapshot.data! as DocumentSnapshot<Map<String, dynamic>>)
                  : null;

              return Column(
                children: [
                  if (task != null) _buildNegotiationBar(context, task),
                  Expanded(child: _buildChatMessages(task)),
                  if (_smartAction != null) _buildSmartActionButton(Theme.of(context)),
                  if (task != null && task.status == 'negotiating')
                    _MessageInputField(
                      controller: _messageController,
                      onSend: _sendMessage,
                      onAttach: _showAttachmentMenu,
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

  Widget _buildChatMessages(Task? task) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatChannelId)
          .collection('messages')
          .orderBy('timestamp')
          .snapshots(),
      builder: (context, messageSnapshot) {
        if (messageSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!messageSnapshot.hasData || messageSnapshot.data!.docs.isEmpty) {
          return const Center(
              child: Text("Say hello!", style: TextStyle(color: Colors.grey)));
        }
        _scrollToBottom();
        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(12),
          itemCount: messageSnapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final messageDoc = messageSnapshot.data!.docs[index];
            final message = ChatMessage.fromFirestore(messageDoc);

            if (message.type == 'offer' && task != null) {
              return _OfferMessageBubble(
                key: ValueKey(message.id),
                message: message,
                task: task,
                currentUserId: _currentUserId,
                onCounterOffer: _showCounterOfferDialog,
              );
            }
            return _MessageBubble(
                key: ValueKey(message.id),
                message: message,
                isSentByMe: message.senderId == _currentUserId);
          },
        );
      },
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
        statusText =
        'Task assigned! Final price: LKR ${NumberFormat("#,##0.00").format(task.finalAmount)}';
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
          Expanded(
              child: Text(statusText,
                  style: TextStyle(
                      color: statusColor, fontWeight: FontWeight.bold))),
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

// --- UI WIDGETS ---

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isSentByMe;

  const _MessageBubble(
      {Key? key, required this.message, required this.isSentByMe})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isImage = message.type == 'image';
    return Align(
      alignment: isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: isImage
            ? const EdgeInsets.all(4)
            : const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
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
            loadingBuilder: (context, child, progress) =>
            progress == null
                ? child
                : const SizedBox(
                height: 200,
                width: 200,
                child: Center(child: CircularProgressIndicator())),
          ),
        )
            : Text(message.text,
            style:
            TextStyle(color: isSentByMe ? Colors.white : Colors.black87)),
      ),
    );
  }
}

class _OfferMessageBubble extends StatelessWidget {
  final ChatMessage message;
  final Task task;
  final String currentUserId;
  final VoidCallback onCounterOffer;

  const _OfferMessageBubble({
    Key? key,
    required this.message,
    required this.task,
    required this.currentUserId,
    required this.onCounterOffer,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final FirestoreService firestoreService = FirestoreService();
    final theme = Theme.of(context);

    final bool isMyOffer = message.senderId == currentUserId;
    final offerAmount = message.offerAmount ?? 0.0;

    final bool isPending = message.offerStatus == 'pending';
    final bool canTakeAction = isPending && !isMyOffer && task.status == 'negotiating';

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
                    if (message.offerId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Cannot accept this offer: Missing Offer ID."), backgroundColor: Colors.red),
                      );
                      return;
                    }
                    firestoreService.acceptOffer(task.id, message.offerId!);
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

  const _MessageInputField(
      {Key? key,
        required this.controller,
        required this.onSend,
        this.onAttach,
        this.isUploading = false})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 8,
      color: theme.cardColor,
      child: Padding(
        padding: EdgeInsets.only(
            left: 8,
            right: 8,
            top: 8,
            bottom: MediaQuery.of(context).padding.bottom + 8),
        child: Row(
          children: [
            IconButton(
              icon: isUploading
                  ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.add_circle_outline),
              onPressed: onAttach,
              tooltip: "Attach File",
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(24)),
                child: TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                      hintText: 'Type a message...', border: InputBorder.none),
                  textCapitalization: TextCapitalization.sentences,
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
