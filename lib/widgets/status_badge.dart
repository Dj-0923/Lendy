// lib/widgets/status_badge.dart
import 'package:flutter/material.dart';
import '../utils/status_style.dart';

/// Small rounded pill used to display a status (Available, Pending, etc).
class StatusBadge extends StatelessWidget {
  final StatusStyle style;
  final bool uppercase;
  final bool compact;

  const StatusBadge({
    super.key,
    required this.style,
    this.uppercase = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final label = uppercase ? style.label.toUpperCase() : style.label;
    final icon = _statusIcon(label);
    return Container(
      key: const Key('status-badge-container'),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(20),
        border: style.border != null
            ? Border.all(color: style.border!, width: 1.2)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 16 : 18,
            height: compact ? 16 : 18,
            decoration: BoxDecoration(
              color: style.foreground,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: compact ? 10 : 12, color: Colors.white),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: style.foreground,
              fontWeight: FontWeight.w700,
              fontSize: compact ? 9 : 12,
              letterSpacing: compact ? 0.1 : 0.2,
            ),
          ),
        ],
      ),
    );
  }

  IconData _statusIcon(String label) {
    final value = label.toLowerCase();
    if (value.contains('available') ||
        value.contains('approved') ||
        value.contains('active') ||
        value.contains('returned')) {
      return Icons.check_rounded;
    }
    if (value.contains('borrowed') || value.contains('borrowing')) {
      return Icons.shield_outlined;
    }
    if (value.contains('pending') ||
        value.contains('return verification') ||
        value.contains('reserved')) {
      return Icons.schedule_rounded;
    }
    if (value.contains('rejected') ||
        value.contains('revoked') ||
        value.contains('cancelled') ||
        value.contains('overdue') ||
        value.contains('maintenance')) {
      return Icons.priority_high_rounded;
    }
    return Icons.circle_rounded;
  }
}
