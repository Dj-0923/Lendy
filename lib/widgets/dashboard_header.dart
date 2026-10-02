// lib/widgets/dashboard_header.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';

/// Flat teal header (straight bottom edge, no rounded corners), used across
/// the dashboard screens (Browse Item, My Requests, Notifications). Shows a
/// title, the logged-in user's name + role, and an avatar with their initials.
class DashboardHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onProfileTap;

  const DashboardHeader({super.key, required this.title, this.onProfileTap});

  String _initial(String fullName) {
    final name = fullName.trim();
    return name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final user = context.watch<AuthProvider>().currentUser;
    final imageBytes = user?.profileImageBytes;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, statusBarHeight + 20, 20, 20),
      color: AppColors.primary, // straight edges — no borderRadius
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${user?.fullName ?? ''}  •  ${user?.role.name ?? ''}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            key: const Key('dashboard-profile-avatar'),
            onPressed: onProfileTap,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 48, height: 48),
            icon: CircleAvatar(
              radius: 24,
              backgroundColor: Colors.white24,
              backgroundImage: imageBytes == null
                  ? null
                  : MemoryImage(imageBytes),
              child: imageBytes == null
                  ? Text(
                      _initial(user?.fullName ?? ''),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
