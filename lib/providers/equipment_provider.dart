// lib/providers/equipment_provider.dart
import 'package:flutter/material.dart';
import '../models/equipment_model.dart';

/// Manages the in-memory list of equipment: seeding, searching, filtering,
/// and applying status changes (called internally by RequestProvider as
/// requests move through their lifecycle).
class EquipmentProvider extends ChangeNotifier {
  final List<EquipmentModel> _equipment = [
    EquipmentModel(
      id: 'EQ-001',
      name: 'Dell Latitude Laptop',
      category: EquipmentCategory.laptop,
      location: 'IT Lab, Rm 204',
      status: EquipmentStatus.available,
    ),
    EquipmentModel(
      id: 'EQ-002',
      name: 'iPad Air Tablet',
      category: EquipmentCategory.tablet,
      location: 'AV Storage, Rm 101',
      status: EquipmentStatus.available,
    ),
    EquipmentModel(
      id: 'EQ-003',
      name: 'BenQ Ceiling Projector',
      category: EquipmentCategory.projector,
      location: 'AV Storage, Rm 101',
      status: EquipmentStatus.borrowed,
    ),
    EquipmentModel(
      id: 'EQ-004',
      name: 'Canon EOS DSLR Camera',
      category: EquipmentCategory.camera,
      location: 'Media Room',
      status: EquipmentStatus.reserved,
    ),
    EquipmentModel(
      id: 'EQ-005',
      name: 'Digital Multimeter Set',
      category: EquipmentCategory.labEquipment,
      location: 'Physics Lab',
      status: EquipmentStatus.available,
    ),
    EquipmentModel(
      id: 'EQ-006',
      name: 'HDMI Cable Bundle',
      category: EquipmentCategory.accessories,
      location: 'IT Storage',
      status: EquipmentStatus.maintenance,
    ),
    EquipmentModel(
      id: 'EQ-007',
      name: 'Epson Projector',
      category: EquipmentCategory.projector,
      location: 'Room 203',
      status: EquipmentStatus.available,
    ),
    EquipmentModel(
      id: 'EQ-008',
      name: 'Lenovo ThinkPad Laptop',
      category: EquipmentCategory.laptop,
      location: 'IT Lab, Rm 204',
      status: EquipmentStatus.borrowed,
    ),
  ];

  String _searchQuery = '';
  EquipmentCategory? _selectedCategory; // null = All categories
  EquipmentStatus? _selectedAvailability; // null = Any availability

  String get searchQuery => _searchQuery;
  EquipmentCategory? get selectedCategory => _selectedCategory;
  EquipmentStatus? get selectedAvailability => _selectedAvailability;

  /// The equipment list after applying search + category + availability filters.
  List<EquipmentModel> get filteredEquipment {
    return _equipment.where((e) {
      final matchesSearch = _searchQuery.isEmpty ||
          e.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          e.id.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory =
          _selectedCategory == null || e.category == _selectedCategory;
      final matchesAvailability =
          _selectedAvailability == null || e.status == _selectedAvailability;
      return matchesSearch && matchesCategory && matchesAvailability;
    }).toList();
  }

  EquipmentModel? findById(String id) {
    try {
      return _equipment.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setCategory(EquipmentCategory? category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void setAvailability(EquipmentStatus? status) {
    _selectedAvailability = status;
    notifyListeners();
  }

  /// Updates a single equipment item's status.
  /// Called by RequestProvider as part of the borrow request lifecycle —
  /// UI screens should never set equipment status directly.
  void setStatus(String equipmentId, EquipmentStatus status) {
    final equipment = findById(equipmentId);
    if (equipment == null) return;
    equipment.status = status;
    notifyListeners();
  }
}