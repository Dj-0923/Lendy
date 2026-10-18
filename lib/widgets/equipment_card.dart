import 'package:flutter/material.dart';
import '../models/equipment_model.dart';
import '../theme/app_colors.dart';
import '../utils/status_style.dart';
import 'status_badge.dart';

/// Card shown in the Browse Item list for a single piece of equipment.
class EquipmentCard extends StatelessWidget {
  final EquipmentModel equipment;
  final VoidCallback onRequest;

  const EquipmentCard({
    super.key,
    required this.equipment,
    required this.onRequest,
  });

  @override
  Widget build(BuildContext context) {
    final imageBytes = equipment.imageBytes;
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
          if (imageBytes != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(
                imageBytes,
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            equipment.displayCategory.toUpperCase(),
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
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          if (equipment.location.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  equipment.location,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 2),
          Text(
            equipment.assetTag?.isNotEmpty == true
                ? equipment.assetTag!
                : equipment.id,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: StatusBadge(
              style: equipmentStatusStyle(equipment.status),
              uppercase: true,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton(
              onPressed: equipment.status == EquipmentStatus.available
                  ? onRequest
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
                equipment.status == EquipmentStatus.available
                    ? 'Request'
                    : equipment.status.label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
