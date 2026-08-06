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
