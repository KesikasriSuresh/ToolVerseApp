import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../firebase_options.dart';
import 'api_service.dart';

/// Top-level background message handler for FCM
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint(
      '[FCM Background Handler] Received message id: ${message.messageId}, Title: ${message.notification?.title ?? message.data['title']}, Body: ${message.notification?.body ?? message.data['body']}',
    );
  } catch (e) {
    debugPrint('[FCM Background Handler] Error in background handler: $e');
  }
}

class NotificationService extends ChangeNotifier {
  NotificationService._internal();
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  FirebaseMessaging get _fcm => FirebaseMessaging.instance;
  String? _fcmToken;
  bool _initialized = false;
  NotificationSettings? _settings;
  String? _initializationError;
  String? _tokenError;
  String? _registeredUserId;
  Future<void>? _initialization;

  String? get fcmToken => _fcmToken;
  bool get isInitialized => _initialized;
  NotificationSettings? get settings => _settings;
  String get firebaseProjectId =>
      Firebase.apps.isEmpty ? 'Unavailable' : Firebase.app().options.projectId;
  String get permissionStatus =>
      _settings?.authorizationStatus.name ?? 'not requested';
  String? get initializationError => _initializationError;
  String? get tokenError => _tokenError;
  bool get isPushReady =>
      _initialized &&
      _fcmToken != null &&
      (_settings?.authorizationStatus == AuthorizationStatus.authorized ||
          _settings?.authorizationStatus == AuthorizationStatus.provisional);

  // Callback to trigger in-app UI banners or custom feedback
  void Function(String title, String body, Map<String, dynamic> data)?
      _onForegroundNotification;

  /// Initialize Firebase Cloud Messaging listeners, permissions, and tokens
  Future<void> initialize({
    void Function(String title, String body, Map<String, dynamic> data)?
        onForegroundNotification,
  }) async {
    _onForegroundNotification =
        onForegroundNotification ?? _onForegroundNotification;
    if (_initialized) return;
    final pendingInitialization = _initialization;
    if (pendingInitialization != null) {
      await pendingInitialization;
      return;
    }
    final initialization = _initializeListeners();
    _initialization = initialization;
    await initialization;
    _initialization = null;
  }

  Future<void> _initializeListeners() async {
    try {
      if (Firebase.apps.isEmpty) {
        debugPrint('[FCM] Firebase not initialized yet, skipping FCM setup');
        _initializationError = 'Firebase has not been initialized.';
        notifyListeners();
        return;
      }

      // 1. Set background messaging handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Set up token refresh and incoming-message listeners.
      _fcm.onTokenRefresh.listen((newToken) {
        debugPrint('[FCM] Token refreshed: $newToken');
        _fcmToken = newToken;
        notifyListeners();
        final uid = _registeredUserId;
        if (uid != null) {
          saveTokenToUser(uid);
        }
      });

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint(
          '[FCM Foreground] Received: ${message.notification?.title ?? message.data['title']} - ${message.notification?.body ?? message.data['body']}',
        );
        _dispatchMessage(message);
      });

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint(
            '[FCM onMessageOpenedApp] User tapped notification: ${message.data}');
        _dispatchMessage(message);
      });

      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        debugPrint(
          '[FCM getInitialMessage] Launched from terminated notification: ${initialMessage.data}',
        );
        _dispatchMessage(initialMessage);
      }

      _initialized = true;
      notifyListeners();
    } catch (e) {
      _initializationError = e.toString();
      debugPrint(
          '[FCM Init Warning] Error initializing Firebase Messaging: $e');
      notifyListeners();
    }
  }

  Future<void> requestPermissionAndRefreshToken() async {
    _initializationError = null;
    _tokenError = null;
    try {
      // Request before awaiting setup so the browser sees a direct user action.
      await _requestPermission();
      await initialize();
      if (!_initialized) return;
      await _retrieveToken();
    } catch (e) {
      _initializationError = e.toString();
      debugPrint('[FCM] Failed to refresh permission/token: $e');
      notifyListeners();
    }
  }

  Future<void> _requestPermission() async {
    _settings = await _fcm.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    debugPrint(
      '[FCM] Permission status: ${_settings?.authorizationStatus.name}',
    );
    notifyListeners();
  }

  void _dispatchMessage(RemoteMessage message) {
    final title = message.notification?.title ??
        message.data['title']?.toString() ??
        'ToolVerse Alert';
    final body = message.notification?.body ??
        message.data['body']?.toString() ??
        'New activity in your neighborhood.';
    _onForegroundNotification?.call(title, body, message.data);
  }

  // VAPID key for web push — from Firebase Console > Project Settings > Cloud Messaging > Web Push certificates
  static const String _vapidKey = 'BAYZStGoSiKbR5KnZrwHVRPizuSh8kVy90R57rGFhYQZWw3eeLadcKiFfA_FhCydeTcVxPH2oo7LLOYMADhV8Ec';

  Future<void> _retrieveToken() async {
    try {
      // Use hardcoded VAPID key for web builds (avoids --dart-define requirement)
      const envKey = String.fromEnvironment('FCM_VAPID_KEY');
      final vapidKey = envKey.isNotEmpty ? envKey : _vapidKey;
      if (kIsWeb && (vapidKey.isEmpty || vapidKey == 'REPLACE_WITH_YOUR_VAPID_KEY')) {
        debugPrint('[FCM] VAPID key not configured — skipping web token fetch.');
        _tokenError = 'VAPID key not set. Add it to notification_service.dart.';
        notifyListeners();
        return;
      }
      final token = await _fcm.getToken(
        vapidKey: kIsWeb ? vapidKey : null,
      );
      _fcmToken = token;
      _tokenError = token == null
          ? 'Firebase Messaging did not return a device token. Check browser support and notification permission.'
          : null;
      debugPrint('[FCM] Device registration token available: ${token != null}');
    } catch (e) {
      _tokenError = e.toString();
      debugPrint('[FCM] Failed to retrieve FCM token: $e');
    }
    final uid = _registeredUserId;
    if (_fcmToken != null && uid != null) {
      await saveTokenToUser(uid);
    }
    notifyListeners();
  }

  /// Saves the current device FCM token to the user document in MongoDB via ApiService
  Future<void> saveTokenToUser(String uid) async {
    if (uid.isEmpty) return;
    _registeredUserId = uid;
    if (_fcmToken == null) return;
    try {
      final api = ApiService();
      await api.registerFcmToken(_fcmToken!);
      debugPrint('[FCM] Saved FCM token to backend for uid: $uid');
    } catch (e) {
      debugPrint('[FCM] Error saving FCM token to user via API: $e');
    }
  }

  void clearRegisteredUser() {
    _registeredUserId = null;
  }

  /// Sends a simulated or test push notification to demonstrate FCM receiving logic
  void triggerTestPushNotification({
    String title = 'Booking Confirmed! 📦',
    String body =
        'Ananya approved your borrow request for Bosch Cordless Drill. Ready for pickup!',
    Map<String, dynamic>? data,
  }) {
    _onForegroundNotification?.call(title, body, data ?? {'type': 'booking'});
  }

  /// Sends a simulated or test reminder push notification for live demo
  void triggerTestReminderNotification({
    String title = 'Return Reminder: Due Tomorrow ⏰',
    String body =
        'Bosch Cordless Drill is scheduled for return tomorrow by 6:00 PM. Please inspect item condition.',
    Map<String, dynamic>? data,
  }) {
    _onForegroundNotification?.call(title, body, data ?? {'type': 'reminder'});
  }
}
