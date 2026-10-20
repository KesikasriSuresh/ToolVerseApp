import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toolverse/main.dart';
import 'package:toolverse/models/user_model.dart';
import 'package:toolverse/services/auth_service.dart';
import 'package:toolverse/services/storage_service.dart';

void main() {
  group('Stage 3 & 4: Email Authentication & Integration Tests', () {
    test('AuthService.isValidEmail correctly validates emails', () {
      // Valid emails
      expect(AuthService.isValidEmail('user@example.com'), isTrue);
      expect(AuthService.isValidEmail('first.last@neighborhood.org'), isTrue);
      expect(AuthService.isValidEmail('alex+test@sub.domain.co'), isTrue);
      expect(AuthService.isValidEmail('member123@toolverse.in'), isTrue);

      // Invalid emails
      expect(AuthService.isValidEmail(''), isFalse);
      expect(AuthService.isValidEmail('   '), isFalse);
      expect(AuthService.isValidEmail('notanemail'), isFalse);
      expect(AuthService.isValidEmail('@domain.com'), isFalse);
      expect(AuthService.isValidEmail('user@'), isFalse);
      expect(AuthService.isValidEmail('user@domain'), isFalse);
      expect(AuthService.isValidEmail('user @domain.com'), isFalse);
    });

    test('UserModel serialization with email authentication support', () {
      final user = UserModel(
        uid: 'usr_test123',
        name: 'Aarav Mehta',
        society: 'Greenwood Heights',
        phone: '+919876543210',
        email: 'aarav@greenwood.in',
        profilePic: 'https://res.cloudinary.com/test/image.jpg',
        latitude: 12.9716,
        longitude: 77.5946,
        formattedAddress: 'Tower B, Flat 402, Greenwood Heights, Bengaluru',
      );

      final json = user.toJson();
      expect(json['name'], 'Aarav Mehta');
      expect(json['society'], 'Greenwood Heights');
      expect(json['email'], 'aarav@greenwood.in');
      expect(json['phone'], '+919876543210');
      expect(json['latitude'], 12.9716);
      expect(json['longitude'], 77.5946);
      expect(json['formattedAddress'], contains('Greenwood Heights'));

      final parsed = UserModel.fromJson(json, 'usr_test123');
      expect(parsed.uid, 'usr_test123');
      expect(parsed.name, 'Aarav Mehta');
      expect(parsed.email, 'aarav@greenwood.in');
      expect(parsed.latitude, 12.9716);
    });

    testWidgets('EmailEntryScreen renders Google Sign-In and options correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AppStateScope(
            notifier: AppState(),
            child: const EmailEntryScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 800));

      expect(find.byType(ToolVerseLogo), findsOneWidget);
      expect(find.text('COMMUNITY SHARING PLATFORM'), findsOneWidget);
      expect(find.text('Sign in with Google'), findsOneWidget);
      expect(find.text('Explore as Guest'), findsOneWidget);
      expect(find.text('Or sign in with phone number'), findsOneWidget);
    });

    testWidgets('OtpScreen renders with email verification instructions',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AppStateScope(
            notifier: AppState(),
            child: const OtpScreen(email: 'neighbor@toolverse.local'),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Verify your\nemail'), findsOneWidget);
      expect(
        find.text('Enter the 6-digit code sent to neighbor@toolverse.local'),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsNWidgets(6));
    });

    test('StorageService Cloudinary upload validation for item photos', () {
      final validBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]); // PNG header
      final result = StorageService.validateImage(
        bytes: validBytes,
        fileName: 'cordless_drill.png',
      );
      expect(result.isValid, isTrue);
      expect(result.errorMessage, isNull);

      final emptyResult = StorageService.validateImage(
        bytes: Uint8List(0),
        fileName: 'empty.png',
      );
      expect(emptyResult.isValid, isFalse);
      expect(emptyResult.errorMessage, contains('empty'));
    });
  });
}
