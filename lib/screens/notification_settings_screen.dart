// lib/screens/notification_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/notification_provider.dart';
import '../theme/app_colors.dart';
import '../utils/responsive_layout.dart';
import '../widgets/simple_header.dart';
import '../widgets/toggle_setting_row.dart';

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final notificationProvider = context.watch<NotificationProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          const SimpleHeader(title: 'Notification'),
          Expanded(
            child: ResponsiveContent(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const _SectionTitle('Request'),
                  const SizedBox(height: 10),
                  ToggleSettingRow(
                    title: 'Request approved / rejected',
                    subtitle: 'Get notified when Admin responds',
                    value: notificationProvider.requestUpdatesEnabled,
                    onChanged: notificationProvider.setRequestUpdatesEnabled,
                  ),
                  ToggleSettingRow(
                    title: 'Returns reminders',
                    subtitle: 'Alert me one day before an item is due',
                    value: notificationProvider.returnRemindersEnabled,
                    onChanged: notificationProvider.setReturnRemindersEnabled,
                  ),
                  const SizedBox(height: 12),
                  const _SectionTitle('General'),
                  const SizedBox(height: 10),
                  ToggleSettingRow(
                    title: 'Push notification',
                    subtitle:
                        'Allow Lendy to send notifications to this device',
                    value: notificationProvider.pushNotificationsEnabled,
                    onChanged: notificationProvider.setPushNotificationsEnabled,
                  ),
                  if (notificationProvider.permissionMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        notificationProvider.permissionMessage!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  if (notificationProvider.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        notificationProvider.errorMessage!,
                        style: const TextStyle(color: Colors.redAccent),
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    );
  }
}
