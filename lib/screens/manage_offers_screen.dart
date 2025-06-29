import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

// Centralized models
import '../models/task_model.dart';
import '../models/offer_model.dart';
import '../models/user_model.dart';

// Screens for navigation
import 'helper_public_profile_screen.dart';
import 'conversation_screen.dart';

class ManageOffersScreen extends StatelessWidget {
  final Task task;
  final HelpifyUser currentUser;

  const ManageOffersScreen({
    Key? key,
    required this.task,
    required this.currentUser,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // The stream now listens to the offers subcollection of the specific task
    final offersQuery = FirebaseFirestore.instance
        .collection('tasks')
        .doc(task.id)
        .collection('offers')
        .orderBy('timestamp', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offers Received'),
        elevation: 1,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Offers for your task:',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey[700]),
                ),
                const SizedBox(height: 4),
                Text(
                  task.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: offersQuery.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  print('Error loading offers: ${snapshot.error}');
                  return const Center(child: Text('An error occurred loading offers.'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: _buildEmptyState(
                      icon: Icons.local_offer_outlined,
                      title: 'No Offers Yet',
                      message: 'You have not received any offers for this task.',
                    ),
                  );
                }

                final offers = snapshot.data!.docs.map((doc) => Offer.fromFirestore(doc)).toList();

                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: offers.length,
                  itemBuilder: (context, index) {
                    final offer = offers[index];
                    return OfferCard(
                      offer: offer,
                      task: task,
                      currentUser: currentUser,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// --- Offer Card Widget ---
class OfferCard extends StatelessWidget {
  final Offer offer;
  final Task task;
  final HelpifyUser currentUser;

  const OfferCard({
    Key? key,
    required this.offer,
    required this.task,
    required this.currentUser,
  }) : super(key: key);

  /// --- FIX: Updated Chat Logic ---
  /// Creates a unique channel ID and ensures the channel document exists
  /// before navigating to the ConversationScreen.
  Future<void> _startChat(BuildContext context) async {
    final otherUserId = offer.helperId;
    final currentUserId = currentUser.id;

    // Create a consistent channel ID regardless of who starts the chat
    final List<String> ids = [currentUserId, otherUserId];
    ids.sort(); // Sort the IDs to ensure the channel ID is always the same
    final chatChannelId = ids.join('_');

    final chatChannelDoc = FirebaseFirestore.instance.collection('chats').doc(chatChannelId);

    // Create the chat channel document if it doesn't exist
    await chatChannelDoc.set({
      'participants': [currentUserId, otherUserId],
      'participantNames': {
        currentUserId: currentUser.displayName ?? 'Me',
        otherUserId: offer.helperName,
      },
      'participantAvatars': {
        currentUserId: currentUser.photoURL,
        otherUserId: offer.helperAvatarUrl,
      },
    }, SetOptions(merge: true)); // Use merge to avoid overwriting existing chat data

    Navigator.of(context).push(MaterialPageRoute(
      builder: (ctx) => ConversationScreen(
        chatChannelId: chatChannelId,
        otherUserName: offer.helperName,
        otherUserAvatarUrl: offer.helperAvatarUrl,
      ),
    ));
  }

  // ... other methods (_requestNumber, _declineOffer, etc.) remain the same
  void _requestNumber(BuildContext context) {
    FirebaseFirestore.instance
        .collection('tasks')
        .doc(task.id)
        .collection('offers')
        .doc(offer.id)
        .update({'numberExchangeStatus': 'requested'});

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Phone number request sent!')),
    );
  }

  void _showCallOptions(BuildContext context) async {
    String? helperPhoneNumber;

    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(offer.helperId).get();
      if (userDoc.exists && userDoc.data() != null) {
        helperPhoneNumber = (userDoc.data() as Map<String, dynamic>)['phoneNumber'] as String?;
      }
    } catch (e) {
      print("Error fetching helper's phone number: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error fetching helper\'s phone number.')),
      );
      return;
    }

    if (helperPhoneNumber == null || helperPhoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Helper phone number is not available or not yet shared.')),
      );
      return;
    }

    String formattedPhoneNumber = helperPhoneNumber.startsWith('+') ? helperPhoneNumber : '+94$helperPhoneNumber';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Wrap(
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.call),
            title: const Text('Call (Direct)'),
            onTap: () async {
              Navigator.of(ctx).pop();
              final url = Uri.parse('tel:$formattedPhoneNumber');
              if (await canLaunchUrl(url)) {
                await launchUrl(url);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Could not make a call to $formattedPhoneNumber')),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.message),
            title: const Text('Call (WhatsApp)'),
            onTap: () async {
              Navigator.of(ctx).pop();
              final whatsappNumber = formattedPhoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
              final whatsappUrl = Uri.parse('https://wa.me/$whatsappNumber');
              if (await canLaunchUrl(whatsappUrl)) {
                await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Could not open WhatsApp for $formattedPhoneNumber')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _declineOffer(BuildContext context) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('Decline Offer'),
          content: Text('Are you sure you want to decline this offer from ${offer.helperName}? This cannot be undone.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(ctx).pop(false),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Decline'),
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('tasks')
          .doc(task.id)
          .collection('offers')
          .doc(offer.id)
          .update({'status': 'declined'});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Offer declined.')),
      );

    } catch (e) {
      print("Error declining offer: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to decline offer: ${e.toString()}'), backgroundColor: Colors.red),
      );
    }
  }

  void _acceptOffer(BuildContext context) async {
    if (task.status != 'open') {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This task is no longer open for offers.')));
      return;
    }

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('Confirm Acceptance'),
          content: Text('Are you sure you want to accept this offer from ${offer.helperName} for LKR ${NumberFormat("#,##0").format(offer.amount)}?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(ctx).pop(false),
            ),
            ElevatedButton(
              child: const Text('Accept Offer'),
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final taskRef = FirebaseFirestore.instance.collection('tasks').doc(task.id);

        transaction.update(taskRef, {
          'status': 'assigned',
          'assignedHelperId': offer.helperId,
          'assignedHelperName': offer.helperName,
          'assignedHelperAvatarUrl': offer.helperAvatarUrl,
          'assignedOfferId': offer.id,
          'finalAmount': offer.amount,
          'assignmentTimestamp': FieldValue.serverTimestamp(),
        });
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Offer from ${offer.helperName} accepted!'),
          backgroundColor: Colors.green,
        ),
      );

      _startChat(context);

    } catch (e) {
      print("Error accepting offer: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to accept offer: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _viewHelperProfile(BuildContext context, String helperId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => HelperPublicProfileScreen(helperId: helperId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isTaskOpen = task.status == 'open';
    final bool isThisOfferAccepted = task.assignedOfferId == offer.id;
    final bool isOfferDeclined = offer.status == 'declined';

    final String helperAvatarUrl = offer.helperAvatarUrl ?? '';
    final int helperTrustScore = offer.helperTrustScore ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => _viewHelperProfile(context, offer.helperId),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: helperAvatarUrl.isNotEmpty ? NetworkImage(helperAvatarUrl) : null,
                    child: helperAvatarUrl.isEmpty ? const Icon(Icons.person_outline, size: 24) : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(offer.helperName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        if (helperTrustScore > 0) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.shield_outlined, color: Theme.of(context).primaryColor, size: 16),
                              const SizedBox(width: 4),
                              Text('Trust Score: $helperTrustScore', style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Text('LKR ${NumberFormat("#,##0").format(offer.amount)}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.secondary)),
                ],
              ),
            ),
            if (offer.message.isNotEmpty) ...[
              const Divider(height: 24, thickness: 0.5),
              Container(
                padding: const EdgeInsets.all(12),
                width: double.infinity,
                decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300, width: 0.5)
                ),
                child: Text('"${offer.message}"', style: TextStyle(fontSize: 15, color: Colors.grey[800], fontStyle: FontStyle.italic)),
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8.0,
              runSpacing: 8.0,
              children: [
                if (isThisOfferAccepted)
                  const Chip(label: Text('Accepted'), backgroundColor: Colors.green, avatar: Icon(Icons.check_circle, color: Colors.white))
                else if (isOfferDeclined)
                  const Chip(label: Text('Declined'), backgroundColor: Colors.redAccent, avatar: Icon(Icons.cancel, color: Colors.white))
                else if(isTaskOpen) ...[
                    OutlinedButton(onPressed: () => _declineOffer(context), child: const Text('Decline'), style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red))),
                    ElevatedButton(onPressed: () => _acceptOffer(context), child: const Text('Accept')),
                  ] else
                    Chip(label: Text('Task ${task.status}'), backgroundColor: Colors.grey.withOpacity(0.2)),

                OutlinedButton.icon(
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: const Text('Chat'),
                  onPressed: () => _startChat(context),
                ),
                if (offer.numberExchangeStatus == 'accepted')
                  OutlinedButton.icon(
                    icon: const Icon(Icons.call_outlined, size: 18, color: Colors.green),
                    label: const Text('View No.'),
                    onPressed: () => _showCallOptions(context),
                  )
                else if (offer.numberExchangeStatus == 'requested')
                  const Chip(label: Text('Requested...'))
                else if(isThisOfferAccepted || isTaskOpen)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.phone_in_talk_outlined, size: 18),
                      label: const Text('Request No.'),
                      onPressed: () => _requestNumber(context),
                    ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

Widget _buildEmptyState({required IconData icon, required String title, required String message}) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 60, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600], fontSize: 16)),
        ],
      ),
    ),
  );
}
