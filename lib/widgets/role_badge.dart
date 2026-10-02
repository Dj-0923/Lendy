// lib/widgets/role_badge.dart
import 'package:flutter/material.dart';
import '../models/user_model.dart';

/// Pill badge showing the user's role (Student or Faculty) with an icon.
class RoleBadge extends StatelessWidget {
  final UserRole role;

  const RoleBadge({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F5EC),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            role == UserRole.student ? Icons.school_outlined : Icons.badge_outlined,
            size: 16,
            color: const Color(0xFF157F5D),
          ),
          const SizedBox(width: 6),
          Text(
            role.label,
            style: const TextStyle(
              color: Color(0xFF157F5D),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}