import 'package:flutter_test/flutter_test.dart';
import 'package:toolverse/main.dart';
import 'package:toolverse/models/chat_model.dart';

void main() {
  group('Step 8: Booking Chat Pickup Location Sharing', () {
    test('ChatMsg model supports location messages and backward compatibility', () {
      // 1. Text message (backward compatibility)
      final textMsg = ChatMsg(true, 'Hello there');
      expect(textMsg.fromMe, isTrue);
      expect(textMsg.text, 'Hello there');
      expect(textMsg.type, 'text');
      expect(textMsg.isLocation, isFalse);
      expect(textMsg.latitude, isNull);
      expect(textMsg.longitude, isNull);
      expect(textMsg.locationAddress, isNull);

      // 2. Location message
      final locMsg = ChatMsg(
        false,
        '📍 Pickup Location: Palm Meadows, Block C',
        type: 'location',
        latitude: 12.9576,
        longitude: 77.7441,
        locationAddress: 'Palm Meadows, Block C',
      );
      expect(locMsg.fromMe, isFalse);
      expect(locMsg.isLocation, isTrue);
      expect(locMsg.latitude, 12.9576);
      expect(locMsg.longitude, 77.7441);
      expect(locMsg.locationAddress, 'Palm Meadows, Block C');
    });

    test('ChatMsgModel serializes and deserializes location data properly', () {
      final model = ChatMsgModel(
        id: 'msg_123',
        text: '📍 Pickup Location: Indiranagar 100ft Road',
        senderId: 'user_abc',
        fromMe: true,
        timestamp: DateTime(2026, 10, 16, 10, 0),
        type: 'location',
        latitude: 12.9716,
        longitude: 77.6412,
        locationAddress: 'Indiranagar 100ft Road',
      );

      final json = model.toJson();
      expect(json['type'], 'location');
      expect(json['latitude'], 12.9716);
      expect(json['longitude'], 77.6412);
      expect(json['locationAddress'], 'Indiranagar 100ft Road');

      final deserialized = ChatMsgModel.fromJson(json, 'msg_123', 'user_abc');
      expect(deserialized.id, 'msg_123');
      expect(deserialized.fromMe, isTrue);
      expect(deserialized.isLocation, isTrue);
      expect(deserialized.latitude, 12.9716);
      expect(deserialized.longitude, 77.6412);
      expect(deserialized.locationAddress, 'Indiranagar 100ft Road');
    });

    test('Booking model chat list holds both text and location messages', () {
      final item = Item(
        id: 'item_1',
        name: 'Tent',
        category: ItemCategory.camping,
        owner: 'Alice',
        desc: '4-person tent',
        deposit: 500,
      );

      final booking = Booking(
        id: 'booking_1',
        item: item,
        from: DateTime.now(),
        to: DateTime.now().add(const Duration(days: 2)),
        note: 'Weekend trek',
        chat: [
          ChatMsg(false, 'Hi, when do you want to pick it up?'),
          ChatMsg(
            true,
            '📍 Pickup Location: Indiranagar',
            type: 'location',
            latitude: 12.9716,
            longitude: 77.6412,
            locationAddress: 'Indiranagar',
          ),
        ],
      );

      expect(booking.chat.length, 2);
      expect(booking.chat[0].isLocation, isFalse);
      expect(booking.chat[1].isLocation, isTrue);
      expect(booking.chat[1].latitude, 12.9716);
      expect(booking.chat[1].longitude, 77.6412);
    });
  });
}
