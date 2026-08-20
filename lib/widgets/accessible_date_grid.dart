import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../theme/app_colors.dart';

/// Accessible replacement for a raw [CalendarDatePicker]: TalkBack users
/// found that CalendarDatePicker announces only the first enabled date and
/// further swipes do nothing -- its internal day grid doesn't expose every
/// cell as its own traversable semantics node once the picker is placed in
/// a size-constrained dialog/sheet. This widget builds the month header and
/// day grid explicitly instead, giving each day cell its own `Semantics`
/// node with a stable `sortKey` so swipe navigation always reaches every
/// enabled date, and exposes month navigation as a single adjustable
/// control (swipe up/down to change month) instead of requiring users to
/// find and double-tap small arrow icons.
///
/// This is the shared inner content only -- callers provide their own
/// surrounding chrome (a `Dialog` via [showAccessibleDatePickerDialog], or
/// e.g. a bottom sheet) since that varies by screen.
class AccessibleDateGrid extends StatefulWidget {
  const AccessibleDateGrid({
    super.key,
    required this.fieldLabel,
    required this.firstDate,
    required this.lastDate,
    required this.initialSelectedDate,
    required this.onCancel,
    required this.onConfirm,
  });

  final String fieldLabel;
  final DateTime firstDate;
  final DateTime lastDate;
  final DateTime initialSelectedDate;
  final VoidCallback onCancel;
  final ValueChanged<DateTime> onConfirm;

  @override
  State<AccessibleDateGrid> createState() => _AccessibleDateGridState();
}

class _AccessibleDateGridState extends State<AccessibleDateGrid> {
  final GlobalKey _monthNavigationKey = GlobalKey();
  final GlobalKey _firstEnabledDateKey = GlobalKey();
  late DateTime _displayMonth;
  late DateTime _selectedDate;
  bool _sentInitialA11yFocus = false;

