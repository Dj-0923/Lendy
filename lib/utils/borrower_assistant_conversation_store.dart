import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/borrower_assistant_service.dart';

enum BorrowerAssistantNoticeState { replying, replied }

class BorrowerAssistantReplyNotice {
  const BorrowerAssistantReplyNotice({
    required this.userId,
    required this.state,
  });

  final String userId;
  final BorrowerAssistantNoticeState state;
}

class BorrowerAssistantConversation {
  const BorrowerAssistantConversation({
    required this.startedAt,
    required this.messages,
  });

  final DateTime startedAt;
  final List<BorrowerAssistantConversationMessage> messages;
}

class BorrowerAssistantConversationMessage {
  const BorrowerAssistantConversationMessage({
    required this.text,
    required this.fromUser,
    this.items = const [],
    this.requestId,
    this.replyToRequestId,
  });

  factory BorrowerAssistantConversationMessage.fromJson(
    Map<String, dynamic> json,
  ) {
    final text = json['text'];
    final fromUser = json['fromUser'];
    final rawItems = json['items'];
    final requestId = json['requestId'];
    final replyToRequestId = json['replyToRequestId'];
    if (text is! String || fromUser is! bool || rawItems is! List) {
      throw const FormatException('Saved assistant conversation is invalid.');
    }
    if ((requestId != null && requestId is! String) ||
        (replyToRequestId != null && replyToRequestId is! String)) {
      throw const FormatException('Saved assistant conversation is invalid.');
    }

    final items = <BorrowerAssistantItem>[];
    for (final rawItem in rawItems) {
      if (rawItem is! Map<String, dynamic>) {
        throw const FormatException('Saved assistant item is invalid.');
      }
      items.add(BorrowerAssistantItem.fromJson(rawItem));
    }

    return BorrowerAssistantConversationMessage(
      text: text,
      fromUser: fromUser,
      items: items,
      requestId: requestId as String?,
      replyToRequestId: replyToRequestId as String?,
    );
  }

  final String text;
  final bool fromUser;
  final List<BorrowerAssistantItem> items;
  final String? requestId;
  final String? replyToRequestId;

  Map<String, dynamic> toJson() => {
    'text': text,
    'fromUser': fromUser,
    if (requestId != null) 'requestId': requestId,
    if (replyToRequestId != null) 'replyToRequestId': replyToRequestId,
    'items': [
      for (final item in items)
        {
          'id': item.id,
          'name': item.name,
          'category': item.category,
          'location': item.location,
          'tag': item.tag,
          'status': item.statusLabel,
        },
    ],
  };
}

class BorrowerAssistantConversationStore {
  BorrowerAssistantConversationStore._();

  static const expiration = Duration(hours: 24);
  static const _keyPrefix = 'borrower_assistant_conversation_';
  static const _unreadReplyKeyPrefix = 'borrower_assistant_unread_reply_';
  static final replyNotice = ValueNotifier<BorrowerAssistantReplyNotice?>(null);

  static void markReplying(String userId) {
    replyNotice.value = BorrowerAssistantReplyNotice(
      userId: userId,
      state: BorrowerAssistantNoticeState.replying,
    );
  }

  static void clearReplying(String userId) {
    final notice = replyNotice.value;
    if (notice?.userId == userId &&
        notice?.state == BorrowerAssistantNoticeState.replying) {
      replyNotice.value = null;
    }
  }

  static Future<void> restoreReplyNotice(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool(_unreadReplyKeyFor(userId)) == true) {
      replyNotice.value = BorrowerAssistantReplyNotice(
        userId: userId,
        state: BorrowerAssistantNoticeState.replied,
      );
      return;
    }

