// lib/screens/qr_scan_screen.dart
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/equipment_model.dart';
import '../providers/equipment_provider.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../utils/status_style.dart';
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

    final equipment = context.read<EquipmentProvider>().findById(code.trim());

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
                if (_state == _ScanState.complete && _scannedEquipment != null)
                  Expanded(flex: 3, child: Center(child: cameraView))
                else
                  Expanded(child: Center(child: cameraView)),
                SizedBox(height: compact ? 4 : 12),
                Text(
                  switch (_state) {
                    _ScanState.ready => 'Ready to scan',
                    _ScanState.scanning => 'Scanning...',
                    _ScanState.complete => 'Scan complete',
                  },
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  switch (_state) {
                    _ScanState.ready => '',
                    _ScanState.scanning => 'Please hold steady',
                    _ScanState.complete => 'Item is ready',
                  },
                  style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                ),
                if (_state == _ScanState.complete && _scannedEquipment != null)
                  Expanded(
                    flex: 2,
                    child: SingleChildScrollView(
                      child: _buildResultCard(context, _scannedEquipment!),
                    ),
                  )
                else
                  const Spacer(),
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
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              equipment.id,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              equipment.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              equipment.location,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            StatusBadge(style: equipmentStatusStyle(equipment.status)),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RequestFormScreen(equipment: equipment),
                    ),
                  );
                },
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