  static const List<String> _months = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static const List<String> _weekdays = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  void initState() {
    super.initState();
    _selectedDate = _dateOnly(widget.initialSelectedDate);
    // Start on the month containing the initially selected date. The earliest
    // enabled date controls navigation bounds only; it must not decide which
    // month is displayed when the picker opens.
    // TalkBack/VoiceOver first focuses the month label, with the Previous
    // and Next month buttons reachable on either side by swiping, then
    // continuing forward reaches the day grid.
    _displayMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    _queueMonthNavigationFocus();
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _fullDateLabel(DateTime date) {
    return '${_weekdays[date.weekday - 1]}, '
        '${_months[date.month - 1]} ${date.day}, ${date.year}';
  }

  void _queueMonthNavigationFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _sentInitialA11yFocus) return;
      await WidgetsBinding.instance.endOfFrame;
      await Future<void>.delayed(const Duration(milliseconds: 220));
      if (!mounted || _sentInitialA11yFocus) return;
      final renderObject = _monthNavigationKey.currentContext
          ?.findRenderObject();
      if (renderObject == null) return;
      _sentInitialA11yFocus = true;
      renderObject.sendSemanticsEvent(const FocusSemanticEvent());
    });
  }

  String _monthYearLabel(DateTime date) {
    return '${_months[date.month - 1]} ${date.year}';
  }

  DateTime get _firstMonth =>
      DateTime(widget.firstDate.year, widget.firstDate.month, 1);

  DateTime get _lastMonth =>
      DateTime(widget.lastDate.year, widget.lastDate.month, 1);

  bool get _canGoPrevious => _displayMonth.isAfter(_firstMonth);
  bool get _canGoNext => _displayMonth.isBefore(_lastMonth);

  void _previousMonth() {
    if (!_canGoPrevious) return;
    setState(() {
      _displayMonth = DateTime(_displayMonth.year, _displayMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    if (!_canGoNext) return;
    setState(() {
      _displayMonth = DateTime(_displayMonth.year, _displayMonth.month + 1, 1);
    });
  }

  List<DateTime?> _calendarCells() {
    final firstOfMonth = DateTime(_displayMonth.year, _displayMonth.month, 1);
    final daysInMonth = DateTime(
      _displayMonth.year,
      _displayMonth.month + 1,
      0,
    ).day;
    final leading = firstOfMonth.weekday % 7; // Sunday-first visual grid.
    final cells = <DateTime?>[
      for (var i = 0; i < leading; i++) null,
      for (var day = 1; day <= daysInMonth; day++)
        DateTime(_displayMonth.year, _displayMonth.month, day),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return cells;
  }

  bool _isEnabled(DateTime date) {
    final day = _dateOnly(date);
    return !day.isBefore(_dateOnly(widget.firstDate)) &&
        !day.isAfter(_dateOnly(widget.lastDate));
  }

  @override
  Widget build(BuildContext context) {
    final cells = _calendarCells();
    final monthLabel =
        '${_months[_displayMonth.month - 1]} ${_displayMonth.year}';

    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Text(
              'Select ${widget.fieldLabel}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.blackCat,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Semantics(
                sortKey: const OrdinalSortKey(1),
                button: true,
                enabled: _canGoPrevious,
                label: 'Previous month',
                onTap: _canGoPrevious ? _previousMonth : null,
                child: ExcludeSemantics(
                  child: IconButton(
                    tooltip: 'Previous month',
                    onPressed: _canGoPrevious ? _previousMonth : null,
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                ),
              ),
              Expanded(
                child: Semantics(
                  key: _monthNavigationKey,
                  sortKey: const OrdinalSortKey(2),
                  liveRegion: true,
                  label: '${widget.fieldLabel} calendar month',
                  value: monthLabel,
                  // Swipe up/down is a bonus for users who already know the
                  // "adjustable" TalkBack/VoiceOver gesture -- the Previous
                  // and Next month buttons on either side are the reliable,
                  // double-tap path everyone can discover and use.
                  increasedValue: _canGoNext
                      ? _monthYearLabel(
                          DateTime(
                            _displayMonth.year,
                            _displayMonth.month + 1,
                            1,
                          ),
                        )
                      : null,
                  decreasedValue: _canGoPrevious
                      ? _monthYearLabel(
                          DateTime(
                            _displayMonth.year,
                            _displayMonth.month - 1,
                            1,
                          ),
                        )
                      : null,
                  onIncrease: _canGoNext ? _nextMonth : null,
                  onDecrease: _canGoPrevious ? _previousMonth : null,
                  child: ExcludeSemantics(
                    child: Text(
                      monthLabel,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.blackCat,
                      ),
                    ),
                  ),
                ),
              ),
              Semantics(
                sortKey: const OrdinalSortKey(3),
                button: true,
                enabled: _canGoNext,
                label: 'Next month',
                onTap: _canGoNext ? _nextMonth : null,
                child: ExcludeSemantics(
                  child: IconButton(
                    tooltip: 'Next month',
                    onPressed: _canGoNext ? _nextMonth : null,
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ExcludeSemantics(
            child: Row(
              children: <Widget>[
                for (final day in const <String>[
                  'S',
                  'M',
                  'T',
                  'W',
                  'T',
                  'F',
                  'S',
                ])
                  Expanded(
                    child: Center(
                      child: Text(
                        day,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.blackCatLight,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Flexible(
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1,
              ),
              itemCount: cells.length,
              itemBuilder: (context, index) {
                final date = cells[index];
                if (date == null) return const SizedBox.shrink();

                final enabled = _isEnabled(date);
                final selected = _sameDate(date, _selectedDate);
                final isFirstEnabled = _sameDate(
                  date,
                  _dateOnly(widget.firstDate),
                );

                if (!enabled) {
                  return ExcludeSemantics(
                    child: Center(
                      child: Text(
                        '${date.day}',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.blackCat.withValues(alpha: 0.25),
                        ),
                      ),
                    ),
                  );
                }

                final label = isFirstEnabled
                    ? '${widget.fieldLabel}, ${_fullDateLabel(date)}'
                    : _fullDateLabel(date);

                return Semantics(
                  key: isFirstEnabled ? _firstEnabledDateKey : null,
                  sortKey: OrdinalSortKey(
                    10.0 +
                        _dateOnly(date)
                            .difference(_dateOnly(widget.firstDate))
                            .inDays
                            .toDouble(),
                  ),
                  button: true,
                  selected: selected,
                  label: label,
                  hint: selected
                      ? 'Selected. Double tap to keep this date'
                      : 'Double tap to select this date',
                  onTap: () => setState(() => _selectedDate = date),
                  child: ExcludeSemantics(
                    child: InkWell(
                      onTap: () => setState(() => _selectedDate = date),
                      child: Center(
                        child: Container(
                          height: 34,
                          width: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.blackCat
                                : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${date.day}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: selected
                                  ? AppColors.snow
                                  : AppColors.blackCat,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Semantics(
                sortKey: const OrdinalSortKey(10000),
                button: true,
                label: 'Cancel date selection',
                child: ExcludeSemantics(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.blackCatLight,
                      foregroundColor: AppColors.snow,
                    ),
                    onPressed: widget.onCancel,
                    child: const Text('Cancel'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                sortKey: const OrdinalSortKey(10001),
                button: true,
                label:
                    'Confirm ${widget.fieldLabel}, ${_fullDateLabel(_selectedDate)}',
                child: ExcludeSemantics(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.blackCat,
                      foregroundColor: AppColors.snow,
                    ),
                    onPressed: () => widget.onConfirm(_selectedDate),
                    child: const Text(
                      'Confirm',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shows [AccessibleDateGrid] inside a `Dialog`, matching the chrome used
/// by the request-flow date pickers (max 360x540, snow background, square
/// corners). Returns the picked date, or null if the user cancelled.
Future<DateTime?> showAccessibleDatePickerDialog({
  required BuildContext context,
  required String fieldLabel,
  required DateTime firstDate,
  required DateTime lastDate,
  required DateTime initialSelectedDate,
}) {
  return showDialog<DateTime>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: AppColors.snow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360, maxHeight: 540),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          child: AccessibleDateGrid(
            fieldLabel: fieldLabel,
            firstDate: firstDate,
            lastDate: lastDate,
            initialSelectedDate: initialSelectedDate,
            onCancel: () => Navigator.of(ctx).pop(),
            onConfirm: (picked) => Navigator.of(ctx).pop(picked),
          ),
        ),
      ),
    ),
  );
}