// Regression test for the "swipe does nothing after the first date"
// TalkBack bug: a raw CalendarDatePicker only exposed one enabled day cell
// as a distinct semantics node once placed in a size-constrained
// dialog/sheet. AccessibleDateGrid replaces it with an explicit day grid
// where every enabled cell is its own Semantics node -- these tests assert
// that property directly instead of just checking the widget builds.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jewelnottool/widgets/accessible_date_grid.dart';

void main() {
  testWidgets('AccessibleDateGrid exposes multiple enabled days as distinct, '
      'independently actionable semantics nodes', (tester) async {
    final handle = tester.ensureSemantics();
    final firstDate = DateTime(2026, 3, 1);
    final lastDate = DateTime(2026, 3, 31);

    DateTime? confirmed;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AccessibleDateGrid(
            fieldLabel: 'Need By Date',
            firstDate: firstDate,
            lastDate: lastDate,
            initialSelectedDate: firstDate,
            onCancel: () {},
            onConfirm: (date) => confirmed = date,
          ),
        ),
      ),
    );

    // Every enabled day in the visible month must be its own semantics
    // node with a real label -- the exact property the raw
    // CalendarDatePicker failed at (only day 1 was reachable).
    final day1 = tester.getSemantics(find.text('1'));
    final day2 = tester.getSemantics(find.text('2'));
    final day15 = tester.getSemantics(find.text('15'));

    expect(day1.id, isNot(equals(day2.id)));
    expect(day2.id, isNot(equals(day15.id)));
    expect(day1.label, contains('March 1, 2026'));
    expect(day2.label, contains('March 2, 2026'));
    expect(day15.label, contains('March 15, 2026'));
    expect(
      day1.getSemanticsData().actions & SemanticsAction.tap.index,
      isNonZero,
    );
    expect(
      day2.getSemanticsData().actions & SemanticsAction.tap.index,
      isNonZero,
    );
    expect(
      day15.getSemanticsData().actions & SemanticsAction.tap.index,
      isNonZero,
    );

    // Tapping a later day (simulating a screen reader's activate action
    // after swiping past day 1) must actually select it.
    await tester.tap(find.text('15'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(confirmed, DateTime(2026, 3, 15));
    handle.dispose();
  });

  testWidgets(
    'AccessibleDateGrid exposes Previous/Next month as independently '
    'double-tappable buttons, not just a hidden swipe-to-adjust node',
    (tester) async {
      final handle = tester.ensureSemantics();
      // A range spanning 3 months so both directions are exercised.
      final firstDate = DateTime(2026, 2, 1);
      final lastDate = DateTime(2026, 4, 30);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccessibleDateGrid(
              fieldLabel: 'Need By Date',
              firstDate: firstDate,
              lastDate: lastDate,
              initialSelectedDate: firstDate,
              onCancel: () {},
              onConfirm: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      // The buttons themselves (found by their tooltip label) must be real,
      // separately actionable semantics nodes -- not swallowed into the
      // month-label node via ExcludeSemantics, which is what made month
      // navigation unreachable for TalkBack/VoiceOver users. Previous is
      // correctly disabled on the first month; Next must be actionable.
      final nextButtonData = tester
          .getSemantics(find.byTooltip('Next month'))
          .getSemanticsData();
      expect(nextButtonData.actions & SemanticsAction.tap.index, isNonZero);
      expect(find.text('February 2026'), findsOneWidget);

      // Double-tap equivalent: invoke the button's tap action directly, the
      // same way TalkBack/VoiceOver activate a focused button.
      await tester.tap(find.byTooltip('Next month'));
      await tester.pumpAndSettle();
      expect(find.text('March 2026'), findsOneWidget);

      // Now that we're past the first month, Previous must also be a real,
      // separately actionable node.
      final previousButtonData = tester
          .getSemantics(find.byTooltip('Previous month'))
          .getSemanticsData();
      expect(
        previousButtonData.actions & SemanticsAction.tap.index,
        isNonZero,
      );

      await tester.tap(find.byTooltip('Next month'));
      await tester.pumpAndSettle();
      expect(find.text('April 2026'), findsOneWidget);

      await tester.tap(find.byTooltip('Previous month'));
      await tester.pumpAndSettle();
      expect(find.text('March 2026'), findsOneWidget);

      handle.dispose();
    },
  );

  testWidgets('AccessibleDateGrid excludes out-of-range days from semantics', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final firstDate = DateTime(2026, 3, 10);
    final lastDate = DateTime(2026, 3, 20);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AccessibleDateGrid(
            fieldLabel: 'Need By Date',
            firstDate: firstDate,
            lastDate: lastDate,
            initialSelectedDate: firstDate,
            onCancel: () {},
            onConfirm: (_) {},
          ),
        ),
      ),
    );

    // Day 5 (before firstDate) is visible in the month grid but disabled;
    // it must not be independently reachable/actionable.
    final day5Data = tester.getSemantics(find.text('5')).getSemanticsData();
    expect(day5Data.actions & SemanticsAction.tap.index, isZero);

    // Let the widget's initial-focus timer (220ms) fire before disposal:
    // one pump to resolve endOfFrame, then one to advance past the delay.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    handle.dispose();
  });
}
