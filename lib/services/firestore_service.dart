import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:servana/models/task_model.dart';
import 'package:servana/models/transaction_model.dart';
import 'package:servana/models/user_model.dart';
import 'package:servana/screens/conversation_screen.dart';
import 'package:servana/screens/payment_screen.dart';
import 'package:servana/screens/rating_screen.dart';

// --- ADDED THIS ENUM FOR BROWSESCREEN SORTING ---
enum TaskSortOption { newest, highestBudget }

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  // --- NEW: Private helper function to generate keywords ---
  List<String> _generateKeywords(String text) {
    if (text.isEmpty) return [];

    // Simple list of common English "stop words" to ignore.
    const stopWords = {
      'i', 'me', 'my', 'myself', 'we', 'our', 'ours', 'ourselves', 'you', 'your',
      'he', 'him', 'his', 'she', 'her', 'it', 'its', 'they', 'them', 'their',
      'what', 'which', 'who', 'whom', 'this', 'that', 'these', 'those', 'am',
      'is', 'are', 'was', 'were', 'be', 'been', 'being', 'have', 'has', 'had',
      'do', 'does', 'did', 'a', 'an', 'the', 'and', 'but', 'if', 'or', 'because',
      'as', 'until', 'while', 'of', 'at', 'by', 'for', 'with', 'about', 'against',
      'between', 'into', 'through', 'during', 'before', 'after', 'above', 'below',
      'to', 'from', 'up', 'down', 'in', 'out', 'on', 'off', 'over', 'under', 'again',
      'further', 'then', 'once', 'here', 'there', 'when', 'where', 'why', 'how',
      'all', 'any', 'both', 'each', 'few', 'more', 'most', 'other', 'some', 'such',
      'no', 'nor', 'not', 'only', 'own', 'same', 'so', 'than', 'too', 'very', 's', 't', 'can', 'will', 'just', 'don', 'should', 'now'
    };

    final String lowerCaseText = text.toLowerCase();
    final RegExp wordRegex = RegExp(r'\w+');
    final Iterable<Match> matches = wordRegex.allMatches(lowerCaseText);

    final Set<String> keywords = matches
        .map((match) => match.group(0)!)
        .where((word) => !stopWords.contains(word) && word.length > 1)
        .toSet();

    return keywords.toList();
  }

  Future<String?> getDirectChatChannelId(String userId1, String userId2) async {
    final List<String> ids = [userId1, userId2];
    ids.sort();
    final chatChannelId = ids.join('_');
    final chatDoc = await _db.collection('chats').doc(chatChannelId).get();
    return chatDoc.exists ? chatChannelId : null;
  }

  Future<String> initiateDirectContact({
    required HelpifyUser currentUser,
    required HelpifyUser helper,
  }) async {
    const double contactFee = 20.0;
    if (currentUser.servCoinBalance < contactFee) {
      throw Exception(
          "Insufficient Serv Coins. You need $contactFee to contact this helper.");
    }
    final List<String> ids = [currentUser.id, helper.id];
    ids.sort();
    final chatChannelId = ids.join('_');
    final chatChannelDoc = _db.collection('chats').doc(chatChannelId);
    final posterRef = _db.collection('users').doc(currentUser.id);
    final transactionRef = posterRef.collection('transactions').doc();
    final batch = _db.batch();
    batch.update(posterRef, {'servCoinBalance': FieldValue.increment(-contactFee)});
    batch.set(transactionRef, {
      'amount': -contactFee,
      'type': TransactionType.commission.name,
      'description': 'Direct contact fee for ${helper.displayName}',
      'timestamp': FieldValue.serverTimestamp(),
    });
    batch.set(chatChannelDoc, {
      'taskTitle': "Direct Inquiry",
      'participantIds': ids,
      'participantNames': {
        currentUser.id: currentUser.displayName,
        helper.id: helper.displayName
      },
      'participantAvatars': {
        currentUser.id: currentUser.photoURL,
        helper.id: helper.photoURL
      },
      'lastMessage': "${currentUser.displayName} started a conversation.",
      'lastMessageTimestamp': FieldValue.serverTimestamp(),
      'lastMessageSenderId': currentUser.id,
    });
    await batch.commit();
    return chatChannelId;
  }

  Future<void> requestProInterview() async {
    final user = FirebaseAuth.instance.currentUser!;
    final interviewRequestRef =
    _db.collection('interviewRequests').doc(user.uid);
    final userRef = _db.collection('users').doc(user.uid);
    final batch = _db.batch();
    batch.set(interviewRequestRef, {
      'userId': user.uid,
      'userName': user.displayName,
      'requestTimestamp': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
    batch.update(userRef, {'interviewStatus': 'requested'});
    await batch.commit();
  }

  // --- MODIFIED: This function now creates searchable keywords ---
  Future<void> postNewTask({
    required Map<String, dynamic> taskData,
    required double postingFee,
  }) async {
    final user = FirebaseAuth.instance.currentUser!;

    // --- UPDATED: Keyword Generation Logic ---
    final String title = taskData['title'] ?? '';
    final String description = taskData['description'] ?? '';
    final String category = taskData['category'] ?? '';
    final String subCategory = taskData['subCategory'] ?? '';

    // Combine relevant text fields for comprehensive keywords
    final String combinedText = '$title $description $category $subCategory';

    // Generate keywords using the helper function
    taskData['keywords'] = _generateKeywords(combinedText);
    // --- END of updated logic ---

    final taskRef = _db.collection('tasks').doc();
    final userRef = _db.collection('users').doc(user.uid);
    final transactionRef = userRef.collection('transactions').doc();
    final batch = _db.batch();

    batch.set(taskRef, taskData); // Save the task with the new keywords
    batch.update(userRef, {'servCoinBalance': FieldValue.increment(-postingFee)});
    batch.set(transactionRef, {
      'amount': -postingFee,
      'type': TransactionType.commission.name,
      'description': 'Fee for posting: "${taskData['title']}"',
      'relatedTaskId': taskRef.id,
      'timestamp': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  // --- NEW: Function to get tasks based on a list of keywords ---
  Stream<QuerySnapshot<Map<String, dynamic>>> getTasksByKeywords({
    required List<String> keywords,
    required String currentUserId,
    TaskSortOption? sortOption,
  }) {
    if (keywords.isEmpty) {
      // Return an empty stream if there are no keywords to search for.
      return const Stream.empty();
    }

    Query<Map<String, dynamic>> query = _db
        .collection('tasks')
        .where('status', isEqualTo: 'open')
        .where('posterId', isNotEqualTo: currentUserId)
        .where('keywords', arrayContainsAny: keywords);

    if (sortOption != null) {
      switch (sortOption) {
        case TaskSortOption.highestBudget:
          query = query.orderBy('budget', descending: true);
          break;
        case TaskSortOption.newest:
          query = query.orderBy('timestamp', descending: true);
          break;
      }
    } else {
      query = query.orderBy('timestamp', descending: true);
    }

    return query.snapshots();
  }

  Future<void> acceptOffer(String taskId, String offerId) async {
    final callable = _functions.httpsCallable('acceptOffer');
    await callable.call(<String, dynamic>{
      'taskId': taskId,
      'offerId': offerId,
    });
  }

  Future<void> sendActionableChatMessage({
    required String chatChannelId,
    required String senderId,
    required String text,
    required String actionType,
    double? offerAmount,
  }) async {
    final messagesRef =
    _db.collection('chats').doc(chatChannelId).collection('messages');
    final channelRef = _db.collection('chats').doc(chatChannelId);

    if (actionType == 'poster_decline' || actionType == 'poster_counter') {
      final previousOffers = await messagesRef
          .where('offerAmount', isEqualTo: offerAmount)
          .where('offerStatus', isEqualTo: 'pending')
          .get();
      final batch = _db.batch();
      for (final doc in previousOffers.docs) {
        batch.update(doc.reference, {'offerStatus': actionType});
      }
      batch.update(channelRef, {
        'lastMessage': text,
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'lastMessageSenderId': senderId
      });
      await batch.commit();
    }
  }

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
      final offerMessage =
          "I've made an offer of LKR ${offerAmount.toStringAsFixed(2)}. ${initialMessage ?? ''}";

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
          'participantNames': {
            helper.id: helper.displayName,
            task.posterId: task.posterName
          },
          'participantAvatars': {
            helper.id: helper.photoURL,
            task.posterId: task.posterAvatarUrl
          },
          'lastMessage': offerMessage,
          'lastMessageTimestamp': FieldValue.serverTimestamp(),
          'lastMessageSenderId': helper.id,
        },
        SetOptions(merge: true),
      );
      initialBatch.update(taskDoc, {
        'status': 'negotiating',
        'participantIds': FieldValue.arrayUnion([helper.id])
      });
      await initialBatch.commit();

      await messagesCollection.doc().set({
        'senderId': helper.id,
        'text': offerMessage,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'offer',
        'offerAmount': offerAmount,
        'offerStatus': 'pending',
        'offerId': offerDoc.id,
      });

      if (context.mounted) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (ctx) => ConversationScreen(
            chatChannelId: chatChannelId,
            otherUserName: task.posterName,
            otherUserAvatarUrl: task.posterAvatarUrl,
            taskTitle: task.title,
          ),
        ));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error initiating chat: ${e.toString()}")));
    }
  }

  Future<void> sendOfferInChat({
    required String chatChannelId,
    required String senderId,
    required String text,
    required double offerAmount,
  }) async {
    final messagesRef =
    _db.collection('chats').doc(chatChannelId).collection('messages');
    final channelRef = _db.collection('chats').doc(chatChannelId);
    final batch = _db.batch();

    final previousOffers =
    await messagesRef.where('offerStatus', isEqualTo: 'pending').get();
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

    batch.update(channelRef, {
      'lastMessage': 'New Offer: LKR ${offerAmount.toStringAsFixed(2)}',
      'lastMessageTimestamp': FieldValue.serverTimestamp(),
      'lastMessageSenderId': senderId
    });
    await batch.commit();
  }

  Future<void> helperStartsJourney(String taskId) async {
    final helperId = FirebaseAuth.instance.currentUser!.uid;
    final taskRef = _db.collection('tasks').doc(taskId);
    final helperRef = _db.collection('users').doc(helperId);
    const double commissionFee = 25.0;

    final batch = _db.batch();

    batch.update(taskRef,
        {'status': 'en_route', 'helperStartedJourneyAt': FieldValue.serverTimestamp()});

    batch
        .update(helperRef, {'servCoinBalance': FieldValue.increment(-commissionFee)});

    final taskDoc = await taskRef.get();
    final taskTitle = taskDoc.data()?['title'] ?? 'Untitled Task';
    final transactionRef = helperRef.collection('transactions').doc();
    batch.set(transactionRef, {
      'amount': -commissionFee,
      'type': TransactionType.commission.name,
      'description': 'Commission for task: "$taskTitle"',
      'relatedTaskId': taskId,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<void> helperStartsOnlineTask(String taskId) async {
    await _db.collection('tasks').doc(taskId).update({
      'status': 'in_progress',
      'posterConfirmedStartAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> helperArrives(String taskId) async {
    final String confirmationCode =
    (1000 + (DateTime.now().millisecond % 9000)).toString();
    await _db.collection('tasks').doc(taskId).update({
      'status': 'arrived',
      'helperArrivedAt': FieldValue.serverTimestamp(),
      'confirmationCode': confirmationCode
    });
  }

  Future<void> helperConfirmsArrivalWithCode(String taskId, String code) async {
    final taskRef = _db.collection('tasks').doc(taskId);
    await _db.runTransaction((transaction) async {
      final taskDoc = await transaction.get(taskRef);
      if (!taskDoc.exists) throw Exception("Task not found!");
      if (taskDoc.data()?['confirmationCode'] != code) {
        throw Exception("Invalid confirmation code.");
      }
      transaction.update(taskRef, {
        'status': 'in_progress',
        'posterConfirmedStartAt': FieldValue.serverTimestamp(),
        'confirmationCode': FieldValue.delete()
      });
    });
  }

  Future<void> helperCompletesTask(String taskId, {String? proofImageUrl}) async {
    await _db.collection('tasks').doc(taskId).update({
      'status': 'pending_completion',
      'helperCompletedAt': FieldValue.serverTimestamp(),
      if (proofImageUrl != null) 'proofImageUrl': proofImageUrl
    });
  }

  Future<void> posterConfirmsCompletion(BuildContext context, Task task) async {
    if (context.mounted) {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => PaymentScreen(task: task)));
    }

    await _db.collection('tasks').doc(task.id).update({
      'status': 'pending_payment',
      'posterConfirmedCompletionAt': FieldValue.serverTimestamp()
    });
  }

  Future<void> markTaskAsPaid(BuildContext context, Task task) async {
    await _db.collection('tasks').doc(task.id).update(
        {'status': 'pending_rating', 'paymentCompletedAt': FieldValue.serverTimestamp()});
    final currentUser = FirebaseAuth.instance.currentUser!;
    final isPoster = currentUser.uid == task.posterId;
    final personToRateId = isPoster ? task.assignedHelperId! : task.posterId;
    final personToRateName =
    isPoster ? task.assignedHelperName! : task.posterName;
    final personToRateAvatarUrl =
    isPoster ? task.assignedHelperAvatarUrl : task.posterAvatarUrl;
    if (context.mounted) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => RatingScreen(
              task: task,
              personToRateId: personToRateId,
              personToRateName: personToRateName,
              personToRateAvatarUrl: personToRateAvatarUrl)));
    }
  }

  Future<void> submitReviewAndCloseTask(
      {required Task task,
        required String ratedUserId,
        required String reviewerId,
        required String reviewerName,
        String? reviewerAvatarUrl,
        required double rating,
        required String reviewText}) async {
    final ratedUserRef = _db.collection('users').doc(ratedUserId);
    final reviewRef = _db.collection('reviews').doc();
    final taskRef = _db.collection('tasks').doc(task.id);
    await _db.runTransaction((transaction) async {
      final ratedUserDoc = await transaction.get(ratedUserRef);
      if (!ratedUserDoc.exists) {
        throw Exception("User to be rated not found!");
      }
      final ratedUserData = HelpifyUser.fromFirestore(ratedUserDoc);
      final oldRatingTotal =
          ratedUserData.averageRating * ratedUserData.ratingCount;
      final newRatingCount = ratedUserData.ratingCount + 1;
      final newAverageRating = (oldRatingTotal + rating) / newRatingCount;
      transaction.update(ratedUserRef,
          {'averageRating': newAverageRating, 'ratingCount': newRatingCount});
      transaction.set(reviewRef, {
        'rating': rating,
        'reviewText': reviewText,
        'taskId': task.id,
        'taskTitle': task.title,
        'reviewerId': reviewerId,
        'reviewerName': reviewerName,
        'reviewerAvatarUrl': reviewerAvatarUrl,
        'ratedUserId': ratedUserId,
        'timestamp': FieldValue.serverTimestamp()
      });
      transaction.update(
          taskRef, {'status': 'closed', 'ratedAt': FieldValue.serverTimestamp()});
    });
  }

  Future<void> initiateDispute(
      {required String taskId,
        required String reason,
        required String initiatedByUserId}) async {
    await _db.collection('tasks').doc(taskId).update({
      'status': 'in_dispute',
      'disputeReason': reason,
      'disputeInitiatorId': initiatedByUserId,
      'disputeTimestamp': FieldValue.serverTimestamp()
    });
  }

  Future<void> cancelTask(
      {required String taskId,
        required String reason,
        required String cancelledById}) async {
    await _db.collection('tasks').doc(taskId).update({
      'status': 'cancelled',
      'cancellationReason': reason,
      'cancelledBy': cancelledById,
      'cancellationTimestamp': FieldValue.serverTimestamp()
    });
  }

  Future<void> requestTaskModification(
      {required String taskId,
        required String description,
        required double additionalCost}) async {
    await _db.collection('tasks').doc(taskId).collection('modifications').add({
      'description': description,
      'additionalCost': additionalCost,
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp()
    });
  }

  Future<void> respondToModification(
      {required String taskId,
        required String modificationId,
        required double additionalCost,
        required bool isApproved}) async {
    final taskRef = _db.collection('tasks').doc(taskId);
    final modificationRef = taskRef.collection('modifications').doc(modificationId);
    if (isApproved) {
      await _db.runTransaction((transaction) async {
        final taskDoc = await transaction.get(taskRef);
        if (!taskDoc.exists) throw Exception("Task not found!");
        final currentFinalAmount =
            (taskDoc.data()?['finalAmount'] as num?)?.toDouble() ?? 0.0;
        final newFinalAmount = currentFinalAmount + additionalCost;
        transaction.update(taskRef, {'finalAmount': newFinalAmount});
        transaction.update(modificationRef, {'status': 'approved'});
      });
    } else {
      await modificationRef.update({'status': 'rejected'});
    }
  }
}