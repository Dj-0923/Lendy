// lib/utils/text_formatters.dart
import 'package:flutter/services.dart';

/// Rewrites whatever the user types to upper case, so "bsit" becomes "BSIT".
///
/// [TextCapitalization.characters] only changes the on-screen keyboard, and
/// some keyboards (plus paste) can still deliver lower case, so the value
/// itself is corrected here instead.
class UpperCaseTextInputFormatter extends TextInputFormatter {
  const UpperCaseTextInputFormatter();
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

/// The number of characters in [text] that are not whitespace.
///
/// Used to measure titles by their letters, so "BS Information Technology"
/// counts as 22 rather than 25.
int countLetters(String text) => text.replaceAll(RegExp(r'\s'), '').length;
