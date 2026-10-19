// lib/widgets/simple_header.dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Flat teal header with a back arrow and title — sized and styled to match
/// the custom header used on the Profile screen, for visual consistency
/// across all secondary/detail screens (Settings, About, Account Info,
/// Change Password, Notification Settings).
class SimpleHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;

  const SimpleHeader({super.key, required this.title, this.onBack});

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(12, statusBarHeight + 20, 20, 20),
      color: AppColors.primary,
      child: Row(
        children: [
          IconButton(
            onPressed: onBack ?? () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 25,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
