String equipmentIdFromQrCode(String code) {
  final value = code.trim();
  if (value.isEmpty) return '';

  final uri = Uri.tryParse(value);
  final id = uri?.queryParameters['id'];
  if (id == null || id.trim().isEmpty) return value;
  return id.trim();
}
