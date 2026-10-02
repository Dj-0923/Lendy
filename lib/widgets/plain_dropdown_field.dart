// lib/widgets/plain_dropdown_field.dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'plain_text_field.dart';

/// A labeled dropdown that matches [PlainTextField]'s look: bold caption,
/// white filled field, 8px radius and the same border colours.
///
/// The field has a fixed height and every option renders as a single
/// non-wrapping line at a fixed row height, so the card never resizes or
/// shifts when the selection changes.
class PlainDropdownField<T> extends StatelessWidget {
  /// Height of each row in the open menu. Flutter requires at least
  /// [kMinInteractiveDimension] (48).
  static const double menuRowHeight = 48;

  final String label;
  final String hint;
  final T? value;
  final List<T> options;
  final String Function(T value) labelOf;
  final ValueChanged<T?>? onChanged;
  final String? Function(T? value)? validator;

  const PlainDropdownField({
    super.key,
    required this.label,
    required this.hint,
    required this.value,
    required this.options,
    required this.labelOf,
    required this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        FormField<T>(
          initialValue: value,
          validator: validator,
          builder: (fieldState) => LayoutBuilder(
            builder: (context, constraints) => MenuAnchor(
              style: MenuStyle(
                minimumSize: WidgetStatePropertyAll(
                  Size(constraints.maxWidth, 0),
                ),
              ),
              menuChildren: options
                  .map(
                    (option) => MenuItemButton(
                      onPressed: () {
                        fieldState.didChange(option);
                        onChanged?.call(option);
                      },
                      child: SizedBox(
                        width: constraints.maxWidth - 32,
                        height: menuRowHeight,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(labelOf(option)),
                        ),
                      ),
                    ),
                  )
                  .toList(),
              builder: (context, controller, child) => InputDecorator(
                isEmpty: fieldState.value == null,
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                  errorText: fieldState.errorText,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 14,
                  ),
                  constraints: const BoxConstraints.tightFor(
                    height: PlainTextField.fieldHeight,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.fieldBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.fieldBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: AppColors.primaryLight,
                      width: 1.4,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.redAccent),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: Colors.redAccent,
                      width: 1.4,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        fieldState.value == null
                            ? ''
                            : labelOf(fieldState.value as T),
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: controller.isOpen
                          ? controller.close
                          : controller.open,
                      tooltip: 'Select $label',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 40,
                        height: 40,
                      ),
                      icon: const Icon(
                        Icons.keyboard_arrow_down,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
