import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../models/equipment_model.dart';
import '../providers/auth_provider.dart';
import '../providers/equipment_provider.dart';
import '../providers/request_provider.dart';
import '../services/borrower_assistant_service.dart';
import '../theme/app_colors.dart';
import '../utils/borrower_assistant_conversation_store.dart';
import '../utils/responsive_layout.dart';
import '../utils/status_style.dart';
import '../widgets/app_notice.dart';
import '../widgets/status_badge.dart';
import 'request_form_screen.dart';

class BorrowerAssistantScreen extends StatefulWidget {
  const BorrowerAssistantScreen({
    super.key,
    this.service,
    this.initialQuestion,
  });

  final BorrowerAssistantService? service;
  final String? initialQuestion;

  @override
  State<BorrowerAssistantScreen> createState() =>
      _BorrowerAssistantScreenState();
}

class _BorrowerAssistantScreenState extends State<BorrowerAssistantScreen> {
  static var _requestSequence = 0;

  static const _suggestions = [
    'Available items?',
    'Camera to borrow?',
    'Request status?',
    'Next due date?',
  ];
  static const _welcomeMessage = _AssistantMessage(
    text:
        'Hi, I\'m Fabii! You can ask me in English, Tagalog, or Taglish about Lendy equipment, your profile, or your own loans and requests. I will answer from information saved in Lendy and let you know when a detail is not available.',
    fromUser: false,
  );

  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_AssistantMessage> _messages = [_welcomeMessage];
  bool _sending = false;
  bool _loadingConversation = false;
  bool _initializedUser = false;
  bool _hasStartedConversation = false;
  bool _initialQuestionQueued = false;
  String? _loadedUserId;
  int _loadGeneration = 0;
  int _conversationGeneration = 0;
  DateTime? _conversationStartedAt;

  BorrowerAssistantService get _service =>
      widget.service ?? BorrowerAssistantService();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userId = context.read<AuthProvider>().currentUser?.id;
    if (_initializedUser && userId == _loadedUserId) return;

