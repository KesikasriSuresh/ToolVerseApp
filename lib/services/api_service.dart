import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../models/item_model.dart';
import '../models/booking_model.dart';
import '../models/chat_model.dart';
import '../models/notification_model.dart';

class ApiService {
  ApiService._internal();
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  // Base URL config
  static const String _defaultLocalBaseUrl = 'http://127.0.0.1:8000';
  static const String _defaultAndroidEmulatorBaseUrl = 'http://10.0.2.2:8000';

  /// Override at build/run time, e.g. for a physical phone on your Wi-Fi:
  ///   flutter run --dart-define=API_BASE_URL=http://192.168.1.20:8000
  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');

  String _customBaseUrl = _envBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');

  // Public backend tunnel URL for web/mobile testing
  static const String _webBackendUrl = 'https://many-marbled-refute.ngrok-free.dev';

  String get baseUrl {
    if (_customBaseUrl.isNotEmpty) return _customBaseUrl;
    if (kIsWeb) {
      final host = Uri.base.host;
      // When running Flutter Web locally, route directly to the local backend
      if (host == 'localhost' || host == '127.0.0.1' || host.isEmpty) {
        return _defaultLocalBaseUrl;
      }
      // When served via a remote tunnel, use the dedicated backend tunnel URL.
      return _webBackendUrl;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return _defaultAndroidEmulatorBaseUrl;
    }
    return _defaultLocalBaseUrl;
  }

  void setBaseUrl(String url) {
    _customBaseUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
  }

  String? _authToken;
  String? get authToken => _authToken;

  static const String _tokenPrefKey = 'toolverse_jwt_token';
  static const String _uidPrefKey = 'toolverse_current_uid';

