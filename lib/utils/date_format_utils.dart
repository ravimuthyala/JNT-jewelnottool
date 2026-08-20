/// Shared date-display formatting so every page renders dates the same way.
library;

/// Formats [date] as `MM/DD/YYYY`, e.g. `01/05/2026`.
String formatDateMdy(DateTime date) {
  final local = date.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final year = local.year.toString().padLeft(4, '0');
  return '$month/$day/$year';
}

/// Formats [date] as `MM/DD/YY`, e.g. `01/05/26`.
String formatDateMdyShortYear(DateTime date) {
  final local = date.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final year = (local.year % 100).toString().padLeft(2, '0');
  return '$month/$day/$year';
}

/// Same as [formatDateMdy] but returns [fallback] (default `'-'`) for null.
String formatDateMdyOrDash(DateTime? date, {String fallback = '-'}) {
  if (date == null) return fallback;
  return formatDateMdy(date);
}

/// Same as [formatDateMdyShortYear] but returns [fallback] for null.
String formatDateMdyShortYearOrDash(DateTime? date, {String fallback = '-'}) {
  if (date == null) return fallback;
  return formatDateMdyShortYear(date);
}

/// Compacts a stored display date or parseable date string to `MM/DD/YY`.
String compactDateDisplay(String value) {
  final text = value.trim();
  if (text.isEmpty) return '';
  final parsedIso = DateTime.tryParse(text);
  if (parsedIso != null) return formatDateMdyShortYear(parsedIso);

  final slash = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{2}|\d{4})$').firstMatch(text);
  if (slash == null) return text;
  final month = slash.group(1)!.padLeft(2, '0');
  final day = slash.group(2)!.padLeft(2, '0');
  final yearRaw = slash.group(3)!;
  final year = yearRaw.length == 2 ? yearRaw : yearRaw.substring(2);
  return '$month/$day/$year';
}

String compactDateDisplayOrDash(String value, {String fallback = '-'}) {
  final compact = compactDateDisplay(value);
  return compact.isEmpty ? fallback : compact;
}

/// Parses a strict `MM/DD/YYYY` string typed by a user, returning null for
/// anything incomplete or invalid (including non-existent calendar dates
/// like 02/30) rather than throwing.
DateTime? tryParseMmDdYyyy(String raw) {
  final text = raw.trim();
  final parts = text.split('/');
  if (parts.length != 3) return null;
  final month = int.tryParse(parts[0]);
  final day = int.tryParse(parts[1]);
  final year = int.tryParse(parts[2]);
  if (month == null || day == null || year == null) return null;
  if (month < 1 || month > 12 || day < 1 || day > 31 || year < 1900) {
    return null;
  }
  final date = DateTime(year, month, day);
  if (date.month != month || date.day != day || date.year != year) {
    return null;
  }
  return date;
}
