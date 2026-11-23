import 'package:flutter/material.dart';
import '../models/equipment_model.dart';
import '../theme/app_colors.dart';
import '../utils/status_style.dart';
import 'status_badge.dart';

/// Card shown in the Browse Item list for a single piece of equipment.
class EquipmentCard extends StatelessWidget {
  final EquipmentModel equipment;
  final VoidCallback onRequest;
  final bool requested;

  const EquipmentCard({
    super.key,
    required this.equipment,
    required this.onRequest,
    this.requested = false,
  });

  void _showDetails(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => _EquipmentDetailsDialog(
        equipment: equipment,
        requested: requested,
        onRequest: onRequest,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imageBytes = equipment.imageBytes;
    return Container(
      key: ValueKey('equipment-card-${equipment.id}'),
      height: 290,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final textDirection = Directionality.of(context);
          final namePainter = TextPainter(
            text: TextSpan(
              text: equipment.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            textDirection: textDirection,
            maxLines: 2,
          )..layout(maxWidth: constraints.maxWidth);
          final nameLineCount = namePainter.computeLineMetrics().length;
          namePainter.dispose();

          var locationLineCount = 1;
          if (equipment.location.isNotEmpty) {
            final locationPainter =
                TextPainter(
                  text: TextSpan(
                    text: equipment.location,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  textDirection: textDirection,
                  maxLines: 2,
                )..layout(
                  maxWidth: (constraints.maxWidth - 18)
                      .clamp(0.0, constraints.maxWidth)
                      .toDouble(),
                );
            locationLineCount = locationPainter.computeLineMetrics().length;
            locationPainter.dispose();
          }
          final imageHeight = nameLineCount == 1 && locationLineCount == 1
              ? 118.0
              : 100.0;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  height: imageHeight,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (imageBytes != null)
                        Image.memory(
                          imageBytes,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: StatusBadge(
                          style: equipmentStatusStyle(equipment.status),
                          uppercase: true,
                          compact: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                equipment.displayCategory.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: Text(
                  equipment.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                equipment.assetTag?.isNotEmpty == true
                    ? equipment.assetTag!
                    : equipment.id,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              if (equipment.location.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      size: 14,
                      color: AppColors.primaryLight,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        equipment.location,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                height: 38,
                child: Row(
                  children: [
                    Expanded(
                      flex: 8,
                      child: OutlinedButton(
                        key: const Key('equipment-card-view-details'),
                        onPressed: () => _showDetails(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryLight,
                          side: const BorderSide(
                            color: AppColors.primaryLight,
                            width: 1.5,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          minimumSize: const Size(0, 38),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.visibility_outlined, size: 16),
                              const SizedBox(width: 4),
                              const Text(
                                'View Details',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      flex: 6,
                      child: ElevatedButton(
                        onPressed:
                            equipment.status == EquipmentStatus.available &&
                                !requested
                            ? onRequest
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryLight,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          minimumSize: const Size(0, 38),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          requested
                              ? 'Requested'
                              : equipment.status == EquipmentStatus.available
                              ? 'Request'
                              : equipment.status.label,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EquipmentDetailsDialog extends StatelessWidget {
  const _EquipmentDetailsDialog({
    required this.equipment,
    required this.requested,
    required this.onRequest,
  });

  final EquipmentModel equipment;
  final bool requested;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    final imageBytes = equipment.imageBytes;
    final brand = equipment.brand?.trim();
    final details = equipment.details?.trim();
    final location = equipment.location.trim();
    final code = equipment.assetTag?.isNotEmpty == true
        ? equipment.assetTag!
        : equipment.id;
    final canRequest =
        equipment.status == EquipmentStatus.available && !requested;
    final requestLabel = requested
        ? 'Requested'
        : equipment.status == EquipmentStatus.available
        ? 'Request'
        : equipment.status.label;
    final imageWidth = (MediaQuery.sizeOf(context).width * 0.3)
        .clamp(96.0, 132.0)
        .toDouble();

    return Dialog(
      key: const Key('equipment-details-dialog'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: imageWidth,
                      height: 112,
                      child: imageBytes == null
                          ? const SizedBox.shrink()
                          : Image.memory(
                              imageBytes,
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) =>
                                  const SizedBox.shrink(),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  equipment.displayCategory,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            DecoratedBox(
                              key: const Key(
                                'equipment-details-close-background',
                              ),
                              decoration: const BoxDecoration(
                                color: Color(0xFFE4F0EC),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                key: const Key('equipment-details-close'),
                                tooltip: 'Close details',
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(
                                  Icons.close,
                                  color: AppColors.primary,
                                ),
                                iconSize: 20,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints.tightFor(
                                  width: 40,
                                  height: 40,
                                ),
                                visualDensity: VisualDensity.standard,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          equipment.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Code: $code',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          'Brand: ${brand?.isNotEmpty == true ? brand : 'Not specified'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
              const SizedBox(height: 14),
              const Text(
                'Details',
                style: TextStyle(
                  color: AppColors.primaryLight,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                details?.isNotEmpty == true
                    ? details!
                    : 'No details available.',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    size: 16,
                    color: AppColors.primaryLight,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Location',
                    style: const TextStyle(
                      color: AppColors.primaryLight,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                location.isNotEmpty ? location : 'Not specified',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 44,
                child: ElevatedButton(
                  key: const Key('equipment-details-request'),
                  onPressed: canRequest
                      ? () {
                          Navigator.of(context).pop();
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            onRequest();
                          });
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
                  child: Text(
                    requestLabel,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