  String? _currentUserId;
  String? get currentUserId => _currentUserId;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _authToken = prefs.getString(_tokenPrefKey);
      _currentUserId = prefs.getString(_uidPrefKey);
    } catch (e) {
      debugPrint('[ApiService] Error loading cached token: $e');
    }
  }

  Future<void> saveAuthToken(String token, String uid) async {
    _authToken = token;
    _currentUserId = uid;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenPrefKey, token);
      await prefs.setString(_uidPrefKey, uid);
    } catch (e) {
      debugPrint('[ApiService] Error saving token to prefs: $e');
    }
  }

  Future<void> clearAuthToken() async {
    _authToken = null;
    _currentUserId = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenPrefKey);
      await prefs.remove(_uidPrefKey);
    } catch (e) {
      debugPrint('[ApiService] Error clearing token: $e');
    }
  }

  /// Turns a FastAPI error body into a user-facing message.
  static String _msg(dynamic body, String fallback) {
    if (body is Map && body['detail'] != null) {
      final d = body['detail'];
      if (d is String && d.isNotEmpty) return d;
      if (d is List && d.isNotEmpty && d.first is Map) {
        final first = d.first as Map;
        final m = first['msg']?.toString() ?? fallback;
        return m.replaceFirst('Value error, ', '');
      }
    }
    return fallback;
  }

  Map<String, String> get _headers {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_authToken != null && _authToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    return headers;
  }

  // ---------------------------------------------------------------------------
  // AUTH
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> sendOtp(String phone) async {
    return sendCode(phone: phone);
  }

  Future<Map<String, dynamic>> sendEmailOtp(String email) async {
    return sendCode(email: email);
  }

  Future<Map<String, dynamic>> sendCode({String? phone, String? email}) async {
    final uri = Uri.parse('$baseUrl/api/auth/otp/send');
    final payload = <String, dynamic>{};
    if (phone != null && phone.isNotEmpty) payload['phone'] = phone;
    if (email != null && email.isNotEmpty) payload['email'] = email;

    final resp = await http
        .post(uri, headers: _headers, body: jsonEncode(payload))
        .timeout(const Duration(seconds: 10));

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode != 200) {
      throw Exception(_msg(data, 'Failed to send verification code.'));
    }
    return data;
  }

  Future<Map<String, dynamic>> verifyOtp(String phone, String otp) async {
    return verifyCode(phone: phone, otp: otp);
  }

  Future<Map<String, dynamic>> verifyEmailOtp(String email, String otp) async {
    return verifyCode(email: email, otp: otp);
  }

  Future<Map<String, dynamic>> verifyCode({
    String? phone,
    String? email,
    required String otp,
  }) async {
    final uri = Uri.parse('$baseUrl/api/auth/otp/verify');
    final payload = <String, dynamic>{'otp': otp};
    if (phone != null && phone.isNotEmpty) payload['phone'] = phone;
    if (email != null && email.isNotEmpty) payload['email'] = email;

    final resp = await http
        .post(uri, headers: _headers, body: jsonEncode(payload))
        .timeout(const Duration(seconds: 10));

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode != 200) {
      throw Exception(_msg(data, 'Invalid verification code.'));
    }

    final token = data['access_token'] as String;
    final uid = data['uid'] as String;
    await saveAuthToken(token, uid);

    return data;
  }

  Future<Map<String, dynamic>> googleLogin({
    required String email,
    String? name,
    String? profilePic,
    String? googleId,
    String? idToken,
  }) async {
    final uri = Uri.parse('$baseUrl/api/auth/google');
    final payload = <String, dynamic>{
      'email': email,
      if (name != null && name.isNotEmpty) 'name': name,
      if (profilePic != null && profilePic.isNotEmpty) 'profilePic': profilePic,
      if (googleId != null && googleId.isNotEmpty) 'googleId': googleId,
      if (idToken != null && idToken.isNotEmpty) 'idToken': idToken,
    };

    final resp = await http
        .post(uri, headers: _headers, body: jsonEncode(payload))
        .timeout(const Duration(seconds: 12));

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode != 200) {
      throw Exception(_msg(data, 'Google login failed.'));
    }

    final token = data['access_token'] as String;
    final uid = data['uid'] as String;
    await saveAuthToken(token, uid);

    return data;
  }

  Future<Map<String, dynamic>> signInAnonymously() async {
    final uri = Uri.parse('$baseUrl/api/auth/anonymous');
    final resp = await http
        .post(uri, headers: _headers)
        .timeout(const Duration(seconds: 10));

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode != 200) {
      throw Exception(_msg(data, 'Anonymous login failed.'));
    }

    final token = data['access_token'] as String;
    final uid = data['uid'] as String;
    await saveAuthToken(token, uid);

    return data;
  }

  Future<void> logout() async {
    if (_authToken == null) return;
    try {
      await http
          .post(Uri.parse('$baseUrl/api/auth/logout'), headers: _headers)
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('[ApiService] logout request failed (continuing locally): $e');
    }
  }

  Future<UserModel?> getMyProfile() async {
    if (_authToken == null) return null;
    try {
      final uri = Uri.parse('$baseUrl/api/auth/me');
      final resp = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final uid = data['uid'] as String? ?? data['id'] as String;
        return UserModel.fromJson(data, uid);
      }
    } catch (e) {
      debugPrint('[ApiService] getMyProfile error: $e');
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // USERS
  // ---------------------------------------------------------------------------

  Future<UserModel?> getUser(String uid) async {
    try {
      final uri = Uri.parse('$baseUrl/api/users/$uid');
      final resp = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return UserModel.fromJson(data, uid);
      }
    } catch (e) {
      debugPrint('[ApiService] getUser error: $e');
    }
    return null;
  }

  Future<UserModel> updateUserProfile({
    String? name,
    String? society,
    String? email,
    String? phone,
    String? profilePic,
    double? latitude,
    double? longitude,
    String? formattedAddress,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (society != null) body['society'] = society;
    if (email != null) body['email'] = email;
    if (phone != null) body['phone'] = phone;
    if (profilePic != null && profilePic.trim().isNotEmpty) {
      body['profilePic'] = profilePic.trim();
    }
    if (latitude != null) body['latitude'] = latitude;
    if (longitude != null) body['longitude'] = longitude;
    if (formattedAddress != null) body['formattedAddress'] = formattedAddress;

    final uri = Uri.parse('$baseUrl/api/users/profile');
    final resp = await http
        .put(uri, headers: _headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 10));

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode != 200) {
      throw Exception(_msg(data, 'Failed to update profile.'));
    }
    final uid = data['uid'] as String? ?? _currentUserId ?? '';
    return UserModel.fromJson(data, uid);
  }

  Future<void> registerFcmToken(String fcmToken) async {
    if (_authToken == null || fcmToken.isEmpty) return;
    try {
      final uri = Uri.parse('$baseUrl/api/users/fcm-token');
      await http.post(
        uri,
        headers: _headers,
        body: jsonEncode({'fcmToken': fcmToken}),
      ).timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('[ApiService] Error registering FCM token: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // ITEMS
  // ---------------------------------------------------------------------------

  Future<List<ItemModel>> getItems({String? category, String? query}) async {
    final queryParams = <String, String>{};
    if (category != null && category.isNotEmpty && category != 'all') {
      queryParams['category'] = category;
    }
    if (query != null && query.isNotEmpty) {
      queryParams['query'] = query;
    }

    final uri = Uri.parse('$baseUrl/api/items').replace(queryParameters: queryParams.isEmpty ? null : queryParams);
    final resp = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 10));

    if (resp.statusCode != 200) {
      throw Exception('Failed to load items catalogue.');
    }

    final list = jsonDecode(resp.body) as List<dynamic>;
    return list.map((item) {
      final map = item as Map<String, dynamic>;
      final id = map['id'] as String? ?? map['_id'] as String? ?? '';
      return ItemModel.fromJson(map, id);
    }).toList();
  }

  Future<List<ItemModel>> getMyItems() async {
    final uri = Uri.parse('$baseUrl/api/items/my');
    final resp = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 10));

    if (resp.statusCode != 200) {
      throw Exception('Failed to load user listed items.');
    }

    final list = jsonDecode(resp.body) as List<dynamic>;
    return list.map((item) {
      final map = item as Map<String, dynamic>;
      final id = map['id'] as String? ?? map['_id'] as String? ?? '';
      return ItemModel.fromJson(map, id);
    }).toList();
  }

  Future<String> createItem(ItemModel item) async {
    final uri = Uri.parse('$baseUrl/api/items');
    final resp = await http
        .post(uri, headers: _headers, body: jsonEncode(item.toJson()))
        .timeout(const Duration(seconds: 12));

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode != 201 && resp.statusCode != 200) {
      throw Exception(_msg(data, 'Failed to create item.'));
    }
    return data['id'] as String? ?? data['_id'] as String? ?? '';
  }

  Future<void> deleteItem(String itemId) async {
    final uri = Uri.parse('$baseUrl/api/items/$itemId');
    final resp = await http.delete(uri, headers: _headers).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) {
      final data = jsonDecode(resp.body);
      throw Exception(_msg(data, 'Failed to delete item.'));
    }
  }

  // ---------------------------------------------------------------------------
  // BOOKINGS
  // ---------------------------------------------------------------------------

  Future<BookingModel> createBooking({
    required String itemId,
    DateTime? from,
    DateTime? to,
    String note = '',
  }) async {
    final uri = Uri.parse('$baseUrl/api/bookings');
    final body = <String, dynamic>{
      'itemId': itemId,
      if (from != null) 'from': from.toUtc().toIso8601String(),
      if (to != null) 'to': to.toUtc().toIso8601String(),
      'note': note,
    };

    final resp = await http
        .post(uri, headers: _headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 12));

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode != 201 && resp.statusCode != 200) {
      throw Exception(_msg(data, 'Failed to submit borrow request.'));
    }
    final id = data['id'] as String? ?? data['_id'] as String? ?? '';
    return BookingModel.fromJson(data, id);
  }

  Future<List<BookingModel>> getBookings({String? role}) async {
    final queryParams = <String, String>{};
    if (role != null) queryParams['role'] = role;

    final uri = Uri.parse('$baseUrl/api/bookings').replace(queryParameters: queryParams.isEmpty ? null : queryParams);
    final resp = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 10));

    if (resp.statusCode != 200) {
      throw Exception('Failed to load bookings.');
    }

    final list = jsonDecode(resp.body) as List<dynamic>;
    return list.map((item) {
      final map = item as Map<String, dynamic>;
      final id = map['id'] as String? ?? map['_id'] as String? ?? '';
      return BookingModel.fromJson(map, id);
    }).toList();
  }

  Future<void> updateBookingStatus(String bookingId, String status) async {
    final uri = Uri.parse('$baseUrl/api/bookings/$bookingId/status');
    final resp = await http
        .patch(uri, headers: _headers, body: jsonEncode({'status': status}))
        .timeout(const Duration(seconds: 10));

    if (resp.statusCode != 200) {
      final data = jsonDecode(resp.body);
      throw Exception(_msg(data, 'Failed to update booking status.'));
    }
  }

  Future<void> cancelBooking(String bookingId) async {
    final uri = Uri.parse('$baseUrl/api/bookings/$bookingId/status');
    final resp = await http
        .patch(uri, headers: _headers, body: jsonEncode({'status': 'cancelled'}))
        .timeout(const Duration(seconds: 10));

    if (resp.statusCode != 200) {
      final data = jsonDecode(resp.body);
      throw Exception(_msg(data, 'Failed to cancel booking request.'));
    }
  }

  Future<void> deleteBooking(String bookingId) async {
    final uri = Uri.parse('$baseUrl/api/bookings/$bookingId');
    final resp = await http.delete(uri, headers: _headers).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) {
      final data = jsonDecode(resp.body);
      throw Exception(_msg(data, 'Failed to delete booking request.'));
    }
  }

  Future<void> deleteAccount() async {
    final uri = Uri.parse('$baseUrl/api/users/me');
    final resp = await http.delete(uri, headers: _headers).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      final data = jsonDecode(resp.body);
      throw Exception(_msg(data, 'Failed to delete account.'));
    }
    await clearAuthToken();
  }

  Future<void> updateBookingPhotos(
    String bookingId, {
    bool? before,
    bool? after,
  }) async {
    final body = <String, dynamic>{};
    if (before != null) body['before'] = before;
    if (after != null) body['after'] = after;

    final uri = Uri.parse('$baseUrl/api/bookings/$bookingId/photos');
    final resp = await http
        .patch(uri, headers: _headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 10));

    if (resp.statusCode != 200) {
      final data = jsonDecode(resp.body);
      throw Exception(_msg(data, 'Failed to update photos.'));
    }
  }

  Future<void> runAiCheck(String bookingId) async {
    final uri = Uri.parse('$baseUrl/api/bookings/$bookingId/ai-check');
    final resp = await http.post(uri, headers: _headers).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      final data = jsonDecode(resp.body);
      throw Exception(_msg(data, 'AI condition check failed.'));
    }
  }

  // ---------------------------------------------------------------------------
  // CHAT
  // ---------------------------------------------------------------------------

  Future<List<ChatMsgModel>> getChatMessages(String bookingId, String currentUid) async {
    final uri = Uri.parse('$baseUrl/api/chats/$bookingId');
    final resp = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 8));

    if (resp.statusCode != 200) {
      return [];
    }

    final list = jsonDecode(resp.body) as List<dynamic>;
    return list.map((msg) {
      final map = msg as Map<String, dynamic>;
      final id = map['id'] as String? ?? map['_id'] as String? ?? '';
      return ChatMsgModel.fromJson(map, id, currentUid);
    }).toList();
  }

  Future<void> sendChatMessage(String bookingId, ChatMsgModel msg) async {
    final uri = Uri.parse('$baseUrl/api/chats/$bookingId');
    final resp = await http
        .post(uri, headers: _headers, body: jsonEncode(msg.toJson()))
        .timeout(const Duration(seconds: 8));

    if (resp.statusCode != 201 && resp.statusCode != 200) {
      final data = jsonDecode(resp.body);
      throw Exception(_msg(data, 'Failed to send message.'));
    }
  }

  // ---------------------------------------------------------------------------
  // NOTIFICATIONS
  // ---------------------------------------------------------------------------

  Future<List<NotificationModel>> getNotifications() async {
    final uri = Uri.parse('$baseUrl/api/notifications');
    final resp = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 8));

    if (resp.statusCode != 200) {
      return [];
    }

    final list = jsonDecode(resp.body) as List<dynamic>;
    return list.map((item) {
      final map = item as Map<String, dynamic>;
      final id = map['id'] as String? ?? map['_id'] as String? ?? '';
      return NotificationModel.fromJson(map, id);
    }).toList();
  }

  Future<void> markNotificationRead(String notificationId) async {
    final uri = Uri.parse('$baseUrl/api/notifications/$notificationId/read');
    await http.patch(uri, headers: _headers).timeout(const Duration(seconds: 5));
  }

  Future<void> markAllNotificationsRead() async {
    final uri = Uri.parse('$baseUrl/api/notifications/read-all');
    await http.patch(uri, headers: _headers).timeout(const Duration(seconds: 5));
  }

  // ---------------------------------------------------------------------------
  // CLOUDINARY UPLOADS
  // ---------------------------------------------------------------------------

  Future<String> uploadImage({
    required Uint8List bytes,
    required String fileName,
    String category = 'item_photo',
  }) async {
    final uri = Uri.parse('$baseUrl/api/uploads/image?category=$category');
    final request = http.MultipartRequest('POST', uri);

    if (_authToken != null && _authToken!.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $_authToken';
    }

    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : 'jpg';
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: fileName,
        contentType: http.MediaType('image', ext == 'png' ? 'png' : (ext == 'webp' ? 'webp' : 'jpeg')),
      ),
    );

    final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamedResponse);

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(_msg(data, 'Failed to upload image to Cloudinary.'));
    }

    final url = data['url'] as String;
    return url;
  }
}
