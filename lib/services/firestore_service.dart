import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/item_model.dart';
import '../models/booking_model.dart';
import '../models/chat_model.dart';
import '../models/notification_model.dart';
import 'api_service.dart';

/// Service adapter that provides the original FirestoreService interface
/// backed by the Python FastAPI + MongoDB backend.
class FirestoreService {
  FirestoreService._internal();
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;

  final ApiService _api = ApiService();

  // -------------------------------------------------------------------------
  // Users
  // -------------------------------------------------------------------------

  Future<void> createUser(UserModel user) async {
    await _api.updateUserProfile(
      name: user.name,
      society: user.society,
      email: user.email,
      phone: user.phone,
      profilePic: user.profilePic.isNotEmpty ? user.profilePic : null,
      latitude: user.latitude,
      longitude: user.longitude,
      formattedAddress: user.formattedAddress,
    );
  }

  Future<UserModel?> getUser(String uid) async {
    return _api.getUser(uid);
  }

  Stream<UserModel?> streamUser(String uid) {
    late StreamController<UserModel?> controller;
    Timer? timer;

    Future<void> fetch() async {
      try {
        final user = await _api.getUser(uid);
        if (!controller.isClosed) controller.add(user);
      } catch (e) {
        debugPrint('[FirestoreService] streamUser error: $e');
      }
    }

    controller = StreamController<UserModel?>.broadcast(
      onListen: () {
        fetch();
        timer = Timer.periodic(const Duration(seconds: 10), (_) => fetch());
      },
      onCancel: () {
        timer?.cancel();
      },
    );

    return controller.stream;
  }

  Future<void> updateUserProfile(
    String uid, {
    String? name,
    String? society,
    String? profilePic,
    String? email,
    String? phone,
    double? latitude,
    double? longitude,
    String? formattedAddress,
  }) async {
    await _api.updateUserProfile(
      name: name,
      society: society,
      profilePic: profilePic,
      email: email,
      phone: phone,
      latitude: latitude,
      longitude: longitude,
      formattedAddress: formattedAddress,
    );
  }

  // -------------------------------------------------------------------------
  // Items
  // -------------------------------------------------------------------------

  Future<String> createItem(ItemModel item) async {
    return _api.createItem(item);
  }

  Future<void> deleteItem(String itemId) async {
    await _api.deleteItem(itemId);
  }

  Stream<List<ItemModel>> streamItems() {
    late StreamController<List<ItemModel>> controller;
    Timer? timer;

    Future<void> fetch() async {
      try {
        final items = await _api.getItems();
        if (!controller.isClosed) controller.add(items);
      } catch (e) {
        debugPrint('[FirestoreService] streamItems error: $e');
      }
    }

    controller = StreamController<List<ItemModel>>.broadcast(
      onListen: () {
        fetch();
        timer = Timer.periodic(const Duration(seconds: 6), (_) => fetch());
      },
      onCancel: () {
        timer?.cancel();
      },
    );

    return controller.stream;
  }

  // -------------------------------------------------------------------------
  // Bookings
  // -------------------------------------------------------------------------

  Future<String> createBooking(BookingModel booking) async {
    // Delegate to the typed API method that sends only what the backend needs
    final created = await _api.createBooking(
      itemId: booking.itemId,
      from: booking.from,
      to: booking.to,
      note: booking.note,
    );
    return created.id;
  }

  Stream<List<BookingModel>> streamUserBookings(String uid) {
    late StreamController<List<BookingModel>> controller;
    Timer? timer;

    Future<void> fetch() async {
      try {
        final bookings = await _api.getBookings();
        if (!controller.isClosed) controller.add(bookings);
      } catch (e) {
        debugPrint('[FirestoreService] streamUserBookings error: $e');
      }
    }

    controller = StreamController<List<BookingModel>>.broadcast(
      onListen: () {
        fetch();
        timer = Timer.periodic(const Duration(seconds: 5), (_) => fetch());
      },
      onCancel: () {
        timer?.cancel();
      },
    );

    return controller.stream;
  }

  Future<void> updateBookingStatus(String bookingId, String status) async {
    await _api.updateBookingStatus(bookingId, status);
  }

  Future<void> cancelBooking(String bookingId) async {
    await _api.cancelBooking(bookingId);
  }

  Future<void> deleteBooking(String bookingId) async {
    await _api.deleteBooking(bookingId);
  }

  Future<void> deleteAccount() async {
    await _api.deleteAccount();
  }

  Future<void> updateBookingPhotos(
    String bookingId, {
    bool? before,
    bool? after,
  }) async {
    await _api.updateBookingPhotos(bookingId, before: before, after: after);
  }

  // -------------------------------------------------------------------------
  // Chat
  // -------------------------------------------------------------------------

  Future<void> sendChatMessage(String bookingId, ChatMsgModel msg) async {
    await _api.sendChatMessage(bookingId, msg);
  }

  Stream<List<ChatMsgModel>> streamChat(
    String bookingId,
    String currentUserId,
  ) {
    late StreamController<List<ChatMsgModel>> controller;
    Timer? timer;

    Future<void> fetch() async {
      try {
        final msgs = await _api.getChatMessages(bookingId, currentUserId);
        if (!controller.isClosed) controller.add(msgs);
      } catch (e) {
        debugPrint('[FirestoreService] streamChat error: $e');
      }
    }

    controller = StreamController<List<ChatMsgModel>>.broadcast(
      onListen: () {
        fetch();
        timer = Timer.periodic(const Duration(seconds: 3), (_) => fetch());
      },
      onCancel: () {
        timer?.cancel();
      },
    );

    return controller.stream;
  }

  // -------------------------------------------------------------------------
  // Notifications
  // -------------------------------------------------------------------------

  String newNotificationId() => DateTime.now().microsecondsSinceEpoch.toString();

  Future<String> createNotification(NotificationModel notification) async {
    return notification.id;
  }

  Stream<List<NotificationModel>> streamUserNotifications(String uid) {
    late StreamController<List<NotificationModel>> controller;
    Timer? timer;

    Future<void> fetch() async {
      try {
        final notifs = await _api.getNotifications();
        if (!controller.isClosed) controller.add(notifs);
      } catch (e) {
        debugPrint('[FirestoreService] streamUserNotifications error: $e');
      }
    }

    controller = StreamController<List<NotificationModel>>.broadcast(
      onListen: () {
        fetch();
        timer = Timer.periodic(const Duration(seconds: 6), (_) => fetch());
      },
      onCancel: () {
        timer?.cancel();
      },
    );

    return controller.stream;
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    await _api.markNotificationRead(notificationId);
  }

  Future<void> markAllNotificationsAsRead(String uid) async {
    await _api.markAllNotificationsRead();
  }
}
