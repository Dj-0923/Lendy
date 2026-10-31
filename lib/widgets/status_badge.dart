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
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(20),
        border: style.border != null
            ? Border.all(color: style.border!, width: 1.2)
            : null,
      ),
      child: Text(
        uppercase ? style.label.toUpperCase() : style.label,
        style: TextStyle(
          color: style.foreground,
          fontWeight: FontWeight.w600,
          fontSize: compact ? 10 : 12,
          letterSpacing: compact ? 0.2 : 0.3,
        ),
      ),
    );
  }
}
