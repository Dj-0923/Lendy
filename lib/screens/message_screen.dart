import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';
import '../utils/responsive_layout.dart';
import '../widgets/app_notice.dart';

class MessageScreen extends StatefulWidget {
  const MessageScreen({super.key, required this.onBackTap});

  final VoidCallback onBackTap;

  @override
  State<MessageScreen> createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen> {
  final _messageController = TextEditingController();
  Stream<QuerySnapshot<Map<String, dynamic>>>? _messagesStream;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _adminProfileStream;
  String? _streamUserId;
  bool _sending = false;

  String _chatName(String name) => String.fromCharCodes(name.runes.take(150));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userId = context.read<AuthProvider>().currentUser?.id;
    if (userId != null && userId != _streamUserId) {
      _streamUserId = userId;
      _adminProfileStream = FirebaseFirestore.instance
          .collection('publicProfiles')
          .doc('admin')
          .snapshots();
      _messagesStream = FirebaseFirestore.instance
          .collection('chats')
          .doc(userId)
          .collection('messages')
          .orderBy('createdAt')
          .snapshots();
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final user = context.read<AuthProvider>().currentUser;
    final text = _messageController.text.trim();
    if (_sending || user == null || text.isEmpty) return;

    setState(() => _sending = true);
    try {
      final chatRef = FirebaseFirestore.instance
          .collection('chats')
          .doc(user.id);
      final messageRef = chatRef.collection('messages').doc();
      final batch = FirebaseFirestore.instance.batch();
      batch.set(chatRef, {
        'userId': user.id,
        'userName': _chatName(user.fullName),
        'userEmail': user.email,
        'lastMessage': text,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastSenderId': user.id,
        'lastSenderRole': 'user',
      }, SetOptions(merge: true));
      batch.set(messageRef, {
        'senderId': user.id,
        'senderName': _chatName(user.fullName),
        'senderRole': 'user',
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      _messageController.clear();
    } catch (error) {
      if (mounted) {
        AppNotice.show(
          context,
          'Could not send message: $error',
          type: AppNoticeType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    return MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(timestamp.toDate()));
  }

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    final today = DateUtils.dateOnly(DateTime.now());
    final messageDate = DateUtils.dateOnly(date);
    if (messageDate == today) return 'Today';
    if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    }
    return MaterialLocalizations.of(context).formatMediumDate(date);
  }

  bool _isSameDate(Timestamp first, Timestamp second) {
    final a = first.toDate();
    final b = second.toDate();
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _adminAvatar(
    Map<String, dynamic>? profile, {
    required double radius,
    String? photoOverride,
  }) {
    final photo = photoOverride ?? profile?['photo'];
    ImageProvider? image;
    if (photo is String && photo.startsWith('data:image/')) {
      final separator = photo.indexOf(',');
      if (separator > 0) {
        try {
          image = MemoryImage(base64Decode(photo.substring(separator + 1)));
        } on FormatException {
          image = null;
        }
      }
    } else if (photo is String && Uri.tryParse(photo)?.hasScheme == true) {
      image = NetworkImage(photo);
    }

    return CircleAvatar(
      key: Key('messages-admin-avatar-${radius.toInt()}'),
      radius: radius,
      backgroundColor: AppColors.primaryLight,
      backgroundImage: image,
      child: image == null
          ? const Icon(Icons.admin_panel_settings_outlined, color: Colors.white)
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _adminProfileStream,
      builder: (context, profileSnapshot) {
        final adminProfile = profileSnapshot.data?.data();
        final savedAdminName = adminProfile?['name'];
        final adminName = savedAdminName is String && savedAdminName.isNotEmpty
            ? savedAdminName
            : 'Lendy Admin';
        return Scaffold(
          backgroundColor: AppColors.background,
          body: Column(
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(
                  8,
                  MediaQuery.paddingOf(context).top + 6,
                  16,
                  10,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(color: AppColors.fieldBorder),
                  ),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Row(
                      children: [
                        IconButton(
                          key: const Key('messages-back'),
                          onPressed: widget.onBackTap,
                          tooltip: 'Back',
                          icon: const Icon(Icons.arrow_back),
                        ),
                        _adminAvatar(adminProfile, radius: 21),
                        const SizedBox(width: 11),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              adminName,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Admin',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ResponsiveContent(
                  maxWidth: 760,
                  child: Column(
                    children: [
                      Expanded(
                        child: _messagesStream == null
                            ? const Center(
                                child: Text(
                                  'Sign in to message the admin.',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              )
                            : StreamBuilder<
                                QuerySnapshot<Map<String, dynamic>>
                              >(
                                stream: _messagesStream,
                                builder: (context, snapshot) {
                                  if (snapshot.hasError) {
                                    return Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(24),
                                        child: Text(
                                          'Could not load messages: ${snapshot.error}',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Colors.redAccent,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                  if (snapshot.connectionState ==
                                          ConnectionState.waiting &&
                                      !snapshot.hasData) {
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  }

                                  final messages = snapshot.data?.docs ?? [];
                                  if (messages.isEmpty) {
                                    return Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(28),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            _adminAvatar(
                                              adminProfile,
                                              radius: 34,
                                            ),
                                            const SizedBox(height: 14),
                                            Text(
                                              adminName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textPrimary,
                                                fontSize: 16,
                                              ),
                                            ),
                                            const SizedBox(height: 24),
                                            Text(
                                              'This is the start of the conversation',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: AppColors.textSecondary,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }

                                  return ListView.builder(
                                    reverse: true,
                                    padding: const EdgeInsets.all(16),
                                    itemCount: messages.length,
                                    itemBuilder: (context, index) {
                                      final documentIndex =
                                          messages.length - 1 - index;
                                      final data = messages[documentIndex]
                                          .data();
                                      final isMine =
                                          data['senderId'] == user?.id;
                                      final timestamp =
                                          data['createdAt'] is Timestamp
                                          ? data['createdAt'] as Timestamp
                                          : null;
                                      final olderTimestamp =
                                          documentIndex > 0 &&
                                              messages[documentIndex - 1]
                                                      .data()['createdAt']
                                                  is Timestamp
                                          ? messages[documentIndex - 1]
                                                    .data()['createdAt']
                                                as Timestamp
                                          : null;
                                      final startsNewDate =
                                          timestamp != null &&
                                          (olderTimestamp == null ||
                                              !_isSameDate(
                                                timestamp,
                                                olderTimestamp,
                                              ));
                                      return Column(
                                        children: [
                                          if (startsNewDate) ...[
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 12,
                                                  ),
                                              child: Text(
                                                _formatDate(timestamp),
                                                style: const TextStyle(
                                                  color:
                                                      AppColors.textSecondary,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ],
                                          Align(
                                            alignment: isMine
                                                ? Alignment.centerRight
                                                : Alignment.centerLeft,
                                            child: isMine
                                                ? _messageBubble(
                                                    context,
                                                    data,
                                                    timestamp,
                                                    isMine: true,
                                                  )
                                                : Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.end,
                                                    children: [
                                                      _adminAvatar(
                                                        adminProfile,
                                                        radius: 14,
                                                        photoOverride:
                                                            data['senderPhoto']
                                                                as String?,
                                                      ),
                                                      const SizedBox(width: 8),
                                                      _messageBubble(
                                                        context,
                                                        data,
                                                        timestamp,
                                                        isMine: false,
                                                      ),
                                                    ],
                                                  ),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                              ),
                      ),
                      Container(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          border: Border(
                            top: BorderSide(color: AppColors.fieldBorder),
                          ),
                        ),
                        child: SafeArea(
                          top: false,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _messageController,
                                  minLines: 1,
                                  maxLines: 4,
                                  maxLength: 500,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  onSubmitted: (_) => _sendMessage(),
                                  decoration: InputDecoration(
                                    hintText: 'Message the admin...',
                                    filled: true,
                                    fillColor: AppColors.fieldFill,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    counterText: '',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(24),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton.filled(
                                onPressed: _sending || user == null
                                    ? null
                                    : _sendMessage,
                                style: IconButton.styleFrom(
                                  backgroundColor: AppColors.primaryLight,
                                  foregroundColor: Colors.white,
                                ),
                                tooltip: 'Send message',
                                icon: _sending
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.send_rounded, size: 19),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _messageBubble(
    BuildContext context,
    Map<String, dynamic> data,
    Timestamp? timestamp, {
    required bool isMine,
  }) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * (isMine ? 0.76 : 0.68),
      ),
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: isMine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (timestamp != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4, left: 8, right: 8),
              child: Text(
                _formatTime(timestamp),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isMine ? AppColors.primaryLight : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: isMine ? null : Border.all(color: AppColors.fieldBorder),
            ),
            child: Text(
              data['text'] as String? ?? '',
              style: TextStyle(
                color: isMine ? Colors.white : AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
