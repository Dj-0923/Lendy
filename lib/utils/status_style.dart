// lib/utils/status_style.dart
import 'package:flutter/material.dart';
import '../models/equipment_model.dart';
import '../models/borrow_request_model.dart';

/// Simple visual style bundle for a status pill/badge.
class StatusStyle {
  final String label;
  final Color background;
  final Color foreground;
  final Color? border;

  const StatusStyle({
    required this.label,
    required this.background,
    required this.foreground,
    this.border,
  });
}

/// Visual style for an [EquipmentStatus] badge (shown uppercase on cards).
StatusStyle equipmentStatusStyle(EquipmentStatus status) {
  switch (status) {
    case EquipmentStatus.available:
      return const StatusStyle(
        label: 'Available',
        background: Color(0xFFE3F5EC),
        foreground: Color(0xFF157F5D),
      );
    case EquipmentStatus.reserved:
      return const StatusStyle(
        label: 'Reserved',
        background: Color(0xFFE7EFFF),
        foreground: Color(0xFF3B5BDB),
      );
    case EquipmentStatus.borrowed:
      return const StatusStyle(
        label: 'Borrowed',
        background: Color(0xFFFCEFD9),
        foreground: Color(0xFFB4740E),
      );
    case EquipmentStatus.maintenance:
      return const StatusStyle(
        label: 'In Maintenance',
        background: Color(0xFFF1F1F1),
        foreground: Color(0xFF6B6B6B),
      );
  }
}

/// Visual style for a [RequestStatus] badge (shown as-is on request cards).
StatusStyle requestStatusStyle(RequestStatus status) {
  switch (status) {
    case RequestStatus.pending:
      return const StatusStyle(
        label: 'pending',
        background: Color(0xFFFCEFD9),
        foreground: Color(0xFFB4740E),
      );
    case RequestStatus.approved:
      return const StatusStyle(
        label: 'Approved',
        background: Colors.white,
        foreground: Color(0xFF157F5D),
        border: Color(0xFF157F5D),
      );
    case RequestStatus.rejected:
      return StatusStyle(
        label: 'Rejected',
        background: Colors.white,
        foreground: Colors.red.shade700,
        border: Colors.red.shade300,
      );
    case RequestStatus.borrowed:
      return const StatusStyle(
        label: 'Borrowed',
        background: Color(0xFFFCEFD9),
        foreground: Color(0xFFB4740E),
      );
    case RequestStatus.returned:
      return const StatusStyle(
        label: 'Returned',
        background: Color(0xFFF1F1F1),
        foreground: Color(0xFF6B6B6B),
      );
    case RequestStatus.cancelled:
      return const StatusStyle(
        label: 'Cancelled',
        background: Color(0xFFF1F1F1),
        foreground: Color(0xFF6B6B6B),
      );
  }
}