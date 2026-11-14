import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../models/equipment_model.dart';
import '../providers/auth_provider.dart';
import '../providers/request_provider.dart';
import '../services/borrower_assistant_service.dart';
import '../theme/app_colors.dart';
import 'request_form_screen.dart';

class BorrowerAssistantScreen extends StatefulWidget {
  const BorrowerAssistantScreen({super.key, this.service});

  final BorrowerAssistantService? service;

  @override
  State<BorrowerAssistantScreen> createState() =>
      _BorrowerAssistantScreenState();
}

class _BorrowerAssistantScreenState extends State<BorrowerAssistantScreen> {
  static const _suggestions = [
    'How do I borrow an item?',
    'What items are available?',
    'I need a camera for recording',
    'When are my loans due?',
  ];

  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_AssistantMessage> _messages = [
    const _AssistantMessage(
      text:
          'Hi! I can answer questions about Lendy equipment, availability, item status, borrowing steps, and your active loan due dates. Describe what you need and I can show items you can request.',
      fromUser: false,
    ),
  ];
  bool _sending = false;

  BorrowerAssistantService get _service =>
      widget.service ?? BorrowerAssistantService();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendQuestion([String? suggestion]) async {
    final question = (suggestion ?? _controller.text).trim();
    if (question.isEmpty || _sending) return;
    _controller.clear();
    setState(() {
      _sending = true;
      _messages.add(_AssistantMessage(text: question, fromUser: true));
    });
    _scrollToBottom();

    try {
      final reply = await _service.ask(question);
      if (!mounted) return;
      setState(() {
        _messages.add(
          _AssistantMessage(
            text: reply.answer,
            fromUser: false,
            items: reply.items,
          ),
        );
      });
    } on BorrowerAssistantApiException catch (error) {
      _addErrorMessage(error.message);
    } on TimeoutException {
      _addErrorMessage(
        'The assistant took too long to respond. Please try again.',
      );
    } on http.ClientException {
      debugPrint('Borrower assistant connection failed.');
      _addErrorMessage(
        'Could not reach the assistant service. Check your connection and try again.',
      );
    } on FormatException {
      _addErrorMessage(
        'The assistant returned an invalid response. Please try again.',
      );
    } catch (error) {
      debugPrint('Borrower assistant request failed: $error');
      _addErrorMessage(
        'The assistant is unavailable right now. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        _scrollToBottom();
      }
    }
  }

  void _addErrorMessage(String message) {
    if (!mounted) return;
    setState(() {
      _messages.add(_AssistantMessage(text: message, fromUser: false));
    });
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
                if (_messages.length == 1 && !_sending) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final suggestion in _suggestions)
                        ActionChip(
                          label: Text(suggestion),
                          onPressed: () => _sendQuestion(suggestion),
                        ),
                    ],
                  ),
                ],
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
                      enabled: !_sending,
                      maxLength: 200,
                      maxLines: 4,
                      minLines: 1,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _sendQuestion(),
                      decoration: InputDecoration(
                        hintText: 'Ask about Lendy equipment or availability...',
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
                    onPressed: _sending ? null : _sendQuestion,
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
    required this.requestedItemIds,
    required this.onRequest,
  });

  final _AssistantMessage message;
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
              _SuggestedItemCard(
                item: item,
                requested: requestedItemIds.contains(item.id),
                onRequest: () => onRequest(item),
              ),
          ],
        ),
      ),
    );
  }
}

class _SuggestedItemCard extends StatelessWidget {
  const _SuggestedItemCard({
    required this.item,
    required this.requested,
    required this.onRequest,
  });

  final BorrowerAssistantItem item;
  final bool requested;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('assistant-item-card-${item.id}'),
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700)),
          if (item.category.isNotEmpty || item.location.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              [
                if (item.category.isNotEmpty) item.category,
                if (item.location.isNotEmpty) item.location,
              ].join(' • '),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            item.statusLabel,
            style: TextStyle(
              color: item.status == EquipmentStatus.available
                  ? AppColors.primary
                  : AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: Key('assistant-request-item-${item.id}'),
              onPressed:
                  requested || item.status != EquipmentStatus.available
                  ? null
                  : onRequest,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: Text(
                requested
                    ? 'Requested'
                    : item.status == EquipmentStatus.available
                    ? 'Request'
                    : item.statusLabel,
              ),
            ),
          ),
        ],
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
