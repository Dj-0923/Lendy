// lib/widgets/status_badge.dart
import 'package:flutter/material.dart';
import '../utils/status_style.dart';

/// Small rounded pill used to display a status (Available, Pending, etc).
class StatusBadge extends StatelessWidget {
  final StatusStyle style;
  final bool uppercase;

  const StatusBadge({super.key, required this.style, this.uppercase = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(20),
        border: style.border != null ? Border.all(color: style.border!, width: 1.2) : null,
      ),
      child: Text(
        uppercase ? style.label.toUpperCase() : style.label,
        style: TextStyle(
          color: style.foreground,
          fontWeight: FontWeight.w600,
          fontSize: 12,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}