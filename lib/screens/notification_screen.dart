// lib/screens/notification_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/notification_provider.dart';
import '../theme/app_colors.dart';
import '../utils/responsive_layout.dart';
import '../widgets/notification_tile.dart';
import '../widgets/simple_header.dart';

class NotificationScreen extends StatefulWidget {
  final VoidCallback onBackTap;
  final bool isActive;

  const NotificationScreen({
    super.key,
    required this.onBackTap,
    required this.isActive,
  });

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  NotificationProvider? _notificationProvider;
  String? _lastMarkedUnreadIds;
  bool _markScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<NotificationProvider>();
    if (_notificationProvider != provider) {
      _notificationProvider?.removeListener(_scheduleMarkUnreadAsRead);
      _notificationProvider = provider..addListener(_scheduleMarkUnreadAsRead);
    }
    _scheduleMarkUnreadAsRead();
  }

  @override
  void didUpdateWidget(covariant NotificationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      _scheduleMarkUnreadAsRead();
    }
  }

  void _scheduleMarkUnreadAsRead() {
    if (!widget.isActive || _markScheduled) return;
    _markScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markScheduled = false;
      if (mounted) _markUnreadAsRead();
    });
  }

  void _markUnreadAsRead() {
    if (!widget.isActive) return;
    final provider = _notificationProvider;
    if (provider == null) return;
    final unreadIds =
        provider.notifications
            .where((notification) => !notification.isRead)
            .map((notification) => notification.id)
            .toList()
          ..sort();
    if (unreadIds.isEmpty) {
      _lastMarkedUnreadIds = null;
      return;
    }
    final signature = unreadIds.join('|');
    if (_lastMarkedUnreadIds == signature) return;
    _lastMarkedUnreadIds = signature;
    unawaited(provider.markAllRead());
  }

  @override
  void dispose() {
    _notificationProvider?.removeListener(_scheduleMarkUnreadAsRead);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notificationProvider = context.watch<NotificationProvider>();
    final notifications = notificationProvider.notifications;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          SimpleHeader(title: 'Notifications', onBack: widget.onBackTap),
          Expanded(
            child: ResponsiveContent(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Reminders, Approval, and Returns.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                      OutlinedButton(
                        onPressed: notificationProvider.markAllRead,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: const BorderSide(color: AppColors.fieldBorder),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: const Text(
                          'Mark all read',
                          style: TextStyle(fontSize: 12.5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (notificationProvider.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        notificationProvider.errorMessage!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  if (notifications.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Center(
                        child: Text(
                          'No notifications yet.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.fieldBorder),
                      ),
                      child: Column(
                        children: [
                          for (int i = 0; i < notifications.length; i++) ...[
                            NotificationTile(notification: notifications[i]),
                            if (i != notifications.length - 1)
                              const Divider(height: 1),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
