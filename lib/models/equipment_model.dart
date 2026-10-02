// lib/models/equipment_model.dart

/// Categories of equipment available in the system.
enum EquipmentCategory { tablet, projector, camera, laptop, labEquipment, accessories }

extension EquipmentCategoryX on EquipmentCategory {
  String get label {
    switch (this) {
      case EquipmentCategory.tablet:
        return 'Tablet';
      case EquipmentCategory.projector:
        return 'Projector';
      case EquipmentCategory.camera:
        return 'Camera';
      case EquipmentCategory.laptop:
        return 'Laptop';
      case EquipmentCategory.labEquipment:
        return 'Lab Equipment';
      case EquipmentCategory.accessories:
        return 'Accessories';
    }
  }
}

/// Lifecycle status of a piece of equipment.
/// Available -> Reserved (once a request is Approved) -> Borrowed (once
/// scanned/checked out) -> Available again (once returned).
enum EquipmentStatus { available, reserved, borrowed, maintenance }

extension EquipmentStatusX on EquipmentStatus {
  String get label {
    switch (this) {
      case EquipmentStatus.available:
        return 'Available';
      case EquipmentStatus.reserved:
        return 'Reserved';
      case EquipmentStatus.borrowed:
        return 'Borrowed';
      case EquipmentStatus.maintenance:
        return 'In Maintenance';
    }
  }
}

/// Represents a single piece of borrowable school equipment.
/// Kept flat and simple now so it maps easily to Firestore later.
class EquipmentModel {
  final String id; // e.g. "EQ-014"
  final String name;
  final EquipmentCategory category;
  final String location;
  EquipmentStatus status; // mutable — updated by RequestProvider

  EquipmentModel({
    required this.id,
    required this.name,
    required this.category,
    required this.location,
    required this.status,
  });
}