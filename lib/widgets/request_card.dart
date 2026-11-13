// lib/widgets/request_card.dart
import 'package:flutter/material.dart';
import '../models/borrow_request_model.dart';
import '../models/equipment_model.dart';
import '../theme/app_colors.dart';
import '../utils/date_utils.dart';
import '../utils/status_style.dart';
import 'status_badge.dart';

/// Card shown in the My Requests list (Active / Pending / History tabs).
/// [actionLabel] and [onAction] are optional — pass null to hide the button
/// (used for History tab items, which are read-only).
class RequestCard extends StatelessWidget {
  final BorrowRequestModel request;
  final EquipmentModel? equipment;
  final String? actionLabel;
  final VoidCallback? onAction;

  const RequestCard({
    super.key,
    required this.request,
    required this.equipment,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final name = equipment?.name ?? 'Unknown equipment';
    final location = equipment?.location ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                request.equipmentId,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Text(
                formatDateRange(
                  request.requestedBorrowDate,
                  request.requestedReturnDate,
                ),
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
              if (location.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      location,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (request.status == RequestStatus.returnPending) ...[
            const SizedBox(height: 8),
            const Text(
              'Your return is waiting for admin verification.',
              style: TextStyle(color: AppColors.primaryLight, fontSize: 12.5),
            ),
          ] else if (request.status == RequestStatus.borrowed &&
              request.returnVerificationStatus == 'rejected' &&
              request.returnRejectionReason != null) ...[
            const SizedBox(height: 8),
            Text(
              'Return not verified: ${request.returnRejectionReason}',
              style: const TextStyle(color: Colors.redAccent, fontSize: 12.5),
            ),
          ],
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: StatusBadge(style: requestStatusStyle(request.status)),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryLight,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  actionLabel!,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
