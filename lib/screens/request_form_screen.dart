// lib/screens/request_form_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/equipment_model.dart';
import '../providers/auth_provider.dart';
import '../providers/request_provider.dart';
import '../theme/app_colors.dart';
import '../utils/date_utils.dart';
import '../widgets/primary_button.dart';

class RequestFormScreen extends StatefulWidget {
  final EquipmentModel equipment;

  const RequestFormScreen({super.key, required this.equipment});

  @override
  State<RequestFormScreen> createState() => _RequestFormScreenState();
}

class _RequestFormScreenState extends State<RequestFormScreen> {
  DateTime? _borrowDate;
  DateTime? _returnDate;
  bool _isSubmitting = false;

  Future<void> _pickDate({required bool isBorrowDate}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked == null) return;

    setState(() {
      if (isBorrowDate) {
        _borrowDate = picked;
      } else {
        _returnDate = picked;
      }
    });
  }

  Future<void> _handleSubmit() async {
    if (_borrowDate == null || _returnDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both borrow and return dates.')),
      );
      return;
    }
    if (_returnDate!.isBefore(_borrowDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Return date cannot be before the borrow date.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final userId = context.read<AuthProvider>().currentUser!.id;

    context.read<RequestProvider>().submitRequest(
          userId: userId,
          equipmentId: widget.equipment.id,
          borrowDate: _borrowDate!,
          returnDate: _returnDate!,
        );

    await Future.delayed(const Duration(milliseconds: 300)); // brief mock latency
    if (!mounted) return;

    setState(() => _isSubmitting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Request submitted! Status: Pending Approval'),
        backgroundColor: AppColors.primaryLight,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Request Equipment'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ----- Equipment summary card -----
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.fieldFill,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.fieldBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.equipment.category.label.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.equipment.name,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.equipment.location}  •  ${widget.equipment.id}',
                    style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Preferred Borrow Date',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 6),
            _DatePickerField(
              label: _borrowDate == null ? 'Select date' : formatShortDate(_borrowDate!),
              onTap: () => _pickDate(isBorrowDate: true),
            ),
            const SizedBox(height: 16),

            const Text(
              'Preferred Return Date',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 6),
            _DatePickerField(
              label: _returnDate == null ? 'Select date' : formatShortDate(_returnDate!),
              onTap: () => _pickDate(isBorrowDate: false),
            ),
            const SizedBox(height: 28),

            PrimaryButton(
              label: 'Submit Request',
              isLoading: _isSubmitting,
              onPressed: _handleSubmit,
            ),
          ],
        ),
      ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _DatePickerField({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.fieldFill,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.fieldBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.primaryLight),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }
}