// lib/screens/qr_scan_screen.dart
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/equipment_model.dart';
import '../providers/equipment_provider.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../utils/status_style.dart';
import '../utils/equipment_qr_code.dart';
import '../widgets/qr_scanner_overlay.dart';
import '../widgets/status_badge.dart';
import 'request_form_screen.dart';

enum _ScanState { ready, scanning, complete }

/// Camera-based QR scanner. Scans an equipment QR code (its equipment ID),
/// looks it up, and shows a result card so the user can submit a borrow
/// request to the Admin. Checking equipment in/out is handled separately
/// (via My Requests), not from this screen.
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final MobileScannerController _controller = MobileScannerController();
  _ScanState _state = _ScanState.ready;
  EquipmentModel? _scannedEquipment;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_state != _ScanState.ready) return; // ignore while processing/complete
    final code = capture.barcodes.isNotEmpty
        ? capture.barcodes.first.rawValue
        : null;
    if (code == null || code.isEmpty) return;
    _processCode(code);
  }

  Future<void> _processCode(String code) async {
    setState(() => _state = _ScanState.scanning);

    // Brief artificial delay so "Scanning... / Please hold steady" is visible,
    // while the camera session stays active for later scans.
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    final equipmentId = equipmentIdFromQrCode(code);
    final equipment = context.read<EquipmentProvider>().findById(equipmentId);

    if (equipment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No equipment found for code "$code".'),
          backgroundColor: Colors.redAccent,
        ),
      );
      setState(() => _state = _ScanState.ready);
      return;
    }

    setState(() {
      _scannedEquipment = equipment;
      _state = _ScanState.complete;
    });
  }

  void _scanAgain() {
    setState(() {
      _state = _ScanState.ready;
      _scannedEquipment = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 520;
            final cameraView = Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ImageFiltered(
                            imageFilter: ui.ImageFilter.blur(
                              sigmaX: _state == _ScanState.scanning ? 5 : 0,
                              sigmaY: _state == _ScanState.scanning ? 5 : 0,
                            ),
                            child: MobileScanner(
                              controller: _controller,
                              onDetect: _onDetect,
                            ),
                          ),
                          QrScannerOverlay(
                            showScanLine: _state == _ScanState.scanning,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );

            return Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(12, compact ? 4 : 12, 12, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                  ),
                ),
                if (_state == _ScanState.complete &&
                    _scannedEquipment != null) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Scan complete',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Items are ready',
                    style: TextStyle(color: Colors.white70, fontSize: 12.5),
                  ),
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: _buildResultCard(context, _scannedEquipment!),
                      ),
                    ),
                  ),
                ] else ...[
                  Expanded(child: Center(child: cameraView)),
                  SizedBox(height: compact ? 4 : 12),
                  Text(
                    _state == _ScanState.ready
                        ? 'Ready to scan'
                        : 'Scanning...',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _state == _ScanState.ready ? '' : 'Please hold steady',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12.5,
                    ),
                  ),
                  const Spacer(),
                ],
                SizedBox(height: compact ? 8 : 16),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildResultCard(BuildContext context, EquipmentModel equipment) {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 420),
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              equipment.id,
              style: const TextStyle(
                fontSize: 29,
                color: Color(0xFF888888),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              equipment.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                color: Color(0xFF555555),
                fontWeight: FontWeight.bold,
              ),
            ),
            if (equipment.location.isNotEmpty)
              Text(
                equipment.location,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            const SizedBox(height: 8),
            StatusBadge(style: equipmentStatusStyle(equipment.status)),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: equipment.status == EquipmentStatus.available
                    ? () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                RequestFormScreen(equipment: equipment),
                          ),
                        );
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryLight,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Request',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: _scanAgain,
                child: const Text(
                  'Scan Another',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
