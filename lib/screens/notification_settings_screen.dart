// lib/screens/notification_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/notification_provider.dart';
import '../theme/app_colors.dart';
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
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
          const Text(
            'Request',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          ToggleSettingRow(
            title: 'Request approved / rejected',
            subtitle: 'Get notified the moment Admin responds',
            value: notificationProvider.requestUpdatesEnabled,
            onChanged: notificationProvider.setRequestUpdatesEnabled,
          ),
          ToggleSettingRow(
            title: 'Returns reminders',
            subtitle: 'Alert me 1 day before an item is due',
            value: notificationProvider.returnRemindersEnabled,
            onChanged: notificationProvider.setReturnRemindersEnabled,
          ),
          const SizedBox(height: 12),
          const Text(
            'General',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
                        ToggleSettingRow(
                title: 'Push notification',
                subtitle: 'Allow Lendy to send notifications to this device',
                value: notificationProvider.pushNotificationsEnabled,
                onChanged: notificationProvider.setPushNotificationsEnabled,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
}