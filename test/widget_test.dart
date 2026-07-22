import 'package:flutter_test/flutter_test.dart';

import 'package:jewelnottool/main.dart';

void main() {
  testWidgets('JntApp renders smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const JntApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.byType(JntApp), findsOneWidget);
  });
}
