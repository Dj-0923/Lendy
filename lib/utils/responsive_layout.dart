import 'package:flutter/material.dart';

/// Keeps the mobile-first app centered and readable on tablets and desktops.
class ResponsiveAppFrame extends StatelessWidget {
  const ResponsiveAppFrame({super.key, required this.child});

  static const double wideBreakpoint = 840;
  static const double maxAppWidth = 1200;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height;
        final frameWidth = width.clamp(0.0, maxAppWidth).toDouble();

        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(width: frameWidth, height: height, child: child),
        );
      },
    );
  }
}

/// Centers page content and prevents phone-sized layouts from stretching
/// edge-to-edge on tablets and desktop-sized viewports.
class ResponsiveContent extends StatelessWidget {
  const ResponsiveContent({
    super.key,
    required this.child,
    this.maxWidth = 760,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
