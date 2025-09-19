// lib/services/chat_navigation.dart — route-friendly, legacy-safe
import 'package:flutter/material.dart';
import 'chat_service_compat.dart';

class ChatNavigation {
  ChatNavigation._();
  static final ChatNavigation instance = ChatNavigation._();

  Future<void> openChat({
    required BuildContext context,
    required String otherUserId,
    String? taskId,
    String? taskTitle,
    String? otherUserName,
    String? highlightOfferId,
  }) async {
    final cid = await ChatServiceCompat.instance.createOrGetChannel(
      otherUserId,
      taskId: taskId,
      taskTitle: taskTitle,
      participantNames: { otherUserId: otherUserName ?? 'User' },
    );

    if (!context.mounted) return;

    Navigator.of(context).pushNamed('/conversation', arguments: {
      'chatChannelId': cid,
      'otherUserId': otherUserId,
      'helperId': otherUserId,
      'taskId': taskId,
      'taskTitle': taskTitle,
      'otherUserName': otherUserName,
      'helperName': otherUserName,
      'highlightOfferId': highlightOfferId,
    });
  }
}
