import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toolverse/main.dart';

void main() {
  testWidgets('HomeShell bottom bar does not take full screen', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1024, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final appState = AppState();

    await tester.pumpWidget(
      AppStateScope(
        notifier: appState,
        child: const MaterialApp(
          home: HomeShell(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final homeFinder = find.byType(HomeScreen);
    expect(homeFinder, findsOneWidget);

    final homeRenderBox = tester.renderObject<RenderBox>(homeFinder);

    final navPos = tester.getCenter(find.text('Home'));

    // The home nav item should be near the bottom of the screen (y around 550-590), NOT in the middle (around y=300)
    expect(navPos.dy, greaterThan(500.0));
    expect(homeRenderBox.size.height, greaterThan(400.0));

    // Verify HomeScreen content is visible
    expect(find.textContaining('Nearby', findRichText: true), findsWidgets);

    // Switch to "My items" tab
    await tester.tap(find.text('My items'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(MyItemsScreen), findsOneWidget);

    // Switch to "Profile" tab
    await tester.tap(find.text('Profile'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(ProfileScreen), findsOneWidget);
  });
}
