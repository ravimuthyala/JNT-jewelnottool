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

/// Same as [formatDateMdy] but returns [fallback] (default `'-'`) for null.
String formatDateMdyOrDash(DateTime? date, {String fallback = '-'}) {
  if (date == null) return fallback;
  return formatDateMdy(date);
}
