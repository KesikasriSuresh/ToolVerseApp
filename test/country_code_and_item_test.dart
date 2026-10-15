import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toolverse/main.dart';
import 'package:toolverse/models/country_code.dart';

void main() {
  testWidgets('CountryCodePickerSheet lists and filters countries',
      (WidgetTester tester) async {
    CountryCode? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                selected = await showModalBottomSheet<CountryCode>(
                  context: context,
                  builder: (_) => CountryCodePickerSheet(
                    selected: kCountryCodes.first,
                  ),
                );
              },
              child: const Text('Open Picker'),
            ),
          ),
        ),
      ),
    );

    // Open sheet
    await tester.tap(find.text('Open Picker'));
    await tester.pumpAndSettle();

    expect(find.text('Select Country Code'), findsOneWidget);
    expect(find.text('India'), findsOneWidget);
    expect(find.text('+91'), findsWidgets);

    // Filter by "United States"
    await tester.enterText(find.byType(TextField), 'United States');
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ListTile, 'United States'), findsOneWidget);
    expect(find.text('+1'), findsWidgets);

    // Select United States
    await tester.tap(find.widgetWithText(ListTile, 'United States'));
    await tester.pumpAndSettle();

    expect(selected, isNotNull);
    expect(selected!.dialCode, '+1');
  });

  testWidgets('ItemCard renders with rich elements and responds to tap',
      (WidgetTester tester) async {
    bool tapped = false;
    final item = Item(
      id: 'test_1',
      name: 'Bosch Power Drill',
      desc: 'Heavy duty drill',
      deposit: 500,
      category: ItemCategory.tools,
      owner: 'Riya M.',
      ownerId: 'owner_1',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ItemCard(
            item: item,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Bosch Power Drill'), findsOneWidget);
    expect(find.text('TOOLS'), findsOneWidget);
    expect(find.text('Available'), findsOneWidget);
    expect(find.text('Riya M.'), findsOneWidget);
    expect(find.text('₹500'), findsOneWidget);

    // Tap the item
    await tester.tap(find.byType(ItemCard));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(tapped, isTrue);
  });
}
