// lib/widgets/teal_header_background.dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// The dark teal, rounded-bottom header background with soft decorative
/// circles used across Login, Create Account, and Forgot Password screens.
///
/// [contentHeight] is the height of the header's visible teal content area
/// (title text, back button, etc.) NOT counting the status bar. This widget
/// automatically adds the device's status bar height on top of that, so the
/// header content never overlaps the notch/status bar on any device.
class TealHeaderBackground extends StatelessWidget {
  final double contentHeight;
  final Widget? child;

  const TealHeaderBackground({
    super.key,
    required this.contentHeight,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final totalHeight = contentHeight + statusBarHeight;

    return Container(
      height: totalHeight,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none, // allows the avatar to overflow at the bottom edge
        children: [
          Positioned(top: -40, right: -30, child: _dot(130, 0.06)),
          Positioned(top: statusBarHeight + 26, right: 36, child: _dot(16, 0.16)),
          Positioned(top: statusBarHeight + 58, right: 66, child: _dot(9, 0.16)),
          Positioned(bottom: -30, left: -40, child: _dot(110, 0.05)),
          if (child != null)
            Positioned(
              top: statusBarHeight,
              left: 0,
              right: 0,
              bottom: 0,
              child: child!,
            ),
        ],
      ),
    );
  }

  Widget _dot(double size, double opacity) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: opacity),
          shape: BoxShape.circle,
        ),
      );
}
