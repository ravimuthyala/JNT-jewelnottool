import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class DirectRequestYearCalendar extends StatefulWidget {
  const DirectRequestYearCalendar({
    super.key,
    this.initialDirectRequestsOn = true,
    this.initialYear,
    this.initialMonth,
    this.initialBlockedDays,
    this.showDirectRequestsFooter = true,
    this.onChanged,
  });

  final bool initialDirectRequestsOn;
  final int? initialYear;
  final int? initialMonth;

  /// Optional: pre-fill blocked days (normalized to yyyy-mm-dd).
  final Set<DateTime>? initialBlockedDays;

  /// Optional callback to save to backend
  final void Function(
    bool directRequestsOn,
    int year,
    Set<DateTime> blockedDays,
  )?
  onChanged;
  final bool showDirectRequestsFooter;

  @override
  State<DirectRequestYearCalendar> createState() =>
      _DirectRequestYearCalendarState();
}

class _DirectRequestYearCalendarState extends State<DirectRequestYearCalendar> {
  bool _directRequestsOn = true;
  int _selectedYear = DateTime.now().year;

  /// 0 = All months, 1..12 = a specific month
  int _selectedMonth = 0;

  final Set<DateTime> _blockedDays = <DateTime>{};

  static const List<String> _months = [
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

  @override
  void initState() {
    super.initState();
    _directRequestsOn = widget.initialDirectRequestsOn;
    _selectedYear = widget.initialYear ?? DateTime.now().year;
    final month = widget.initialMonth;
    _selectedMonth = month != null && month >= 1 && month <= 12 ? month : 0;
    if (widget.initialBlockedDays != null) {
      _blockedDays.addAll(widget.initialBlockedDays!.map(_norm));
    }
  }

  @override
  void didUpdateWidget(covariant DirectRequestYearCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialDirectRequestsOn != widget.initialDirectRequestsOn) {
      _directRequestsOn = widget.initialDirectRequestsOn;
    }
  }

  DateTime _norm(DateTime d) => DateTime(d.year, d.month, d.day);
  bool _isBlocked(DateTime d) => _blockedDays.contains(_norm(d));

  void _emit() {
    widget.onChanged?.call(_directRequestsOn, _selectedYear, {..._blockedDays});
  }

  void _toggleDay(DateTime d) {
    final nd = _norm(d);
    setState(() {
      _blockedDays.contains(nd)
          ? _blockedDays.remove(nd)
          : _blockedDays.add(nd);
    });
    _emit();
  }

  void _clearAll() {
    setState(_blockedDays.clear);
    _emit();
  }

  void _toggleMonth(int year, int month) {
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final allBlocked = List.generate(
      daysInMonth,
      (i) => DateTime(year, month, i + 1),
    ).every(_isBlocked);

    setState(() {
      for (var i = 1; i <= daysInMonth; i++) {
        final dt = DateTime(year, month, i);
        final nd = _norm(dt);
        if (allBlocked) {
          _blockedDays.remove(nd);
        } else {
          _blockedDays.add(nd);
        }
      }
    });
    _emit();
  }

  void _toggleWeek(List<DateTime> weekDays, int monthShown) {
    final inMonth = weekDays.where((d) => d.month == monthShown).toList();
    if (inMonth.isEmpty) return;

    final allBlocked = inMonth.every(_isBlocked);

    setState(() {
      for (final d in inMonth) {
        final nd = _norm(d);
        if (allBlocked) {
          _blockedDays.remove(nd);
        } else {
          _blockedDays.add(nd);
        }
      }
    });
    _emit();
  }

  List<int> _yearsAroundNow() {
    final now = DateTime.now().year;
    return List.generate(11, (i) => now - 5 + i);
  }

