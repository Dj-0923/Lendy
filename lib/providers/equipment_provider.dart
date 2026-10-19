// lib/providers/equipment_provider.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/equipment_model.dart';

/// Streams admin-managed equipment and applies browse filters and statuses.
class EquipmentProvider extends ChangeNotifier {
  EquipmentProvider({FirebaseFirestore? firestore}) {
    if (firestore != null) {
      _watchEquipment(firestore);
    }
  }

  final List<EquipmentModel> _equipment = [];
  final Set<String> _approvedLoanEquipmentIds = {};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _equipmentSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _loanSubscription;
  bool _isLoading = false;
  String? _equipmentLoadError;
  String? _loanLoadError;
  String _searchQuery = '';
  EquipmentCategory? _selectedCategory; // null = All categories
  EquipmentStatus? _selectedAvailability; // null = Any availability

  bool get isLoading => _isLoading;
  String? get loadError => _equipmentLoadError ?? _loanLoadError;
  String get searchQuery => _searchQuery;
  EquipmentCategory? get selectedCategory => _selectedCategory;
  EquipmentStatus? get selectedAvailability => _selectedAvailability;

  void _watchEquipment(FirebaseFirestore firestore) {
    _isLoading = true;
    _equipmentSubscription = firestore
        .collection('equipment')
        .snapshots()
        .listen(
          (snapshot) {
            _equipment
              ..clear()
              ..addAll(
                snapshot.docs.map((document) {
                  final data = document.data();
                  final maintenance = data['maintenance'] == true;
                  final isBorrowed = _approvedLoanEquipmentIds.contains(
                    document.id,
                  );
                  return EquipmentModel.fromFirestore(
                    documentId: document.id,
                    data: data,
                    status: maintenance
                        ? EquipmentStatus.maintenance
                        : isBorrowed
                        ? EquipmentStatus.borrowed
                        : EquipmentStatus.available,
                  );
                }),
              )
              ..sort(
                (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
              );
            _isLoading = false;
            _equipmentLoadError = null;
            notifyListeners();
          },
          onError: (Object error) {
            _isLoading = false;
            _equipmentLoadError = 'Could not load the equipment list: $error';
            debugPrint(_equipmentLoadError);
            notifyListeners();
          },
        );
  }

  void updateAuthentication(bool isAuthenticated, FirebaseFirestore firestore) {
    if (isAuthenticated && _loanSubscription == null) {
      // This shared stream is only for item availability. Personal borrowing
      // records are loaded by RequestProvider using the current borrower's UID.
      _loanSubscription = firestore
          .collection('loans')
          .snapshots()
          .listen(
            (snapshot) {
              _approvedLoanEquipmentIds
                ..clear()
                ..addAll(
                  snapshot.docs
                      .where(
                        (document) => document.data()['status'] == 'approved',
                      )
                      .map((document) => document.data()['equipmentId'])
                      .whereType<String>(),
                );
              for (final equipment in _equipment) {
                if (equipment.status != EquipmentStatus.maintenance) {
                  equipment.status =
                      _approvedLoanEquipmentIds.contains(equipment.id)
                      ? EquipmentStatus.borrowed
                      : EquipmentStatus.available;
                }
              }
              _loanLoadError = null;
              notifyListeners();
            },
            onError: (Object error) {
              _loanLoadError = 'Could not sync equipment availability: $error';
              debugPrint(_loanLoadError);
              notifyListeners();
            },
          );
    } else if (!isAuthenticated && _loanSubscription != null) {
      _loanSubscription!.cancel();
      _loanSubscription = null;
      _approvedLoanEquipmentIds.clear();
      for (final equipment in _equipment) {
        if (equipment.status != EquipmentStatus.maintenance) {
          equipment.status = EquipmentStatus.available;
        }
      }
      _loanLoadError = null;
      notifyListeners();
    }
  }

  /// The equipment list after applying search + category + availability filters.
  List<EquipmentModel> get filteredEquipment {
    return _equipment.where((e) {
      final matchesSearch =
          _searchQuery.isEmpty ||
          e.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          e.id.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (e.assetTag?.toLowerCase().contains(_searchQuery.toLowerCase()) ??
              false);
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

  @override
  void dispose() {
    _equipmentSubscription?.cancel();
    _loanSubscription?.cancel();
    super.dispose();
  }
}
