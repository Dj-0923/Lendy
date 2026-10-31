// lib/widgets/simple_header.dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Shared teal header for Profile and secondary/detail screens.
class SimpleHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;
  final bool showBackButton;
  final Widget? trailing;

  const SimpleHeader({
    super.key,
    required this.title,
    this.onBack,
    this.showBackButton = true,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(12, statusBarHeight + 20, 20, 20),
      color: AppColors.primary,
      child: Row(
        children: [
          if (showBackButton)
            IconButton(
              onPressed: onBack ?? () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back, color: Colors.white),
            )
          else
            const SizedBox(width: 8),
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
          ?trailing,
        ],
      ),
    );
  }
}