  // ----------------------------
  // Matching dropdown styles
  // ----------------------------
  Widget _dropdownShell({required Widget child, double? width}) {
    return SizedBox(
      width: width,
      child: Container(
        height: 30, // ✅ reduced size
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: Colors.black.withOpacity(0.10)),
        ),
        child: Center(child: child),
      ),
    );
  }

  Widget _monthDropdown({double width = 150}) {
    return _dropdownShell(
      width: width,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _selectedMonth,
          icon: const Icon(Icons.keyboard_arrow_down, size: 18),
          style: const TextStyle(
            fontWeight: FontWeight.w400,
            fontSize: 10,
            color: Colors.black,
          ),
          borderRadius: BorderRadius.zero,
          isExpanded: true,
          menuMaxHeight: 280,
          items: [
            const DropdownMenuItem(
              value: 0,
              child: Text(
                'All months',
                style: TextStyle(fontWeight: FontWeight.w400, fontSize: 9.5),
              ),
            ),
            ...List.generate(12, (i) {
              final m = i + 1;
              return DropdownMenuItem(
                value: m,
                child: Text(
                  _months[i],
                  style: const TextStyle(
                    fontWeight: FontWeight.w400,
                    fontSize: 10,
                  ),
                ),
              );
            }),
          ],
          onChanged: (v) => setState(() => _selectedMonth = v ?? 0),
        ),
      ),
    );
  }

  Widget _yearDropdown({double width = 100}) {
    final years = _yearsAroundNow();
    return _dropdownShell(
      width: width,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _selectedYear,
          icon: const Icon(Icons.keyboard_arrow_down, size: 16),
          style: const TextStyle(
            fontWeight: FontWeight.w400,
            fontSize: 10,
            color: Colors.black,
          ),
          borderRadius: BorderRadius.zero,
          isExpanded: true,
          menuMaxHeight: 220,
          items: years
              .map(
                (y) => DropdownMenuItem(
                  value: y,
                  child: Text(
                    '$y',
                    style: const TextStyle(
                      fontWeight: FontWeight.w400,
                      fontSize: 9.5,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => _selectedYear = v ?? _selectedYear),
        ),
      ),
    );
  }

  Widget _chevron(VoidCallback onTap, IconData icon) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon),
      iconSize: 18, // ✅ reduced
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 28, height: 28),
      padding: EdgeInsets.zero,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    final crossAxisCount = isWide ? 4 : 2;
    final cardHeight = isWide ? 240.0 : 260.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header controls - responsive (no overflow)
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 430;

            return Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _legendDot(
                  color: const Color(0xFF6FCF97),
                  label: 'Direct Requests On',
                ),
                _legendHatch(label: 'Blocked Off'),

                const SizedBox(width: 2),

                // ✅ Month first (matches year dropdown)
                _monthDropdown(width: 100),

                // ✅ Year controls second
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _chevron(
                      () => setState(() => _selectedYear -= 1),
                      Icons.chevron_left,
                    ),
                    _yearDropdown(width: 65),
                    _chevron(
                      () => setState(() => _selectedYear += 1),
                      Icons.chevron_right,
                    ),
                  ],
                ),

                TextButton(
                  onPressed: _clearAll,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                  child: const Text(
                    'Clear All',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 10),

        // ✅ Month grid (filtered by selected month)
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _selectedMonth == 0 ? 12 : 1,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent: cardHeight,
          ),
          itemBuilder: (_, i) {
            final monthToShow = _selectedMonth == 0 ? (i + 1) : _selectedMonth;
            return _monthCard(_selectedYear, monthToShow);
          },
        ),
        if (widget.showDirectRequestsFooter) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                'Direct Requests',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Switch(
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                value: _directRequestsOn,
                activeThumbColor: AppColors.deepPlum,
                inactiveThumbColor: AppColors.blackCatLight,
                inactiveTrackColor: AppColors.blackCatLight.withOpacity(0.35),
                onChanged: (v) {
                  setState(() => _directRequestsOn = v);
                  _emit();
                },
              ),
            ],
          ),
          Text(
            _directRequestsOn
                ? 'Clients can send Direct Requests on unblocked dates.'
                : 'Direct Requests are currently turned OFF.',
            style: TextStyle(
              color: Colors.black.withOpacity(0.6),
              fontWeight: FontWeight.w400,
              fontSize: 9.5,
            ),
          ),
        ],
      ],
    );
  }

  Widget _monthCard(int year, int month) {
    final first = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;

    // Sun-start offset: Sun=0, Mon=1, ... Sat=6
    final offset = (first.weekday % 7);
    const totalCells = 42;

    final cells = List<DateTime?>.generate(totalCells, (index) {
      final dayNum = index - offset + 1;
      if (dayNum < 1 || dayNum > daysInMonth) return null;
      return DateTime(year, month, dayNum);
    });

    final weeks = <List<DateTime?>>[];
    for (var i = 0; i < totalCells; i += 7) {
      weeks.add(cells.sublist(i, i + 7));
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: Colors.black.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.zero,
            onTap: () => _toggleMonth(year, month),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                '${_months[month - 1]} $year',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(height: 6),

          Row(
            children: const [
              _Wday('Sun'),
              _Wday('Mon'),
              _Wday('Tue'),
              _Wday('Wed'),
              _Wday('Thu'),
              _Wday('Fri'),
              _Wday('Sat'),
            ],
          ),
          const SizedBox(height: 6),

          Expanded(
            child: Column(
              children: weeks.map((week) {
                final weekHasAny = week.any((d) => d != null);
                if (!weekHasAny) return const SizedBox.shrink();

                final safeWeek = week
                    .map((d) => d ?? DateTime(year, month, 1))
                    .toList();

                return Expanded(
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () => _toggleWeek(safeWeek, month),
                        borderRadius: BorderRadius.zero,
                        child: Container(
                          width: 10,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.05),
                            borderRadius: BorderRadius.zero,
                          ),
                        ),
                      ),

                      Expanded(
                        child: Row(
                          children: week.map((d) {
                            if (d == null) {
                              return const Expanded(child: SizedBox.shrink());
                            }

                            final blocked = _isBlocked(d);

                            return Expanded(
                              child: Center(
                                child: InkWell(
                                  onTap: () => _toggleDay(d),
                                  borderRadius: BorderRadius.zero,
                                  child: Container(
                                    width: 22,
                                    height: 22,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: blocked
                                          ? const Color(0xFFFFE6EA)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.zero,
                                      border: blocked
                                          ? Border.all(
                                              color: const Color(
                                                0xFFF06C7A,
                                              ).withOpacity(0.55),
                                            )
                                          : null,
                                    ),
                                    child: Text(
                                      '${d.day}',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black.withOpacity(0.75),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot({required Color color, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.zero,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _legendHatch({required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: const Color(0xFFFFE6EA),
            borderRadius: BorderRadius.zero,
            border: Border.all(color: Colors.black.withOpacity(0.10)),
          ),
          child: CustomPaint(painter: _HatchPainter()),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _Wday extends StatelessWidget {
  const _Wday(this.t);
  final String t;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Text(
        t,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: Colors.black.withOpacity(0.55),
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _HatchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFFF06C7A).withOpacity(0.35)
      ..strokeWidth = 2;
    for (double x = -size.height; x < size.width; x += 6) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