    final notice = replyNotice.value;
    if (notice?.userId == userId &&
        notice?.state == BorrowerAssistantNoticeState.replied) {
      replyNotice.value = null;
    }
  }

  static Future<void> markReplyAvailable(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.setBool(_unreadReplyKeyFor(userId), true)) {
      throw StateError('Could not save the assistant reply notification.');
    }
    replyNotice.value = BorrowerAssistantReplyNotice(
      userId: userId,
      state: BorrowerAssistantNoticeState.replied,
    );
  }

  static Future<void> markReplyRead(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    final key = _unreadReplyKeyFor(userId);
    if (preferences.getBool(key) == true &&
        !await preferences.setBool(key, false)) {
      throw StateError('Could not clear the assistant reply notification.');
    }
    final notice = replyNotice.value;
    if (notice?.userId == userId &&
        notice?.state == BorrowerAssistantNoticeState.replied) {
      replyNotice.value = null;
    }
  }

  static Future<BorrowerAssistantConversation?> load(
    String userId, {
    DateTime? now,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final key = _keyFor(userId);
    final savedConversation = preferences.getString(key);
    if (savedConversation == null) return null;

    try {
      final decoded = jsonDecode(savedConversation);
      if (decoded is! Map<String, dynamic> ||
          decoded['startedAt'] is! int ||
          decoded['messages'] is! List) {
        throw const FormatException('Saved assistant conversation is invalid.');
      }
      final startedAt = DateTime.fromMillisecondsSinceEpoch(
        decoded['startedAt'] as int,
      );
      if ((now ?? DateTime.now()).difference(startedAt) >= expiration) {
        await _remove(preferences, key);
        return null;
      }

      final messages = <BorrowerAssistantConversationMessage>[];
      for (final rawMessage in decoded['messages'] as List) {
        if (rawMessage is! Map<String, dynamic>) {
          throw const FormatException(
            'Saved assistant conversation is invalid.',
          );
        }
        messages.add(BorrowerAssistantConversationMessage.fromJson(rawMessage));
      }
      return BorrowerAssistantConversation(
        startedAt: startedAt,
        messages: messages,
      );
    } on FormatException {
      await _remove(preferences, key);
      rethrow;
    }
  }

  static Future<void> save(
    String userId,
    BorrowerAssistantConversation conversation,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(
      _keyFor(userId),
      jsonEncode({
        'startedAt': conversation.startedAt.millisecondsSinceEpoch,
        'messages': [
          for (final message in conversation.messages) message.toJson(),
        ],
      }),
    );
    if (!saved) {
      throw StateError('Could not save the assistant conversation.');
    }
  }

  static Future<bool> appendAssistantReply({
    required String userId,
    required DateTime startedAt,
    required String requestId,
    required BorrowerAssistantConversationMessage reply,
  }) async {
    final conversation = await load(userId);
    if (conversation == null ||
        conversation.startedAt.millisecondsSinceEpoch !=
            startedAt.millisecondsSinceEpoch) {
      return false;
    }
    final requestIndex = conversation.messages.indexWhere(
      (message) => message.fromUser && message.requestId == requestId,
    );
    if (requestIndex < 0) return false;

    if (conversation.messages.any(
      (message) => message.replyToRequestId == requestId,
    )) {
      return true;
    }

    final messages = [...conversation.messages]
      ..insert(requestIndex + 1, reply);
    await save(
      userId,
      BorrowerAssistantConversation(
        startedAt: conversation.startedAt,
        messages: messages,
      ),
    );
    return true;
  }

  static Future<void> clear(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    await _remove(preferences, _keyFor(userId));
    final unreadReplyKey = _unreadReplyKeyFor(userId);
    if (preferences.getBool(unreadReplyKey) == true &&
        !await preferences.remove(unreadReplyKey)) {
      throw StateError('Could not clear the assistant reply notification.');
    }
    if (replyNotice.value?.userId == userId) {
      replyNotice.value = null;
    }
  }

  static String _keyFor(String userId) => '$_keyPrefix$userId';
  static String _unreadReplyKeyFor(String userId) =>
      '$_unreadReplyKeyPrefix$userId';

  static Future<void> _remove(SharedPreferences preferences, String key) async {
    if (!await preferences.remove(key)) {
      throw StateError('Could not clear the assistant conversation.');
    }
  }
}
