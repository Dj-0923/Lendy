// lib/screens/request_form_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/borrow_request_model.dart';
import '../models/equipment_model.dart';
import '../providers/auth_provider.dart';
import '../providers/request_provider.dart';
import '../theme/app_colors.dart';
import '../utils/date_utils.dart';
import '../utils/responsive_layout.dart';
import '../widgets/app_notice.dart';
import '../widgets/primary_button.dart';

class RequestFormScreen extends StatefulWidget {
  final List<EquipmentModel> equipments;

  RequestFormScreen({super.key, required EquipmentModel equipment})
    : equipments = [equipment];

  RequestFormScreen.multi({super.key, required this.equipments})
    : assert(equipments.isNotEmpty);

  @override
  State<RequestFormScreen> createState() => _RequestFormScreenState();
}

class _RequestFormScreenState extends State<RequestFormScreen> {
  BorrowDurationType _durationType = BorrowDurationType.days;
  DateTime? _borrowDate;
  DateTime? _returnDate;
  TimeOfDay? _borrowTime;
  TimeOfDay? _returnTime;
  bool _isSubmitting = false;

  Future<void> _pickDate({required bool isBorrowDate}) async {
    final now = DateTime.now();
    if (!isBorrowDate && _borrowDate == null) {
      AppNotice.show(context, 'Please select a borrow date first.');
      return;
    }

    final firstDate = isBorrowDate
        ? DateUtils.dateOnly(now)
        : DateUtils.dateOnly(_borrowDate!);
    final lastDate = isBorrowDate
        ? DateUtils.dateOnly(now.add(const Duration(days: 365)))
        : DateUtils.dateOnly(_borrowDate!.add(const Duration(days: 14)));
    final initialDate = isBorrowDate
        ? _borrowDate ?? firstDate
        : _returnDate ?? _borrowDate!;
    final picked = await showDatePicker(
      context: context,
      initialDate: DateUtils.dateOnly(initialDate),
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked == null) return;

    setState(() {
      if (isBorrowDate) {
        _borrowDate = picked;
        if (_durationType == BorrowDurationType.hours) {
          _returnDate = picked;
        } else if (_returnDate != null &&
            (_returnDate!.isBefore(picked) ||
                _returnDate!.isAfter(picked.add(const Duration(days: 14))))) {
          _returnDate = null;
        }
      } else {
        _returnDate = picked;
      }
    });
  }

  Future<void> _pickTime({required bool isBorrowTime}) async {
    if (_borrowDate == null) {
      AppNotice.show(context, 'Please select a use date first.');
      return;
    }

    final picked = await showTimePicker(
      context: context,
      initialTime: isBorrowTime
          ? (_borrowTime ?? _defaultBorrowTime())
          : (_returnTime ?? _defaultReturnTime()),
    );
    if (picked == null) return;

    setState(() {
      if (isBorrowTime) {
        _borrowTime = picked;
        if (_returnTime != null &&
            _minutesOfDay(_returnTime!) <= _minutesOfDay(picked)) {
          _returnTime = null;
        }
      } else {
        _returnTime = picked;
      }
    });
  }

  TimeOfDay _defaultBorrowTime() {
    final now = DateTime.now();
    final isToday =
        _borrowDate!.year == now.year &&
        _borrowDate!.month == now.month &&
        _borrowDate!.day == now.day;
    return isToday
        ? TimeOfDay.fromDateTime(now)
        : const TimeOfDay(hour: 9, minute: 0);
  }

  TimeOfDay _defaultReturnTime() {
    final borrowTime = _borrowTime ?? _defaultBorrowTime();
    final returnMinutes = _minutesOfDay(borrowTime) + 60;
    if (returnMinutes >= 24 * 60) {
      return const TimeOfDay(hour: 23, minute: 59);
    }
    return TimeOfDay(hour: returnMinutes ~/ 60, minute: returnMinutes % 60);
  }

  int _minutesOfDay(TimeOfDay time) => time.hour * 60 + time.minute;

  DateTime _dateAtTime(DateTime date, TimeOfDay time) =>
      DateTime(date.year, date.month, date.day, time.hour, time.minute);

  void _selectDurationType(BorrowDurationType durationType) {
    setState(() {
      _durationType = durationType;
      _borrowTime = null;
      _returnTime = null;
      if (durationType == BorrowDurationType.hours) {
        _returnDate = _borrowDate;
      } else if (_returnDate == _borrowDate) {
        _returnDate = null;
      }
    });
  }

