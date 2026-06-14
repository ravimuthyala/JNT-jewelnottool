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

  static String normalizeAreaCode(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '+1';
    return '+$digits';
  }

  static bool isValidAreaCode(String value) {
    final normalized = normalizeAreaCode(value);
    return RegExp(r'^\+\d{1,4}$').hasMatch(normalized);
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
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length && i < 10; i++) {
      if (i == 0) buffer.write('(');
      if (i == 3) buffer.write(') ');
      if (i == 6) buffer.write('-');
      buffer.write(digits[i]);
    }
    final text = buffer.toString();
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
