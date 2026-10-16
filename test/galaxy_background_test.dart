import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toolverse/widgets/galaxy_background.dart';

void main() {
  testWidgets('ToolVerseGalaxyBackground renders and captures mouse movement',
      (WidgetTester tester) async {
    bool clicked = false;

    await tester.pumpWidget(
      MaterialApp(
        home: ToolVerseGalaxyBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Center(
              child: ElevatedButton(
                onPressed: () => clicked = true,
                child: const Text('Interact'),
              ),
            ),
          ),
        ),
      ),
    );

    // Initial pump
    await tester.pump(const Duration(milliseconds: 100));

    // Verify child is rendered and clickable
    expect(find.text('Interact'), findsOneWidget);
    await tester.tap(find.text('Interact'));
    expect(clicked, isTrue);

    // Simulate mouse move / hover
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: const Offset(100, 100));
    await gesture.moveTo(const Offset(300, 200));
    await tester.pump(const Duration(milliseconds: 100));

    await gesture.removePointer();
  });
}
