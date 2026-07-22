import 'package:flutter/services.dart';

class RegistrationInputUtils {
  static const List<String> areaCodes = <String>[
    '+1',
    '+44',
    '+61',
    '+91',
    '+81',
    '+49',
    '+33',
    '+34',
    '+39',
    '+52',
  ];

  static final RegExp _emailRegex = RegExp(
    r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
  );
  static final RegExp _strongPasswordRegex = RegExp(
    r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^A-Za-z0-9]).{8,}$',
  );

  static bool isValidEmail(String value) => _emailRegex.hasMatch(value.trim());

  static bool isStrongPassword(String value) =>
      _strongPasswordRegex.hasMatch(value);

  static String normalizePhone(String value) =>
      value.replaceAll(RegExp(r'\D'), '');

  static String normalizeUsPhoneLocal(String value) {
    final digits = normalizePhone(value);
    if (digits.length <= 10) return digits;
    return digits.substring(digits.length - 10);
  }

  static String formatUsPhoneLocal(String value) {
    final digits = normalizeUsPhoneLocal(value);
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i == 0) buffer.write('(');
      if (i == 3) buffer.write(') ');
      if (i == 6) buffer.write('-');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  static String normalizeAreaCode(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '+1';
    return '+$digits';
  }

  static bool isValidAreaCode(String value) {
    final normalized = normalizeAreaCode(value);
    return RegExp(r'^\+\d{1,4}$').hasMatch(normalized);
  }

  /// Splits a stored phone number (e.g. "+447911123456", saved by the
  /// registration pages as areaCode + local digits concatenated) back into
  /// its dial code and local number, so profile edit screens can prefill a
  /// country-code picker the same way registration does instead of always
  /// assuming the number is a US local number.
  ///
  /// Falls back to '+1' with the input treated as a local number if no
  /// known area code prefix matches (e.g. legacy data saved before a
  /// country was tracked).
  static ({String areaCode, String localNumber}) splitStoredPhone(
    String value,
  ) {
    final raw = value.trim();
    if (raw.isEmpty) return (areaCode: '+1', localNumber: '');
    final withPlus = raw.startsWith('+') ? raw : '+$raw';
    final byLengthDesc = List<String>.from(areaCodes)
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final code in byLengthDesc) {
      if (withPlus.startsWith(code)) {
        return (
          areaCode: code,
          localNumber: normalizePhone(withPlus.substring(code.length)),
        );
      }
    }
    return (areaCode: '+1', localNumber: normalizePhone(raw));
  }

  static String normalizeCardNumber(String value) =>
      value.replaceAll(RegExp(r'\D'), '');

  static String normalizeExpiry(String value) =>
      value.replaceAll(RegExp(r'[^0-9/]'), '');
}

class UsPhoneTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = RegistrationInputUtils.formatUsPhoneLocal(newValue.text);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class CardNumberTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final chunks = <String>[];
    for (var i = 0; i < digits.length; i += 4) {
      chunks.add(
        digits.substring(i, i + 4 > digits.length ? digits.length : i + 4),
      );
    }
    final text = chunks.join(' ');
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class ExpiryDateTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final mm = digits.length >= 2 ? digits.substring(0, 2) : digits;
    final yy = digits.length > 2
        ? digits.substring(2, digits.length > 4 ? 4 : digits.length)
        : '';
    final text = yy.isEmpty ? mm : '$mm/$yy';
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class NailDimensionTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final rawText = newValue.text;
    if (rawText.isEmpty) return newValue;

    final normalized = _normalize(rawText);
    if (normalized == oldValue.text && rawText != normalized) {
      return oldValue;
    }

    return TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(offset: normalized.length),
    );
  }

  String _normalize(String input) {
    final text = input.replaceAll(',', '.');
    final buffer = StringBuffer();
    var hasDecimal = false;
    var wholeDigits = 0;
    var decimalDigits = 0;

    for (final rune in text.runes) {
      final char = String.fromCharCode(rune);
      final isDigit = char.codeUnitAt(0) >= 48 && char.codeUnitAt(0) <= 57;

      if (isDigit) {
        if (!hasDecimal) {
          if (wholeDigits >= 2) continue;
          wholeDigits++;
        } else {
          if (decimalDigits >= 2) continue;
          decimalDigits++;
        }
        buffer.write(char);
        continue;
      }

      if (char == '.' && !hasDecimal) {
        hasDecimal = true;
        if (wholeDigits == 0) {
          buffer.write('0');
          wholeDigits = 1;
        }
        buffer.write('.');
      }
    }

    return buffer.toString();
  }
}