  Future<void> _handleSubmit() async {
    if (_borrowDate == null) {
      AppNotice.show(context, 'Please select a borrow date.');
      return;
    }

    late final DateTime borrowDate;
    late final DateTime returnDate;
    if (_durationType == BorrowDurationType.hours) {
      if (_borrowTime == null || _returnTime == null) {
        AppNotice.show(context, 'Please select both borrow and return times.');
        return;
      }
      borrowDate = _dateAtTime(_borrowDate!, _borrowTime!);
      returnDate = _dateAtTime(_borrowDate!, _returnTime!);
      if (!returnDate.isAfter(borrowDate)) {
        AppNotice.show(
          context,
          'Return time must be after the borrow time.',
          type: AppNoticeType.error,
        );
        return;
      }
    } else {
      if (_returnDate == null) {
        AppNotice.show(context, 'Please select a return date.');
        return;
      }
      borrowDate = _borrowDate!;
      returnDate = _returnDate!;
      final dayCount =
          DateTime.utc(returnDate.year, returnDate.month, returnDate.day)
              .difference(
                DateTime.utc(borrowDate.year, borrowDate.month, borrowDate.day),
              )
              .inDays;
      if (dayCount < 0) {
        AppNotice.show(
          context,
          'Return date cannot be before the borrow date.',
          type: AppNoticeType.error,
        );
        return;
      }
      if (dayCount > 14) {
        AppNotice.show(
          context,
          'The maximum borrowing period is 14 days.',
          type: AppNoticeType.error,
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) {
      setState(() => _isSubmitting = false);
      AppNotice.show(
        context,
        'Please sign in before requesting an item.',
        type: AppNoticeType.error,
      );
      return;
    }
    try {
      final requestProvider = context.read<RequestProvider>();
      if (widget.equipments.length > 1) {
        await requestProvider.submitGroupRequest(
          userId: user.id,
          borrowerName: user.fullName,
          equipment: widget.equipments,
          borrowDate: borrowDate,
          returnDate: returnDate,
          durationType: _durationType,
        );
      } else {
        final equipment = widget.equipments.single;
        await requestProvider.submitRequest(
          userId: user.id,
          borrowerName: user.fullName,
          equipmentId: equipment.id,
          equipmentName: equipment.name,
          borrowDate: borrowDate,
          returnDate: returnDate,
          durationType: _durationType,
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      AppNotice.show(
        context,
        'Could not submit your request: $error',
        type: AppNoticeType.error,
      );
      return;
    }
    if (!mounted) return;

    setState(() => _isSubmitting = false);
    AppNotice.show(
      context,
      'Request submitted! Status: Pending Approval',
      type: AppNoticeType.success,
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text(
          widget.equipments.length > 1 ? 'Request Items' : 'Request Equipment',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ResponsiveContent(
          maxWidth: 620,
          child: Padding(
            padding: const EdgeInsets.all(8),
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
                  child: widget.equipments.length == 1
                      ? _SingleEquipmentSummary(
                          equipment: widget.equipments.single,
                        )
                      : _GroupedEquipmentSummary(equipments: widget.equipments),
                ),
                const SizedBox(height: 24),

                Text(
                  widget.equipments.length > 1
                      ? 'How long will you use these items?'
                      : 'How long will you use it?',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('For hours'),
                      selected: _durationType == BorrowDurationType.hours,
                      onSelected: (_) =>
                          _selectDurationType(BorrowDurationType.hours),
                    ),
                    ChoiceChip(
                      label: const Text('By days'),
                      selected: _durationType == BorrowDurationType.days,
                      onSelected: (_) =>
                          _selectDurationType(BorrowDurationType.days),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                if (_durationType == BorrowDurationType.hours) ...[
                  const Text(
                    'Preferred Use Date',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  _DatePickerField(
                    label: _borrowDate == null
                        ? 'Select date'
                        : formatShortDate(_borrowDate!),
                    onTap: () => _pickDate(isBorrowDate: true),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Preferred Borrow Time',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  _DatePickerField(
                    icon: Icons.schedule_outlined,
                    label: _borrowTime == null
                        ? 'Select time'
                        : MaterialLocalizations.of(
                            context,
                          ).formatTimeOfDay(_borrowTime!),
                    onTap: () => _pickTime(isBorrowTime: true),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Preferred Return Time',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  _DatePickerField(
                    icon: Icons.schedule_outlined,
                    label: _returnTime == null
                        ? 'Select time'
                        : MaterialLocalizations.of(
                            context,
                          ).formatTimeOfDay(_returnTime!),
                    onTap: () => _pickTime(isBorrowTime: false),
                  ),
                ] else ...[
                  const Text(
                    'Preferred Borrow Date',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  _DatePickerField(
                    label: _borrowDate == null
                        ? 'Select date'
                        : formatShortDate(_borrowDate!),
                    onTap: () => _pickDate(isBorrowDate: true),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Preferred Return Date',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  _DatePickerField(
                    label: _returnDate == null
                        ? 'Select date'
                        : formatShortDate(_returnDate!),
                    onTap: () => _pickDate(isBorrowDate: false),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Maximum borrowing period: 14 days.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 28),

                PrimaryButton(
                  label: 'Submit Request',
                  isLoading: _isSubmitting,
                  onPressed: _handleSubmit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SingleEquipmentSummary extends StatelessWidget {
  const _SingleEquipmentSummary({required this.equipment});

  final EquipmentModel equipment;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          equipment.category.label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          equipment.name,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          '${equipment.location}  •  Tag: ${equipment.displayTag}',
          style: const TextStyle(
            fontSize: 12.5,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _GroupedEquipmentSummary extends StatelessWidget {
  const _GroupedEquipmentSummary({required this.equipments});

  final List<EquipmentModel> equipments;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${equipments.length} items selected',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 200),
          child: SingleChildScrollView(
            child: Column(
              children: [
                for (final equipment in equipments)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            equipment.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          equipment.displayTag,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DatePickerField extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final IconData icon;

  const _DatePickerField({
    required this.label,
    required this.onTap,
    this.icon = Icons.calendar_today_outlined,
  });

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
            Icon(icon, size: 18, color: AppColors.primaryLight),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
