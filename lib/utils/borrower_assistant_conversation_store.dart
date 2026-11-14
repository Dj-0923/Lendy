import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../services/borrower_assistant_service.dart';

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
  });

  factory BorrowerAssistantConversationMessage.fromJson(
    Map<String, dynamic> json,
  ) {
    final text = json['text'];
    final fromUser = json['fromUser'];
    final rawItems = json['items'];
    if (text is! String || fromUser is! bool || rawItems is! List) {
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
    );
  }

  final String text;
  final bool fromUser;
  final List<BorrowerAssistantItem> items;

  Map<String, dynamic> toJson() => {
    'text': text,
    'fromUser': fromUser,
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
        throw const FormatException(
          'Saved assistant conversation is invalid.',
        );
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
        messages.add(
          BorrowerAssistantConversationMessage.fromJson(rawMessage),
        );
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

  static Future<void> clear(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    await _remove(preferences, _keyFor(userId));
  }

  static String _keyFor(String userId) => '$_keyPrefix$userId';

  static Future<void> _remove(
    SharedPreferences preferences,
    String key,
  ) async {
    if (!await preferences.remove(key)) {
      throw StateError('Could not clear the assistant conversation.');
    }
  }
}