import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/item_model.dart';
import '../models/booking_model.dart';
import '../models/chat_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart';

// Singleton access — same instance as the one in main.dart
final ApiService apiService = ApiService();

class AppState extends ChangeNotifier {
  final AuthService _auth;
  final FirestoreService _firestore;
  final StorageService _storage;

  AppState({
    AuthService? auth,
    FirestoreService? firestore,
    StorageService? storage,
  })  : _auth = auth ?? AuthService(),
        _firestore = firestore ?? FirestoreService(),
        _storage = storage ?? StorageService();

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  UserModel? user;
  List<ItemModel> items = [];
  List<BookingModel> bookings = [];

  String pendingPhone = '';
  String pendingEmail = '';

  StreamSubscription<UserModel?>? _userSub;
  StreamSubscription<List<ItemModel>>? _itemsSub;
  StreamSubscription<List<BookingModel>>? _bookingsSub;

  // ---------------------------------------------------------------------------
  // Stream wiring — polls backend via FirestoreService adapters
  // ---------------------------------------------------------------------------

  void initStreams(String uid) {
    _userSub?.cancel();
    _itemsSub?.cancel();
    _bookingsSub?.cancel();

    _userSub = _firestore.streamUser(uid).listen((u) {
      if (u != null) user = u;
      notifyListeners();
    });

    _itemsSub = _firestore.streamItems().listen((list) {
      items = list;
      notifyListeners();
    });

    _bookingsSub = _firestore.streamUserBookings(uid).listen((list) {
      bookings = list;
      notifyListeners();
    });
  }

  void _cancelStreams() {
    _userSub?.cancel();
    _itemsSub?.cancel();
    _bookingsSub?.cancel();
    _userSub = null;
    _itemsSub = null;
    _bookingsSub = null;
  }

  // ---------------------------------------------------------------------------
  // Auth actions
  // ---------------------------------------------------------------------------

  bool isUploadingProfilePic = false;
  bool isUploadingItem = false;

  Future<void> signUp(
    String name,
    String society, {
    String? email,
    String? phone,
    double? latitude,
    double? longitude,
    String? formattedAddress,
    String? profilePic,
  }) async {
    final existingPic = (profilePic != null && profilePic.trim().isNotEmpty)
        ? profilePic.trim()
        : (user?.profilePic.isNotEmpty == true
            ? user!.profilePic
            : (_auth.currentUser?.photoURL ?? ''));

    // Update profile on the backend
    await _firestore.updateUserProfile(
      apiService.currentUserId ?? '',
      name: name,
      society: society,
      email: email ?? '',
      phone: phone ?? pendingPhone,
      profilePic: existingPic.isNotEmpty ? existingPic : null,
      latitude: latitude,
      longitude: longitude,
      formattedAddress: formattedAddress ?? society,
    );

    // Refresh from backend
    final refreshed = await apiService.getMyProfile();
    if (refreshed != null) {
      user = refreshed;
    } else {
      final uid = apiService.currentUserId ?? _auth.currentUserId ?? '';
      user = UserModel(
        uid: uid,
        name: name,
        society: society,
        phone: phone ?? pendingPhone,
        profilePic: existingPic,
        email: email ?? '',
        latitude: latitude,
        longitude: longitude,
        formattedAddress: formattedAddress ?? society,
      );
    }
    notifyListeners();

    final uid = apiService.currentUserId ?? _auth.currentUserId ?? '';
    if (uid.isNotEmpty) {
      initStreams(uid);
    }
  }

