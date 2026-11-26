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
    final tag = equipment?.displayTag ?? 'Tag unavailable';
    final today = DateUtils.dateOnly(DateTime.now());
    final dueDate = DateUtils.dateOnly(request.requestedReturnDate);
    final isOverdue =
        request.status == RequestStatus.borrowed && dueDate.isBefore(today);
    final showLoanReminder = {
      RequestStatus.approved,
      RequestStatus.borrowed,
      RequestStatus.returnPending,
    }.contains(request.status);
    final borrowPeriod = request.durationType == BorrowDurationType.hours
        ? '${formatShortDate(request.requestedBorrowDate)} · '
              '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(request.requestedBorrowDate))}'
              ' – ${formatShortDate(request.requestedReturnDate)} · '
              '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(request.requestedReturnDate))}'
        : formatDateRange(
            request.requestedBorrowDate,
            request.requestedReturnDate,
          );

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isOverdue ? const Color(0xFFFFEBEE) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isOverdue ? AppColors.danger : AppColors.fieldBorder,
        ),
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
                tag,
                key: const Key('request-card-equipment-tag'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
                borrowPeriod,
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
                      Icons.location_on,
                      size: 14,
                      color: AppColors.primaryLight,
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
          if (showLoanReminder)
            Container(
              key: const Key('loan-policy-reminder'),
              width: double.infinity,
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF0E1B7)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Loan reminders',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text('Do not take borrowed items home.'),
                  SizedBox(height: 2),
                  Text(
                    'Borrowers are responsible for repair or replacement '
                    'costs for lost or damaged items.',
                  ),
                ],
              ),
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
          if (request.status == RequestStatus.returned &&
              request.returnRequestedAt != null) ...[
            const SizedBox(height: 8),
            Text(
              'Return reported: '
              '${formatFullDateTime(request.returnRequestedAt!)}',
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (request.status == RequestStatus.returned &&
              request.returnVerifiedAt != null) ...[
            const SizedBox(height: 4),
            Text(
              'Verified by Admin: '
              '${formatFullDateTime(request.returnVerifiedAt!)}',
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
          ] else if (request.status == RequestStatus.returned &&
              request.returnedDate != null) ...[
            const SizedBox(height: 4),
            Text(
              'Verified by Admin: ${formatFullDate(request.returnedDate!)}',
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
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

class GroupedRequestCard extends StatelessWidget {
  const GroupedRequestCard({
    super.key,
    required this.requests,
    required this.equipments,
    required this.onCancel,
  });

  final List<BorrowRequestModel> requests;
  final List<EquipmentModel?> equipments;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final request = requests.first;
    final borrowPeriod = request.durationType == BorrowDurationType.hours
        ? '${formatShortDate(request.requestedBorrowDate)} · '
              '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(request.requestedBorrowDate))}'
              ' – ${formatShortDate(request.requestedReturnDate)} · '
              '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(request.requestedReturnDate))}'
        : formatDateRange(
            request.requestedBorrowDate,
            request.requestedReturnDate,
          );

    return Container(
      key: Key('request-group-card-${request.requestGroupId}'),
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
          Text(
            '${requests.length} items requested',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          for (var index = 0; index < requests.length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      equipments[index]?.name ?? 'Unknown equipment',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    equipments[index]?.displayTag ?? 'Tag unavailable',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Text(
            borrowPeriod,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: StatusBadge(style: requestStatusStyle(request.status)),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: OutlinedButton(
              onPressed: onCancel,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.danger),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Cancel request',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
