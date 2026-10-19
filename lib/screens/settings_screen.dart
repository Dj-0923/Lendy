// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';
import '../utils/responsive_layout.dart';
import '../utils/simple_page_route.dart';
import '../widgets/simple_header.dart';
import '../widgets/settings_tile.dart';
import 'notification_settings_screen.dart';
import 'account_info_screen.dart';
import 'change_password_screen.dart';
import 'about_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          const SimpleHeader(title: 'Settings'),
          Expanded(
            child: ResponsiveContent(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  SettingsTile(
                    icon: Icons.notifications_outlined,
                    title: 'Notification',
                    subtitle: 'Manage your notification preferences',
                    onTap: () {
                      Navigator.push(
                        context,
                        simpleFadeRoute<void>(
                          (_) => const NotificationSettingsScreen(),
                        ),
                      );
                    },
                  ),
                  SettingsTile(
                    icon: Icons.person_outline,
                    title: 'Account Information',
                    subtitle: 'View and update your account details',
                    onTap: () {
                      Navigator.push(
                        context,
                        simpleFadeRoute<void>((_) => const AccountInfoScreen()),
                      );
                    },
                  ),
                  SettingsTile(
                    icon: Icons.lock_outline,
                    title: 'Change Password',
                    subtitle:
                        'Update your password to keep your account secure',
                    onTap: () {
                      Navigator.push(
                        context,
                        simpleFadeRoute<void>(
                          (_) => const ChangePasswordScreen(),
                        ),
                      );
                    },
                  ),
                  SettingsTile(
                    icon: Icons.info_outline,
                    title: 'About LENDY',
                    subtitle: 'Learn more about LENDY',
                    onTap: () {
                      Navigator.push(
                        context,
                        simpleFadeRoute<void>((_) => const AboutScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmLogout(context),
                      icon: const Icon(Icons.logout, size: 18),
                      label: const Text('Logout'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.redAccent),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
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
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log out?'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Logout',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final authProvider = context.read<AuthProvider>();
      await authProvider.logout();
      if (!context.mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    }
  }
}