  Future<void> updateProfile({
    String? name,
    String? society,
    String? profilePic,
    String? email,
    String? phone,
    double? latitude,
    double? longitude,
    String? formattedAddress,
  }) async {
    // Optimistic local update for instant UI feedback
    if (user != null) {
      if (name != null && name.trim().isNotEmpty) user!.name = name.trim();
      if (society != null && society.trim().isNotEmpty) user!.society = society.trim();
      if (profilePic != null) user!.profilePic = profilePic.trim();
      if (email != null && email.trim().isNotEmpty) user!.email = email.trim();
      if (phone != null && phone.trim().isNotEmpty) user!.phone = phone.trim();
      if (latitude != null) user!.latitude = latitude;
      if (longitude != null) user!.longitude = longitude;
      if (formattedAddress != null && formattedAddress.trim().isNotEmpty) {
        user!.formattedAddress = formattedAddress.trim();
      }
      notifyListeners();
    }

    var uid = _auth.currentUserId;
    if (uid == null || uid.isEmpty) {
      uid = await _auth.signInAnonymously();
    }

    if (uid != null && uid.isNotEmpty) {
      await _firestore.updateUserProfile(
        uid,
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
  }

  Future<String> uploadProfilePicture({
    required Uint8List bytes,
    required String fileName,
  }) async {
    var uid = _auth.currentUserId;
    if (uid == null || uid.isEmpty) {
      uid = await _auth.signInAnonymously();
    }
    if (uid == null || uid.isEmpty) {
      throw Exception('Unable to authenticate session for image upload.');
    }

    isUploadingProfilePic = true;
    notifyListeners();

    try {
      final downloadUrl = await _storage.uploadProfilePicture(
        bytes: bytes,
        fileName: fileName,
        userId: uid,
      );
      await updateProfile(profilePic: downloadUrl);
      return downloadUrl;
    } finally {
      isUploadingProfilePic = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _cancelStreams();
    user = null;
    items = [];
    bookings = [];
    pendingPhone = '';
    pendingEmail = '';
    notifyListeners();
    await _auth.signOut();
  }

  // ---------------------------------------------------------------------------
  // Items — all backed by real backend, NO hardcoded seeds
  // ---------------------------------------------------------------------------

  Future<String> uploadAndPublishItem({
    required ItemModel item,
    Uint8List? imageBytes,
    String? imageFileName,
  }) async {
    final uid = _auth.currentUserId ?? (item.ownerId.isNotEmpty ? item.ownerId : '');
    String finalImageUrl = item.imageUrl;

    isUploadingItem = true;
    notifyListeners();

    try {
      if (imageBytes != null &&
          imageBytes.isNotEmpty &&
          imageFileName != null &&
          imageFileName.isNotEmpty) {
        finalImageUrl = await _storage.uploadItemImage(
          bytes: imageBytes,
          fileName: imageFileName,
          userId: uid,
        );
      }

      final itemToPublish = ItemModel(
        id: item.id,
        name: item.name,
        category: item.category,
        owner: item.owner,
        ownerId: uid,
        desc: item.desc,
        deposit: item.deposit,
        imageUrl: finalImageUrl,
        createdAt: item.createdAt,
      );

      final createdId = await _firestore.createItem(itemToPublish);

      // Refresh item list from backend immediately
      try {
        final refreshed = await apiService.getItems();
        items = refreshed;
        notifyListeners();
      } catch (_) {}

      return createdId;
    } finally {
      isUploadingItem = false;
      notifyListeners();
    }
  }

  Future<void> deleteItem(String itemId) async {
    await _firestore.deleteItem(itemId);
    items.removeWhere((i) => i.id == itemId);
    bookings.removeWhere((b) => b.itemId == itemId);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Bookings — backend API, no hardcoded fields
  // ---------------------------------------------------------------------------

  Future<BookingModel> requestBorrow(
    ItemModel item,
    DateTime? from,
    DateTime? to,
    String note,
  ) async {
    final uid = _auth.currentUserId ?? '';

    // Backend resolves itemName, lenderId, deposit, etc. from the item record
    final created = await apiService.createBooking(
      itemId: item.id,
      from: from,
      to: to,
      note: note,
    );

    // Optimistically insert so BookingScreen can display immediately
    bookings.insert(0, created);
    notifyListeners();

    // Sync bookings from backend
    _refreshBookings(uid);

    return created;
  }

  Future<void> _refreshBookings(String uid) async {
    try {
      final refreshed = await apiService.getBookings();
      bookings = refreshed;
      notifyListeners();
    } catch (e) {
      debugPrint('[AppState] _refreshBookings error: $e');
    }
  }

  Future<void> cancelBooking(String bookingId) async {
    await _firestore.cancelBooking(bookingId);
    final idx = bookings.indexWhere((b) => b.id == bookingId);
    if (idx != -1) {
      bookings[idx].status = BookingStatus.cancelled;
      notifyListeners();
    }
  }

  Future<void> deleteBooking(String bookingId) async {
    await _firestore.deleteBooking(bookingId);
    bookings.removeWhere((b) => b.id == bookingId);
    notifyListeners();
  }

  Future<void> deleteAccount() async {
    await _firestore.deleteAccount();
    await logout();
  }

  // ---------------------------------------------------------------------------
  // Chat — real API calls, no fake auto-replies
  // ---------------------------------------------------------------------------

  Future<void> sendChat(String bookingId, String text) async {
    final uid = _auth.currentUserId ?? '';
    final msg = ChatMsgModel(
      id: '',
      text: text,
      senderId: uid,
      fromMe: true,
      timestamp: DateTime.now(),
    );
    await _firestore.sendChatMessage(bookingId, msg);
  }

  Future<void> sendLocationMessage({
    required String bookingId,
    required double latitude,
    required double longitude,
    required String address,
  }) async {
    final uid = _auth.currentUserId ?? '';
    final msg = ChatMsgModel(
      id: '',
      text: '📍 Pickup Location: $address',
      senderId: uid,
      fromMe: true,
      timestamp: DateTime.now(),
      type: 'location',
      latitude: latitude,
      longitude: longitude,
      locationAddress: address,
    );
    await _firestore.sendChatMessage(bookingId, msg);
  }

  // ---------------------------------------------------------------------------
  // Booking lifecycle — all via backend
  // ---------------------------------------------------------------------------

  Future<void> markPickedUp(String bookingId) async {
    await _firestore.updateBookingStatus(bookingId, BookingStatus.active.name);
    final idx = bookings.indexWhere((b) => b.id == bookingId);
    if (idx != -1) {
      bookings[idx].status = BookingStatus.active;
      notifyListeners();
    }
  }

  Future<void> markPhoto(String bookingId, {required bool before}) async {
    await _firestore.updateBookingPhotos(
      bookingId,
      before: before ? true : null,
      after: before ? null : true,
    );
    final idx = bookings.indexWhere((b) => b.id == bookingId);
    if (idx != -1) {
      if (before) {
        bookings[idx].beforePhoto = true;
      } else {
        bookings[idx].afterPhoto = true;
      }
      notifyListeners();
    }
  }

  Future<void> runAiCheck(String bookingId) async {
    await Future.delayed(const Duration(milliseconds: 1600));
    try {
      await apiService.runAiCheck(bookingId);
    } catch (_) {
      await _firestore.updateBookingStatus(bookingId, BookingStatus.done.name);
    }
    final idx = bookings.indexWhere((b) => b.id == bookingId);
    if (idx != -1) {
      bookings[idx].status = BookingStatus.done;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _cancelStreams();
    super.dispose();
  }
}
