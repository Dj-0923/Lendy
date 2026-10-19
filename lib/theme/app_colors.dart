// lib/theme/app_colors.dart
import 'package:flutter/material.dart';

/// Central color palette matching the "Lendy Campus Access" design.
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF0E4B45); // dark teal header
  static const Color primaryLight = Color(0xFF15746B); // buttons / links
  static const Color brandDeep = Color(0xFF0E4F44); // admin summary values
  static const Color danger = Color(0xFFC62828); // admin overdue values
  static const Color line = Color(0xFFDDD9CE); // admin card borders
  static const Color muted = Color(0xFF66746F); // admin secondary text
  static const Color background = Colors.white;
  static const Color textPrimary = Color(0xFF1B1B1B);
  static const Color textSecondary = Color(0xFF6B6B6B);
  static const Color fieldBorder = Color(0xFFDDE3E2);
  static const Color fieldFill = Color(0xFFF7F9F9);
}
