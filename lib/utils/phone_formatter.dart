import 'package:flutter/services.dart';

/// Phone number formatter for Moroccan phone numbers.
///
/// Format: XX XX XX XX XX (10 digits with spaces between each pair)
/// Valid prefixes: 01, 05, 07
class PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Remove all non-digit characters
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');

    // Limit to 10 digits
    final limitedDigits = digitsOnly.length > 10
        ? digitsOnly.substring(0, 10)
        : digitsOnly;

    // Format with spaces: XX XX XX XX XX
    final buffer = StringBuffer();
    for (int i = 0; i < limitedDigits.length; i++) {
      if (i > 0 && i % 2 == 0) {
        buffer.write(' ');
      }
      buffer.write(limitedDigits[i]);
    }

    final formatted = buffer.toString();

    // Calculate new cursor position
    int cursorPosition = formatted.length;
    if (newValue.selection.baseOffset <= newValue.text.length) {
      // Count digits up to cursor position in new value
      int digitsBeforeCursor = 0;
      for (int i = 0; i < newValue.selection.baseOffset && i < newValue.text.length; i++) {
        if (RegExp(r'\d').hasMatch(newValue.text[i])) {
          digitsBeforeCursor++;
        }
      }

      // Find corresponding position in formatted string
      int formattedPos = 0;
      int digitCount = 0;
      while (formattedPos < formatted.length && digitCount < digitsBeforeCursor) {
        if (RegExp(r'\d').hasMatch(formatted[formattedPos])) {
          digitCount++;
        }
        formattedPos++;
      }
      cursorPosition = formattedPos;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: cursorPosition),
    );
  }
}

/// Utility class for phone number operations
class PhoneUtils {
  /// Valid phone number prefixes
  static const List<String> validPrefixes = ['01', '05', '07'];

  /// Removes all spaces from a phone number for API submission
  static String stripSpaces(String phone) {
    return phone.replaceAll(' ', '');
  }

  /// Validates the phone number format
  /// Returns null if valid, error message if invalid
  static String? validate(String phone) {
    final digitsOnly = stripSpaces(phone);

    if (digitsOnly.isEmpty) {
      return 'Ce champ est requis';
    }

    if (digitsOnly.length != 10) {
      return 'Le numéro doit contenir 10 chiffres';
    }

    final prefix = digitsOnly.substring(0, 2);
    if (!validPrefixes.contains(prefix)) {
      return 'Le numéro doit commencer par 01, 05 ou 07';
    }

    return null;
  }

  /// Checks if the phone number has a valid prefix (for partial validation during input)
  static bool hasValidPrefixStart(String phone) {
    final digitsOnly = stripSpaces(phone);
    if (digitsOnly.isEmpty) return true; // Empty is allowed during input

    // Check if first digit could lead to a valid prefix
    if (digitsOnly.length == 1) {
      return digitsOnly == '0';
    }

    // Check if prefix is valid or potentially valid
    if (digitsOnly.length >= 2) {
      final prefix = digitsOnly.substring(0, 2);
      return validPrefixes.contains(prefix);
    }

    return true;
  }
}
