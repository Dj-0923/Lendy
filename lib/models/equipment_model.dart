// lib/models/equipment_model.dart

import 'dart:convert';
import 'dart:typed_data';

/// Categories of equipment available in the system.
enum EquipmentCategory {
  tablet,
  projector,
  camera,
  laptop,
  labEquipment,
  accessories,
}

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
  final String? categoryName;
  final String? assetTag;
  final String location;
  final String? image;
  EquipmentStatus status; // mutable — updated by RequestProvider

  EquipmentModel({
    required this.id,
    required this.name,
    required this.category,
    required this.location,
    required this.status,
    this.categoryName,
    this.assetTag,
    this.image,
  });

  factory EquipmentModel.fromFirestore({
    required String documentId,
    required Map<String, dynamic> data,
    required EquipmentStatus status,
  }) {
    final name = data['name'];
    final category = data['category'];
    return EquipmentModel(
      id: documentId,
      name: name is String ? name : '',
      category: _categoryFor(category is String ? category : ''),
      categoryName: category is String && category.trim().isNotEmpty
          ? category.trim()
          : null,
      assetTag: data['tag'] is String ? data['tag'] as String : null,
      location: data['location'] is String ? data['location'] as String : '',
      image: data['image'] is String ? data['image'] as String : null,
      status: status,
    );
  }

  String get displayCategory => categoryName ?? category.label;

  Uint8List? get imageBytes {
    final imageData = image;
    if (imageData == null || imageData.isEmpty) return null;
    final separator = imageData.indexOf(',');
    final encoded = imageData.startsWith('data:') && separator >= 0
        ? imageData.substring(separator + 1)
        : imageData;
    try {
      return base64Decode(encoded);
    } on FormatException {
      return null;
    }
  }

  static EquipmentCategory _categoryFor(String value) {
    switch (value.trim().toLowerCase()) {
      case 'tablet':
      case 'tablets':
        return EquipmentCategory.tablet;
      case 'projector':
      case 'display':
      case 'displays':
        return EquipmentCategory.projector;
      case 'camera':
      case 'cameras':
        return EquipmentCategory.camera;
      case 'computer':
      case 'computers':
      case 'laptop':
      case 'laptops':
        return EquipmentCategory.laptop;
      case 'robotics':
      case 'lab equipment':
        return EquipmentCategory.labEquipment;
      default:
        return EquipmentCategory.accessories;
    }
  }
}
