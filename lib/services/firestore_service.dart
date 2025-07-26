import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:servana/models/task_model.dart';
import 'package:servana/models/user_model.dart';
import 'package:servana/screens/conversation_screen.dart';
import 'package:servana/screens/payment_screen.dart';
import 'package:servana/screens/rating_screen.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- PHASE 1: NEGOTIATION ---
  Future<void> initiateOfferAndNavigateToChat({
    required BuildContext context,
    required Task task,
    required HelpifyUser helper,
    required double offerAmount,
    String? initialMessage,
  }) async {
    try {
      final List<String> ids = [helper.id, task.posterId];
      ids.sort();
      final chatChannelId = ids.join('_${task.id}');
      final chatChannelDoc = _db.collection('chats').doc(chatChannelId);
      final messagesCollection = chatChannelDoc.collection('messages');
      final taskDoc = _db.collection('tasks').doc(task.id);
      final offerDoc = taskDoc.collection('offers').doc();
      final offerMessage = "I've made an offer of LKR ${offerAmount.toStringAsFixed(2)}. ${initialMessage ?? ''}";

      final initialBatch = _db.batch();
      initialBatch.set(offerDoc, {
        'taskId': task.id,
        'helperId': helper.id,
        'helperName': helper.displayName,
        'helperAvatarUrl': helper.photoURL,
        'helperTrustScore': helper.trustScore,
        'amount': offerAmount,
        'message': initialMessage ?? '',
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
      initialBatch.set(
        chatChannelDoc,
        {
          'taskId': task.id,
          'taskTitle': task.title,
          'participantIds': ids,
          'participantNames': {helper.id: helper.displayName, task.posterId: task.posterName},
          'participantAvatars': {helper.id: helper.photoURL, task.posterId: task.posterAvatarUrl},
          'lastMessage': offerMessage,
          'lastMessageTimestamp': FieldValue.serverTimestamp(),
          'lastMessageSenderId': helper.id,
        },
        SetOptions(merge: true),
      );
      initialBatch.update(taskDoc, {'status': 'negotiating', 'participantIds': FieldValue.arrayUnion([helper.id])});
      await initialBatch.commit();

      await messagesCollection.doc().set({
        'senderId': helper.id,
        'text': offerMessage,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'offer',
        'offerAmount': offerAmount,
        'offerStatus': 'pending',
      });

      if (context.mounted) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (ctx) => ConversationScreen(
            chatChannelId: chatChannelId,
            otherUserName: task.posterName,
            otherUserAvatarUrl: task.posterAvatarUrl,
          ),
        ));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error initiating chat: ${e.toString()}")));
    }
  }

  Future<void> sendActionableChatMessage({
    required String chatChannelId,
    required String taskId,
    required String senderId, // This is the Poster's ID
    required String helperId,
    required String text,
    required String actionType,
    double? offerAmount,
  }) async {
    final messagesRef = _db.collection('chats').doc(chatChannelId).collection('messages');
    final channelRef = _db.collection('chats').doc(chatChannelId);
    final taskRef = _db.collection('tasks').doc(taskId);
    final batch = _db.batch();

    final previousOffers = await messagesRef.where('offerAmount', isEqualTo: offerAmount).where('offerStatus', isEqualTo: 'pending').get();
    for (final doc in previousOffers.docs) {
      batch.update(doc.reference, {'offerStatus': actionType});
    }

    if (actionType == 'poster_accept') {
      // --- THIS IS THE UPGRADED LOGIC ---
      // Fetch both user documents in parallel to get all their details.
      final posterId = senderId;
      final helperDocFuture = _db.collection('users').doc(helperId).get();
      final posterDocFuture = _db.collection('users').doc(posterId).get();

      final List<DocumentSnapshot> userDocs = await Future.wait([helperDocFuture, posterDocFuture]);

      final helperData = userDocs[0].data() as Map<String, dynamic>?;
      final posterData = userDocs[1].data() as Map<String, dynamic>?;

      // Extract all necessary details for both users.
      final helperName = helperData?['displayName'] as String? ?? 'Unknown Helper';
      final helperAvatarUrl = helperData?['photoURL'] as String?;
      final helperPhoneNumber = helperData?['phoneNumber'] as String?;

      final posterPhoneNumber = posterData?['phoneNumber'] as String?;

      // Now update the task with all the reciprocal contact info.
      batch.update(taskRef, {
        'status': 'assigned',
        'finalAmount': offerAmount,
        'assignedHelperId': helperId,
        'assignedHelperName': helperName,
        'assignedHelperAvatarUrl': helperAvatarUrl,
        'assignedHelperPhoneNumber': helperPhoneNumber, // Add helper phone
        'posterPhoneNumber': posterPhoneNumber, // Add poster phone
        'assignmentTimestamp': FieldValue.serverTimestamp(),
      });
    }

    batch.update(channelRef, {'lastMessage': text, 'lastMessageTimestamp': FieldValue.serverTimestamp(), 'lastMessageSenderId': senderId});
    await batch.commit();
  }

  Future<void> sendOfferInChat({
    required String chatChannelId,
    required String senderId,
    required String text,
    required double offerAmount,
  }) async {
    final messagesRef = _db.collection('chats').doc(chatChannelId).collection('messages');
    final channelRef = _db.collection('chats').doc(chatChannelId);
    final batch = _db.batch();

    final previousOffers = await messagesRef.where('offerStatus', isEqualTo: 'pending').get();
    for (final doc in previousOffers.docs) {
      batch.update(doc.reference, {'offerStatus': 'countered'});
    }

    batch.set(messagesRef.doc(), {
      'senderId': senderId,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'offer',
      'offerAmount': offerAmount,
      'offerStatus': 'pending',
    });

    batch.update(channelRef, {'lastMessage': 'New Offer: LKR ${offerAmount.toStringAsFixed(2)}', 'lastMessageTimestamp': FieldValue.serverTimestamp(), 'lastMessageSenderId': senderId});
    await batch.commit();
  }

  // --- PHASE 2 & 3: LIVE TASK ---
  Future<void> helperStartsJourney(String taskId) async {
    await _db.collection('tasks').doc(taskId).update({'status': 'en_route', 'helperStartedJourneyAt': FieldValue.serverTimestamp()});
  }

  Future<void> helperArrives(String taskId) async {
    final String confirmationCode = (1000 + (DateTime.now().millisecond % 9000)).toString();
    await _db.collection('tasks').doc(taskId).update({'status': 'arrived', 'helperArrivedAt': FieldValue.serverTimestamp(), 'confirmationCode': confirmationCode});
  }

  Future<void> helperConfirmsArrivalWithCode(String taskId, String code) async {
    final taskRef = _db.collection('tasks').doc(taskId);
    await _db.runTransaction((transaction) async {
      final taskDoc = await transaction.get(taskRef);
      if (!taskDoc.exists) throw Exception("Task not found!");
      if (taskDoc.data()?['confirmationCode'] != code) throw Exception("Invalid confirmation code.");
      transaction.update(taskRef, {'status': 'in_progress', 'posterConfirmedStartAt': FieldValue.serverTimestamp(), 'confirmationCode': FieldValue.delete()});
    });
  }

  Future<void> helperCompletesTask(String taskId, {String? proofImageUrl}) async {
    await _db.collection('tasks').doc(taskId).update({'status': 'pending_completion', 'helperCompletedAt': FieldValue.serverTimestamp(), if (proofImageUrl != null) 'proofImageUrl': proofImageUrl});
  }

  // --- PHASE 4: PAYMENT & RATING ---
  Future<void> posterConfirmsCompletion(BuildContext context, Task task) async {
    await _db.collection('tasks').doc(task.id).update({'status': 'pending_payment', 'posterConfirmedCompletionAt': FieldValue.serverTimestamp()});
    if (context.mounted) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => PaymentScreen(task: task)));
    }
  }

  Future<void> markTaskAsPaid(BuildContext context, Task task) async {
    await _db.collection('tasks').doc(task.id).update({'status': 'pending_rating', 'paymentCompletedAt': FieldValue.serverTimestamp()});
    final currentUser = FirebaseAuth.instance.currentUser!;
    final isPoster = currentUser.uid == task.posterId;
    final personToRateId = isPoster ? task.assignedHelperId! : task.posterId;
    final personToRateName = isPoster ? task.assignedHelperName! : task.posterName;
    final personToRateAvatarUrl = isPoster ? task.assignedHelperAvatarUrl : task.posterAvatarUrl;
    if (context.mounted) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => RatingScreen(task: task, personToRateId: personToRateId, personToRateName: personToRateName, personToRateAvatarUrl: personToRateAvatarUrl)));
    }
  }

  Future<void> submitReviewAndCloseTask({required Task task, required String ratedUserId, required String reviewerId, required String reviewerName, String? reviewerAvatarUrl, required double rating, required String reviewText}) async {
    final ratedUserRef = _db.collection('users').doc(ratedUserId);
    final reviewRef = _db.collection('reviews').doc();
    final taskRef = _db.collection('tasks').doc(task.id);
    await _db.runTransaction((transaction) async {
      final ratedUserDoc = await transaction.get(ratedUserRef);
      if (!ratedUserDoc.exists) throw Exception("User to be rated not found!");
      final ratedUserData = HelpifyUser.fromFirestore(ratedUserDoc);
      final oldRatingTotal = ratedUserData.averageRating * ratedUserData.ratingCount;
      final newRatingCount = ratedUserData.ratingCount + 1;
      final newAverageRating = (oldRatingTotal + rating) / newRatingCount;
      transaction.update(ratedUserRef, {'averageRating': newAverageRating, 'ratingCount': newRatingCount});
      transaction.set(reviewRef, {'rating': rating, 'reviewText': reviewText, 'taskId': task.id, 'taskTitle': task.title, 'reviewerId': reviewerId, 'reviewerName': reviewerName, 'reviewerAvatarUrl': reviewerAvatarUrl, 'ratedUserId': ratedUserId, 'timestamp': FieldValue.serverTimestamp()});
      transaction.update(taskRef, {'status': 'closed', 'ratedAt': FieldValue.serverTimestamp()});
    });
  }

  // --- PHASE 5: EXCEPTIONS & MODIFICATIONS ---
  Future<void> initiateDispute({required String taskId, required String reason, required String initiatedByUserId}) async {
    await _db.collection('tasks').doc(taskId).update({'status': 'in_dispute', 'disputeReason': reason, 'disputeInitiatorId': initiatedByUserId, 'disputeTimestamp': FieldValue.serverTimestamp()});
  }

  Future<void> cancelTask({required String taskId, required String reason, required String cancelledById}) async {
    await _db.collection('tasks').doc(taskId).update({'status': 'cancelled', 'cancellationReason': reason, 'cancelledBy': cancelledById, 'cancellationTimestamp': FieldValue.serverTimestamp()});
  }

  Future<void> requestTaskModification({required String taskId, required String description, required double additionalCost}) async {
    await _db.collection('tasks').doc(taskId).collection('modifications').add({'description': description, 'additionalCost': additionalCost, 'status': 'pending', 'timestamp': FieldValue.serverTimestamp()});
  }

  Future<void> respondToModification({required String taskId, required String modificationId, required double additionalCost, required bool isApproved}) async {
    final taskRef = _db.collection('tasks').doc(taskId);
    final modificationRef = taskRef.collection('modifications').doc(modificationId);
    if (isApproved) {
      await _db.runTransaction((transaction) async {
        final taskDoc = await transaction.get(taskRef);
        if (!taskDoc.exists) throw Exception("Task not found!");
        final currentFinalAmount = (taskDoc.data()?['finalAmount'] as num?)?.toDouble() ?? 0.0;
        final newFinalAmount = currentFinalAmount + additionalCost;
        transaction.update(taskRef, {'finalAmount': newFinalAmount});
        transaction.update(modificationRef, {'status': 'approved'});
      });
    } else {
      await modificationRef.update({'status': 'rejected'});
    }
  }
}
