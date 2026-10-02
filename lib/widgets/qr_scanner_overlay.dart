// lib/widgets/qr_scanner_overlay.dart
import 'package:flutter/material.dart';

/// Rounded-square viewfinder frame with four green L-shaped corner
/// brackets, plus an optional animated horizontal scan line — drawn on top
/// of the camera preview.
class QrScannerOverlay extends StatefulWidget {
  final bool showScanLine;

  const QrScannerOverlay({super.key, this.showScanLine = false});

  @override
  State<QrScannerOverlay> createState() => _QrScannerOverlayState();
}

class _QrScannerOverlayState extends State<QrScannerOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scanLineController;

  @override
  void initState() {
    super.initState();
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    if (widget.showScanLine) _scanLineController.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant QrScannerOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showScanLine && !oldWidget.showScanLine) {
      _scanLineController.repeat(reverse: true);
    } else if (!widget.showScanLine && oldWidget.showScanLine) {
      _scanLineController.stop();
    }
  }

  @override
  void dispose() {
    _scanLineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scanLineController,
      builder: (context, child) => LayoutBuilder(
        builder: (context, constraints) {
          final lineTravel = (constraints.maxHeight - 64)
              .clamp(0.0, double.infinity)
              .toDouble();
          final lineTop = 32.0 + lineTravel * _scanLineController.value;

          return Stack(
            children: [
              const Positioned(
                top: 10,
                left: 10,
                child: _CornerBracket(rotation: 0),
              ),
              const Positioned(
                top: 10,
                right: 10,
                child: _CornerBracket(rotation: 90),
              ),
              const Positioned(
                bottom: 10,
                right: 10,
                child: _CornerBracket(rotation: 180),
              ),
              const Positioned(
                bottom: 10,
                left: 10,
                child: _CornerBracket(rotation: 270),
              ),
              if (widget.showScanLine)
                Positioned(
                  key: const ValueKey('qr-scan-line'),
                  left: 24,
                  right: 24,
                  top: lineTop,
                  child: Container(height: 2, color: const Color(0xFF2ECC91)),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _CornerBracket extends StatelessWidget {
  final double rotation; // degrees

  const _CornerBracket({required this.rotation});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotation * 3.1415926535 / 180,
      child: SizedBox(
        width: 22,
        height: 22,
        child: Stack(
          children: [
            Container(width: 22, height: 3, color: const Color(0xFF2ECC91)),
            Container(width: 3, height: 22, color: const Color(0xFF2ECC91)),
          ],
        ),
      ),
    );
  }
}
