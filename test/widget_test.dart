import 'package:flutter_test/flutter_test.dart';

import 'package:toolverse/main.dart';

void main() {
  testWidgets('ToolVerse splash screen smoke test',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ToolVerseApp());
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('ToolVerse'), findsWidgets);
    expect(
      find.text('Borrow & lend with your neighbors'),
      findsOneWidget,
    );

    // Let the timer finish
    await tester.pump(const Duration(milliseconds: 2500));
  });
}