    _initializedUser = true;
    _loadedUserId = userId;
    _conversationGeneration++;
    _conversationStartedAt = null;
    _hasStartedConversation = false;
    _messages
      ..clear()
      ..add(_welcomeMessage);
    _sending = false;
    _loadingConversation = userId != null;
    final generation = ++_loadGeneration;
    if (userId != null) {
      unawaited(_restoreConversation(userId, generation));
    } else {
      _queueInitialQuestion();
    }
  }

  void _queueInitialQuestion() {
    final question = widget.initialQuestion;
    if (question == null || _initialQuestionQueued) return;
    _initialQuestionQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_sendQuestion(question));
    });
  }

  Future<void> _restoreConversation(String userId, int generation) async {
    try {
      final conversation = await BorrowerAssistantConversationStore.load(
        userId,
      );
      if (!mounted ||
          generation != _loadGeneration ||
          userId != _loadedUserId) {
        return;
      }
      if (conversation != null) {
        _hasStartedConversation = conversation.messages.any(
          (message) => message.fromUser,
        );
        _conversationStartedAt = conversation.startedAt;
        _messages
          ..clear()
          ..addAll(
            conversation.messages.map(
              (message) => _AssistantMessage(
                text: message.text,
                fromUser: message.fromUser,
                items: message.items,
                requestId: message.requestId,
                replyToRequestId: message.replyToRequestId,
              ),
            ),
          );
      }
      setState(() => _loadingConversation = false);
      unawaited(_markReplyRead(userId));
      _queueInitialQuestion();
      _scrollToBottom();
    } catch (error) {
      if (!mounted ||
          generation != _loadGeneration ||
          userId != _loadedUserId) {
        return;
      }
      debugPrint('Could not restore assistant conversation: $error');
      setState(() => _loadingConversation = false);
      _queueInitialQuestion();
      AppNotice.show(
        context,
        'Could not restore your previous AI conversation. A new chat has started.',
        type: AppNoticeType.error,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendQuestion([String? suggestion]) async {
    final question = (suggestion ?? _controller.text).trim();
    if (question.isEmpty || _sending || _loadingConversation) return;
    final userId = context.read<AuthProvider>().currentUser?.id;
    final equipmentProvider = context.read<EquipmentProvider?>();
    final requestId =
        '${DateTime.now().microsecondsSinceEpoch}-${_requestSequence++}';
    late final DateTime startedAt;
    _controller.clear();
    setState(() {
      _conversationStartedAt ??= DateTime.now();
      startedAt = _conversationStartedAt!;
      _hasStartedConversation = true;
      _sending = true;
      _messages.add(
        _AssistantMessage(text: question, fromUser: true, requestId: requestId),
      );
    });
    final conversationGeneration = _conversationGeneration;
    _scrollToBottom();
    if (userId != null) {
      BorrowerAssistantConversationStore.markReplying(userId);
    }
    await _saveConversation(userId);

    try {
      final reply =
          _maintenanceQuestionReply(question, equipmentProvider) ??
          await _service.ask(question);
      if (_isCurrentConversation(userId, conversationGeneration)) {
        setState(() {
          _messages.add(
            _AssistantMessage(
              text: reply.answer,
              fromUser: false,
              items: reply.items,
              replyToRequestId: requestId,
            ),
          );
        });
        await _saveConversation(userId);
        if (_isCurrentConversation(userId, conversationGeneration)) {
          if (userId != null) {
            BorrowerAssistantConversationStore.clearReplying(userId);
          }
        } else {
          await _persistAssistantReplyWhenClosed(
            userId,
            startedAt,
            requestId,
            _AssistantMessage(
              text: reply.answer,
              fromUser: false,
              items: reply.items,
              replyToRequestId: requestId,
            ),
          );
        }
      } else {
        await _persistAssistantReplyWhenClosed(
          userId,
          startedAt,
          requestId,
          _AssistantMessage(
            text: reply.answer,
            fromUser: false,
            items: reply.items,
            replyToRequestId: requestId,
          ),
        );
      }
    } on BorrowerAssistantApiException catch (error) {
      await _addErrorMessage(
        userId,
        conversationGeneration,
        startedAt,
        requestId,
        error.message,
      );
    } on TimeoutException {
      await _addErrorMessage(
        userId,
        conversationGeneration,
        startedAt,
        requestId,
        'The assistant took too long to respond. Please try again.',
      );
    } on http.ClientException {
      debugPrint('Borrower assistant connection failed.');
      await _addErrorMessage(
        userId,
        conversationGeneration,
        startedAt,
        requestId,
        'Could not reach the assistant service. Check your connection and try again.',
      );
    } on FormatException {
      await _addErrorMessage(
        userId,
        conversationGeneration,
        startedAt,
        requestId,
        'The assistant returned an invalid response. Please try again.',
      );
    } catch (error) {
      debugPrint('Borrower assistant request failed: $error');
      await _addErrorMessage(
        userId,
        conversationGeneration,
        startedAt,
        requestId,
        'The assistant is unavailable right now. Please try again.',
      );
    } finally {
      if (_isCurrentConversation(userId, conversationGeneration)) {
        setState(() => _sending = false);
        _scrollToBottom();
      }
    }
  }

  BorrowerAssistantReply? _maintenanceQuestionReply(
    String question,
    EquipmentProvider? equipmentProvider,
  ) {
    if (!RegExp(
      r'\b(?:maintenance|under repair|being repaired|for repair)\b',
      caseSensitive: false,
    ).hasMatch(question)) {
      return null;
    }

    if (equipmentProvider == null) return null;
    final lowerQuestion = question.toLowerCase();
    final filipino = RegExp(
      r'\b(?:ano|anong|mga|wala|ilan|may|na|ng)\b',
    ).hasMatch(lowerQuestion);
    if (equipmentProvider.isLoading || equipmentProvider.loadError != null) {
      return BorrowerAssistantReply(
        answer: filipino
            ? 'Hindi ko ma-check ang status ng inventory ngayon. Pakisubukan ulit mamaya.'
            : 'I cannot check the inventory status right now. Please try again later.',
        items: const [],
      );
    }

    final equipment = equipmentProvider.allEquipment;
    EquipmentModel? mentionedItem;
    for (final item in equipment) {
      final identifiers = [item.name, item.id, item.assetTag];
      if (identifiers.any(
        (identifier) =>
            identifier != null &&
            identifier.isNotEmpty &&
            lowerQuestion.contains(identifier.toLowerCase()),
      )) {
        mentionedItem = item;
        break;
      }
    }
    final matches = mentionedItem == null
        ? equipment
              .where((item) => item.status == EquipmentStatus.maintenance)
              .toList()
        : [mentionedItem];
    final items = [
      for (final item in matches)
        BorrowerAssistantItem(
          id: item.id,
          name: item.name,
          category: item.displayCategory,
          location: item.location,
          tag: item.assetTag ?? '',
          statusLabel: item.status.label,
          status: item.status,
        ),
    ];

    final answer = mentionedItem != null
        ? filipino
              ? '${mentionedItem.name} ay kasalukuyang ${mentionedItem.status.label}${mentionedItem.status == EquipmentStatus.maintenance ? "." : ", hindi naka-maintenance."}'
              : '${mentionedItem.name} is currently ${mentionedItem.status.label}${mentionedItem.status == EquipmentStatus.maintenance ? "." : ", not in maintenance."}'
        : matches.isEmpty
        ? filipino
              ? 'Walang item na nasa maintenance sa ngayon.'
              : 'There are no items in maintenance right now.'
        : filipino
        ? 'May ${matches.length} item na nasa maintenance sa ngayon.'
        : '${matches.length} item(s) are currently in maintenance.';

    return BorrowerAssistantReply(answer: answer, items: items);
  }

  bool _isCurrentConversation(String? userId, int generation) =>
      mounted &&
      ModalRoute.of(context)?.isCurrent == true &&
      _loadedUserId == userId &&
      _conversationGeneration == generation;

  Future<void> _clearConversation(String userId) async {
    try {
      await BorrowerAssistantConversationStore.clear(userId);
    } catch (error) {
      debugPrint('Could not clear assistant conversation: $error');
      if (mounted && _loadedUserId == userId) {
        AppNotice.show(
          context,
          'The AI conversation could not be deleted from this device.',
          type: AppNoticeType.error,
        );
      }
    }
  }

  Future<void> _deleteConversation() async {
    final userId = _loadedUserId;
    final shouldDelete = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        backgroundColor: Colors.white,
        icon: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.danger.withValues(alpha: 0.10),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.delete_outline,
            color: AppColors.danger,
            size: 24,
          ),
        ),
        title: const Text(
          'Delete conversation?',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: const Text(
          'This will permanently remove all messages and item cards in this chat.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            height: 1.45,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.fieldBorder),
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  key: const Key('delete-conversation-confirm'),
                  onPressed: () => Navigator.pop(dialogContext, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Delete'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (shouldDelete != true) return;

    _conversationGeneration++;
    _conversationStartedAt = null;
    _hasStartedConversation = false;
    _messages
      ..clear()
      ..add(_welcomeMessage);
    setState(() => _sending = false);
    if (userId != null) {
      await _clearConversation(userId);
    }
  }

  Future<void> _saveConversation(String? userId) async {
    final startedAt = _conversationStartedAt;
    if (userId == null || startedAt == null) return;
    try {
      await BorrowerAssistantConversationStore.save(
        userId,
        BorrowerAssistantConversation(
          startedAt: startedAt,
          messages: [
            for (final message in _messages)
              BorrowerAssistantConversationMessage(
                text: message.text,
                fromUser: message.fromUser,
                items: message.items,
                requestId: message.requestId,
                replyToRequestId: message.replyToRequestId,
              ),
          ],
        ),
      );
    } catch (error) {
      debugPrint('Could not save assistant conversation: $error');
      if (mounted && _loadedUserId == userId) {
        AppNotice.show(
          context,
          'Your AI conversation could not be saved on this device.',
          type: AppNoticeType.error,
        );
      }
    }
  }

  Future<void> _addErrorMessage(
    String? userId,
    int conversationGeneration,
    DateTime startedAt,
    String requestId,
    String message,
  ) async {
    final errorReply = _AssistantMessage(
      text: message,
      fromUser: false,
      replyToRequestId: requestId,
    );
    if (_isCurrentConversation(userId, conversationGeneration)) {
      setState(() => _messages.add(errorReply));
      await _saveConversation(userId);
      if (_isCurrentConversation(userId, conversationGeneration)) {
        if (userId != null) {
          BorrowerAssistantConversationStore.clearReplying(userId);
        }
      } else {
        await _persistAssistantReplyWhenClosed(
          userId,
          startedAt,
          requestId,
          errorReply,
        );
      }
      return;
    }

    await _persistAssistantReplyWhenClosed(
      userId,
      startedAt,
      requestId,
      errorReply,
    );
  }

  Future<void> _persistAssistantReplyWhenClosed(
    String? userId,
    DateTime startedAt,
    String requestId,
    _AssistantMessage reply,
  ) async {
    if (userId == null) return;
    try {
      final saved =
          await BorrowerAssistantConversationStore.appendAssistantReply(
            userId: userId,
            startedAt: startedAt,
            requestId: requestId,
            reply: BorrowerAssistantConversationMessage(
              text: reply.text,
              fromUser: false,
              items: reply.items,
              replyToRequestId: requestId,
            ),
          );
      if (saved) {
        await BorrowerAssistantConversationStore.markReplyAvailable(userId);
      } else {
        BorrowerAssistantConversationStore.clearReplying(userId);
      }
    } catch (error) {
      debugPrint('Could not save assistant reply after closing chat: $error');
    }
  }

  Future<void> _markReplyRead(String userId) async {
    try {
      await BorrowerAssistantConversationStore.markReplyRead(userId);
    } catch (error) {
      debugPrint('Could not clear assistant reply notification: $error');
      if (mounted && _loadedUserId == userId) {
        AppNotice.show(
          context,
          'The AI reply notification could not be cleared.',
          type: AppNoticeType.error,
        );
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final equipmentProvider = context.watch<EquipmentProvider?>();
    final requestProvider = context.watch<RequestProvider?>();
    final userId = context.watch<AuthProvider>().currentUser?.id;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            const _AssistantAvatar(
              avatarKey: Key('assistant-header-avatar'),
              radius: 24,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Fabii',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      height: 1,
                    ),
                  ),
                  Row(
                    children: [
                      const Flexible(
                        child: Text(
                          "your AI assistant",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white70,
                            height: 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        key: const Key('assistant-online-indicator'),
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF55D98B),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Online',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white70,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        titleSpacing: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            key: const Key('assistant-conversation-menu'),
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'delete') {
                unawaited(_deleteConversation());
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem<String>(
                key: Key('delete-conversation-menu-item'),
                value: 'delete',
                child: Text('Delete conversation'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                for (final message in _messages)
                  _MessageBubble(
                    message: message,
                    equipmentProvider: equipmentProvider,
                    requestedItemIds: {
                      for (final item in message.items)
                        if (userId != null &&
                            (requestProvider?.hasPendingRequest(
                                  userId,
                                  item.id,
                                ) ??
                                false))
                          item.id,
                    },
                    onRequest: _openRequestForm,
                  ),
                if (_sending) const _TypingIndicator(),
              ],
            ),
          ),
          if (!_hasStartedConversation && !_sending && !_loadingConversation)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              child: SizedBox(
                height: 40,
                child: ListView.separated(
                  key: const Key('assistant-suggestions-list'),
                  scrollDirection: Axis.horizontal,
                  itemCount: _suggestions.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final suggestion = _suggestions[index];
                    return ActionChip(
                      key: ValueKey('assistant-suggestion-$suggestion'),
                      visualDensity: VisualDensity.compact,
                      label: Text(suggestion),
                      onPressed: () => _sendQuestion(suggestion),
                    );
                  },
                ),
              ),
            ),
          SafeArea(
            top: false,
            child: ResponsiveContent(
              maxWidth: 980,
              child: Container(
                key: const Key('assistant-composer'),
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: AppColors.fieldBorder)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        enabled: !_sending && !_loadingConversation,
                        maxLength: 200,
                        maxLines: 4,
                        minLines: 1,
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: (_) => _sendQuestion(),
                        decoration: InputDecoration(
                          hintText: 'Ask in English, Tagalog, or Taglish...',
                          counterText: '',
                          filled: true,
                          fillColor: AppColors.fieldFill,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      key: const Key('borrower-assistant-send'),
                      tooltip: 'Send question',
                      onPressed: _sending || _loadingConversation
                          ? null
                          : _sendQuestion,
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openRequestForm(BorrowerAssistantItem item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RequestFormScreen(equipment: item.toEquipmentModel()),
      ),
    );
  }
}

class _AssistantMessage {
  const _AssistantMessage({
    required this.text,
    required this.fromUser,
    this.items = const [],
    this.requestId,
    this.replyToRequestId,
  });

  final String text;
  final bool fromUser;
  final List<BorrowerAssistantItem> items;
  final String? requestId;
  final String? replyToRequestId;
}

class _MessageBubble extends StatefulWidget {
  const _MessageBubble({
    required this.message,
    required this.equipmentProvider,
    required this.requestedItemIds,
    required this.onRequest,
  });

  final _AssistantMessage message;
  final EquipmentProvider? equipmentProvider;
  final Set<String> requestedItemIds;
  final ValueChanged<BorrowerAssistantItem> onRequest;

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  int _visibleItemCount = 2;

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final color = message.fromUser ? AppColors.primary : Colors.white;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final tabletItemMessage =
        !message.fromUser && message.items.isNotEmpty && screenWidth >= 600;
    final bubbleMaxWidth = (screenWidth - (message.fromUser ? 48 : 76)).clamp(
      0.0,
      tabletItemMessage ? 640.0 : 320.0,
    );
    final bubble = Container(
      constraints: BoxConstraints(maxWidth: bubbleMaxWidth),
      width: message.items.isNotEmpty ? bubbleMaxWidth : null,
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message.text,
            style: TextStyle(
              color: message.fromUser ? Colors.white : AppColors.textPrimary,
            ),
          ),
          if (message.items.isNotEmpty)
            LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = tabletItemMessage
                    ? (constraints.maxWidth - 8) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 8,
                  children: [
                    for (final item in message.items.take(_visibleItemCount))
                      SizedBox(
                        width: cardWidth,
                        child: _AssistantLandscapeItemCard(
                          key: ValueKey('assistant-landscape-item-${item.id}'),
                          equipment: item.toEquipmentModel(
                            inventoryItem: widget.equipmentProvider?.findById(
                              item.id,
                            ),
                          ),
                          requested: widget.requestedItemIds.contains(item.id),
                          onRequest: () => widget.onRequest(item),
                        ),
                      ),
                  ],
                );
              },
            ),
          if (message.items.length > 2)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: OutlinedButton(
                      key: const Key('assistant-show-more-items'),
                      onPressed: () => setState(() {
                        _visibleItemCount = _visibleItemCount == 2
                            ? message.items.length
                            : 2;
                      }),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.fieldBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        _visibleItemCount == 2
                            ? 'Show ${message.items.length - 2} more'
                            : 'Hide',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );

    if (message.fromUser) {
      return Align(alignment: Alignment.centerRight, child: bubble);
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: _AssistantAvatar(),
          ),
          const SizedBox(width: 8),
          Flexible(child: bubble),
        ],
      ),
    );
  }
}

