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
