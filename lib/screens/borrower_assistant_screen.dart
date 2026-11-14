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
  static const _suggestions = [
    'Available items?',
    'Camera to borrow?',
    'Request status?',
    'Next due date?',
  ];
  static const _welcomeMessage = _AssistantMessage(
    text:
        'Hi! You can ask in English, Tagalog, or Taglish about Lendy equipment, your profile, or your own loans and requests. I will answer from information saved in Lendy and let you know when a detail is not available.',
    fromUser: false,
  );

  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_AssistantMessage> _messages = [_welcomeMessage];
  bool _sending = false;
  bool _loadingConversation = false;
  bool _initializedUser = false;
  bool _initialQuestionQueued = false;
  String? _loadedUserId;
  int _loadGeneration = 0;
  int _conversationGeneration = 0;
  Timer? _expirationTimer;
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
    _expirationTimer?.cancel();
    _expirationTimer = null;
    _conversationGeneration++;
    _conversationStartedAt = null;
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
        _conversationStartedAt = conversation.startedAt;
        _scheduleExpiration(userId, conversation.startedAt);
        _messages
          ..clear()
          ..addAll(
            conversation.messages.map(
              (message) => _AssistantMessage(
                text: message.text,
                fromUser: message.fromUser,
                items: message.items,
              ),
            ),
          );
      }
      setState(() => _loadingConversation = false);
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
    _expirationTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendQuestion([String? suggestion]) async {
    final question = (suggestion ?? _controller.text).trim();
    if (question.isEmpty || _sending || _loadingConversation) return;
    final userId = context.read<AuthProvider>().currentUser?.id;
    _controller.clear();
    setState(() {
      if (_conversationStartedAt == null) {
        _conversationStartedAt = DateTime.now();
        if (userId != null) {
          _scheduleExpiration(userId, _conversationStartedAt!);
        }
      }
      _sending = true;
      _messages.add(_AssistantMessage(text: question, fromUser: true));
    });
    final conversationGeneration = _conversationGeneration;
    _scrollToBottom();
    await _saveConversation(userId);

    try {
      final reply = await _service.ask(question);
      if (!_isCurrentConversation(userId, conversationGeneration)) return;
      setState(() {
        _messages.add(
          _AssistantMessage(
            text: reply.answer,
            fromUser: false,
            items: reply.items,
          ),
        );
      });
      await _saveConversation(userId);
    } on BorrowerAssistantApiException catch (error) {
      await _addErrorMessage(userId, conversationGeneration, error.message);
    } on TimeoutException {
      await _addErrorMessage(
        userId,
        conversationGeneration,
        'The assistant took too long to respond. Please try again.',
      );
    } on http.ClientException {
      debugPrint('Borrower assistant connection failed.');
      await _addErrorMessage(
        userId,
        conversationGeneration,
        'Could not reach the assistant service. Check your connection and try again.',
      );
    } on FormatException {
      await _addErrorMessage(
        userId,
        conversationGeneration,
        'The assistant returned an invalid response. Please try again.',
      );
    } catch (error) {
      debugPrint('Borrower assistant request failed: $error');
      await _addErrorMessage(
        userId,
        conversationGeneration,
        'The assistant is unavailable right now. Please try again.',
      );
    } finally {
      if (_isCurrentConversation(userId, conversationGeneration)) {
        setState(() => _sending = false);
        _scrollToBottom();
      }
    }
  }

  bool _isCurrentConversation(String? userId, int generation) =>
      mounted &&
      _loadedUserId == userId &&
      _conversationGeneration == generation;

  void _scheduleExpiration(String userId, DateTime startedAt) {
    _expirationTimer?.cancel();
    final remaining = startedAt.add(
      BorrowerAssistantConversationStore.expiration,
    ).difference(DateTime.now());
    _expirationTimer = Timer(
      remaining.isNegative ? Duration.zero : remaining,
      () => _expireConversation(userId, startedAt),
    );
  }

  void _expireConversation(String userId, DateTime startedAt) {
    if (!mounted ||
        _loadedUserId != userId ||
        _conversationStartedAt != startedAt) {
      return;
    }
    _expirationTimer = null;
    _conversationStartedAt = null;
    _conversationGeneration++;
    _messages
      ..clear()
      ..add(_welcomeMessage);
    setState(() => _sending = false);
    unawaited(_clearConversation(userId));
  }

  Future<void> _clearConversation(String userId) async {
    try {
      await BorrowerAssistantConversationStore.clear(userId);
    } catch (error) {
      debugPrint('Could not clear expired assistant conversation: $error');
      if (mounted && _loadedUserId == userId) {
        AppNotice.show(
          context,
          'The expired AI conversation could not be cleared from this device.',
          type: AppNoticeType.error,
        );
      }
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
    String message,
  ) async {
    if (!_isCurrentConversation(userId, conversationGeneration)) return;
    setState(() {
      _messages.add(_AssistantMessage(text: message, fromUser: false));
    });
    await _saveConversation(userId);
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
        title: const Text('AI Assistant'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
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
          if (!_sending && !_loadingConversation)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mga puwedeng itanong',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 0,
                    children: [
                      for (final suggestion in _suggestions)
                        ActionChip(
                          key: ValueKey('assistant-suggestion-$suggestion'),
                          visualDensity: VisualDensity.compact,
                          label: Text(suggestion),
                          onPressed: () => _sendQuestion(suggestion),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
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
                        hintText:
                            'Ask in English, Tagalog, or Taglish...',
                        counterText: '',
                        filled: true,
                        fillColor: Colors.white,
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
  });

  final String text;
  final bool fromUser;
  final List<BorrowerAssistantItem> items;
}

class _MessageBubble extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final color = message.fromUser ? AppColors.primary : Colors.white;
    final bubbleMaxWidth = (MediaQuery.sizeOf(context).width - 48).clamp(
      0.0,
      320.0,
    );
    return Align(
      alignment: message.fromUser
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
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
            for (final item in message.items)
              _AssistantLandscapeItemCard(
                key: ValueKey('assistant-landscape-item-${item.id}'),
                equipment: item.toEquipmentModel(
                  inventoryItem: equipmentProvider?.findById(item.id),
                ),
                requested: requestedItemIds.contains(item.id),
                onRequest: () => onRequest(item),
              ),
          ],
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
          final imageWidth = constraints.maxWidth < 250 ? 72.0 : 92.0;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: imageWidth,
                  height: 128,
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
                            Icons.location_on_outlined,
                            size: 13,
                            color: AppColors.textSecondary,
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
        child: Container(
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
                    final opacity = 0.25 + 0.75 * (1 - (phase - 0.5).abs() * 2);
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
      ),
    );
  }
}
