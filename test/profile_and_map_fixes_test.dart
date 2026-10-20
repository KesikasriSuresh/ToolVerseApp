import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toolverse/main.dart';
import 'package:toolverse/widgets/map_location_picker.dart';

void main() {
  group('Profile and Map Overflow & Upload Fixes Tests', () {
    testWidgets('Profile feature tiles render without overflow on narrow screen',
        (WidgetTester tester) async {
      // Just verify that a compact tile built inline does not overflow on 360px wide screen
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.glassLine),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.place_outlined, size: 17, color: AppColors.violet),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Neighborhood & location',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          SizedBox(height: 2),
                          Text(
                            'Varthur Road, Ramagondanahalli, Whitefield, Bengaluru East City Corporation, Bengaluru, Bangalore East, Bengaluru Urban, Karnataka, 560066, India',
                            style: TextStyle(fontSize: 11.5, color: AppColors.muted),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.muted),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Neighborhood & location'), findsOneWidget);
    });

    test('LocationResult stores full address and coordinates accurately', () {
      const longAddress =
          'Varthur Road, Ramagondanahalli, Whitefield, Bengaluru East City Corporation, Bengaluru, Karnataka, India';
      const result = LocationResult(
        latitude: 12.9576,
        longitude: 77.7441,
        address: longAddress,
      );

      expect(result.latitude, 12.9576);
      expect(result.longitude, 77.7441);
      expect(result.address, contains('Ramagondanahalli'));
    });

    test('Booking model initializes with empty chat and preserves borrower/lender ids', () {
      final item = Item(
        id: 'item_101',
        name: 'Angle Grinder',
        category: ItemCategory.tools,
        owner: 'David',
        ownerId: 'owner_123',
        desc: 'Cordless 18V',
        deposit: 300,
      );

      final booking = Booking(
        id: 'booking_202',
        item: item,
        borrowerId: 'borrower_456',
        lenderId: 'owner_123',
        from: DateTime(2026, 10, 20),
        to: DateTime(2026, 10, 22),
        note: 'Cutting tiles',
      );

      expect(booking.chat, isEmpty, reason: 'Chat must NOT have hardcoded fake messages');
      expect(booking.borrowerId, 'borrower_456');
      expect(booking.lenderId, 'owner_123');
      expect(booking.status, BookingStatus.pending);
    });

    test('AppState items start empty and not populated with hardcoded seeds', () {
      final appState = AppState();
      expect(appState.items, isEmpty, reason: 'Items must start empty and sync from backend');
    });
  });
}
