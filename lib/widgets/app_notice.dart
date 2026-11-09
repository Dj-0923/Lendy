import 'package:flutter/material.dart';

enum AppNoticeType { info, success, error }

class AppNotice {
  AppNotice._();

  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static const Duration defaultDuration = Duration(seconds: 4);

  static void show(
    BuildContext? context,
    String message, {
    AppNoticeType type = AppNoticeType.info,
    String? title,
    Duration duration = defaultDuration,
  }) {
    final messenger = context == null
        ? messengerKey.currentState
        : ScaffoldMessenger.maybeOf(context) ?? messengerKey.currentState;
    if (messenger == null) return;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: _NoticeCard(message: message, title: title, type: type),
          duration: duration,
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          elevation: 0,
          padding: EdgeInsets.zero,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        ),
      );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.message,
    required this.title,
    required this.type,
  });

  final String message;
  final String? title;
  final AppNoticeType type;

  @override
  Widget build(BuildContext context) {
    final color = switch (type) {
      AppNoticeType.info => const Color(0xFF16796F),
      AppNoticeType.success => const Color(0xFF22845A),
      AppNoticeType.error => const Color(0xFFC43D3D),
    };
    final icon = switch (type) {
      AppNoticeType.info => Icons.info_outline_rounded,
      AppNoticeType.success => Icons.check_circle_outline_rounded,
      AppNoticeType.error => Icons.error_outline_rounded,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 11),
          Expanded(
            child: title == null
                ? Text(
                    message,
                    style: const TextStyle(
                      color: Color(0xFF26332F),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title!,
                        style: TextStyle(
                          color: color,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        message,
                        style: const TextStyle(
                          color: Color(0xFF4F5B57),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
