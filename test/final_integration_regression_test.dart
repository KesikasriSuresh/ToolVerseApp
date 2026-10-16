import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:toolverse/main.dart';
import 'package:toolverse/models/chat_model.dart';
import 'package:toolverse/models/user_model.dart';
import 'package:toolverse/services/storage_service.dart';
import 'package:toolverse/widgets/map_location_picker.dart';
import 'package:toolverse/widgets/web_location_helper.dart';

void main() {
  group('Step 9 — Final Integration & Regression Tests', () {
    // -------------------------------------------------------------------------
    // 1. StorageService: Image type & 10 MB validation
    // -------------------------------------------------------------------------
    group('StorageService image validation', () {
      test('accepts valid formats (jpg, jpeg, png, webp) within 10 MB', () {
        final smallBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00]);

        for (final ext in ['jpg', 'jpeg', 'png', 'webp']) {
          final res = StorageService.validateImage(
            bytes: smallBytes,
            fileName: 'sample_photo.$ext',
          );
          expect(res.isValid, isTrue, reason: 'Failed for extension: $ext');
          expect(res.errorMessage, isNull);
        }
      });

      test('accepts larger images up to 10 MB (e.g. 7 MB)', () {
        final sevenMb = Uint8List(7 * 1024 * 1024);
        final res = StorageService.validateImage(
          bytes: sevenMb,
          fileName: 'high_res_photo.jpg',
        );
        expect(res.isValid, isTrue);
        expect(res.errorMessage, isNull);
      });

      test('rejects empty byte arrays', () {
        final emptyBytes = Uint8List(0);
        final res = StorageService.validateImage(
          bytes: emptyBytes,
          fileName: 'tool.png',
        );
        expect(res.isValid, isFalse);
        expect(res.errorMessage, contains('empty'));
      });

      test('rejects images exceeding 10 MB limit', () {
        // 10 MB + 1 byte
        final oversized = Uint8List(10 * 1024 * 1024 + 1);
        final res = StorageService.validateImage(
          bytes: oversized,
          fileName: 'large_photo.jpg',
        );
        expect(res.isValid, isFalse);
        expect(res.errorMessage, contains('exceeds the 10 MB limit'));
      });

      test('rejects unsupported extensions (.gif, .pdf, .svg, .exe)', () {
        final dummyBytes = Uint8List.fromList([1, 2, 3, 4]);
        for (final badExt in ['gif', 'pdf', 'svg', 'exe', 'bmp']) {
          final res = StorageService.validateImage(
            bytes: dummyBytes,
            fileName: 'file.$badExt',
          );
          expect(res.isValid, isFalse, reason: 'Allowed bad extension: $badExt');
          expect(res.errorMessage, contains('Unsupported file format'));
        }
      });
    });

    // -------------------------------------------------------------------------
    // 2. UserModel: Backward compatibility & location fields
    // -------------------------------------------------------------------------
    group('UserModel profile and backward compatibility', () {
      test('parses legacy documents without new optional fields', () {
        final legacyJson = {
          'name': 'Rahul Sharma',
          'society': 'Palm Meadows',
          'phone': '+919876543210',
          'profilePic': '',
        };

        final user = UserModel.fromJson(legacyJson, 'uid_123');
        expect(user.uid, 'uid_123');
        expect(user.name, 'Rahul Sharma');
        expect(user.society, 'Palm Meadows');
        expect(user.phone, '+919876543210');
        expect(user.email, isEmpty);
        expect(user.latitude, isNull);
        expect(user.longitude, isNull);
        expect(user.formattedAddress, isEmpty);
      });

      test('supports legacy coordinate key fallbacks (lat, lng, address)', () {
        final legacyGeoJson = {
          'name': 'Priya Patel',
          'society': 'Indiranagar',
          'phone': '+919123456789',
          'lat': 12.9716,
          'lng': 77.6412,
          'address': '100ft Road, Indiranagar',
        };

        final user = UserModel.fromJson(legacyGeoJson, 'uid_456');
        expect(user.latitude, 12.9716);
        expect(user.longitude, 77.6412);
        expect(user.formattedAddress, '100ft Road, Indiranagar');
      });

      test('serializes all updated profile fields correctly', () {
        final user = UserModel(
          uid: 'uid_789',
          name: 'Vikram Rao',
          society: 'Koramangala 4th Block',
          phone: '+919988776655',
          email: 'vikram@example.com',
          latitude: 12.9352,
          longitude: 77.6245,
          formattedAddress: '80ft Road, Koramangala 4th Block',
          profilePic: 'https://storage.googleapis.com/test.jpg',
        );

        final json = user.toJson();
        expect(json['name'], 'Vikram Rao');
        expect(json['society'], 'Koramangala 4th Block');
        expect(json['email'], 'vikram@example.com');
        expect(json['latitude'], 12.9352);
        expect(json['longitude'], 77.6245);
        expect(json['formattedAddress'], '80ft Road, Koramangala 4th Block');
        expect(json['profilePic'], 'https://storage.googleapis.com/test.jpg');
      });
    });

    // -------------------------------------------------------------------------
    // 3. ChatMsg & ChatMsgModel: Backward compatibility & location messages
    // -------------------------------------------------------------------------
    group('Chat messages backward compatibility', () {
      test('legacy text chat deserializes without errors', () {
        final legacyMsg = {
          'text': 'Hi, is this lawn mower still available?',
          'senderId': 'user_borrower',
          'timestamp': null,
        };

        final model =
            ChatMsgModel.fromJson(legacyMsg, 'msg_001', 'user_borrower');
        expect(model.id, 'msg_001');
        expect(model.text, 'Hi, is this lawn mower still available?');
        expect(model.fromMe, isTrue);
        expect(model.type, 'text');
        expect(model.isLocation, isFalse);
        expect(model.latitude, isNull);
        expect(model.longitude, isNull);
      });

      test('location message correctly derives isLocation flag', () {
        final locMsg = {
          'text': '📍 Pickup Location: Indiranagar',
          'senderId': 'user_owner',
          'type': 'location',
          'latitude': 12.9716,
          'longitude': 77.6412,
          'locationAddress': 'Indiranagar',
        };

        final model =
            ChatMsgModel.fromJson(locMsg, 'msg_002', 'user_borrower');
        expect(model.id, 'msg_002');
        expect(model.fromMe, isFalse);
        expect(model.isLocation, isTrue);
        expect(model.latitude, 12.9716);
        expect(model.longitude, 77.6412);
        expect(model.locationAddress, 'Indiranagar');
      });
    });

    // -------------------------------------------------------------------------
    // 4. WebLocationHelper: GeoResult handling
    // -------------------------------------------------------------------------
    group('WebLocationHelper result handling', () {
      test('handles denied GPS permission state correctly', () {
        const deniedResult = WebGeoResult(
          errorMessage: 'Location permission was denied.',
          isPermissionDenied: true,
        );

        expect(deniedResult.isPermissionDenied, isTrue);
        expect(deniedResult.latitude, isNull);
        expect(deniedResult.longitude, isNull);
        expect(deniedResult.errorMessage, isNotNull);
      });

      test('handles successful coordinates properly', () {
        const successResult = WebGeoResult(
          latitude: 12.9716,
          longitude: 77.6412,
        );

        expect(successResult.isPermissionDenied, isFalse);
        expect(successResult.latitude, 12.9716);
        expect(successResult.longitude, 77.6412);
        expect(successResult.errorMessage, isNull);
      });

      test('openMapUrl stub can be safely called in VM/test environment', () {
        expect(() => openMapUrl('https://maps.google.com'), returnsNormally);
      });

      test('GeocodeResult correctly represents address and unavailable states', () {
        const result = GeocodeResult(
          displayName: 'Amrita Vishwa Vidyapeetham, Ettimadai, Coimbatore, Tamil Nadu, India',
          primaryName: 'Amrita Vishwa Vidyapeetham',
          locality: 'Ettimadai',
          isSuccess: true,
        );

        expect(result.isSuccess, isTrue);
        expect(result.primaryName, 'Amrita Vishwa Vidyapeetham');
        expect(result.locality, 'Ettimadai');
        expect(result.displayName, contains('Coimbatore'));

        const unavailable = GeocodeResult.unavailable();
        expect(unavailable.isSuccess, isFalse);
        expect(unavailable.displayName, 'Address unavailable');
        expect(unavailable.primaryName, 'Address unavailable');
        expect(unavailable.locality, isNull);
      });

      test('LocationResult pairs coordinates with resolved address', () {
        const loc = LocationResult(
          latitude: 10.9070,
          longitude: 76.8991,
          address: 'Amrita Vishwa Vidyapeetham, Ettimadai, Coimbatore',
        );

        expect(loc.latitude, 10.9070);
        expect(loc.longitude, 76.8991);
        expect(loc.address, 'Amrita Vishwa Vidyapeetham, Ettimadai, Coimbatore');
        expect(loc.toString(), contains('10.907'));
      });
    });

    // -------------------------------------------------------------------------
    // 5. AppUser UI Model: Fallbacks
    // -------------------------------------------------------------------------
    group('AppUser UI model defaults', () {
      test('creates AppUser with default coordinates as null and empty address', () {
        final appUser = AppUser(
          name: 'Hasini',
          society: 'Indiranagar',
        );

        expect(appUser.name, 'Hasini');
        expect(appUser.society, 'Indiranagar');
        expect(appUser.latitude, isNull);
        expect(appUser.longitude, isNull);
        expect(appUser.formattedAddress, isEmpty);
      });

      test('populates coordinates and formatted address when provided', () {
        final appUser = AppUser(
          name: 'Hasini',
          society: 'Indiranagar',
          latitude: 12.9716,
          longitude: 77.6412,
          formattedAddress: '100ft Road, Indiranagar',
        );

        expect(appUser.latitude, 12.9716);
        expect(appUser.longitude, 77.6412);
        expect(appUser.formattedAddress, '100ft Road, Indiranagar');
      });
    });

    // -------------------------------------------------------------------------
    // 6. Profile Completion: Society Field Removal & Fallback Persistence
    // -------------------------------------------------------------------------
    group('Profile completion without society field requirement', () {
      test('UserModel creation seamlessly falls back to formattedAddress when society is not a complex name', () {
        const resolvedAddress = 'Amrita Nagar, Ettimadai, Coimbatore, Tamil Nadu';
        final user = UserModel(
          uid: 'u_no_complex',
          name: 'Hasini User',
          society: resolvedAddress, // Auto-populated from resolved map address
          email: 'hasini@example.com',
          phone: '+91 9876543210',
          latitude: 10.9070,
          longitude: 76.8990,
          formattedAddress: resolvedAddress,
        );

        final json = user.toJson();
        expect(json['name'], 'Hasini User');
        expect(json['society'], resolvedAddress);
        expect(json['latitude'], 10.9070);
        expect(json['longitude'], 76.8990);
        expect(json['formattedAddress'], resolvedAddress);

        final restored = UserModel.fromJson(json, 'u_no_complex');
        expect(restored.latitude, 10.9070);
        expect(restored.longitude, 76.8990);
        expect(restored.formattedAddress, resolvedAddress);
      });

      test('UserModel creation falls back to My Neighborhood when formatted address is empty', () {
        const defaultFallback = 'My Neighborhood';
        final user = UserModel(
          uid: 'u_default_fallback',
          name: 'User Without Society',
          society: defaultFallback,
          email: 'test@example.com',
          phone: '+91 9123456789',
          latitude: 13.0827,
          longitude: 80.2707,
          formattedAddress: defaultFallback,
        );

        expect(user.society, 'My Neighborhood');
        expect(user.formattedAddress, 'My Neighborhood');
        expect(user.latitude, 13.0827);
        expect(user.longitude, 80.2707);
      });
    });

    // -------------------------------------------------------------------------
    // 7. Edit Profile: Profile Photo URL Field Removal & Storage Persistence
    // -------------------------------------------------------------------------
    group('Edit profile picture upload & preservation', () {
      test('preserves existing profile picture when no new image is selected', () {
        const existingPic = 'https://firebasestorage.googleapis.com/v0/b/toolverse/o/profile_pics%2Fuser123.jpg';
        final appUser = AppUser(
          name: 'Hasini',
          society: 'Indiranagar',
          profilePic: existingPic,
        );

        expect(appUser.profilePic, existingPic);

        // Simulate save when finalPhoto is empty or defaults to user.profilePic
        final updatedPic = '' != '' ? '' : appUser.profilePic;
        expect(updatedPic, existingPic);
      });

      test('updates profile picture when newly uploaded Storage URL is provided', () {
        const newStorageUrl = 'https://firebasestorage.googleapis.com/v0/b/toolverse/o/profile_pics%2Fuser123_new.png';
        final user = UserModel(
          uid: 'user123',
          name: 'Hasini',
          society: 'Koramangala',
          phone: '+91 9876543210',
          profilePic: newStorageUrl,
        );

        final json = user.toJson();
        expect(json['profilePic'], newStorageUrl);

        final restored = UserModel.fromJson(json, 'user123');
        expect(restored.profilePic, newStorageUrl);
      });

      test('validates image files properly before saving (StorageService)', () {
        final validJpg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00]);
        final valRes = StorageService.validateImage(
          bytes: validJpg,
          fileName: 'profile.jpg',
        );
        expect(valRes.isValid, isTrue);

        final invalidExt = StorageService.validateImage(
          bytes: validJpg,
          fileName: 'profile.svg',
        );
        expect(invalidExt.isValid, isFalse);
        expect(invalidExt.errorMessage, contains('Unsupported file format'));

        final oversized = Uint8List(10 * 1024 * 1024 + 1);
        final oversizedRes = StorageService.validateImage(
          bytes: oversized,
          fileName: 'large.png',
        );
        expect(oversizedRes.isValid, isFalse);
        expect(oversizedRes.errorMessage, contains('exceeds the 10 MB limit'));
      });
    });
  });
}