class _AssistantAvatar extends StatelessWidget {
  const _AssistantAvatar({this.avatarKey, this.radius = 19});

  final Key? avatarKey;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      key: avatarKey ?? const Key('assistant-profile-avatar'),
      radius: radius,
      backgroundColor: AppColors.primaryLight,
      child: ClipOval(
        child: Image.asset(
          'assets/images/fabi_pfp.png',
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}

class _AssistantLandscapeItemCard extends StatelessWidget {
  const _AssistantLandscapeItemCard({
    super.key,
    required this.equipment,
    required this.requested,
    required this.onRequest,
  });

  final EquipmentModel equipment;
  final bool requested;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    final imageBytes = equipment.imageBytes;
    final isAvailable = equipment.status == EquipmentStatus.available;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final imageWidth = constraints.maxWidth < 220 ? 64.0 : 76.0;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: imageWidth,
                  height: 118,
                  child: ColoredBox(
                    color: Colors.white,
                    child: imageBytes == null
                        ? const Center(
                            child: Icon(
                              Icons.inventory_2_outlined,
                              color: AppColors.textSecondary,
                              size: 30,
                            ),
                          )
                        : Image.memory(
                            imageBytes,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const Center(
                              child: Icon(
                                Icons.inventory_2_outlined,
                                color: AppColors.textSecondary,
                                size: 30,
                              ),
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      equipment.displayCategory.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      equipment.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      equipment.assetTag?.isNotEmpty == true
                          ? equipment.assetTag!
                          : equipment.id,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    if (equipment.location.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 13,
                            color: AppColors.primaryLight,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              equipment.location,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 5),
                    StatusBadge(
                      style: equipmentStatusStyle(equipment.status),
                      uppercase: true,
                      compact: true,
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      height: 36,
                      child: ElevatedButton(
                        key: Key('assistant-request-item-${equipment.id}'),
                        onPressed: isAvailable && !requested ? onRequest : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryLight,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                        child: Text(
                          requested
                              ? 'Requested'
                              : isAvailable
                              ? 'Request'
                              : equipment.status.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Assistant is typing',
      child: Align(
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _AssistantAvatar(),
            const SizedBox(width: 6),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 5),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var index = 0; index < 3; index++)
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        final phase = (_controller.value + index / 3) % 1;
                        final opacity =
                            0.25 + 0.75 * (1 - (phase - 0.5).abs() * 2);
                        return Opacity(
                          opacity: opacity,
                          child: Container(
                            width: 7,
                            height: 7,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: const BoxDecoration(
                              color: AppColors.textSecondary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
