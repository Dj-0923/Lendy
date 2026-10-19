// lib/screens/notification_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/notification_provider.dart';
import '../theme/app_colors.dart';
import '../utils/responsive_layout.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/notification_tile.dart';

class NotificationScreen extends StatelessWidget {
  final VoidCallback? onProfileTap;

  const NotificationScreen({super.key, this.onProfileTap});

  @override
  Widget build(BuildContext context) {
    final notificationProvider = context.watch<NotificationProvider>();
    final notifications = notificationProvider.notifications;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          DashboardHeader(title: 'Notifications', onProfileTap: onProfileTap),
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
