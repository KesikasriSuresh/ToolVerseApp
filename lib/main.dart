import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'firebase_options.dart';
import 'package:google_fonts/google_fonts.dart';
import 'models/item_model.dart' as fm;
import 'models/booking_model.dart' as bm;
import 'models/chat_model.dart';
import 'models/notification_model.dart' as nm;
import 'models/user_model.dart';
import 'models/country_code.dart';
import 'widgets/galaxy_background.dart';
import 'widgets/map_location_picker.dart';
import 'widgets/web_location_helper.dart';
import 'widgets/camera_helper.dart';
import 'widgets/tts_helper.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'services/gemini_vision_service.dart';
import 'utils/input_validators.dart';
import 'package:image_picker/image_picker.dart';

// Global singletons — accessible from auth screens without BuildContext
final apiService = ApiService();
final authService = AuthService();
final firestoreService = FirestoreService();
final notificationService = NotificationService();
final storageService = StorageService();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  checkAndSwitchToSecureOrigin();
  await apiService.init();
  try {
    final app = await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint(
        '[Firebase Init] Successfully connected to Firebase Project: "${app.options.projectId}" (Platform: ${kIsWeb ? "Web" : defaultTargetPlatform.name})');
    final supportsAnalytics = kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    final hasWebMeasurementId =
        DefaultFirebaseOptions.web.measurementId?.isNotEmpty ?? false;
    if (supportsAnalytics && (!kIsWeb || hasWebMeasurementId)) {
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);
    }
  } catch (e) {
    debugPrint(
        '[Firebase Init] Connection warning/fallback: $e — running with local fallback');
  }
  runApp(const ToolVerseApp());
}

// ---------------------------------------------------------------------------
// THEME — New Midnight Indigo + Neon Cyan + Vivid Violet palette
// ---------------------------------------------------------------------------

class AppColors {
  // Deep midnight backgrounds
  static const midnight = Color(0xFF080B14);
  static const surface = Color(0xFF0D1120);
  static const card = Color(0xFF131929);
  static const cardElevated = Color(0xFF1A2236);

  // Text
  static const ink = Color(0xFFEDF2FF);
  static const inkSoft = Color(0xFFB8C4E0);
  static const muted = Color(0xFF5A6A8A);

  // Cyan accent — primary brand
  static const cyan = Color(0xFF00D4FF);
  static const cyanDim = Color(0xFF0099BB);
  static const cyanDark = Color(0xFF003D4D);

  // Violet accent — secondary brand
  static const violet = Color(0xFF8B5CF6);
  static const violetBright = Color(0xFFA78BFA);
  static const violetDark = Color(0xFF3B1F7A);

  // Neon green — success / ok
  static const neonGreen = Color(0xFF10F7A0);
  static const neonGreenDim = Color(0xFF065F46);

  // Amber — gold
  static const amber = Color(0xFFFFBB00);
  static const amberDim = Color(0xFF4D3700);

  // Red — danger
  static const red = Color(0xFFFF4B6E);
  static const redDim = Color(0xFF4D0E1C);

  // Dividers / borders
  static const line = Color(0x1A4A7CFF);
  static const glassLine = Color(0x2AFFFFFF);
}

// ---------------------------------------------------------------------------
// GRADIENT HELPERS
// ---------------------------------------------------------------------------
class AppGradients {
  static const brandGradient = LinearGradient(
    colors: [AppColors.cyan, AppColors.violet],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const cardGradient = LinearGradient(
    colors: [Color(0xFF131929), Color(0xFF0F1520)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const heroGradient = LinearGradient(
    colors: [Color(0xFF0A0F1E), Color(0xFF14073D), Color(0xFF080B14)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const cyanGlow = RadialGradient(
    colors: [Color(0x3000D4FF), Color(0x0000D4FF)],
    radius: 0.8,
  );
  static const violetGlow = RadialGradient(
    colors: [Color(0x308B5CF6), Color(0x008B5CF6)],
    radius: 0.8,
  );
}

// ---------------------------------------------------------------------------
// BRAND LOGO WIDGET
// ---------------------------------------------------------------------------

class ToolVerseLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final TextStyle? textStyle;
  final bool circular;
  final bool withGlow;

  const ToolVerseLogo({
    super.key,
    this.size = 36,
    this.showText = false,
    this.textStyle,
    this.circular = true,
    this.withGlow = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget logoWidget = ClipRRect(
      borderRadius: BorderRadius.circular(circular ? size / 2 : size * 0.25),
      child: Image.asset(
        'assets/images/logo.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              gradient: AppGradients.brandGradient,
              borderRadius:
                  BorderRadius.circular(circular ? size / 2 : size * 0.25),
            ),
            child: Icon(Icons.handyman_rounded,
                size: size * 0.52, color: Colors.white),
          );
        },
      ),
    );

    if (withGlow) {
      logoWidget = Container(
        decoration: BoxDecoration(
          shape: circular ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: circular ? null : BorderRadius.circular(size * 0.25),
          boxShadow: [
            BoxShadow(
              color: AppColors.cyan.withValues(alpha: 0.5),
              blurRadius: 24,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: AppColors.violet.withValues(alpha: 0.3),
              blurRadius: 40,
              spreadRadius: 4,
            ),
          ],
        ),
        child: logoWidget,
      );
    }

    if (!showText) return logoWidget;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        logoWidget,
        const SizedBox(width: 10),
        ShaderMask(
          shaderCallback: (bounds) =>
              AppGradients.brandGradient.createShader(bounds),
          child: Text(
            'ToolVerse',
            style: textStyle ??
                GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.4,
                ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// ANIMATED GLOW WIDGET
// ---------------------------------------------------------------------------
class AnimatedGlowContainer extends StatefulWidget {
  final Widget child;
  final Color glowColor;
  final double blurRadius;
  final Duration duration;

  const AnimatedGlowContainer({
    super.key,
    required this.child,
    this.glowColor = AppColors.cyan,
    this.blurRadius = 20,
    this.duration = const Duration(seconds: 2),
  });

  @override
  State<AnimatedGlowContainer> createState() => _AnimatedGlowContainerState();
}

class _AnimatedGlowContainerState extends State<AnimatedGlowContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration)
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 0.9).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, child) => Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: widget.glowColor.withValues(alpha: _anim.value * 0.6),
              blurRadius: widget.blurRadius,
              spreadRadius: _anim.value * 3,
            ),
          ],
        ),
        child: child,
      ),
      child: widget.child,
    );
  }
}

// ---------------------------------------------------------------------------
// GLASS CARD WIDGET
// ---------------------------------------------------------------------------
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final Color? glowColor;
  final bool elevated;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.glowColor,
    this.elevated = false,
  });

  @override
  Widget build(BuildContext context) {
    final br = borderRadius ?? BorderRadius.circular(20);
    return Container(
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: br,
        gradient: LinearGradient(
          colors: [
            AppColors.cardElevated.withValues(alpha: 0.8),
            AppColors.card.withValues(alpha: 0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: glowColor != null
              ? glowColor!.withValues(alpha: 0.3)
              : AppColors.glassLine,
          width: 1,
        ),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: (glowColor ?? AppColors.cyan).withValues(alpha: 0.12),
                  blurRadius: 30,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// MODELS — UI-layer classes
// ---------------------------------------------------------------------------

enum ItemCategory { tools, electronics, sports, camping, games }

extension CategoryX on ItemCategory {
  String get label => switch (this) {
        ItemCategory.tools => 'Tools',
        ItemCategory.electronics => 'Electronics',
        ItemCategory.sports => 'Sports',
        ItemCategory.camping => 'Camping',
        ItemCategory.games => 'Books & Games',
      };

  IconData get icon => switch (this) {
        ItemCategory.tools => Icons.build_rounded,
        ItemCategory.electronics => Icons.videocam_rounded,
        ItemCategory.sports => Icons.sports_cricket_rounded,
        ItemCategory.camping => Icons.landscape_rounded,
        ItemCategory.games => Icons.casino_rounded,
      };

  Color get color => switch (this) {
        ItemCategory.tools => AppColors.amber,
        ItemCategory.electronics => AppColors.cyan,
        ItemCategory.sports => AppColors.neonGreen,
        ItemCategory.camping => const Color(0xFF4ADE80),
        ItemCategory.games => AppColors.violet,
      };
}

class Item {
  final String id;
  String name;
  ItemCategory category;
  String owner;
  String ownerId;
  String desc;
  int deposit;
  String imageUrl; // optional photo URL

  Item({
    required this.id,
    required this.name,
    required this.category,
    required this.owner,
    this.ownerId = '',
    required this.desc,
    required this.deposit,
    this.imageUrl = '',
  });
}

enum BookingStatus { pending, active, done, cancelled }

class ChatMsg {
  final bool fromMe;
  final String text;
  final String type;
  final double? latitude;
  final double? longitude;
  final String? locationAddress;

  ChatMsg(
    this.fromMe,
    this.text, {
    this.type = 'text',
    this.latitude,
    this.longitude,
    this.locationAddress,
  });

  bool get isLocation =>
      type == 'location' || (latitude != null && longitude != null);
}

class Booking {
  final String id;
  final Item item;
  String borrowerId;
  String lenderId;
  String lenderEmail;
  String borrowerName;
  String borrowerEmail;
  DateTime? from;
  DateTime? to;
  final String note;
  BookingStatus status;
  bool beforePhoto = false;
  bool afterPhoto = false;
  Uint8List? beforeImageBytes;
  Uint8List? afterImageBytes;
  final List<ChatMsg> chat;

  Booking({
    required this.id,
    required this.item,
    this.borrowerId = '',
    this.lenderId = '',
    this.lenderEmail = '',
    this.borrowerName = '',
    this.borrowerEmail = '',
    required this.from,
    required this.to,
    required this.note,
    this.status = BookingStatus.pending,
    List<ChatMsg>? chat,
  }) : chat = chat ?? [];
}

class AppUser {
  String name;
  String society;
  String profilePic; // URL or empty
  int listed;
  String email;
  String phone;
  double? latitude;
  double? longitude;
  String formattedAddress;

  AppUser({
    required this.name,
    required this.society,
    this.profilePic = '',
    this.listed = 0,
    this.email = '',
    this.phone = '',
    this.latitude,
    this.longitude,
    this.formattedAddress = '',
  });
}

class AppNotification {
  final String id;
  final String title;
  final String body;
  final nm.NotificationType type;
  final DateTime timestamp;
  bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    DateTime? timestamp,
    this.isRead = false,
  }) : timestamp = timestamp ?? DateTime.now();
}

// ---------------------------------------------------------------------------
// APP STATE
// ---------------------------------------------------------------------------

class AppState extends ChangeNotifier {
  AppUser? user;
  String pendingPhone = '';
  String pendingEmail = '';

  final List<Item> items = [];
  final List<Booking> bookings = [];
  final List<AppNotification> notifications = [];
  AppNotification? activePushBanner;
  Timer? _pushBannerTimer;

  StreamSubscription<List<fm.ItemModel>>? _itemsSub;
  StreamSubscription<List<bm.BookingModel>>? _bookingsSub;
  StreamSubscription<UserModel?>? _userSub;
  StreamSubscription<List<nm.NotificationModel>>? _notificationsSub;
  final Set<String> _firestoreNotificationIds = {};

  int get unreadNotificationsCount =>
      notifications.where((n) => !n.isRead).length;

  void triggerPushNotification({
    required String title,
    required String body,
    nm.NotificationType type = nm.NotificationType.booking,
    String? notificationId,
    bool persistToFirestore = true,
  }) {
    final uid = authService.currentUserId;
    final id = notificationId ??
        (uid == null
            ? DateTime.now().microsecondsSinceEpoch.toString()
            : firestoreService.newNotificationId());
    final notif = AppNotification(
      id: id,
      title: title,
      body: body,
      type: type,
      timestamp: DateTime.now(),
      isRead: false,
    );
    final existingIndex =
        notifications.indexWhere((notification) => notification.id == id);
    if (existingIndex == -1) {
      notifications.insert(0, notif);
    } else {
      notifications[existingIndex] = notif;
    }
    activePushBanner = notif;
    HapticFeedback.lightImpact();
    notifyListeners();

    if (uid != null && persistToFirestore) {
      final notification = nm.NotificationModel(
        id: id,
        userId: uid,
        title: title,
        body: body,
        type: type,
        timestamp: notif.timestamp,
      );
      firestoreService.createNotification(notification).then<void>(
        (_) {},
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('[Notifications] Failed to save notification: $error');
        },
      );
    }

    _pushBannerTimer?.cancel();
    _pushBannerTimer = Timer(const Duration(seconds: 4), () {
      if (activePushBanner?.id == notif.id) {
        activePushBanner = null;
        notifyListeners();
      }
    });
  }

  void triggerReminderNotification({
    required String itemName,
    String? dueDate,
  }) {
    triggerPushNotification(
      title: 'Return Reminder: Due Soon ⏰',
      body:
          '$itemName is scheduled for return ${dueDate != null ? "on $dueDate" : "tomorrow by 6:00 PM"}. Please coordinate safe handover.',
      type: nm.NotificationType.reminder,
    );
  }

  void dismissPushBanner() {
    _pushBannerTimer?.cancel();
    activePushBanner = null;
    notifyListeners();
  }

  void markAllNotificationsRead() {
    for (final n in notifications) {
      n.isRead = true;
    }
    notifyListeners();
    final uid = authService.currentUserId;
    if (uid != null) {
      firestoreService.markAllNotificationsAsRead(uid);
    }
  }

  void markNotificationRead(String id) {
    final idx = notifications.indexWhere((n) => n.id == id);
    if (idx != -1 && !notifications[idx].isRead) {
      notifications[idx].isRead = true;
      notifyListeners();
      firestoreService.markNotificationAsRead(id);
    }
  }

  // -------------------------------------------------------------------------
  // Stream wiring
  // -------------------------------------------------------------------------

  void initStreams(String uid) {
    // Auto-request FCM permission and register token after login
    notificationService.requestPermissionAndRefreshToken().then((_) {
      notificationService.saveTokenToUser(uid);
    });
    _userSub?.cancel();
    _itemsSub?.cancel();
    _bookingsSub?.cancel();
    _notificationsSub?.cancel();

    _userSub = firestoreService.streamUser(uid).listen((u) {
      if (u != null) {
        user = AppUser(
          name: u.name,
          society: u.society,
          profilePic: u.profilePic,
          email: u.email,
          phone: u.phone,
          latitude: u.latitude,
          longitude: u.longitude,
          formattedAddress: u.formattedAddress,
        );
        notifyListeners();
      }
    });

    _itemsSub = firestoreService.streamItems().listen((list) {
      items
        ..clear()
        ..addAll(list.map(_toUiItem));
      notifyListeners();
    });

    _bookingsSub = firestoreService.streamUserBookings(uid).listen((list) {
      for (final bmEntry in list) {
        final idx = bookings.indexWhere((b) => b.id == bmEntry.id);
        if (idx == -1) {
          final item = items.firstWhere(
            (i) => i.id == bmEntry.itemId,
            orElse: () => _bookingModelToItem(bmEntry),
          );
          bookings.insert(
            0,
            Booking(
              id: bmEntry.id,
              item: item,
              borrowerId: bmEntry.borrowerId,
              lenderId: bmEntry.lenderId,
              lenderEmail: bmEntry.lenderEmail,
              borrowerName: bmEntry.borrowerName,
              borrowerEmail: bmEntry.borrowerEmail,
              from: bmEntry.from,
              to: bmEntry.to,
              note: bmEntry.note,
              status: _toUiStatus(bmEntry.status),
              chat: [],
            )
              ..beforePhoto = bmEntry.beforePhoto
              ..afterPhoto = bmEntry.afterPhoto,
          );
        } else {
          bookings[idx].status = _toUiStatus(bmEntry.status);
          bookings[idx].beforePhoto = bmEntry.beforePhoto;
          bookings[idx].afterPhoto = bmEntry.afterPhoto;
          if (bmEntry.lenderEmail.isNotEmpty) {
            bookings[idx].lenderEmail = bmEntry.lenderEmail;
          }
          if (bmEntry.borrowerName.isNotEmpty) {
            bookings[idx].borrowerName = bmEntry.borrowerName;
          }
          if (bmEntry.borrowerEmail.isNotEmpty) {
            bookings[idx].borrowerEmail = bmEntry.borrowerEmail;
          }
          if (bmEntry.lenderId.isNotEmpty) {
            bookings[idx].lenderId = bmEntry.lenderId;
          }
          if (bmEntry.borrowerId.isNotEmpty) {
            bookings[idx].borrowerId = bmEntry.borrowerId;
          }
        }
      }
      notifyListeners();
    });

    _notificationsSub =
        firestoreService.streamUserNotifications(uid).listen((list) {
      final currentIds = list.map((notification) => notification.id).toSet();
      notifications.removeWhere((notification) =>
          _firestoreNotificationIds.contains(notification.id) &&
          !currentIds.contains(notification.id));

      final isInitialLoad = _firestoreNotificationIds.isEmpty;

      for (final notification in list) {
        final index = notifications
            .indexWhere((existing) => existing.id == notification.id);
        final appNotification = AppNotification(
          id: notification.id,
          title: notification.title,
          body: notification.body,
          type: notification.type,
          timestamp: notification.timestamp,
          isRead: notification.isRead,
        );
        if (index == -1) {
          notifications.add(appNotification);
        } else {
          notifications[index] = appNotification;
        }

        // Pop up the notification banner if it's a new, unread notification arriving after initial load
        if (!isInitialLoad &&
            !_firestoreNotificationIds.contains(notification.id) &&
            !notification.isRead) {
          activePushBanner = appNotification;
          HapticFeedback.lightImpact();
          _pushBannerTimer?.cancel();
          _pushBannerTimer = Timer(const Duration(seconds: 4), () {
            if (activePushBanner?.id == appNotification.id) {
              activePushBanner = null;
              notifyListeners();
            }
          });
        }
      }

      _firestoreNotificationIds
        ..clear()
        ..addAll(currentIds);
      notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      notifyListeners();
    });
  }

  void _cancelStreams() {
    _userSub?.cancel();
    _itemsSub?.cancel();
    _bookingsSub?.cancel();
    _notificationsSub?.cancel();
    _userSub = null;
    _itemsSub = null;
    _bookingsSub = null;
    _notificationsSub = null;
    _firestoreNotificationIds.clear();
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  Item _toUiItem(fm.ItemModel m) => Item(
        id: m.id,
        name: m.name,
        category: _toUiCategory(m.category),
        owner: m.owner,
        ownerId: m.ownerId,
        desc: m.desc,
        deposit: m.deposit,
        imageUrl: m.imageUrl,
      );

  Item _bookingModelToItem(bm.BookingModel bmEntry) => Item(
        id: bmEntry.itemId,
        name: bmEntry.itemName,
        category: _toUiCategoryFromString(bmEntry.itemCategory),
        owner: bmEntry.itemOwner,
        ownerId: bmEntry.lenderId,
        desc: '',
        deposit: bmEntry.itemDeposit,
        imageUrl: bmEntry.itemImageUrl,
      );

  ItemCategory _toUiCategory(fm.ItemCategory cat) {
    return ItemCategory.values.firstWhere(
      (c) => c.name == cat.name,
      orElse: () => ItemCategory.tools,
    );
  }

  ItemCategory _toUiCategoryFromString(String s) {
    return ItemCategory.values.firstWhere(
      (c) => c.name == s,
      orElse: () => ItemCategory.tools,
    );
  }

  BookingStatus _toUiStatus(bm.BookingStatus s) =>
      BookingStatus.values.firstWhere(
        (v) => v.name == s.name,
        orElse: () => BookingStatus.pending,
      );

  fm.ItemModel _toFirestoreItem(Item item) => fm.ItemModel(
        id: item.id,
        name: item.name,
        category: fm.ItemCategory.values.firstWhere(
          (c) => c.name == item.category.name,
          orElse: () => fm.ItemCategory.tools,
        ),
        owner: item.owner,
        ownerId: item.ownerId.isEmpty
            ? (authService.currentUserId ?? '')
            : item.ownerId,
        desc: item.desc,
        deposit: item.deposit,
        imageUrl: item.imageUrl,
      );

  // -------------------------------------------------------------------------
  // Seed items
  // -------------------------------------------------------------------------


  // -------------------------------------------------------------------------
  // Auth actions
  // -------------------------------------------------------------------------


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
    var uid = authService.currentUserId;
    if (uid == null || uid.isEmpty) {
      uid = await authService.signInAnonymously();
    }
    final resolvedPhone = (phone != null && phone.trim().isNotEmpty)
        ? phone.trim()
        : (authService.currentUser?.phoneNumber ?? pendingPhone);
    final resolvedEmail = (email != null && email.trim().isNotEmpty)
        ? email.trim()
        : (authService.currentUser?.email ?? pendingEmail);
    final resolvedAddress = (formattedAddress != null && formattedAddress.trim().isNotEmpty)
        ? formattedAddress.trim()
        : society;
    final resolvedProfilePic = (profilePic != null && profilePic.trim().isNotEmpty)
        ? profilePic.trim()
        : (user?.profilePic.isNotEmpty == true
            ? user!.profilePic
            : (authService.currentUser?.photoURL ?? ''));

    if (uid != null && uid.isNotEmpty) {
      final u = UserModel(
        uid: uid,
        name: name,
        society: society,
        phone: resolvedPhone,
        email: resolvedEmail,
        profilePic: resolvedProfilePic,
        latitude: latitude,
        longitude: longitude,
        formattedAddress: resolvedAddress,
      );
      await firestoreService.createUser(u);
      user = AppUser(
        name: name,
        society: society,
        profilePic: resolvedProfilePic,
        email: resolvedEmail,
        phone: resolvedPhone,
        latitude: latitude,
        longitude: longitude,
        formattedAddress: resolvedAddress,
      );
      notifyListeners();
      initStreams(uid);
    } else {
      user = AppUser(
        name: name,
        society: society,
        profilePic: resolvedProfilePic,
        email: resolvedEmail,
        phone: resolvedPhone,
        latitude: latitude,
        longitude: longitude,
        formattedAddress: resolvedAddress,
      );
      notifyListeners();
    }
  }

  Future<void> updateProfile({
    required String name,
    required String society,
    String? profilePic,
    String? email,
    String? phone,
    double? latitude,
    double? longitude,
    String? formattedAddress,
  }) async {
    var uid = authService.currentUserId;
    if (user != null) {
      user!.name = name;
      user!.society = society;
      if (profilePic != null) user!.profilePic = profilePic;
      if (email != null && email.trim().isNotEmpty) user!.email = email.trim();
      if (phone != null && phone.trim().isNotEmpty) user!.phone = phone.trim();
      if (latitude != null) user!.latitude = latitude;
      if (longitude != null) user!.longitude = longitude;
      if (formattedAddress != null && formattedAddress.trim().isNotEmpty) {
        user!.formattedAddress = formattedAddress.trim();
      }
      notifyListeners();
    }
    if (uid == null || uid.isEmpty) {
      uid = await authService.signInAnonymously();
    }
    if (uid != null && uid.isNotEmpty) {
      await firestoreService.updateUserProfile(
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
    var uid = authService.currentUserId;
    if (uid == null || uid.isEmpty) {
      uid = await authService.signInAnonymously();
    }
    if (uid == null || uid.isEmpty) {
      throw Exception('Unable to authenticate session for image upload. Please sign in and try again.');
    }

    final downloadUrl = await storageService.uploadProfilePicture(
      bytes: bytes,
      fileName: fileName,
      userId: uid,
    );

    if (user != null) {
      user!.profilePic = downloadUrl;
      notifyListeners();
    }

    await firestoreService.updateUserProfile(
      uid,
      profilePic: downloadUrl,
    );

    return downloadUrl;
  }

  Future<void> logout() async {
    _cancelStreams();
    notificationService.clearRegisteredUser();
    user = null;
    items.clear();
    bookings.clear();
    notifications.clear();
    _firestoreNotificationIds.clear();
    activePushBanner = null;
    _pushBannerTimer?.cancel();
    pendingPhone = '';
    pendingEmail = '';
    notifyListeners();
    await authService.signOut();
  }

  // -------------------------------------------------------------------------
  // Items
  // -------------------------------------------------------------------------

  Future<void> publishItem(Item item) async {
    final uid = authService.currentUserId;
    if (uid != null) {
      final itemId = await firestoreService.createItem(_toFirestoreItem(item));
      triggerPushNotification(
        title: 'Your item is listed',
        body: '${item.name} is now available for neighbors to borrow.',
        type: nm.NotificationType.status,
        notificationId: 'item_listed_$itemId',
        persistToFirestore: false,
      );
    } else {
      items.insert(0, item);
      user?.listed = items.where((i) => i.owner == user!.name).length;
      notifyListeners();
    }
  }

  Future<void> uploadAndPublishItem({
    required Item item,
    Uint8List? imageBytes,
    String? imageFileName,
  }) async {
    final uid = authService.currentUserId ??
        (item.ownerId.isNotEmpty ? item.ownerId : 'user');
    String finalImageUrl = item.imageUrl;

    if (imageBytes != null &&
        imageBytes.isNotEmpty &&
        imageFileName != null &&
        imageFileName.isNotEmpty) {
      finalImageUrl = await storageService.uploadItemImage(
        bytes: imageBytes,
        fileName: imageFileName,
        userId: uid,
      );
    }

    final itemWithImage = Item(
      id: item.id,
      name: item.name,
      category: item.category,
      owner: item.owner,
      ownerId: uid,
      desc: item.desc,
      deposit: item.deposit,
      imageUrl: finalImageUrl,
    );

    await publishItem(itemWithImage);
  }

  // -------------------------------------------------------------------------
  // Bookings
  // -------------------------------------------------------------------------

  Future<Booking> requestBorrow(
      Item item, DateTime? from, DateTime? to, String note) async {
    final uid = authService.currentUserId;
    if (uid == null || uid.isEmpty) {
      throw Exception('You must be logged in to request a borrow.');
    }

    // Backend resolves itemName, lenderId, deposit from the item record server-side.
    // Only send itemId, from, to, note.
    final created = await apiService.createBooking(
      itemId: item.id,
      from: from,
      to: to,
      note: note,
    );

    final booking = Booking(
      id: created.id,
      item: item,
      borrowerId: uid,
      lenderId: created.lenderId.isNotEmpty ? created.lenderId : item.ownerId,
      lenderEmail: created.lenderEmail,
      borrowerName:
          user?.name.isNotEmpty == true ? user!.name : (user?.email ?? ''),
      borrowerEmail: user?.email ?? '',
      from: from,
      to: to,
      note: note,
      chat: [],
    );
    bookings.insert(0, booking);
    triggerPushNotification(
      title: 'Borrow request sent',
      body: 'Your request for ${item.name} was sent to the owner.',
      type: nm.NotificationType.booking,
      notificationId: 'booking_created_${created.id}',
      persistToFirestore: false,
    );
    notifyListeners();
    return booking;
  }

  // -------------------------------------------------------------------------
  // Chat
  // -------------------------------------------------------------------------

  void sendChat(Booking booking, String text) {
    booking.chat.add(ChatMsg(true, text));
    notifyListeners();
    final uid = authService.currentUserId;
    if (uid != null) {
      firestoreService.sendChatMessage(
        booking.id,
        ChatMsgModel(
          id: '',
          text: text,
          senderId: uid,
          fromMe: true,
          timestamp: DateTime.now(),
        ),
      );
    }
  }

  /// Sends a pickup location message to the booking chat.
  Future<void> sendLocationMessage({
    required String bookingId,
    required double latitude,
    required double longitude,
    required String address,
  }) async {
    Booking? targetBooking;
    for (final b in bookings) {
      if (b.id == bookingId) {
        targetBooking = b;
        break;
      }
    }

    final localMsg = ChatMsg(
      true,
      '📍 Pickup Location: $address',
      type: 'location',
      latitude: latitude,
      longitude: longitude,
      locationAddress: address,
    );
    if (targetBooking != null) {
      targetBooking.chat.add(localMsg);
    }
    notifyListeners();

    final uid = authService.currentUserId ?? '';
    await firestoreService.sendChatMessage(
      bookingId,
      ChatMsgModel(
        id: '',
        text: '📍 Pickup Location: $address',
        senderId: uid,
        fromMe: true,
        timestamp: DateTime.now(),
        type: 'location',
        latitude: latitude,
        longitude: longitude,
        locationAddress: address,
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Booking lifecycle
  // -------------------------------------------------------------------------

  void markPickedUp(Booking booking) {
    booking.status = BookingStatus.active;
    notifyListeners();
    final uid = authService.currentUserId;
    if (uid != null) {
      firestoreService.updateBookingStatus(booking.id, 'active');
    }
  }

  /// Lender accepts a pending booking request → moves to active.
  void acceptBooking(Booking booking) {
    booking.status = BookingStatus.active;
    notifyListeners();
    final uid = authService.currentUserId;
    if (uid != null) {
      firestoreService.updateBookingStatus(booking.id, 'active');
    }
    triggerPushNotification(
      title: 'Booking Accepted ✅',
      body: 'You accepted the request for ${booking.item.name}.',
      type: nm.NotificationType.booking,
      notificationId: 'booking_accepted_${booking.id}',
      persistToFirestore: false,
    );
  }

  void markPhoto(Booking booking, {required bool before}) {
    if (before) {
      booking.beforePhoto = true;
    } else {
      booking.afterPhoto = true;
    }
    notifyListeners();
    final uid = authService.currentUserId;
    if (uid != null) {
      firestoreService.updateBookingPhotos(booking.id,
          before: before ? true : null, after: before ? null : true);
    }
  }

  Future<void> runAiCheck(Booking booking) async {
    await Future.delayed(const Duration(milliseconds: 1600));
    try {
      if (booking.id.isNotEmpty) {
        await apiService.runAiCheck(booking.id);
      }
    } catch (_) {
      final uid = authService.currentUserId;
      if (uid != null) {
        await firestoreService.updateBookingStatus(booking.id, 'done');
      }
    }
    booking.status = BookingStatus.done;
    triggerPushNotification(
      title: 'Return Verified ✅',
      body:
          'Item returned in verified condition. ₹${booking.item.deposit} deposit refunded!',
      type: nm.NotificationType.ai,
    );
    notifyListeners();
  }

  Future<void> deleteItem(String itemId) async {
    try {
      await apiService.deleteItem(itemId);
      items.removeWhere((i) => i.id == itemId);
      bookings.removeWhere((b) => b.item.id == itemId);
      if (user != null) {
        user!.listed = items
            .where((i) =>
                i.owner == user!.name ||
                i.ownerId == (authService.currentUserId ?? ''))
            .length;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[AppState] deleteItem error: $e');
      rethrow;
    }
  }

  Future<void> cancelBooking(String bookingId) async {
    try {
      await apiService.cancelBooking(bookingId);
      final b = bookings.firstWhere((b) => b.id == bookingId,
          orElse: () => throw Exception('Booking not found'));
      b.status = BookingStatus.cancelled;
      notifyListeners();
    } catch (e) {
      debugPrint('[AppState] cancelBooking error: $e');
      rethrow;
    }
  }

  Future<void> deleteBooking(String bookingId) async {
    try {
      await apiService.deleteBooking(bookingId);
      bookings.removeWhere((b) => b.id == bookingId);
      notifyListeners();
    } catch (e) {
      debugPrint('[AppState] deleteBooking error: $e');
      rethrow;
    }
  }

  Future<void> deleteAccount() async {
    try {
      await apiService.deleteAccount();
    } catch (e) {
      debugPrint('[AppState] deleteAccount API error: $e');
    }
    await logout();
  }

  @override
  void dispose() {
    _cancelStreams();
    super.dispose();
  }
}

class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope(
      {super.key, required AppState super.notifier, required super.child});

  static AppState of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AppStateScope>()!
        .notifier!;
  }
}

// ---------------------------------------------------------------------------
// APP ROOT
// ---------------------------------------------------------------------------

class ToolVerseApp extends StatefulWidget {
  const ToolVerseApp({super.key});
  @override
  State<ToolVerseApp> createState() => _ToolVerseAppState();
}

class _ToolVerseAppState extends State<ToolVerseApp> {
  final AppState state = AppState();

  @override
  void initState() {
    super.initState();
    notificationService.initialize(
      onForegroundNotification: (title, body, data) {
        final rawType = data['type']?.toString() ?? 'booking';
        final type = nm.NotificationType.values.firstWhere(
          (t) => t.name == rawType,
          orElse: () => nm.NotificationType.booking,
        );
        state.triggerPushNotification(
          title: title,
          body: body,
          type: type,
          notificationId: data['notificationId']?.toString(),
          persistToFirestore: data['notificationId'] == null,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppStateScope(
      notifier: state,
      child: MaterialApp(
        navigatorKey: navigatorKey,
        scaffoldMessengerKey: rootScaffoldMessengerKey,
        title: 'ToolVerse',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: AppColors.midnight,
          colorScheme: const ColorScheme.dark(
            primary: AppColors.cyan,
            secondary: AppColors.violet,
            surface: AppColors.card,
            onSurface: AppColors.ink,
            inverseSurface: AppColors.cardElevated,
            onInverseSurface: Colors.white,
          ),
          snackBarTheme: SnackBarThemeData(
            backgroundColor: AppColors.cardElevated,
            contentTextStyle: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
            actionTextColor: AppColors.cyan,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppColors.glassLine, width: 1.2),
            ),
            elevation: 10,
          ),
          textTheme: GoogleFonts.plusJakartaSansTextTheme(
            ThemeData.dark().textTheme,
          ).copyWith(
            bodyLarge: GoogleFonts.plusJakartaSans(color: AppColors.ink),
            bodyMedium: GoogleFonts.plusJakartaSans(color: AppColors.ink),
            bodySmall: GoogleFonts.plusJakartaSans(color: AppColors.muted),
          ),
          appBarTheme: AppBarTheme(
            backgroundColor: AppColors.midnight,
            foregroundColor: AppColors.ink,
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: false,
            titleTextStyle: GoogleFonts.plusJakartaSans(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          navigationBarTheme: const NavigationBarThemeData(
            backgroundColor: AppColors.surface,
            indicatorColor: Colors.transparent,
            elevation: 0,
          ),
          checkboxTheme: CheckboxThemeData(
            fillColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) return AppColors.cyan;
              return AppColors.card;
            }),
            checkColor: WidgetStateProperty.all(AppColors.midnight),
          ),
          datePickerTheme: DatePickerThemeData(
            backgroundColor: AppColors.surface,
            headerBackgroundColor: AppColors.card,
            headerForegroundColor: AppColors.ink,
            dayStyle: GoogleFonts.plusJakartaSans(color: AppColors.ink),
            dayForegroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) return AppColors.midnight;
              return AppColors.ink;
            }),
            dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) return AppColors.cyan;
              return Colors.transparent;
            }),
            todayForegroundColor: WidgetStateProperty.all(AppColors.cyan),
            todayBorder: const BorderSide(color: AppColors.cyan, width: 1),
          ),
        ),
        home: const SplashScreen(),
        builder: (context, child) {
          return PushNotificationOverlay(child: child!);
        },
      ),
    );
  }
}

class PushNotificationOverlay extends StatelessWidget {
  final Widget child;
  const PushNotificationOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final banner = state.activePushBanner;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          child,
          if (banner != null)
            Positioned(
              top: 18,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 384),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: HeadsUpNotificationBanner(
                        notification: banner,
                        onTap: () {
                          state.dismissPushBanner();
                          final navContext = navigatorKey.currentContext;
                          if (navContext != null) {
                            openNotificationCenter(navContext);
                          }
                        },
                        onDismiss: () => state.dismissPushBanner(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// HEADS-UP NOTIFICATION BANNER
// ---------------------------------------------------------------------------
class HeadsUpNotificationBanner extends StatefulWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const HeadsUpNotificationBanner({
    super.key,
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  State<HeadsUpNotificationBanner> createState() =>
      _HeadsUpNotificationBannerState();
}

class _HeadsUpNotificationBannerState extends State<HeadsUpNotificationBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offsetAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _offsetAnim = Tween<Offset>(
      begin: const Offset(0, -1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));
    _fadeAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleDismiss() async {
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final notif = widget.notification;
    final color = switch (notif.type) {
      nm.NotificationType.booking => AppColors.amber,
      nm.NotificationType.chat => AppColors.cyan,
      nm.NotificationType.status => AppColors.neonGreen,
      nm.NotificationType.ai => AppColors.violet,
      nm.NotificationType.reminder => const Color(0xFFFF8C42),
    };

    return SlideTransition(
      position: _offsetAnim,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: GestureDetector(
          onTap: widget.onTap,
          onVerticalDragEnd: (details) {
            if (details.primaryVelocity != null &&
                details.primaryVelocity! < -80) {
              _handleDismiss();
            }
          },
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.cardElevated.withValues(alpha: 0.97),
                    AppColors.surface.withValues(alpha: 0.97),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: color.withValues(alpha: 0.5),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.7),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                  BoxShadow(
                    color: color.withValues(alpha: 0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: color.withValues(alpha: 0.3), width: 0.8),
                        ),
                        child: Icon(
                          Icons.notifications_active_rounded,
                          size: 13,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ShaderMask(
                        shaderCallback: (bounds) =>
                            AppGradients.brandGradient.createShader(bounds),
                        child: const Text(
                          'TOOLVERSE',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const Text(
                        ' • ',
                        style: TextStyle(color: AppColors.muted, fontSize: 10),
                      ),
                      const Text(
                        'Just now',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: AppColors.muted,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _handleDismiss,
                        child: const Padding(
                          padding: EdgeInsets.all(2.0),
                          child: Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    notif.title,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notif.body,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.inkSoft,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// NOTIFICATION BELL
// ---------------------------------------------------------------------------
class NotificationBellButton extends StatefulWidget {
  const NotificationBellButton({super.key});

  @override
  State<NotificationBellButton> createState() => _NotificationBellButtonState();
}

class _NotificationBellButtonState extends State<NotificationBellButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _rotateAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _rotateAnim = Tween<double>(begin: -0.05, end: 0.05).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.elasticInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _shake() {
    _ctrl.repeat(reverse: true);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _ctrl.stop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final unread = state.unreadNotificationsCount;

    return GestureDetector(
      onTap: () {
        _shake();
        openNotificationCenter(context);
      },
      child: AnimatedBuilder(
        animation: _rotateAnim,
        builder: (_, child) => Transform.rotate(
          angle: _rotateAnim.value,
          child: child,
        ),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [AppColors.cardElevated, AppColors.card],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: unread > 0
                  ? AppColors.cyan.withValues(alpha: 0.5)
                  : AppColors.glassLine,
            ),
            boxShadow: unread > 0
                ? [
                    BoxShadow(
                      color: AppColors.cyan.withValues(alpha: 0.2),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Icon(
                unread > 0
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_outlined,
                size: 20,
                color:
                    unread > 0 ? AppColors.cyan : AppColors.inkSoft,
              ),
              if (unread > 0)
                Positioned(
                  top: -3,
                  right: -3,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.red, Color(0xFFFF7A95)],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.red.withValues(alpha: 0.5),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 15,
                      minHeight: 15,
                    ),
                    child: Text(
                      '$unread',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

void openNotificationCenter(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: const NotificationCenterSheet(),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// NOTIFICATION CENTER SHEET
// ---------------------------------------------------------------------------
class NotificationCenterSheet extends StatelessWidget {
  const NotificationCenterSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final notifs = state.notifications;
    final unreadCount = state.unreadNotificationsCount;

    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.cardElevated, AppColors.surface],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: AppColors.glassLine),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [AppColors.cyan, AppColors.violet]),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 16, 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.cyan.withValues(alpha: 0.2),
                        AppColors.violet.withValues(alpha: 0.2),
                      ],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: AppColors.cyan.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(
                    Icons.notifications_active_rounded,
                    color: AppColors.cyan,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Notifications',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                if (unreadCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [AppColors.red, Color(0xFFFF7A95)]),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.red.withValues(alpha: 0.3),
                          blurRadius: 8,
                        )
                      ],
                    ),
                    child: Text(
                      '$unreadCount new',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                if (notifs.isNotEmpty)
                  TextButton(
                    onPressed: () => state.markAllNotificationsRead(),
                    child: const Text(
                      'Mark all read',
                      style: TextStyle(
                        color: AppColors.cyan,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.glassLine),
          // FCM info card
          AnimatedBuilder(
            animation: notificationService,
            builder: (context, _) {
              final fcmToken = notificationService.fcmToken;
              final statusColor = notificationService.isPushReady
                  ? AppColors.neonGreen
                  : AppColors.amber;
              final statusLabel = notificationService.isPushReady
                  ? 'Ready'
                  : notificationService.permissionStatus;

              return Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.midnight,
                      AppColors.surface,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.glassLine),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: AppColors.amber.withValues(alpha: 0.3)),
                          ),
                          child: const Icon(
                            Icons.cloud_sync_rounded,
                            color: AppColors.amber,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'Firebase notification report',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: statusColor.withValues(alpha: 0.3)),
                                    ),
                                    child: Text(
                                      statusLabel,
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        color: statusColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Project: ${notificationService.firebaseProjectId}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Permission: ${notificationService.permissionStatus}  •  '
                            'Device token: ${fcmToken == null ? "unavailable" : "ready"}',
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Copy FCM device token',
                          visualDensity: VisualDensity.compact,
                          onPressed: fcmToken == null
                              ? null
                              : () async {
                                  await Clipboard.setData(
                                    ClipboardData(text: fcmToken),
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'FCM device token copied for Firebase Console testing.'),
                                      ),
                                    );
                                  }
                                },
                          icon:
                              const Icon(Icons.copy_rounded, size: 16, color: AppColors.muted),
                        ),
                      ],
                    ),
                    if (notificationService.initializationError != null ||
                        notificationService.tokenError != null)
                      Text(
                        notificationService.initializationError ??
                            notificationService.tokenError!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.red,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      kIsWeb
                          ? 'Edge/Web sends do not appear in Firebase Messaging Reports. Check Firestore > notifications for pushStatus; Firebase Console reporting supports Android and iOS sends.'
                          : 'Real item-listing and booking pushes are sent by the deployed Firebase Function. Demo buttons only show in-app alerts.',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _neonOutlineBtn(
                          label: 'Enable / refresh push',
                          icon: Icons.notifications_active_rounded,
                          color: AppColors.amber,
                          onTap: () async {
                            await notificationService
                                .requestPermissionAndRefreshToken();
                          },
                        ),
                        _neonFilledBtn(
                          label: 'Demo: Confirmed',
                          color: AppColors.cyan,
                          onTap: () {
                            Navigator.of(context).pop();
                            notificationService.triggerTestPushNotification(
                              title: 'Booking Confirmed! 📦',
                              body:
                                  'Ananya confirmed your borrow request for Bosch Cordless Drill. Ready for pickup!',
                              data: {'type': 'booking'},
                            );
                          },
                        ),
                        _neonFilledBtn(
                          label: 'Demo: Reminder',
                          color: const Color(0xFFFF8C42),
                          onTap: () {
                            Navigator.of(context).pop();
                            notificationService.triggerTestReminderNotification(
                              title: 'Return Reminder: Due Tomorrow ⏰',
                              body:
                                  'Bosch Cordless Drill is scheduled for return tomorrow by 6:00 PM. Please inspect item condition.',
                              data: {'type': 'reminder'},
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          // Notification list
          Expanded(
            child: notifs.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.cyan.withValues(alpha: 0.1),
                                  AppColors.violet.withValues(alpha: 0.1),
                                ],
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.notifications_none_rounded,
                              size: 40,
                              color: AppColors.muted,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No notifications yet',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Borrow an item or send a message to trigger real-time booking alerts.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.muted,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: notifs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      final n = notifs[idx];
                      final color = switch (n.type) {
                        nm.NotificationType.booking => AppColors.amber,
                        nm.NotificationType.chat => AppColors.cyan,
                        nm.NotificationType.status => AppColors.neonGreen,
                        nm.NotificationType.ai => AppColors.violet,
                        nm.NotificationType.reminder => const Color(0xFFFF8C42),
                      };
                      final icon = switch (n.type) {
                        nm.NotificationType.booking =>
                          Icons.inventory_2_rounded,
                        nm.NotificationType.chat => Icons.chat_bubble_rounded,
                        nm.NotificationType.status => Icons.sync_alt_rounded,
                        nm.NotificationType.ai => Icons.verified_rounded,
                        nm.NotificationType.reminder => Icons.alarm_rounded,
                      };

                      return GestureDetector(
                        onTap: () {
                          if (!n.isRead) {
                            HapticFeedback.lightImpact();
                            state.markNotificationRead(n.id);
                          }
                        },
                        child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: n.isRead
                                ? [AppColors.surface, AppColors.midnight]
                                : [
                                    AppColors.cardElevated,
                                    AppColors.card,
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: n.isRead
                                ? AppColors.glassLine
                                : color.withValues(alpha: 0.4),
                          ),
                          boxShadow: n.isRead
                              ? null
                              : [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.1),
                                    blurRadius: 12,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: color.withValues(alpha: 0.3)),
                              ),
                              child: Icon(icon, color: color, size: 16),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          n.title,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: n.isRead
                                                ? FontWeight.w500
                                                : FontWeight.w700,
                                            color: AppColors.ink,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        _fmtTime(n.timestamp),
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: AppColors.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    n.body,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.inkSoft,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!n.isRead) ...[
                              const SizedBox(width: 6),
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: color.withValues(alpha: 0.6),
                                      blurRadius: 6,
                                    )
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  static String _fmtTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}';
  }
}

Widget _neonOutlineBtn({
  required String label,
  required IconData icon,
  required Color color,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.6)),
        color: color.withValues(alpha: 0.08),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _neonFilledBtn({
  required String label,
  required Color color,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.7)],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// RESPONSIVE WRAPPER
// ---------------------------------------------------------------------------

class PhoneShell extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  const PhoneShell({super.key, required this.child, this.maxWidth = 480});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SPLASH SCREEN — Stunning animated brand intro
// ---------------------------------------------------------------------------

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _mainCtrl;
  late final AnimationController _particleCtrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _slideAnim;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _mainCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _scaleAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
          parent: _mainCtrl,
          curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack)),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _mainCtrl,
          curve: const Interval(0.0, 0.5, curve: Curves.easeIn)),
    );
    _slideAnim = Tween<double>(begin: 30, end: 0).animate(
      CurvedAnimation(
          parent: _mainCtrl,
          curve: const Interval(0.3, 0.9, curve: Curves.easeOutCubic)),
    );
    _mainCtrl.forward();

    _timer = Timer(const Duration(milliseconds: 2400), () async {
      if (!mounted) return;
      try {
        final profile = await apiService.getMyProfile();
        if (mounted && profile != null) {
          final state = AppStateScope.of(context);
          final appUser = AppUser(
            name: profile.name,
            society: profile.society,
            profilePic: profile.profilePic,
            email: profile.email,
            phone: profile.phone,
            latitude: profile.latitude,
            longitude: profile.longitude,
            formattedAddress: profile.formattedAddress,
          );
          state.user = appUser;
          state.initStreams(profile.uid);

          // If profile is incomplete, show setup screen first
          final nextScreen = _isProfileComplete(appUser)
              ? const HomeShell()
              : const AddressScreen();

          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => nextScreen,
              transitionsBuilder: (_, anim, __, child) =>
                  FadeTransition(opacity: anim, child: child),
              transitionDuration: const Duration(milliseconds: 500),
            ),
          );
          return;
        }
      } catch (_) {}

      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const EmailEntryScreen(),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _mainCtrl.dispose();
    _particleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppGradients.heroGradient),
        child: Stack(
          children: [
            // Animated background orbs
            AnimatedBuilder(
              animation: _particleCtrl,
              builder: (_, __) {
                final t = _particleCtrl.value;
                return Stack(
                  children: [
                    Positioned(
                      left: -60 + 40 * math.sin(t * 2 * math.pi),
                      top: 80 + 30 * math.cos(t * 2 * math.pi),
                      child: Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppColors.cyan.withValues(alpha: 0.18),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: -80 + 40 * math.cos(t * 2 * math.pi + 1),
                      bottom:
                          120 + 50 * math.sin(t * 2 * math.pi + 0.5),
                      child: Container(
                        width: 280,
                        height: 280,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppColors.violet.withValues(alpha: 0.2),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: MediaQuery.of(context).size.width * 0.3,
                      top: MediaQuery.of(context).size.height * 0.6,
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppColors.neonGreen.withValues(alpha: 0.1),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            // Main content
            SafeArea(
              child: Center(
                child: AnimatedBuilder(
                  animation: _mainCtrl,
                  builder: (_, __) {
                    return Opacity(
                      opacity: _fadeAnim.value,
                      child: Transform.scale(
                        scale: _scaleAnim.value,
                        child: Transform.translate(
                          offset: Offset(0, _slideAnim.value),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Logo with layered glow
                              AnimatedGlowContainer(
                                glowColor: AppColors.cyan,
                                blurRadius: 40,
                                duration: const Duration(milliseconds: 1800),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      colors: [AppColors.cyan, AppColors.violet],
                                    ),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.midnight,
                                    ),
                                    child: const ToolVerseLogo(
                                      size: 108,
                                      circular: true,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 32),
                              ShaderMask(
                                shaderCallback: (bounds) =>
                                    AppGradients.brandGradient
                                        .createShader(bounds),
                                child: Text(
                                  'ToolVerse',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 46,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -1.2,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                      color: AppColors.glassLine, width: 1),
                                  color: Colors.white.withValues(alpha: 0.05),
                                ),
                                child: Text(
                                  'Borrow & lend with your neighbors',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.inkSoft,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 56),
                              // Animated dots loader
                              _AnimatedDotsLoader(),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedDotsLoader extends StatefulWidget {
  @override
  State<_AnimatedDotsLoader> createState() => _AnimatedDotsLoaderState();
}

class _AnimatedDotsLoaderState extends State<_AnimatedDotsLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i / 3;
            final t = (_ctrl.value + delay) % 1.0;
            final bounce = math.sin(t * math.pi);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 8,
              height: 8 + bounce * 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                gradient: LinearGradient(
                  colors: [AppColors.cyan, AppColors.violet],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.cyan.withValues(alpha: bounce * 0.6),
                    blurRadius: 8,
                  )
                ],
              ),
            );
          }),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// AUTH FLOW — Dynamic Country Code Dropdown & Verification
// ---------------------------------------------------------------------------

class CountryCodePickerSheet extends StatefulWidget {
  final CountryCode selected;
  const CountryCodePickerSheet({super.key, required this.selected});

  @override
  State<CountryCodePickerSheet> createState() => _CountryCodePickerSheetState();
}

class _CountryCodePickerSheetState extends State<CountryCodePickerSheet> {
  final _searchCtrl = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _filter.trim().toLowerCase();
    final filtered = kCountryCodes.where((c) {
      if (query.isEmpty) return true;
      return c.name.toLowerCase().contains(query) ||
          c.dialCode.toLowerCase().contains(query) ||
          c.code.toLowerCase().contains(query);
    }).toList();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 600),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: AppColors.glassLine),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 30,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              // Drag handle
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.glassLine,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.cyan.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: AppColors.cyan.withValues(alpha: 0.3)),
                          ),
                          child: const Icon(Icons.public_rounded,
                              size: 18, color: AppColors.cyan),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Select Country Code',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: AppColors.muted, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Search field
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _filter = v),
                  style: const TextStyle(color: AppColors.ink, fontSize: 14),
                  decoration: neonFieldDecoration(
                    hint: 'Search country name or code (e.g. +1, India)...',
                    prefixIcon: const Icon(Icons.search_rounded,
                        size: 18, color: AppColors.muted),
                    suffixIcon: _filter.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded,
                                size: 16, color: AppColors.muted),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _filter = '');
                            },
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Countries list
              Flexible(
                child: filtered.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(40),
                        child: Text(
                          'No countries match your search',
                          style: TextStyle(color: AppColors.muted, fontSize: 13),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) =>
                            const Divider(color: AppColors.line, height: 1),
                        itemBuilder: (context, i) {
                          final c = filtered[i];
                          final isSelected = c == widget.selected;
                          return Material(
                            color: Colors.transparent,
                            child: ListTile(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                Navigator.of(context).pop(c);
                              },
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            tileColor: isSelected
                                ? AppColors.cyan.withValues(alpha: 0.1)
                                : Colors.transparent,
                            leading: Container(
                              width: 38,
                              height: 38,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.card,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: isSelected
                                        ? AppColors.cyan.withValues(alpha: 0.4)
                                        : AppColors.glassLine),
                              ),
                              child: Text(c.flag,
                                  style: const TextStyle(fontSize: 20)),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    c.name,
                                    style: TextStyle(
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      fontSize: 14.5,
                                      color: isSelected
                                          ? AppColors.cyan
                                          : AppColors.ink,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.cardElevated,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    c.code,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  c.dialCode,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: isSelected
                                        ? AppColors.cyan
                                        : AppColors.inkSoft,
                                  ),
                                ),
                                if (isSelected) ...[
                                  const SizedBox(width: 8),
                                  const Icon(Icons.check_circle_rounded,
                                      size: 18, color: AppColors.cyan),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EmailEntryScreen extends StatefulWidget {
  const EmailEntryScreen({super.key});
  @override
  State<EmailEntryScreen> createState() => _EmailEntryScreenState();
}

class _EmailEntryScreenState extends State<EmailEntryScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = false;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleGuestLogin() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final uid = await authService.signInAnonymously();
      if (!mounted) return;
      if (uid != null) {
        final existing = await firestoreService.getUser(uid);
        if (!mounted) return;
        if (existing != null) {
          final appUser = AppUser(
            name: existing.name,
            society: existing.society,
            profilePic: existing.profilePic,
            email: existing.email,
            phone: existing.phone,
            latitude: existing.latitude,
            longitude: existing.longitude,
            formattedAddress: existing.formattedAddress,
          );
          AppStateScope.of(context).user = appUser;
          AppStateScope.of(context).initStreams(uid);
          final nextScreen = _isProfileComplete(appUser)
              ? const HomeShell()
              : const AddressScreen();
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => nextScreen),
            (route) => false,
          );
          return;
        }
      }
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AddressScreen()),
      );
    } catch (e) {
      if (mounted) {
        ValidationFeedback.showWarning(context, 'Guest login failed: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleGoogleLogin() async {
    if (_loading) return;
    setState(() => _loading = true);

    try {
      String? googleError;
      final success = await authService.signInWithGoogle(
        onError: (err) => googleError = err,
      );

      if (!mounted) return;
      if (success) {
        final uid = authService.currentUserId!;
        final existing = await firestoreService.getUser(uid);
        if (!mounted) return;
        final photo = (existing?.profilePic.isNotEmpty == true)
            ? existing!.profilePic
            : (authService.currentUser?.photoURL ?? '');

        if (existing != null) {
          final appUser = AppUser(
            name: existing.name,
            society: existing.society,
            profilePic: photo,
            email: existing.email,
            phone: existing.phone,
            latitude: existing.latitude,
            longitude: existing.longitude,
            formattedAddress: existing.formattedAddress,
          );
          AppStateScope.of(context).user = appUser;
          AppStateScope.of(context).initStreams(uid);
          AppStateScope.of(context).pendingEmail = existing.email;

          if (_isProfileComplete(appUser)) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const HomeShell()),
              (route) => false,
            );
          } else {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const AddressScreen()),
              (route) => false,
            );
          }
        } else {
          final authUser = authService.currentUser;
          final appUser = AppUser(
            name: authUser?.displayName ?? '',
            society: '',
            profilePic: photo,
            email: authUser?.email ?? '',
          );
          AppStateScope.of(context).user = appUser;
          AppStateScope.of(context).initStreams(uid);
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const AddressScreen()),
            (route) => false,
          );
        }
      } else if (googleError != null) {
        ValidationFeedback.showWarning(context, googleError!, isError: true);
      }
    } catch (e) {
      if (mounted) {
        ValidationFeedback.showWarning(
            context, 'Google Sign-In failed: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ToolVerseGalaxyBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: PhoneShell(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      Center(
                        child: AnimatedGlowContainer(
                          glowColor: AppColors.cyan,
                          blurRadius: 30,
                          child: const ToolVerseLogo(
                            size: 80,
                            circular: true,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30),
                            gradient: LinearGradient(
                              colors: [
                                AppColors.cyan.withValues(alpha: 0.15),
                                AppColors.violet.withValues(alpha: 0.15),
                              ],
                            ),
                            border: Border.all(
                                color: AppColors.cyan.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.verified_user_rounded,
                                  size: 13, color: AppColors.cyan),
                              SizedBox(width: 6),
                              Text(
                                'COMMUNITY SHARING PLATFORM',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  color: AppColors.cyan,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'Welcome to\n',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 28,
                                fontWeight: FontWeight.w500,
                                color: AppColors.inkSoft,
                                letterSpacing: -0.5,
                              ),
                            ),
                            TextSpan(
                              text: 'ToolVerse',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 36,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Sign in with your Google account to get started in your neighborhood.',
                        style: TextStyle(
                            color: AppColors.muted, fontSize: 13.5, height: 1.5),
                      ),
                      const SizedBox(height: 28),
                      // One-Tap Google Sign-In Button
                      SizedBox(
                        width: double.infinity,
                        child: _googleSignInBtn(
                          onTap: _handleGoogleLogin,
                          loading: _loading,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: TextButton(
                          onPressed: _handleGuestLogin,
                          child: const Text(
                            'Explore as Guest',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const PhoneEntryScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.phone_iphone_rounded, size: 16, color: AppColors.cyan),
                          label: const Text(
                            'Or sign in with phone number',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.cyan,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.lock_outline_rounded,
                                size: 14, color: AppColors.muted),
                            SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Quick & secure — join your neighborhood',
                                style: TextStyle(
                                    fontSize: 11.5, color: AppColors.muted),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PhoneEntryScreen extends StatefulWidget {
  const PhoneEntryScreen({super.key});
  @override
  State<PhoneEntryScreen> createState() => _PhoneEntryScreenState();
}

class _PhoneEntryScreenState extends State<PhoneEntryScreen>
    with SingleTickerProviderStateMixin {
  CountryCode _selectedCountry = kCountryCodes.first; // Default India (+91)
  final phoneCtrl = TextEditingController();
  final phoneFocus = FocusNode();
  String? _phoneError;
  bool _loading = false;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    phoneCtrl.dispose();
    phoneFocus.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  void _onPhoneChanged(String val) {
    if (_phoneError != null) setState(() => _phoneError = null);
  }

  Future<void> _openCountryPicker() async {
    final picked = await showModalBottomSheet<CountryCode>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CountryCodePickerSheet(selected: _selectedCountry),
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedCountry = picked;
        if (_phoneError != null) _phoneError = null;
      });
    }
  }

  Future<void> _handleContinue() async {
    if (_loading) return;
    final rawInput = phoneCtrl.text.trim();
    if (rawInput.isEmpty) {
      setState(() => _phoneError = 'Please enter your mobile number.');
      ValidationFeedback.showWarning(context, _phoneError!, isError: true);
      phoneFocus.requestFocus();
      return;
    }

    final digitsOnly = rawInput.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length < _selectedCountry.minDigits) {
      setState(() => _phoneError =
          'Please enter a valid ${_selectedCountry.name} mobile number (${_selectedCountry.minDigits} digits).');
      ValidationFeedback.showWarning(context, _phoneError!, isError: true);
      phoneFocus.requestFocus();
      return;
    }

    // Build international phone number with country code
    String fullPhone;
    if (rawInput.startsWith('+')) {
      fullPhone = rawInput;
    } else {
      fullPhone = '${_selectedCountry.dialCode}$digitsOnly';
    }

    final formatted = AuthService.formatPhoneNumber(fullPhone) ?? fullPhone;

    setState(() {
      _phoneError = null;
      _loading = true;
    });

    AppStateScope.of(context).pendingPhone = formatted;

    String? sendError;
    await authService.sendOtp(
      fullPhone,
      onError: (err) {
        sendError = err;
      },
      onCodeSent: () {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification code sent to your phone (Dev code: 123456) 📱'),
            backgroundColor: AppColors.cardElevated,
            duration: Duration(seconds: 4),
          ),
        );
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OtpScreen(phone: formatted),
          ),
        );
      },
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (sendError != null) {
      final msg = sendError!;
      setState(() => _phoneError = msg);
      ValidationFeedback.showWarning(context, msg, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ToolVerseGalaxyBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: PhoneShell(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      Center(
                        child: AnimatedGlowContainer(
                          glowColor: AppColors.cyan,
                          blurRadius: 30,
                          child: const ToolVerseLogo(
                            size: 80,
                            circular: true,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30),
                            gradient: LinearGradient(
                              colors: [
                                AppColors.cyan.withValues(alpha: 0.15),
                                AppColors.violet.withValues(alpha: 0.15),
                              ],
                            ),
                            border: Border.all(
                                color: AppColors.cyan.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.verified_user_rounded,
                                  size: 13, color: AppColors.cyan),
                              SizedBox(width: 6),
                              Text(
                                'COMMUNITY SHARING PLATFORM',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  color: AppColors.cyan,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'Welcome to\n',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 28,
                                fontWeight: FontWeight.w500,
                                color: AppColors.inkSoft,
                                letterSpacing: -0.5,
                              ),
                            ),
                            TextSpan(
                              text: 'ToolVerse',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 36,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Enter your phone number to sign in or create a verified account in your neighborhood.',
                        style: TextStyle(
                            color: AppColors.muted, fontSize: 13.5, height: 1.5),
                      ),
                      const SizedBox(height: 28),
                      GlassCard(
                        glowColor: AppColors.cyan,
                        elevated: true,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Mobile number',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12.5,
                                    color: AppColors.inkSoft,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: _openCountryPicker,
                                  child: MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _selectedCountry.flag,
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _selectedCountry.name,
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            color: AppColors.cyan,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(width: 2),
                                        const Icon(
                                          Icons.arrow_drop_down_rounded,
                                          size: 16,
                                          color: AppColors.cyan,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Country code dropdown trigger button
                                GestureDetector(
                                  onTap: _openCountryPicker,
                                  child: MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      height: 52,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12),
                                      decoration: BoxDecoration(
                                        color: AppColors.surface,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: AppColors.glassLine,
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            _selectedCountry.flag,
                                            style:
                                                const TextStyle(fontSize: 20),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _selectedCountry.dialCode,
                                            style: const TextStyle(
                                              color: AppColors.ink,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14.5,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          const Icon(
                                            Icons.keyboard_arrow_down_rounded,
                                            color: AppColors.cyan,
                                            size: 20,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                // Phone number text field
                                Expanded(
                                  child: TextField(
                                    controller: phoneCtrl,
                                    focusNode: phoneFocus,
                                    keyboardType: TextInputType.phone,
                                    inputFormatters: [
                                      PhoneInputFormatter(
                                        context,
                                        maxLength:
                                            _selectedCountry.maxDigits + 4,
                                      ),
                                    ],
                                    onChanged: _onPhoneChanged,
                                    style: const TextStyle(
                                      color: AppColors.ink,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
                                    decoration: neonFieldDecoration(
                                      hint: _selectedCountry.example,
                                      errorText: _phoneError,
                                      prefixIcon: const Icon(
                                        Icons.phone_rounded,
                                        size: 18,
                                        color: AppColors.cyan,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: _loading
                                  ? _loadingBtn()
                                  : _gradientBtn(
                                      label: 'Continue',
                                      onTap: _handleContinue,
                                    ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: TextButton.icon(
                          onPressed: () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => const EmailEntryScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.alternate_email_rounded,
                              size: 16, color: AppColors.cyan),
                          label: const Text(
                            'Or sign in with email address',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.cyan,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.lock_outline_rounded,
                                size: 14, color: AppColors.muted),
                            SizedBox(width: 6),
                            Text(
                              'Quick & secure — join your neighborhood',
                              style: TextStyle(
                                  fontSize: 11.5, color: AppColors.muted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class OtpScreen extends StatefulWidget {
  final String? phone;
  final String? email;
  const OtpScreen({super.key, this.phone, this.email});
  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen>
    with SingleTickerProviderStateMixin {
  final List<TextEditingController> digits =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> focusNodes = List.generate(6, (_) => FocusNode());
  bool _loading = false;
  String? _otpError;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    for (final c in digits) {
      c.dispose();
    }
    for (final f in focusNodes) {
      f.dispose();
    }
    _animCtrl.dispose();
    super.dispose();
  }

  void _onDigitChanged(int index, String val) {
    if (_otpError != null) setState(() => _otpError = null);
    if (val.length > 1) {
      final clean = val.replaceAll(RegExp(r'\D'), '');
      for (int k = 0; k < 6 && k < clean.length; k++) {
        digits[k].text = clean[k];
      }
      if (clean.length >= 6) {
        focusNodes[5].requestFocus();
      } else if (clean.isNotEmpty) {
        focusNodes[clean.length.clamp(0, 5)].requestFocus();
      }
      return;
    }
    if (val.isNotEmpty && index < 5) {
      focusNodes[index + 1].requestFocus();
    } else if (val.isEmpty && index > 0) {
      focusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _verify() async {
    if (_loading) return;
    final smsCode = digits.map((c) => c.text.trim()).join();
    if (smsCode.length != 6) {
      setState(() =>
          _otpError = 'Please enter the complete 6-digit verification code.');
      ValidationFeedback.showWarning(context, _otpError!, isError: true);
      final firstEmpty = digits.indexWhere((c) => c.text.trim().isEmpty);
      if (firstEmpty != -1) focusNodes[firstEmpty].requestFocus();
      return;
    }
    setState(() {
      _otpError = null;
      _loading = true;
    });
    String? otpError;
    final isEmail = widget.email != null && widget.email!.isNotEmpty;
    final success = isEmail
        ? await authService.verifyEmailOtp(
            smsCode,
            email: widget.email,
            onError: (err) => otpError = err,
          )
        : await authService.verifyOtp(
            smsCode,
            phone: widget.phone,
            onError: (err) => otpError = err,
          );
    if (!mounted) return;
    setState(() => _loading = false);
    if (success) {
      final uid = authService.currentUserId!;
      final existing = await firestoreService.getUser(uid);
      if (!mounted) return;
      if (existing != null) {
        final resolvedEmail = existing.email.isNotEmpty ? existing.email : (widget.email ?? '');
        final resolvedPhone = existing.phone.isNotEmpty ? existing.phone : (widget.phone ?? '');
        final appUser = AppUser(
          name: existing.name,
          society: existing.society,
          profilePic: existing.profilePic,
          email: resolvedEmail,
          phone: resolvedPhone,
          latitude: existing.latitude,
          longitude: existing.longitude,
          formattedAddress: existing.formattedAddress,
        );
        AppStateScope.of(context).user = appUser;
        AppStateScope.of(context).initStreams(uid);
        if (isEmail) {
          AppStateScope.of(context).pendingEmail = resolvedEmail;
        } else if (resolvedPhone.isNotEmpty) {
          AppStateScope.of(context).pendingPhone = resolvedPhone;
        }

        // Route to home if user exists with completed profile; otherwise prompt to fill details
        if (_isProfileComplete(appUser)) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomeShell()),
            (route) => false,
          );
        } else {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const AddressScreen()),
            (route) => false,
          );
        }
      } else {
        if (isEmail) {
          AppStateScope.of(context).pendingEmail = widget.email!;
        } else if (widget.phone != null) {
          AppStateScope.of(context).pendingPhone = widget.phone!;
        }
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AddressScreen()),
          (route) => false,
        );
      }
    } else {
      final message = otpError ??
          (authService.lastErrorMessage ??
              '[invalid-verification-code] Invalid verification code. Please try again.');
      setState(() => _otpError = message);
      ValidationFeedback.showWarning(context, message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.heroGradient),
        child: SafeArea(
          child: PhoneShell(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _glassBackBtn(context),
                        const ToolVerseLogo(size: 34, circular: true, withGlow: true),
                      ],
                    ),
                    const SizedBox(height: 32),
                    ShaderMask(
                      shaderCallback: (bounds) =>
                          AppGradients.brandGradient.createShader(bounds),
                      child: Text(
                        widget.email != null
                            ? 'Verify your\nemail'
                            : 'Verify your\nnumber',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.8,
                          height: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Enter the 6-digit code sent to ${widget.email ?? widget.phone ?? ""}',
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 13.5, height: 1.4),
                    ),
                    const SizedBox(height: 32),
                    GlassCard(
                      glowColor: AppColors.violet,
                      elevated: true,
                      child: Column(
                        children: [
                          Row(
                            children: List.generate(6, (i) {
                              return Expanded(
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 3),
                                  child: SizedBox(
                                    height: 54,
                                    child: TextField(
                                      controller: digits[i],
                                      focusNode: focusNodes[i],
                                      textAlign: TextAlign.center,
                                      keyboardType: TextInputType.number,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.ink,
                                      ),
                                      decoration: neonFieldDecoration(
                                        errorText:
                                            _otpError != null ? '' : null,
                                        counterText: '',
                                        contentPadding: EdgeInsets.zero,
                                        accentColor: AppColors.violet,
                                      ),
                                      inputFormatters: [
                                        OtpDigitInputFormatter(context),
                                        LengthLimitingTextInputFormatter(6),
                                      ],
                                      onChanged: (val) =>
                                          _onDigitChanged(i, val),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                          if (_otpError != null &&
                              _otpError!.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(Icons.error_outline_rounded,
                                    size: 14, color: AppColors.red),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _otpError!,
                                    style: const TextStyle(
                                      color: AppColors.red,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: _loading
                                ? _loadingBtn()
                                : _gradientBtn(
                                    label: 'Verify & Continue',
                                    onTap: _verify,
                                    gradient: const LinearGradient(
                                      colors: [
                                        AppColors.violet,
                                        AppColors.cyan
                                      ],
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        child: const Text(
                          'Wrong number? Go back',
                          style: TextStyle(color: AppColors.muted, fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Returns true if the user has all required profile fields filled.
bool _isProfileComplete(AppUser user) {
  // Phone is optional — Google sign-in users may not have a phone.
  // Only require name + location to access the home screen.
  return user.name.trim().length >= 2 &&
      user.latitude != null &&
      user.longitude != null;
}

class AddressScreen extends StatefulWidget {
  const AddressScreen({super.key});
  @override
  State<AddressScreen> createState() => _AddressScreenState();
}

class _AddressScreenState extends State<AddressScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final societyCtrl = TextEditingController();

  final nameFocus = FocusNode();
  final emailFocus = FocusNode();
  final phoneFocus = FocusNode();
  final societyFocus = FocusNode();

  double? _latitude;
  double? _longitude;
  String _formattedAddress = '';
  String? _locationError;

  bool _isSubmitting = false;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = AppStateScope.of(context);
      final existingUser = state.user;
      final authUser = authService.currentUser;

      if (existingUser != null) {
        if (nameCtrl.text.isEmpty && existingUser.name.isNotEmpty) {
          nameCtrl.text = existingUser.name;
        }
        if (emailCtrl.text.isEmpty && existingUser.email.isNotEmpty) {
          emailCtrl.text = existingUser.email;
        }
        if (phoneCtrl.text.isEmpty && existingUser.phone.isNotEmpty) {
          phoneCtrl.text = existingUser.phone;
        }
        if (societyCtrl.text.isEmpty && existingUser.society.isNotEmpty) {
          societyCtrl.text = existingUser.society;
        }
        if (_latitude == null && existingUser.latitude != null) {
          setState(() {
            _latitude = existingUser.latitude;
            _longitude = existingUser.longitude;
            _formattedAddress = existingUser.formattedAddress;
          });
        }
      }
      if (emailCtrl.text.isEmpty) {
        if (authUser?.email != null && authUser!.email!.isNotEmpty) {
          emailCtrl.text = authUser.email!;
        } else if (state.pendingEmail.isNotEmpty) {
          emailCtrl.text = state.pendingEmail;
        }
      }
      if (phoneCtrl.text.isEmpty) {
        if (authUser?.phoneNumber != null &&
            authUser!.phoneNumber!.isNotEmpty) {
          phoneCtrl.text = authUser.phoneNumber!;
        } else if (state.pendingPhone.isNotEmpty) {
          phoneCtrl.text = state.pendingPhone;
        }
      }
    });
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    emailCtrl.dispose();
    phoneCtrl.dispose();
    societyCtrl.dispose();
    nameFocus.dispose();
    emailFocus.dispose();
    phoneFocus.dispose();
    societyFocus.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _chooseLocationOnMap() async {
    try {
      final result = await MapLocationPicker.show(
        context,
        initialLatitude: _latitude,
        initialLongitude: _longitude,
        initialAddress: _formattedAddress,
      );

      if (result != null && mounted) {
        setState(() {
          _latitude = result.latitude;
          _longitude = result.longitude;
          _formattedAddress = result.address;
          _locationError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ValidationFeedback.showWarning(
          context,
          'Could not open map location picker: $e',
          isError: true,
        );
      }
    }
  }

  Future<void> _handleSetup() async {
    if (_isSubmitting) return;

    final isFormValid = _formKey.currentState!.validate();
    if (!isFormValid) {
      ValidationFeedback.showWarning(
        context,
        'Please correct the highlighted fields before continuing.',
        isError: true,
      );
      if (nameCtrl.text.trim().length < 2) {
        nameFocus.requestFocus();
      } else if (emailCtrl.text.trim().isEmpty) {
        emailFocus.requestFocus();
      }
      return;
    }

    if (_latitude == null || _longitude == null) {
      setState(() {
        _locationError =
            'Please tap "Choose Location" to pin your neighborhood on the map.';
      });
      ValidationFeedback.showWarning(
        context,
        'Please choose your neighborhood on the map before continuing.',
        isError: true,
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final societyInput = societyCtrl.text.trim();
      final resolvedSociety = societyInput.isNotEmpty
          ? societyInput
          : (_formattedAddress.isNotEmpty
              ? _formattedAddress
              : 'My Neighborhood');

      await AppStateScope.of(context).signUp(
        nameCtrl.text.trim(),
        resolvedSociety,
        email: emailCtrl.text.trim(),
        phone: phoneCtrl.text.trim(),
        latitude: _latitude,
        longitude: _longitude,
        formattedAddress: _formattedAddress.isNotEmpty
            ? _formattedAddress
            : resolvedSociety,
        profilePic: AppStateScope.of(context).user?.profilePic,
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile setup complete! Welcome to ToolVerse 🛠️'),
          backgroundColor: AppColors.cardElevated,
        ),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeShell()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ValidationFeedback.showWarning(
        context,
        'Failed to save profile details: $e',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.heroGradient),
        child: SafeArea(
          child: PhoneShell(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _glassBackBtn(context),
                          const ToolVerseLogo(
                              size: 34, circular: true, withGlow: true),
                        ],
                      ),
                      const SizedBox(height: 32),
                      ShaderMask(
                        shaderCallback: (bounds) =>
                            AppGradients.brandGradient.createShader(bounds),
                        child: Text(
                          'Complete your\nprofile',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.8,
                            height: 1.1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Provide your details and pin your neighborhood map location to borrow and lend tools safely.',
                        style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 13.5,
                            height: 1.5),
                      ),
                      const SizedBox(height: 28),
                      GlassCard(
                        glowColor: AppColors.neonGreen,
                        elevated: true,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Full Name
                            neonLabeled(
                              'Full name',
                              TextFormField(
                                controller: nameCtrl,
                                focusNode: nameFocus,
                                style: const TextStyle(color: AppColors.ink),
                                decoration: neonFieldDecoration(
                                  hint: 'e.g. Riya Menon',
                                  prefixIcon: const Icon(
                                    Icons.person_outline_rounded,
                                    color: AppColors.cyan,
                                    size: 18,
                                  ),
                                ),
                                inputFormatters: [
                                  NameInputFormatter(context, maxLength: 50),
                                ],
                                validator: (value) {
                                  final trimmed = (value ?? '').trim();
                                  if (trimmed.isEmpty) {
                                    return 'Please enter your full name.';
                                  }
                                  if (trimmed.length < 2) {
                                    return 'Name must contain at least 2 characters.';
                                  }
                                  if (trimmed.length > 50) {
                                    return 'Name cannot exceed 50 characters.';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            // Email Address
                            neonLabeled(
                              'Email address',
                              TextFormField(
                                controller: emailCtrl,
                                focusNode: emailFocus,
                                keyboardType: TextInputType.emailAddress,
                                style: const TextStyle(color: AppColors.ink),
                                decoration: neonFieldDecoration(
                                  hint: 'e.g. riya.menon@example.com',
                                  prefixIcon: const Icon(
                                    Icons.email_outlined,
                                    color: AppColors.cyan,
                                    size: 18,
                                  ),
                                ),
                                validator: (value) {
                                  final trimmed = (value ?? '').trim();
                                  if (trimmed.isEmpty) {
                                    return 'Please enter your email address.';
                                  }
                                  final emailRegex = RegExp(
                                      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                                  if (!emailRegex.hasMatch(trimmed)) {
                                    return 'Please enter a valid email format.';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            // Phone Number
                            neonLabeled(
                              'Phone number (optional)',
                              TextFormField(
                                controller: phoneCtrl,
                                focusNode: phoneFocus,
                                keyboardType: TextInputType.phone,
                                style: const TextStyle(color: AppColors.ink),
                                decoration: neonFieldDecoration(
                                  hint: 'e.g. +91 9876543210',
                                  prefixIcon: const Icon(
                                    Icons.phone_outlined,
                                    color: AppColors.cyan,
                                    size: 18,
                                  ),
                                ),
                                validator: (value) {
                                  final trimmed = (value ?? '').trim();
                                  if (trimmed.isEmpty) return null;
                                  final digits =
                                      trimmed.replaceAll(RegExp(r'\D'), '');
                                  if (digits.length < 8) {
                                    return 'Phone number must contain at least 8 digits.';
                                  }
                                  if (digits.length > 15) {
                                    return 'Phone number cannot exceed 15 digits.';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            // Map Location Picker
                            neonLabeled(
                              'Neighborhood Location (Map Pin)',
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_latitude != null &&
                                      _longitude != null) ...[
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppColors.surface,
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        border: Border.all(
                                          color: AppColors.cyan
                                              .withValues(alpha: 0.4),
                                        ),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: AppColors.cyan
                                                  .withValues(alpha: 0.15),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.pin_drop_rounded,
                                              color: AppColors.cyan,
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  _formattedAddress.isNotEmpty
                                                      ? _formattedAddress
                                                      : 'Pinned Location',
                                                  style: const TextStyle(
                                                    color: AppColors.ink,
                                                    fontWeight:
                                                        FontWeight.w700,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                                const SizedBox(height: 3),
                                                Text(
                                                  'Lat: ${_latitude!.toStringAsFixed(4)}, Lng: ${_longitude!.toStringAsFixed(4)}',
                                                  style: const TextStyle(
                                                    color: AppColors.muted,
                                                    fontSize: 11,
                                                    fontWeight:
                                                        FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          TextButton.icon(
                                            onPressed: _chooseLocationOnMap,
                                            icon: const Icon(
                                              Icons.edit_location_alt_rounded,
                                              size: 15,
                                              color: AppColors.cyan,
                                            ),
                                            label: const Text(
                                              'Change',
                                              style: TextStyle(
                                                color: AppColors.cyan,
                                                fontSize: 12,
                                                fontWeight:
                                                    FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ] else ...[
                                    InkWell(
                                      borderRadius: BorderRadius.circular(14),
                                      onTap: _chooseLocationOnMap,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 14),
                                        decoration: BoxDecoration(
                                          color: AppColors.surface,
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          border: Border.all(
                                            color: AppColors.glassLine,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.add_location_alt_rounded,
                                              color: AppColors.violet,
                                              size: 22,
                                            ),
                                            const SizedBox(width: 10),
                                            const Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Choose Location on Map',
                                                    style: TextStyle(
                                                      color: AppColors.cyan,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                  SizedBox(height: 2),
                                                  Text(
                                                    'Pin your neighborhood or apartment building',
                                                    style: TextStyle(
                                                      color: AppColors.muted,
                                                      fontSize: 11.5,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const Icon(
                                              Icons.chevron_right_rounded,
                                              color: AppColors.muted,
                                              size: 20,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (_locationError != null) ...[
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.error_outline_rounded,
                                          size: 13,
                                          color: AppColors.red,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            _locationError!,
                                            style: const TextStyle(
                                              color: AppColors.red,
                                              fontSize: 11.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            // Neighborhood / Society Name
                            neonLabeled(
                              'Neighborhood / Society',
                              TextFormField(
                                controller: societyCtrl,
                                focusNode: societyFocus,
                                style: const TextStyle(color: AppColors.ink),
                                decoration: neonFieldDecoration(
                                  hint: 'e.g. Sobha City, HSR Layout',
                                  prefixIcon: const Icon(
                                    Icons.holiday_village_rounded,
                                    color: AppColors.violet,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: _isSubmitting
                                  ? _loadingBtn()
                                  : _gradientBtn(
                                      label: 'Save Changes',
                                      onTap: _handleSetup,
                                      gradient: const LinearGradient(
                                        colors: [
                                          AppColors.neonGreen,
                                          AppColors.cyan
                                        ],
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// HOME SHELL — Bottom Navigation with stunning design
// ---------------------------------------------------------------------------

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell>
    with SingleTickerProviderStateMixin {
  int tab = 0;
  late AnimationController _tabAnimCtrl;

  @override
  void initState() {
    super.initState();
    _tabAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();
  }

  @override
  void dispose() {
    _tabAnimCtrl.dispose();
    super.dispose();
  }

  void _setTab(int idx) {
    if (tab == idx) return;
    setState(() => tab = idx);
    _tabAnimCtrl
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      const HomeScreen(),
      const MyItemsScreen(),
      const ProfileScreen(),
    ];

    final navItems = [
      (Icons.home_outlined, Icons.home_rounded, 'Home'),
      (Icons.inventory_2_outlined, Icons.inventory_2_rounded, 'My items'),
      (Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
    ];

    return ToolVerseGalaxyBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: SizedBox.expand(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              layoutBuilder: (currentChild, previousChildren) => Stack(
                fit: StackFit.expand,
                children: [
                  ...previousChildren,
                  if (currentChild != null) currentChild,
                ],
              ),
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
              child: KeyedSubtree(
                key: ValueKey<int>(tab),
                child: screens[tab],
              ),
            ),
          ),
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.cardElevated.withValues(alpha: 0.9),
                AppColors.surface.withValues(alpha: 0.95),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            border: Border(
                top: BorderSide(color: AppColors.glassLine, width: 1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Center(
              heightFactor: 1.0,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: List.generate(navItems.length, (i) {
                      final (outIcon, selIcon, label) = navItems[i];
                      final isActive = tab == i;
                      return GestureDetector(
                        onTap: () => _setTab(i),
                        behavior: HitTestBehavior.opaque,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 8),
                          decoration: isActive
                              ? BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.cyan.withValues(alpha: 0.15),
                                      AppColors.violet.withValues(alpha: 0.15),
                                    ],
                                  ),
                                  border: Border.all(
                                      color:
                                          AppColors.cyan.withValues(alpha: 0.3)),
                                )
                              : null,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isActive ? selIcon : outIcon,
                                size: 22,
                                color: isActive
                                    ? AppColors.cyan
                                    : AppColors.muted,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                label,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isActive
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isActive
                                      ? AppColors.cyan
                                      : AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// HOME SCREEN
// ---------------------------------------------------------------------------

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  String query = '';
  ItemCategory? filter;
  late AnimationController _headerCtrl;
  late Animation<double> _headerFade;

  @override
  void initState() {
    super.initState();
    _headerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _headerFade =
        CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _headerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final items = state.items.where((i) {
      final matchesCat = filter == null || i.category == filter;
      final matchesQuery = i.name.toLowerCase().contains(query.toLowerCase());
      return matchesCat && matchesQuery;
    }).toList();

    return Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top header
                FadeTransition(
                  opacity: _headerFade,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedGlowContainer(
                              glowColor: AppColors.cyan,
                              blurRadius: 20,
                              duration: const Duration(milliseconds: 2200),
                              child: const ToolVerseLogo(
                                  size: 40, circular: true),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ShaderMask(
                                      shaderCallback: (bounds) =>
                                          AppGradients.brandGradient
                                              .createShader(bounds),
                                      child: Text(
                                        'ToolVerse',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 19,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                          letterSpacing: -0.4,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            AppColors.cyan
                                                .withValues(alpha: 0.2),
                                            AppColors.violet
                                                .withValues(alpha: 0.2),
                                          ],
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(6),
                                        border: Border.all(
                                            color: AppColors.cyan
                                                .withValues(alpha: 0.3)),
                                      ),
                                      child: const Text(
                                        'NEIGHBORS',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.6,
                                          color: AppColors.cyan,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.place_rounded,
                                        size: 12, color: AppColors.muted),
                                    const SizedBox(width: 3),
                                    Text(
                                      state.user?.society ??
                                          'Palm Meadows Residency',
                                      style: const TextStyle(
                                          fontSize: 11.5,
                                          color: AppColors.muted),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                        const NotificationBellButton(),
                      ],
                    ),
                  ),
                ),
                // Title + search
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'Nearby',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink,
                                letterSpacing: -0.6,
                              ),
                            ),
                            TextSpan(
                              text: ' to borrow',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 26,
                                fontWeight: FontWeight.w400,
                                color: AppColors.inkSoft,
                                letterSpacing: -0.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        style: const TextStyle(color: AppColors.ink),
                        inputFormatters: [
                          LengthLimitWithWarningFormatter(context,
                              maxLength: 60, fieldLabel: 'Search query'),
                        ],
                        decoration: neonFieldDecoration(
                          hint: 'Search drills, cameras, camping gear…',
                          prefixIcon: const Icon(Icons.search_rounded,
                              size: 20, color: AppColors.muted),
                        ),
                        onChanged: (v) => setState(() => query = v),
                      ),
                    ],
                  ),
                ),
                // Category chips
                SizedBox(
                  height: 50,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                    children: [
                      _categoryChip(context, null, 'All', filter == null,
                          () => setState(() => filter = null)),
                      for (final c in ItemCategory.values)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: _categoryChip(
                            context,
                            c,
                            c.label,
                            filter == c,
                            () => setState(() => filter = c),
                          ),
                        ),
                    ],
                  ),
                ),
                // Items grid/list
                Expanded(
                  child: items.isEmpty
                      ? const NeonEmptyState(
                          text:
                              'No items match yet. Try another search or list your own item with the + button.')
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth >= 680) {
                              final cols = constraints.maxWidth >= 1400
                                  ? 4
                                  : (constraints.maxWidth >= 960 ? 3 : 2);
                              return GridView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                    20, 10, 20, 100),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: cols,
                                  mainAxisSpacing: 14,
                                  crossAxisSpacing: 14,
                                  mainAxisExtent: 140,
                                ),
                                itemCount: items.length,
                                itemBuilder: (context, i) {
                                  final it = items[i];
                                  return ItemCard(
                                    item: it,
                                    index: i,
                                    onTap: () =>
                                        Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            ItemDetailScreen(item: it),
                                      ),
                                    ),
                                  );
                                },
                              );
                            }
                            return ListView.separated(
                              padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                              itemCount: items.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, i) {
                                final it = items[i];
                                return ItemCard(
                                  item: it,
                                  index: i,
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          ItemDetailScreen(item: it),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
            // FAB
            Positioned(
              right: 20,
              bottom: 20,
              child: _GradientFAB(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ListItemScreen()),
                ),
              ),
            ),
          ],
        );
  }
}

Widget _categoryChip(
  BuildContext context,
  ItemCategory? category,
  String label,
  bool active,
  VoidCallback onTap,
) {
  final color = category?.color ?? AppColors.cyan;
  return MouseRegion(
    cursor: SystemMouseCursors.click,
    child: GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: active
              ? LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.28),
                    color.withValues(alpha: 0.12),
                  ],
                )
              : null,
          color: active ? null : AppColors.card,
          border: Border.all(
            color: active ? color.withValues(alpha: 0.7) : AppColors.glassLine,
            width: active ? 1.4 : 1,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (category != null) ...[
              Icon(category.icon,
                  size: 13, color: active ? color : AppColors.muted),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                color: active ? color : AppColors.inkSoft,
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _GradientFAB extends StatefulWidget {
  final VoidCallback onTap;
  const _GradientFAB({required this.onTap});

  @override
  State<_GradientFAB> createState() => _GradientFABState();
}

class _GradientFABState extends State<_GradientFAB>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      lowerBound: 0.9,
      upperBound: 1.0,
      value: 1.0,
    );
    _scaleAnim = _ctrl;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.reverse(),
      onTapUp: (_) {
        _ctrl.forward();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.forward(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: AnimatedGlowContainer(
          glowColor: AppColors.cyan,
          blurRadius: 25,
          duration: const Duration(milliseconds: 1600),
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppGradients.brandGradient,
              boxShadow: [
                BoxShadow(
                  color: AppColors.cyan.withValues(alpha: 0.4),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(Icons.add_rounded,
                size: 30, color: AppColors.midnight),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ITEM CARD
// ---------------------------------------------------------------------------

class ItemCard extends StatefulWidget {
  final Item item;
  final VoidCallback onTap;
  final int index;
  const ItemCard(
      {super.key, required this.item, required this.onTap, this.index = 0});

  @override
  State<ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<ItemCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;
  late Animation<double> _scaleAnim;
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
      lowerBound: 0.94,
      upperBound: 1.0,
      value: 1.0,
    );
    _scaleAnim = CurvedAnimation(
      parent: _pressCtrl,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final catColor = item.category.color;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) {
          HapticFeedback.lightImpact();
          setState(() => _isPressed = true);
          _pressCtrl.reverse();
        },
        onTapUp: (_) {
          setState(() => _isPressed = false);
          _pressCtrl.forward();
          widget.onTap();
        },
        onTapCancel: () {
          setState(() => _isPressed = false);
          _pressCtrl.forward();
        },
        child: ScaleTransition(
          scale: _scaleAnim,
          child: AnimatedSlide(
            offset: Offset(0, _isHovered && !_isPressed ? -0.025 : 0),
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isHovered
                      ? [const Color(0xFF1B2338), const Color(0xFF121828)]
                      : [AppColors.cardElevated, AppColors.card],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _isPressed
                      ? catColor
                      : (_isHovered
                          ? catColor.withValues(alpha: 0.85)
                          : AppColors.glassLine),
                  width: _isHovered || _isPressed ? 1.6 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _isPressed
                        ? catColor.withValues(alpha: 0.55)
                        : (_isHovered
                            ? catColor.withValues(alpha: 0.38)
                            : Colors.black.withValues(alpha: 0.35)),
                    blurRadius: _isHovered ? 28 : (_isPressed ? 22 : 12),
                    offset: Offset(0, _isHovered ? 8 : 4),
                  ),
                  if (_isHovered)
                    BoxShadow(
                      color: AppColors.cyan.withValues(alpha: 0.18),
                      blurRadius: 16,
                      offset: const Offset(0, 2),
                    ),
                ],
              ),
              child: Row(
                children: [
                  // Item photo or Category Icon tile
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 58,
                    height: 58,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          catColor.withValues(
                              alpha: _isHovered ? 0.35 : 0.22),
                          catColor.withValues(alpha: 0.08),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: catColor.withValues(
                            alpha: _isHovered ? 0.85 : 0.35),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: catColor.withValues(
                              alpha: _isHovered ? 0.4 : 0.15),
                          blurRadius: _isHovered ? 16 : 8,
                        ),
                      ],
                    ),
                    child: item.imageUrl.isNotEmpty
                        ? Image.network(
                            item.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(
                              child: AnimatedScale(
                                scale: _isHovered ? 1.15 : 1.0,
                                duration: const Duration(milliseconds: 200),
                                child: Icon(item.category.icon,
                                    color: catColor, size: 28),
                              ),
                            ),
                          )
                        : Center(
                            child: AnimatedScale(
                              scale: _isHovered ? 1.15 : 1.0,
                              duration: const Duration(milliseconds: 200),
                              child: Icon(item.category.icon,
                                  color: catColor, size: 28),
                            ),
                          ),
                  ),
                  const SizedBox(width: 14),
                  // Item description & details
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top category badge & live availability dot
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: catColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: catColor.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Text(
                                item.category.label.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                  color: catColor,
                                ),
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: AppColors.neonGreen,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.neonGreen
                                            .withValues(alpha: 0.8),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Text(
                                  'Available',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.neonGreen,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        // Item title
                        Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _isHovered ? AppColors.cyan : AppColors.ink,
                            fontWeight: FontWeight.w700,
                            fontSize: 15.5,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Owner avatar, name, and rating
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 8,
                              backgroundColor: AppColors.surface,
                              child: Text(
                                item.owner.isNotEmpty
                                    ? item.owner[0].toUpperCase()
                                    : 'U',
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  color: catColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                item.owner,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.inkSoft,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Refundable deposit
                        Row(
                          children: [
                            Text(
                              '₹${item.deposit}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: catColor,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Flexible(
                              child: Text(
                                'refundable deposit',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.muted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Animated Action arrow button
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: _isHovered
                          ? AppColors.cyan.withValues(alpha: 0.2)
                          : AppColors.surface,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _isHovered
                            ? AppColors.cyan.withValues(alpha: 0.7)
                            : AppColors.glassLine,
                      ),
                    ),
                    child: Center(
                      child: AnimatedSlide(
                        offset: Offset(_isHovered ? 0.12 : 0, 0),
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: _isHovered ? AppColors.cyan : AppColors.muted,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// LIST ITEM SCREEN
// ---------------------------------------------------------------------------

class ListItemScreen extends StatefulWidget {
  const ListItemScreen({super.key});
  @override
  State<ListItemScreen> createState() => _ListItemScreenState();
}

class _ListItemScreenState extends State<ListItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final nameCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final depositCtrl = TextEditingController(text: '500');
  final imageCtrl = TextEditingController();
  final nameFocus = FocusNode();
  final descFocus = FocusNode();
  final depositFocus = FocusNode();
  ItemCategory category = ItemCategory.tools;
  bool _isPublishing = false;
  String _imagePreview = '';

  // Image upload state
  final ImagePicker _picker = ImagePicker();
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  int? _selectedImageSize;
  String? _imageError;
  bool _showUrlFallback = false;

  @override
  void dispose() {
    nameCtrl.dispose();
    descCtrl.dispose();
    depositCtrl.dispose();
    imageCtrl.dispose();
    nameFocus.dispose();
    descFocus.dispose();
    depositFocus.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
      );
      if (pickedFile == null) return;

      final bytes = await pickedFile.readAsBytes();
      final fileName = pickedFile.name;

      final validation = StorageService.validateImage(
        bytes: bytes,
        fileName: fileName,
      );

      if (!validation.isValid) {
        setState(() {
          _imageError = validation.errorMessage;
        });
        if (mounted) {
          ValidationFeedback.showWarning(
            context,
            validation.errorMessage ?? 'Invalid image file.',
            isError: true,
          );
        }
        return;
      }

      setState(() {
        _selectedImageBytes = bytes;
        _selectedImageName = fileName;
        _selectedImageSize = bytes.lengthInBytes;
        _imageError = null;
        _imagePreview = '';
        imageCtrl.clear();
      });
    } catch (e) {
      if (mounted) {
        ValidationFeedback.showWarning(
          context,
          'Could not open file manager: $e',
          isError: true,
        );
      }
    }
  }

  void _removeSelectedImage() {
    setState(() {
      _selectedImageBytes = null;
      _selectedImageName = null;
      _selectedImageSize = null;
      _imageError = null;
    });
  }

  Future<void> _handlePublish() async {
    if (_isPublishing) return;
    if (!_formKey.currentState!.validate()) {
      ValidationFeedback.showWarning(
        context,
        'Please correct the highlighted fields before continuing.',
        isError: true,
      );
      if (nameCtrl.text.trim().length < 2) {
        nameFocus.requestFocus();
      } else if (descCtrl.text.trim().length < 5) {
        descFocus.requestFocus();
      } else {
        depositFocus.requestFocus();
      }
      return;
    }

    setState(() => _isPublishing = true);
    final state = AppStateScope.of(context);
    final depositAmount = int.tryParse(depositCtrl.text.trim()) ?? 0;

    try {
      await state.uploadAndPublishItem(
        item: Item(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: nameCtrl.text.trim(),
          category: category,
          owner: state.user?.name ?? 'You',
          desc: descCtrl.text.trim(),
          deposit: depositAmount,
          imageUrl: imageCtrl.text.trim(),
        ),
        imageBytes: _selectedImageBytes,
        imageFileName: _selectedImageName,
      );

      if (!mounted) return;
      setState(() => _isPublishing = false);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Listed! Neighbors can now request to borrow it. ✨'),
          backgroundColor: AppColors.cardElevated,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isPublishing = false);
      ValidationFeedback.showWarning(
        context,
        'Failed to publish listing: $e',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.midnight,
      appBar: _neonAppBar(
        context,
        title: 'List an item',
        leading: _glassBackBtn(context),
      ),
      body: Align (
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  neonLabeled(
                    'Item name',
                    TextFormField(
                      controller: nameCtrl,
                      focusNode: nameFocus,
                      style: const TextStyle(color: AppColors.ink),
                      decoration: neonFieldDecoration(
                        hint: 'e.g. Bosch Drill 500W, Pressure Washer',
                      ),
                      inputFormatters: [
                        ItemNameInputFormatter(context, maxLength: 60),
                      ],
                      validator: (value) {
                        final trimmed = (value ?? '').trim();
                        if (trimmed.isEmpty) {
                          return 'Please enter an item name.';
                        }
                        if (trimmed.length < 2) {
                          return 'Item name must contain at least 2 characters.';
                        }
                        if (trimmed.length > 60) {
                          return 'Item name cannot exceed 60 characters.';
                        }
                        return null;
                      },
                    ),
                  ),
                  neonLabeled(
                    'Category',
                    DropdownButtonFormField<ItemCategory>(
                      initialValue: category,
                      dropdownColor: AppColors.surface,
                      style: const TextStyle(color: AppColors.ink),
                      decoration: neonFieldDecoration(),
                      items: ItemCategory.values
                          .map((c) => DropdownMenuItem(
                              value: c, child: Text(c.label)))
                          .toList(),
                      validator: (value) {
                        if (value == null) {
                          return 'Please select an item category.';
                        }
                        return null;
                      },
                      onChanged: (v) =>
                          setState(() => category = v ?? category),
                    ),
                  ),
                  neonLabeled(
                    'Short description',
                    TextFormField(
                      controller: descCtrl,
                      focusNode: descFocus,
                      maxLines: 3,
                      style: const TextStyle(color: AppColors.ink),
                      decoration: neonFieldDecoration(
                        hint: 'Condition, accessories included, usage notes…',
                      ),
                      inputFormatters: [
                        LengthLimitWithWarningFormatter(context,
                            maxLength: 500, fieldLabel: 'Description'),
                      ],
                      validator: (value) {
                        final trimmed = (value ?? '').trim();
                        if (trimmed.isEmpty) {
                          return 'Please enter an item description.';
                        }
                        if (trimmed.length < 5) {
                          return 'Description must contain at least 5 characters.';
                        }
                        if (trimmed.length > 500) {
                          return 'Description cannot exceed 500 characters.';
                        }
                        return null;
                      },
                    ),
                  ),
                  neonLabeled(
                    'Refundable deposit (₹)',
                    TextFormField(
                      controller: depositCtrl,
                      focusNode: depositFocus,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: AppColors.ink),
                      decoration: neonFieldDecoration(hint: 'e.g. 500'),
                      inputFormatters: [
                        NumericAmountInputFormatter(context, maxLength: 6),
                      ],
                      validator: (value) {
                        final trimmed = (value ?? '').trim();
                        if (trimmed.isEmpty) {
                          return 'Please enter a valid deposit amount.';
                        }
                        final amount = int.tryParse(trimmed);
                        if (amount == null) {
                          return 'Please enter a valid deposit amount.';
                        }
                        if (amount < 0 || amount > 50000) {
                          return 'Deposit must be between ₹0 and ₹50,000.';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Item photo upload section
                  neonLabeled(
                    'Item photo (optional)',
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_selectedImageBytes != null) ...[
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: AppColors.cyan.withValues(alpha: 0.5),
                                  width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.cyan.withValues(alpha: 0.15),
                                  blurRadius: 16,
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(15)),
                                  child: Image.memory(
                                    _selectedImageBytes!,
                                    height: 180,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.check_circle_rounded,
                                          color: AppColors.neonGreen, size: 16),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '${_selectedImageName ?? "photo"} (${((_selectedImageSize ?? 0) / (1024 * 1024)).toStringAsFixed(1)} MB)',
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: AppColors.ink,
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      TextButton.icon(
                                        onPressed: _pickImage,
                                        icon: const Icon(Icons.refresh_rounded,
                                            size: 15, color: AppColors.cyan),
                                        label: const Text(
                                          'Replace',
                                          style: TextStyle(
                                              color: AppColors.cyan,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700),
                                        ),
                                        style: TextButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        onPressed: _removeSelectedImage,
                                        icon: const Icon(
                                            Icons.delete_outline_rounded,
                                            size: 18,
                                            color: AppColors.red),
                                        tooltip: 'Remove photo',
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          // Upload button
                          InkWell(
                            onTap: _pickImage,
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 22, horizontal: 16),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppColors.glassLine,
                                  width: 1.2,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.cyan
                                          .withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.add_photo_alternate_rounded,
                                      color: AppColors.cyan,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    'Choose Image from Computer',
                                    style: TextStyle(
                                      color: AppColors.ink,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Supports JPG, PNG, WebP • Max 10 MB',
                                    style: TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        if (_imageError != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _imageError!,
                            style: const TextStyle(
                                color: AppColors.red, fontSize: 12),
                          ),
                        ],
                        const SizedBox(height: 10),
                        // Collapsible URL fallback
                        InkWell(
                          onTap: () => setState(
                              () => _showUrlFallback = !_showUrlFallback),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _showUrlFallback
                                      ? Icons.keyboard_arrow_up_rounded
                                      : Icons.keyboard_arrow_down_rounded,
                                  color: AppColors.muted,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _showUrlFallback
                                      ? 'Hide URL option'
                                      : 'Or paste an image URL instead',
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_showUrlFallback) ...[
                          const SizedBox(height: 8),
                          TextField(
                            controller: imageCtrl,
                            style: const TextStyle(color: AppColors.ink),
                            decoration: neonFieldDecoration(
                              hint: 'https://example.com/image.jpg',
                              prefixIcon: const Icon(
                                Icons.link_rounded,
                                size: 18,
                                color: AppColors.violet,
                              ),
                              accentColor: AppColors.violet,
                            ),
                            onChanged: (val) {
                              setState(() => _imagePreview = val.trim());
                            },
                          ),
                          if (_imagePreview.isNotEmpty &&
                              _selectedImageBytes == null) ...[
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                _imagePreview,
                                height: 140,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: AppColors.glassLine),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'Could not load image URL',
                                      style: TextStyle(
                                          color: AppColors.muted, fontSize: 12),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: _isPublishing
                        ? _loadingBtn()
                        : _gradientBtn(
                            label: 'Publish listing',
                            onTap: _handlePublish,
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ITEM DETAIL SCREEN
// ---------------------------------------------------------------------------

class ItemDetailScreen extends StatelessWidget {
  final Item item;
  const ItemDetailScreen({super.key, required this.item});

  Widget _itemHeroFallback(Color catColor, Item item) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: catColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: catColor.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: Icon(item.category.icon, size: 52, color: catColor),
          ),
          const SizedBox(height: 10),
          Text(
            item.category.label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: catColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catColor = item.category.color;
    return Scaffold(
      backgroundColor: AppColors.midnight,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 840),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Hero Banner
                        Stack(
                          children: [
                            Container(
                              height: 230,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    catColor.withValues(alpha: 0.3),
                                    AppColors.midnight,
                                    catColor.withValues(alpha: 0.1),
                                  ],
                                ),
                              ),
                              child: item.imageUrl.isNotEmpty
                                  ? Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Image.network(
                                          item.imageUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              _itemHeroFallback(
                                                  catColor, item),
                                        ),
                                        Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                Colors.transparent,
                                                AppColors.midnight
                                                    .withValues(alpha: 0.7),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  : _itemHeroFallback(catColor, item),
                            ),
                            Positioned(
                              top: 14,
                              left: 14,
                              right: 14,
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  _glassBackBtn(context, light: false),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                          color: AppColors.glassLine),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        ToolVerseLogo(size: 18, circular: true),
                                        SizedBox(width: 6),
                                        Text(
                                          'ToolVerse',
                                          style: TextStyle(
                                            color: AppColors.ink,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        // Content
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 5),
                                decoration: BoxDecoration(
                                  color: catColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: catColor.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(item.category.icon,
                                        size: 13, color: catColor),
                                    const SizedBox(width: 5),
                                    Text(
                                      item.category.label,
                                      style: TextStyle(
                                        color: catColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),
                              // Owner card
                              GlassCard(
                                padding: const EdgeInsets.all(14),
                                glowColor: catColor,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [catColor, catColor.withValues(alpha: 0.5)],
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        initials(item.owner),
                                        style: const TextStyle(
                                          color: AppColors.midnight,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.owner,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.ink,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const Text('Community lender', style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
                                       ],
                                     ),
                                   ],
                                 ),
                               ),
                              const SizedBox(height: 18),
                              Text(
                                item.desc,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  height: 1.6,
                                  color: AppColors.inkSoft,
                                ),
                              ),
                              const SizedBox(height: 22),
                              const Text(
                                'AVAILABILITY THIS MONTH',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.muted,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 10),
                              const AvailabilityCalendar(),
                              const SizedBox(height: 22),
                              GlassCard(
                                padding: const EdgeInsets.all(16),
                                glowColor: AppColors.amber,
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: AppColors.amber
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: AppColors.amber
                                                .withValues(alpha: 0.3)),
                                      ),
                                      child: const Icon(
                                          Icons.account_balance_wallet_rounded,
                                          color: AppColors.amber,
                                          size: 22),
                                    ),
                                    const SizedBox(width: 14),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Refundable deposit',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.muted,
                                          ),
                                        ),
                                        Text(
                                          '₹${item.deposit}',
                                          style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.amber,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Spacer(),
                                    const Text(
                                      'Returned after\nAI check ✓',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                          fontSize: 11.5,
                                          color: AppColors.muted,
                                          height: 1.4),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Bottom action
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.cardElevated, AppColors.surface],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    border: Border(
                        top: BorderSide(color: AppColors.glassLine)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: _gradientBtn(
                      label: 'Request to borrow',
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => BorrowRequestScreen(item: item))),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AvailabilityCalendar extends StatelessWidget {
  const AvailabilityCalendar({super.key});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 28,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7, mainAxisSpacing: 6, crossAxisSpacing: 6),
          itemBuilder: (context, i) {
            final day = i + 1;
            final avail = day % 5 != 0 && day % 7 != 1;
            return Container(
              decoration: BoxDecoration(
                gradient: avail
                    ? LinearGradient(
                        colors: [
                          AppColors.neonGreen.withValues(alpha: 0.25),
                          AppColors.cyan.withValues(alpha: 0.1),
                        ],
                      )
                    : null,
                color: avail ? null : AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: avail
                      ? AppColors.neonGreen.withValues(alpha: 0.3)
                      : AppColors.glassLine,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                '$day',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight:
                      avail ? FontWeight.w700 : FontWeight.w400,
                  color: avail ? AppColors.neonGreen : AppColors.muted,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// BORROW REQUEST SCREEN
// ---------------------------------------------------------------------------

class BorrowRequestScreen extends StatefulWidget {
  final Item item;
  const BorrowRequestScreen({super.key, required this.item});
  @override
  State<BorrowRequestScreen> createState() => _BorrowRequestScreenState();
}

class _BorrowRequestScreenState extends State<BorrowRequestScreen> {
  DateTime? from;
  DateTime? to;
  bool esign = false;
  bool _submitting = false;
  String? _dateError;
  final noteCtrl = TextEditingController();

  @override
  void dispose() {
    noteCtrl.dispose();
    super.dispose();
  }

  Future<void> pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final firstAllowed = isFrom ? now : (from ?? now);
    final initial = isFrom
        ? (from ?? now)
        : (to != null && !to!.isBefore(firstAllowed) ? to! : firstAllowed);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          from = picked;
          if (to != null && to!.isBefore(picked)) to = picked;
        } else {
          to = picked;
        }
        if (from != null && to != null) {
          if (to!.isBefore(from!)) {
            _dateError = 'Return date must be on or after the pickup date.';
          } else {
            _dateError = null;
          }
        } else {
          _dateError = null;
        }
      });
    }
  }

  String fmt(DateTime? d) =>
      d == null ? 'Select date' : '${d.day}/${d.month}/${d.year}';

  Future<void> _handleSubmit() async {
    if (_submitting) return;
    if (from == null) {
      setState(() => _dateError = 'Please select a pickup date.');
      ValidationFeedback.showWarning(context, 'Please select a pickup date.',
          isError: true);
      return;
    }
    if (to == null) {
      setState(() => _dateError = 'Please select a return date.');
      ValidationFeedback.showWarning(context, 'Please select a return date.',
          isError: true);
      return;
    }
    if (to!.isBefore(from!)) {
      setState(() =>
          _dateError = 'Return date must be on or after the pickup date.');
      ValidationFeedback.showWarning(
          context, 'Return date must be on or after the pickup date.',
          isError: true);
      return;
    }
    if (!esign) {
      ValidationFeedback.showWarning(
        context,
        'Please accept the digital borrowing agreement before continuing.',
        isError: true,
      );
      return;
    }

    setState(() {
      _dateError = null;
      _submitting = true;
    });

    try {
      final item = widget.item;
      final state = AppStateScope.of(context);
      final booking =
          await state.requestBorrow(item, from, to, noteCtrl.text.trim());

      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Request sent to ${item.owner}',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppColors.cardElevated,
        ),
      );
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => BookingScreen(booking: booking)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      final msg = e.toString().replaceAll('Exception: ', '').replaceAll('Exception', '');
      ValidationFeedback.showWarning(context, msg, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final catColor = item.category.color;
    return Scaffold(
      backgroundColor: AppColors.midnight,
      appBar: _neonAppBar(
        context,
        title: 'Borrow request',
        leading: _glassBackBtn(context),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Item summary card
                GlassCard(
                  padding: const EdgeInsets.all(14),
                  glowColor: catColor,
                  elevated: true,
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              catColor.withValues(alpha: 0.25),
                              catColor.withValues(alpha: 0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: catColor.withValues(alpha: 0.3)),
                        ),
                        child: Icon(item.category.icon, color: catColor),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.ink,
                                    fontSize: 15)),
                            Text('Owner: ${item.owner}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12.5, color: AppColors.muted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                neonLabeled('Pick up',
                    _neonDateField(fmt(from), () => pickDate(isFrom: true))),
                neonLabeled('Return by',
                    _neonDateField(fmt(to), () => pickDate(isFrom: false))),
                if (_dateError != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            size: 14, color: AppColors.red),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _dateError!,
                            style: const TextStyle(
                              color: AppColors.red,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // Deposit card
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  glowColor: AppColors.amber,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Refundable deposit',
                              style: TextStyle(
                                  fontSize: 11.5, color: AppColors.muted)),
                          Text('₹${item.deposit}',
                              style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.amber)),
                        ],
                      ),
                      const Flexible(
                        child: Text('Refunded after\nAI condition check',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                                fontSize: 11.5, color: AppColors.muted,
                                height: 1.4)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                neonLabeled(
                  'Note to owner (optional)',
                  TextField(
                    controller: noteCtrl,
                    maxLines: 2,
                    inputFormatters: [
                      LengthLimitWithWarningFormatter(context,
                          maxLength: 300, fieldLabel: 'Note to owner'),
                    ],
                    style: const TextStyle(color: AppColors.ink),
                    decoration: neonFieldDecoration(
                      hint: 'Anything they should know, e.g. exact pickup time…',
                    ),
                  ),
                ),
                // Agreement
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.violet.withValues(alpha: 0.1),
                        AppColors.cyan.withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: AppColors.violet.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: esign,
                        onChanged: (v) =>
                            setState(() => esign = v ?? false),
                        activeColor: AppColors.cyan,
                        checkColor: AppColors.midnight,
                      ),
                      const Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text(
                            'I agree to the digital borrowing agreement — item, dates and deposit as shown above — and will return the item in its original condition.',
                            style: TextStyle(
                                fontSize: 12.5, color: AppColors.inkSoft,
                                height: 1.4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: _submitting
                      ? _loadingBtn()
                      : AnimatedOpacity(
                          opacity: esign ? 1.0 : 0.5,
                          duration: const Duration(milliseconds: 200),
                          child: _gradientBtn(
                            label: 'Confirm & send request',
                            onTap: (!esign || _submitting)
                                ? () {}
                                : _handleSubmit,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// BOOKING SCREEN
// ---------------------------------------------------------------------------

class BookingScreen extends StatefulWidget {
  final Booking booking;
  const BookingScreen({super.key, required this.booking});
  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final chatCtrl = TextEditingController();
  bool aiRunning = false;
  bool _isSharingLocation = false;
  StreamSubscription<List<ChatMsgModel>>? _chatSub;

  @override
  void initState() {
    super.initState();
    _subscribeToLiveChat();
  }

  void _subscribeToLiveChat() {
    final uid = authService.currentUserId;
    if (uid != null && widget.booking.id.isNotEmpty) {
      _chatSub = firestoreService
          .streamChat(widget.booking.id, uid)
          .listen((msgs) {
        if (!mounted || msgs.isEmpty) return;
        setState(() {
          widget.booking.chat
            ..clear()
            ..addAll(
              msgs.map((m) => ChatMsg(
                    m.fromMe,
                    m.text,
                    type: m.type,
                    latitude: m.latitude,
                    longitude: m.longitude,
                    locationAddress: m.locationAddress,
                  )),
            );
        });
      }, onError: (e) {
        debugPrint('[BookingChat] Stream error: $e');
      });
    }
  }

  @override
  void dispose() {
    _chatSub?.cancel();
    chatCtrl.dispose();
    super.dispose();
  }

  String fmt(DateTime? d) =>
      d == null ? '—' : '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final booking = widget.booking;
    final uid = authService.currentUserId ?? '';
    final myEmail = (state.user?.email.isNotEmpty == true
            ? state.user!.email
            : (authService.currentUser?.email ?? ''))
        .trim()
        .toLowerCase();

    // Determine whether current user is definitely the borrower:
    // Strictly by UID or Email (never by display name, which can be identical)
    final isBorrower = (booking.borrowerId.isNotEmpty &&
            uid.isNotEmpty &&
            booking.borrowerId == uid) ||
        (myEmail.isNotEmpty &&
            booking.borrowerEmail.trim().toLowerCase() == myEmail);

    // Determine whether current user is owner/lender:
    final isOwner = !isBorrower &&
        ((booking.lenderId.isNotEmpty &&
                uid.isNotEmpty &&
                booking.lenderId == uid) ||
            (booking.item.ownerId.isNotEmpty &&
                uid.isNotEmpty &&
                booking.item.ownerId == uid) ||
            (myEmail.isNotEmpty &&
                (booking.lenderEmail.trim().toLowerCase() == myEmail ||
                    booking.lenderId.trim().toLowerCase() == myEmail ||
                    booking.item.owner.trim().toLowerCase() == myEmail)) ||
            state.items.any((i) => i.id == booking.item.id && i.ownerId == uid));

    final lenderEmail = booking.lenderEmail.isNotEmpty
        ? booking.lenderEmail
        : (booking.item.owner.contains('@') ? booking.item.owner : '');

    final ownerDisplayName = booking.item.owner.isNotEmpty
        ? (lenderEmail.isNotEmpty && booking.item.owner != lenderEmail
            ? '${booking.item.owner} ($lenderEmail)'
            : (booking.item.owner.isNotEmpty ? booking.item.owner : lenderEmail))
        : (lenderEmail.isNotEmpty ? lenderEmail : 'Owner');

    final borrowerDisplayName = booking.borrowerName.isNotEmpty
        ? (booking.borrowerEmail.isNotEmpty &&
                booking.borrowerName != booking.borrowerEmail
            ? '${booking.borrowerName} (${booking.borrowerEmail})'
            : booking.borrowerName)
        : (booking.borrowerEmail.isNotEmpty ? booking.borrowerEmail : 'Borrower');

    final otherPartyName = isOwner ? borrowerDisplayName : ownerDisplayName;

    return Scaffold(
      backgroundColor: AppColors.midnight,
      appBar: _neonAppBar(
        context,
        title: isOwner ? 'Lending Booking' : 'Borrow Booking',
        leading: _glassBackBtn(context),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: const NotificationBellButton(),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: AnimatedBuilder(
            animation: state,
            builder: (context, _) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Agreement card
                    GlassCard(
                      padding: const EdgeInsets.all(16),
                      glowColor: AppColors.violet,
                      elevated: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          AppColors.violet
                                              .withValues(alpha: 0.2),
                                          AppColors.cyan
                                              .withValues(alpha: 0.2),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                        Icons.description_rounded,
                                        size: 16,
                                        color: AppColors.violet),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('Digital agreement',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.ink,
                                          fontSize: 15)),
                                ],
                              ),
                              neonStatusPill(booking.status),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _agreementRow('Item', booking.item.name),
                          if (isOwner) ...[
                            _agreementRow('Owner', '${booking.item.owner} (You)'),
                            _agreementRow('Borrower', borrowerDisplayName),
                            if (booking.borrowerEmail.isNotEmpty)
                              _agreementRow('Borrower Email', booking.borrowerEmail),
                            _agreementRow('Your Role', 'Owner / Lender 🛠️ (You)'),
                          ] else ...[
                            _agreementRow('Owner', ownerDisplayName),
                            if (lenderEmail.isNotEmpty)
                              _agreementRow('Owner Email', lenderEmail),
                            _agreementRow('Borrower', '${booking.borrowerName.isNotEmpty ? booking.borrowerName : "Borrower"} (You)'),
                            _agreementRow('Your Role', 'Borrower 🤝 (You)'),
                          ],
                          _agreementRow('Dates',
                              '${fmt(booking.from)} → ${fmt(booking.to)}'),
                          _agreementRow('Deposit', '₹${booking.item.deposit}'),
                          _agreementRow('E-signed', 'Both parties ✓'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      isOwner
                          ? 'CHAT WITH BORROWER (${borrowerDisplayName.toUpperCase()})'
                          : 'CHAT WITH OWNER (${ownerDisplayName.toUpperCase()})',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.muted,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Chat messages
                    GlassCard(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final m in booking.chat)
                            if (m.isLocation)
                              _buildLocationChatBubble(context, m)
                            else
                              Align(
                                alignment: m.fromMe
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  constraints: BoxConstraints(
                                      maxWidth:
                                          MediaQuery.of(context).size.width *
                                              0.68),
                                  decoration: BoxDecoration(
                                    gradient: m.fromMe
                                        ? const LinearGradient(
                                            colors: [
                                              AppColors.cyan,
                                              AppColors.violet
                                            ],
                                          )
                                        : null,
                                    color: m.fromMe ? null : AppColors.surface,
                                    border: m.fromMe
                                        ? null
                                        : Border.all(
                                            color: AppColors.glassLine),
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(16),
                                      topRight: const Radius.circular(16),
                                      bottomLeft: m.fromMe
                                          ? const Radius.circular(16)
                                          : const Radius.circular(4),
                                      bottomRight: m.fromMe
                                          ? const Radius.circular(4)
                                          : const Radius.circular(16),
                                    ),
                                    boxShadow: m.fromMe
                                        ? [
                                            BoxShadow(
                                              color: AppColors.cyan
                                                  .withValues(alpha: 0.3),
                                              blurRadius: 12,
                                              offset: const Offset(0, 4),
                                            )
                                          ]
                                        : null,
                                  ),
                                  child: Text(m.text,
                                      style: TextStyle(
                                          color: m.fromMe
                                              ? AppColors.midnight
                                              : AppColors.ink,
                                          fontSize: 13.5,
                                          fontWeight: m.fromMe
                                              ? FontWeight.w600
                                              : FontWeight.w400)),
                                ),
                              ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    // "Pick Me" Location Action Row
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          InkWell(
                            onTap: _isSharingLocation
                                ? null
                                : () => _handlePickMeTap(state, booking),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.cyan.withValues(alpha: 0.2),
                                    AppColors.violet.withValues(alpha: 0.15),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.cyan.withValues(alpha: 0.5),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_isSharingLocation)
                                    const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                            AppColors.cyan),
                                      ),
                                    )
                                  else
                                    const Icon(Icons.near_me_rounded,
                                        size: 16, color: AppColors.cyan),
                                  const SizedBox(width: 6),
                                  const Text(
                                    '📍 Pick Me',
                                    style: TextStyle(
                                      color: AppColors.cyan,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12.5,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Share pickup location with $otherPartyName',
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 11.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Chat input
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: chatCtrl,
                            style: const TextStyle(color: AppColors.ink),
                            inputFormatters: [
                              LengthLimitWithWarningFormatter(context,
                                  maxLength: 300, fieldLabel: 'Message'),
                            ],
                            decoration: neonFieldDecoration(
                                hint: 'Message about pickup…'),
                            onSubmitted: (_) => sendMsg(state, booking),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => sendMsg(state, booking),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: AppGradients.brandGradient,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.cyan.withValues(alpha: 0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                )
                              ],
                            ),
                            child: const Icon(Icons.send_rounded,
                                size: 20, color: AppColors.midnight),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (booking.status == BookingStatus.pending)
                      SizedBox(
                        width: double.infinity,
                        child: _gradientBtn(
                          label: isOwner
                              ? '✅ Accept & Hand Over Item'
                              : 'Confirm Item Received / Picked Up 📦',
                          onTap: () => isOwner
                              ? state.acceptBooking(booking)
                              : state.markPickedUp(booking),
                          gradient: isOwner
                              ? const LinearGradient(
                                  colors: [AppColors.neonGreen, AppColors.cyan],
                                )
                              : const LinearGradient(
                                  colors: [AppColors.neonGreen, AppColors.cyan],
                                ),
                        ),
                      ),
                    if (isOwner && booking.status != BookingStatus.cancelled)
                      buildAiCheck(state, booking),
                    const SizedBox(height: 14),
                    // Return reminder button
                    GestureDetector(
                      onTap: () {
                        state.triggerReminderNotification(
                          itemName: booking.item.name,
                          dueDate: fmt(booking.to),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('⏰ Return Reminder added to Notifications.'),
                            backgroundColor: AppColors.cardElevated,
                          ),
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            vertical: 13, horizontal: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: const Color(0xFFFF8C42)
                                  .withValues(alpha: 0.5)),
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFFFF8C42).withValues(alpha: 0.12),
                              const Color(0xFFFF8C42).withValues(alpha: 0.05),
                            ],
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.alarm_rounded,
                                size: 18, color: Color(0xFFFF8C42)),
                            SizedBox(width: 8),
                            Text(
                              'Send Return Reminder (Live Demo)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFFF8C42),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void sendMsg(AppState state, Booking booking) {
    final text = chatCtrl.text.trim();
    if (text.isEmpty) {
      ValidationFeedback.showWarning(
          context, 'Please enter a message before sending.',
          isError: true);
      return;
    }
    if (text.length > 300) {
      ValidationFeedback.showWarning(
          context, 'Message cannot exceed 300 characters.',
          isError: true);
      return;
    }
    state.sendChat(booking, text);
    chatCtrl.clear();
  }

  // ---------------------------------------------------------------------------
  // Step 8: Booking Chat Pickup Location Sharing
  // ---------------------------------------------------------------------------

  Future<void> _handlePickMeTap(AppState state, Booking booking) async {
    if (_isSharingLocation) return;

    final chosenOption = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _PickMeOptionsSheet(user: state.user),
    );

    if (chosenOption == null || !mounted) return;

    if (chosenOption == 'gps') {
      await _handleGpsOption(state, booking);
    } else if (chosenOption == 'profile') {
      await _handleProfileOption(state, booking);
    } else if (chosenOption == 'map') {
      await _handleMapOption(state, booking);
    }
  }

  Future<void> _handleGpsOption(AppState state, Booking booking) async {
    if (_isSharingLocation) return;
    setState(() => _isSharingLocation = true);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.cyan),
              ),
            ),
            SizedBox(width: 12),
            Text('Acquiring current GPS location…'),
          ],
        ),
        duration: Duration(seconds: 4),
        backgroundColor: AppColors.cardElevated,
      ),
    );

    try {
      final res = await getBrowserCoordinates();
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (res.latitude != null && res.longitude != null) {
        final lat = res.latitude!;
        final lng = res.longitude!;
        final geocode = await fetchReverseGeocode(lat, lng);
        final address = geocode.isSuccess
            ? geocode.displayName
            : 'GPS Pin (${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)})';

        await _confirmAndShareLocation(
          state,
          booking,
          latitude: lat,
          longitude: lng,
          address: address,
          sourceLabel: geocode.isSuccess ? geocode.primaryName : 'Current GPS Location',
        );
      } else {
        final isDenied = res.isPermissionDenied;
        final errorMsg = res.errorMessage ??
            'Could not retrieve GPS coordinates. You can choose a location on the map manually.';
        _showGpsErrorDialog(state, booking,
            message: errorMsg, isDenied: isDenied);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ValidationFeedback.showWarning(
          context,
          'GPS location acquisition failed: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isSharingLocation = false);
    }
  }

  void _showGpsErrorDialog(
    AppState state,
    Booking booking, {
    required String message,
    required bool isDenied,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.glassLine),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.location_off_rounded,
                  color: AppColors.amber, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'GPS Unavailable',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 13.5,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child:
                const Text('Cancel', style: TextStyle(color: AppColors.muted)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              _handleMapOption(state, booking);
            },
            icon: const Icon(Icons.map_rounded, size: 16),
            label: const Text('Choose on Map'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.cyan,
              foregroundColor: AppColors.midnight,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleProfileOption(AppState state, Booking booking) async {
    final user = state.user;
    final hasCoords = user?.latitude != null && user?.longitude != null;
    final address = (user?.formattedAddress.trim().isNotEmpty == true)
        ? user!.formattedAddress.trim()
        : (user?.society.trim().isNotEmpty == true
            ? user!.society.trim()
            : '');

    if (!hasCoords || address.isEmpty) {
      _showMissingProfileLocationDialog(state, booking);
      return;
    }

    await _confirmAndShareLocation(
      state,
      booking,
      latitude: user!.latitude!,
      longitude: user.longitude!,
      address: address,
      sourceLabel: 'Saved Profile Location',
    );
  }

  void _showMissingProfileLocationDialog(AppState state, Booking booking) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.glassLine),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.cyan.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.person_pin_circle_rounded,
                  color: AppColors.cyan, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'No Saved Location',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        content: const Text(
          'You have not saved pickup coordinates in your profile yet. You can choose a location on the map now.',
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 13.5,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child:
                const Text('Cancel', style: TextStyle(color: AppColors.muted)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              _handleMapOption(state, booking);
            },
            icon: const Icon(Icons.map_rounded, size: 16),
            label: const Text('Choose on Map'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.cyan,
              foregroundColor: AppColors.midnight,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleMapOption(AppState state, Booking booking) async {
    if (_isSharingLocation) return;
    final initialLat = state.user?.latitude;
    final initialLng = state.user?.longitude;
    final initialAddr = (state.user?.formattedAddress.isNotEmpty == true)
        ? state.user!.formattedAddress
        : (state.user?.society.isNotEmpty == true ? state.user!.society : null);

    final result = await MapLocationPicker.show(
      context,
      initialLatitude: initialLat,
      initialLongitude: initialLng,
      initialAddress: initialAddr,
    );

    if (result == null || !mounted) return;

    await _confirmAndShareLocation(
      state,
      booking,
      latitude: result.latitude,
      longitude: result.longitude,
      address: result.address,
      sourceLabel: 'Map Selection',
    );
  }

  Future<void> _confirmAndShareLocation(
    AppState state,
    Booking booking, {
    required double latitude,
    required double longitude,
    required String address,
    required String sourceLabel,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.glassLine),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.cyan, AppColors.violet],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.location_on_rounded,
                  color: AppColors.midnight, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Share Pickup Location?',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Confirm pickup point to share with ${(booking.borrowerId == (authService.currentUserId ?? '') ? booking.item.owner : (booking.borrowerName.isNotEmpty ? booking.borrowerName : (booking.borrowerEmail.isNotEmpty ? booking.borrowerEmail : 'borrower')))}:',
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.midnight.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.cyan.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.pin_drop_rounded,
                          color: AppColors.neonGreen, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          address,
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const SizedBox(width: 26),
                      Text(
                        'Coords: ${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 11.5,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const SizedBox(width: 26),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.violet.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          sourceLabel,
                          style: const TextStyle(
                            color: AppColors.violet,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child:
                const Text('Cancel', style: TextStyle(color: AppColors.muted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.cyan,
              foregroundColor: AppColors.midnight,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 10),
            ),
            child: const Text('Confirm & Share',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isSharingLocation = true);
    try {
      await state.sendLocationMessage(
        bookingId: booking.id,
        latitude: latitude,
        longitude: longitude,
        address: address,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded,
                  color: AppColors.neonGreen, size: 20),
              SizedBox(width: 10),
              Text('📍 Pickup location shared successfully!'),
            ],
          ),
          backgroundColor: AppColors.cardElevated,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ValidationFeedback.showWarning(
        context,
        'Failed to send pickup location. Please check your network.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isSharingLocation = false);
    }
  }

  Widget _buildLocationChatBubble(BuildContext context, ChatMsg m) {
    final lat = m.latitude;
    final lng = m.longitude;
    final address = (m.locationAddress != null && m.locationAddress!.isNotEmpty)
        ? m.locationAddress!
        : m.text.replaceAll('📍 Pickup Location: ', '');
    final hasCoords = lat != null && lng != null;

    return Align(
      alignment: m.fromMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.76,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: m.fromMe
                ? const Radius.circular(18)
                : const Radius.circular(4),
            bottomRight: m.fromMe
                ? const Radius.circular(4)
                : const Radius.circular(18),
          ),
          border: Border.all(
            color: m.fromMe
                ? AppColors.cyan.withValues(alpha: 0.5)
                : AppColors.violet.withValues(alpha: 0.4),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: (m.fromMe ? AppColors.cyan : AppColors.violet)
                  .withValues(alpha: 0.15),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: m.fromMe
                      ? [
                          AppColors.cyan.withValues(alpha: 0.25),
                          AppColors.violet.withValues(alpha: 0.15),
                        ]
                      : [
                          AppColors.violet.withValues(alpha: 0.25),
                          AppColors.cyan.withValues(alpha: 0.15),
                        ],
                ),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.neonGreen.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.location_on_rounded,
                        color: AppColors.neonGreen, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      m.fromMe
                          ? 'My Pickup Location'
                          : 'Pickup Location Shared',
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.midnight.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '📍 Verified Pin',
                      style: TextStyle(
                        color: AppColors.neonGreen,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    address,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      height: 1.3,
                    ),
                  ),
                  if (hasCoords) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.gps_fixed_rounded,
                            size: 13, color: AppColors.muted),
                        const SizedBox(width: 4),
                        Text(
                          '${lat.toStringAsFixed(4)}° N, ${lng.toStringAsFixed(4)}° E',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 11.5,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final mapUrl = hasCoords
                            ? 'https://www.google.com/maps/search/?api=1&query=$lat,$lng'
                            : 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}';
                        openMapUrl(mapUrl);
                      },
                      icon: const Icon(Icons.open_in_new_rounded, size: 15),
                      label: const Text('Open in Maps'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.midnight,
                        foregroundColor: AppColors.cyan,
                        side: BorderSide(
                          color: AppColors.cyan.withValues(alpha: 0.5),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPhotoSourceSheet(AppState state, Booking booking,
      {required bool isBefore}) async {
    final option = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppColors.midnight,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: AppColors.glassLine)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.muted.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.cyan, AppColors.violet],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.add_a_photo_rounded,
                        color: AppColors.midnight, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isBefore
                              ? 'Capture Pickup Photo (Before)'
                              : 'Capture Return Photo (After)',
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Choose camera for real-time picture or upload from computer',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: AppColors.glassLine),
                ),
                tileColor: AppColors.surface,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.cyan.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.camera_alt_rounded,
                      color: AppColors.cyan, size: 22),
                ),
                title: const Text('Take Real-Time Picture (Camera)',
                    style: TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                subtitle: const Text(
                    'Use device camera or webcam to take live picture',
                    style: TextStyle(color: AppColors.muted, fontSize: 12)),
                onTap: () => Navigator.of(ctx).pop('camera'),
              ),
              const SizedBox(height: 10),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: AppColors.glassLine),
                ),
                tileColor: AppColors.surface,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.violet.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.upload_file_rounded,
                      color: AppColors.violet, size: 22),
                ),
                title: const Text('Upload from Computer / Gallery',
                    style: TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                subtitle: const Text(
                    'Select an existing image file from your system',
                    style: TextStyle(color: AppColors.muted, fontSize: 12)),
                onTap: () => Navigator.of(ctx).pop('gallery'),
              ),
            ],
          ),
        ),
      ),
    );

    if (option == null || !mounted) return;

    try {
      Uint8List? bytes;

      if (option == 'camera') {
        // Opens the device camera app or laptop webcam viewfinder
        bytes = await captureLiveCameraPhoto(context);
      } else {
        // Upload from computer / device gallery
        final picker = ImagePicker();
        final XFile? pickedFile = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1600,
          imageQuality: 88,
        );
        if (pickedFile != null) {
          bytes = await pickedFile.readAsBytes();
        }
      }

      if (bytes == null || bytes.isEmpty || !mounted) return;

      setState(() {
        if (isBefore) {
          booking.beforePhoto = true;
          booking.beforeImageBytes = bytes;
        } else {
          booking.afterPhoto = true;
          booking.afterImageBytes = bytes;
        }
      });

      state.markPhoto(booking, before: isBefore);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${isBefore ? "Before (Pickup)" : "After (Return)"} photo saved! 📸',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppColors.cardElevated,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ValidationFeedback.showWarning(
          context,
          'Failed to capture photo: $e',
          isError: true,
        );
      }
    }
  }

  Future<void> _showGeminiApiKeyDialog(BuildContext context) async {
    final currentKey = await GeminiVisionService.getSavedApiKey() ?? '';
    final ctrl = TextEditingController(text: currentKey);

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: AppColors.glassLine),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.violet, AppColors.cyan],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.bolt_rounded,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gemini Vision API Key',
                    style: TextStyle(
                      color: AppColors.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Google Multimodal AI Vision for tool inspection',
                    style: TextStyle(color: AppColors.muted, fontSize: 11.5),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.cyan.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.cyan.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'How to get a FREE Gemini API key:',
                      style: TextStyle(
                          color: AppColors.cyan,
                          fontWeight: FontWeight.w700,
                          fontSize: 12),
                    ),
                    SizedBox(height: 6),
                    Text(
                      '1. Go to: aistudio.google.com/app/apikey\n2. Sign in with your Google account\n3. Click "Create API Key"\n4. Paste the key below and tap Save',
                      style: TextStyle(
                          color: AppColors.inkSoft, fontSize: 11.5, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                obscureText: true,
                style: const TextStyle(color: AppColors.ink, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Gemini API Key',
                  labelStyle: const TextStyle(color: AppColors.muted),
                  hintText: 'AIzaSy...',
                  hintStyle: const TextStyle(color: AppColors.muted),
                  filled: true,
                  fillColor: AppColors.midnight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.glassLine),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.cyan),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (currentKey.isNotEmpty)
            TextButton(
              onPressed: () async {
                await GeminiVisionService.clearApiKey();
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Gemini API key removed.'),
                      backgroundColor: AppColors.cardElevated,
                    ),
                  );
                }
              },
              child: const Text('Clear Key',
                  style: TextStyle(color: AppColors.red)),
            ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.muted)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newKey = ctrl.text.trim();
              if (newKey.isNotEmpty) {
                await GeminiVisionService.saveApiKey(newKey);
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Gemini API key saved successfully! ⚡'),
                      backgroundColor: AppColors.cardElevated,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.cyan,
              foregroundColor: AppColors.midnight,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Save Key',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showAiInspectionReportDialog(
    BuildContext context,
    AppState state,
    Booking booking, {
    required String listingImageUrl,
    required GeminiVisionResult geminiResult,
  }) {
    final spokenText = geminiResult.spokenVerdict;

    // Automatically speak the inspection verdict aloud
    speakInspectionVerdict(spokenText);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: AppColors.glassLine),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.neonGreen, AppColors.cyan],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.auto_awesome_rounded,
                  color: AppColors.midnight, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'AI Vision Inspection',
                        style: TextStyle(
                          color: AppColors.ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: !geminiResult.success
                              ? AppColors.red.withValues(alpha: 0.2)
                              : geminiResult.isRealAi
                                  ? AppColors.violet.withValues(alpha: 0.25)
                                  : AppColors.cyan.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: !geminiResult.success
                                ? AppColors.red
                                : geminiResult.isRealAi
                                    ? AppColors.violet
                                    : AppColors.cyan,
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          !geminiResult.success
                              ? 'Inspection Error'
                              : geminiResult.isRealAi
                                  ? 'Gemini 1.5 Flash ⚡'
                                  : 'AI Vision Mode',
                          style: TextStyle(
                            color: !geminiResult.success
                                ? AppColors.red
                                : geminiResult.isRealAi
                                    ? AppColors.violet
                                    : AppColors.cyan,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    geminiResult.success
                        ? 'Match: ${geminiResult.matchPercentageString} vs listing baseline'
                        : 'Inspection could not complete — see error below',
                    style: TextStyle(
                      color: geminiResult.success
                          ? AppColors.neonGreen
                          : AppColors.red,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Photos preview row: Listing (Before) vs Return (After)
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.inventory_2_rounded,
                                  size: 13, color: AppColors.cyan),
                              SizedBox(width: 4),
                              Text('Original Listing (Before)',
                                  style: TextStyle(
                                      color: AppColors.cyan,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Container(
                            height: 105,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: AppColors.midnight,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: AppColors.cyan.withValues(alpha: 0.5)),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(11),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  if (booking.beforeImageBytes != null)
                                    Image.memory(
                                      booking.beforeImageBytes!,
                                      fit: BoxFit.cover,
                                    )
                                  else if (listingImageUrl.isNotEmpty)
                                    Image.network(
                                      listingImageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const Center(
                                        child: Icon(Icons.handyman_rounded,
                                            color: AppColors.cyan, size: 28),
                                      ),
                                    )
                                  else
                                    const Center(
                                      child: Icon(Icons.handyman_rounded,
                                          color: AppColors.cyan, size: 28),
                                    ),
                                  Positioned(
                                    bottom: 0,
                                    left: 0,
                                    right: 0,
                                    child: Container(
                                      color:
                                          Colors.black.withValues(alpha: 0.65),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 3, horizontal: 6),
                                      child: const Text(
                                        'From Item Listing',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.camera_alt_rounded,
                                  size: 13, color: AppColors.neonGreen),
                              SizedBox(width: 4),
                              Text('Return Photo (After)',
                                  style: TextStyle(
                                      color: AppColors.neonGreen,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Container(
                            height: 105,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: AppColors.midnight,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.neonGreen),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(11),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  if (booking.afterImageBytes != null)
                                    Image.memory(
                                      booking.afterImageBytes!,
                                      fit: BoxFit.cover,
                                    )
                                  else
                                    const Center(
                                      child: Icon(Icons.check_circle_rounded,
                                          color: AppColors.neonGreen,
                                          size: 28),
                                    ),
                                  Positioned(
                                    bottom: 0,
                                    left: 0,
                                    right: 0,
                                    child: Container(
                                      color:
                                          Colors.black.withValues(alpha: 0.65),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 3, horizontal: 6),
                                      child: const Text(
                                        'Returned Camera Shot',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // AI Spoken Verdict & Audio Announcement Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.cyan.withValues(alpha: 0.15),
                        AppColors.violet.withValues(alpha: 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: AppColors.cyan.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: AppColors.cyan.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.volume_up_rounded,
                            color: AppColors.cyan, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Text(
                                  'AI SPOKEN VERDICT',
                                  style: TextStyle(
                                    color: AppColors.cyan,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                SizedBox(width: 6),
                                Icon(Icons.record_voice_over_rounded,
                                    color: AppColors.cyan, size: 13),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              spokenText,
                              style: const TextStyle(
                                color: AppColors.ink,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.replay_rounded,
                            color: AppColors.cyan, size: 20),
                        tooltip: 'Listen again',
                        onPressed: () => speakInspectionVerdict(spokenText),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Show error state if inspection failed
                if (!geminiResult.success) ...[  
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: AppColors.red.withValues(alpha: 0.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.error_outline_rounded,
                                color: AppColors.red, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'AI INSPECTION FAILED',
                              style: TextStyle(
                                color: AppColors.red,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          geminiResult.errorMessage ??
                              'Unknown error during AI inspection.',
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'NO deposit decision has been made. Resolve the issue and run the inspection again.',
                          style: TextStyle(
                            color: AppColors.amber,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[  
                // AI Metrics Comparison Box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        (geminiResult.isSameItem ? AppColors.neonGreen : AppColors.red)
                            .withValues(alpha: 0.12),
                        AppColors.cyan.withValues(alpha: 0.06),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: (geminiResult.isSameItem
                                ? AppColors.neonGreen
                                : AppColors.red)
                            .withValues(alpha: 0.35)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('AI Match Comparison',
                              style: TextStyle(
                                  color: AppColors.ink,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (geminiResult.isSameItem
                                      ? AppColors.neonGreen
                                      : AppColors.red)
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: (geminiResult.isSameItem
                                          ? AppColors.neonGreen
                                          : AppColors.red)
                                      .withValues(alpha: 0.6)),
                            ),
                            child: Text(
                              geminiResult.isSameItem
                                  ? '${geminiResult.matchPercentageString} Match ✓'
                                  : 'DIFFERENT ITEM ✗',
                              style: TextStyle(
                                  color: geminiResult.isSameItem
                                      ? AppColors.neonGreen
                                      : AppColors.red,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Surface & Edge Integrity',
                              style: TextStyle(
                                  color: AppColors.muted, fontSize: 12)),
                          Text(
                              '${geminiResult.surfaceIntegrity.toStringAsFixed(1)}% Intact',
                              style: TextStyle(
                                  color: geminiResult.surfaceIntegrity >= 75
                                      ? AppColors.neonGreen
                                      : AppColors.amber,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Defects & Observations',
                              style: TextStyle(
                                  color: AppColors.muted, fontSize: 12)),
                          Expanded(
                            child: Text(
                              geminiResult.defectsCount == 0
                                  ? '0 (Pristine Condition)'
                                  : '${geminiResult.defectsCount} detected',
                              textAlign: TextAlign.end,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: geminiResult.defectsCount == 0
                                      ? AppColors.neonGreen
                                      : AppColors.amber,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Defect summary text
                      if (geminiResult.defectsSummary.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            geminiResult.defectsSummary,
                            style: const TextStyle(
                              color: AppColors.inkSoft,
                              fontSize: 11.5,
                              height: 1.35,
                            ),
                          ),
                        ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Deposit Refund',
                              style: TextStyle(
                                  color: AppColors.muted, fontSize: 12)),
                          Text(
                              geminiResult.depositApproved
                                  ? '₹${booking.item.deposit} Approved 💰'
                                  : 'Deposit Withheld ⚠️',
                              style: TextStyle(
                                  color: geminiResult.depositApproved
                                      ? AppColors.amber
                                      : AppColors.red,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ],
                  ),
                ),
                ], // end else
                if (!geminiResult.isRealAi)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: InkWell(
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _showGeminiApiKeyDialog(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.violet.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppColors.violet.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.bolt_rounded,
                                color: AppColors.violet, size: 16),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Tap here to add your free Gemini API key for live multimodal vision.',
                                style: TextStyle(
                                  color: AppColors.violet,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios_rounded,
                                color: AppColors.violet, size: 11),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  geminiResult.depositApproved
                      ? 'Item condition verified against original listing. The loan can be concluded and the borrower\'s security deposit of ₹${booking.item.deposit} will be released.'
                      : (geminiResult.isSameItem
                          ? 'Item condition below required threshold (${geminiResult.matchPercentage.toStringAsFixed(1)}%). Security deposit is withheld pending dispute resolution.'
                          : 'Returned item does NOT match the original listing. Security deposit of ₹${booking.item.deposit} is strictly withheld.'),
                  style: TextStyle(
                    color: geminiResult.depositApproved
                        ? AppColors.inkSoft
                        : AppColors.amber,
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: geminiResult.depositApproved
                        ? FontWeight.normal
                        : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          if (geminiResult.depositApproved)
            ElevatedButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                booking.beforePhoto = true;
                await state.runAiCheck(booking);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.neonGreen,
                foregroundColor: AppColors.midnight,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: Text(
                'Approve Return & Refund ₹${booking.item.deposit}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          else
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.red.withValues(alpha: 0.2),
                foregroundColor: AppColors.red,
                side: const BorderSide(color: AppColors.red),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: const Text('Close (Deposit Withheld)',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }

  Widget buildAiCheck(AppState state, Booking booking) {
    // Resolve baseline before photo from the listing image
    String listingImageUrl = booking.item.imageUrl;
    if (listingImageUrl.isEmpty) {
      final matches = state.items.where((i) => i.id == booking.item.id);
      if (matches.isNotEmpty && matches.first.imageUrl.isNotEmpty) {
        listingImageUrl = matches.first.imageUrl;
      }
    }
    if (listingImageUrl.isEmpty) {
      listingImageUrl = switch (booking.item.category) {
        ItemCategory.tools =>
          'https://images.unsplash.com/photo-1504148455328-c376907d081c?w=600&auto=format&fit=crop&q=80',
        ItemCategory.electronics =>
          'https://images.unsplash.com/photo-1516035069371-29a1b244cc32?w=600&auto=format&fit=crop&q=80',
        ItemCategory.sports =>
          'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=600&auto=format&fit=crop&q=80',
        ItemCategory.camping =>
          'https://images.unsplash.com/photo-1510312305653-8ed496efae75?w=600&auto=format&fit=crop&q=80',
        ItemCategory.games =>
          'https://images.unsplash.com/photo-1610890716171-6b1bb98ffd09?w=600&auto=format&fit=crop&q=80',
      };
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.violet.withValues(alpha: 0.12),
            AppColors.cyan.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.violet.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.violet, AppColors.cyan],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    size: 18, color: Colors.white),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('AI return condition check',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.ink)),
              ),
              TextButton.icon(
                onPressed: () => _showGeminiApiKeyDialog(context),
                icon: const Icon(Icons.bolt_rounded,
                    size: 14, color: AppColors.cyan),
                label: const Text('Gemini Key',
                    style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.cyan,
                        fontWeight: FontWeight.w700)),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  backgroundColor: AppColors.cyan.withValues(alpha: 0.12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'The original listing photo is linked as the baseline "Before" image. Simply take or upload the "After (Return)" photo with the camera to run the Gemini AI condition inspection.',
            style: TextStyle(
                fontSize: 12.5, color: AppColors.muted, height: 1.4),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _photoSlot(
                  label: 'Original Listing (Before)',
                  filled: true,
                  imageBytes: booking.beforeImageBytes,
                  imageUrl: listingImageUrl,
                  badgeText: 'Listing Photo ✓',
                  subtitle: 'From item listing',
                  isReadOnly: true,
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppColors.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: const BorderSide(color: AppColors.glassLine),
                        ),
                        title: Row(
                          children: const [
                            Icon(Icons.verified_rounded,
                                color: AppColors.cyan, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Original Listing Photo',
                              style: TextStyle(
                                color: AppColors.ink,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                listingImageUrl,
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  height: 160,
                                  color: AppColors.midnight,
                                  child: const Center(
                                    child: Icon(Icons.handyman_rounded,
                                        color: AppColors.cyan, size: 48),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'This photo was saved when you listed the tool. ToolVerse AI uses it as the baseline to compare against the returned tool condition.',
                              style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 12,
                                  height: 1.4),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('Close',
                                style: TextStyle(color: AppColors.cyan)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _photoSlot(
                  label: 'After (Return Photo)',
                  filled: booking.afterPhoto || booking.afterImageBytes != null,
                  imageBytes: booking.afterImageBytes,
                  badgeText: 'Return Photo ✓',
                  subtitle: (booking.afterPhoto || booking.afterImageBytes != null)
                      ? 'Tap to retake'
                      : 'Camera or upload',
                  onTap: () =>
                      _showPhotoSourceSheet(state, booking, isBefore: false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: _gradientBtn(
              label: aiRunning
                  ? 'Analyzing with Gemini Vision…'
                  : 'Run AI condition check',
              onTap: aiRunning
                  ? () {}
                  : () async {
                      if (!booking.afterPhoto &&
                          booking.afterImageBytes == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Please capture or upload the After (Return) photo first.',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600),
                            ),
                            backgroundColor: AppColors.cardElevated,
                          ),
                        );
                        return;
                      }
                      setState(() => aiRunning = true);

                      try {
                        // Run Gemini Vision Multimodal Inspection
                        final geminiResult =
                            await GeminiVisionService.inspectToolReturn(
                          listingImageBytes: booking.beforeImageBytes,
                          listingImageUrl: listingImageUrl,
                          returnImageBytes: booking.afterImageBytes!,
                          toolName: booking.item.name,
                          depositAmount: booking.item.deposit,
                        );

                        if (mounted) {
                          _showAiInspectionReportDialog(
                            context,
                            state,
                            booking,
                            listingImageUrl: listingImageUrl,
                            geminiResult: geminiResult,
                          );
                        }
                      } catch (e, st) {
                        debugPrint('[AI Check Error] $e\n$st');
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Inspection error: $e',
                                style: const TextStyle(color: Colors.white),
                              ),
                              backgroundColor: AppColors.red,
                            ),
                          );
                        }
                      } finally {
                        if (mounted) {
                          setState(() => aiRunning = false);
                        }
                      }
                    },
              gradient: const LinearGradient(
                colors: [AppColors.amber, AppColors.red],
              ),
            ),
          ),
          if (booking.status == BookingStatus.done)
            Container(
              margin: const EdgeInsets.only(top: 14),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.neonGreen.withValues(alpha: 0.15),
                    AppColors.cyan.withValues(alpha: 0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.neonGreen.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.verified_rounded,
                      color: AppColors.neonGreen, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No new damage detected. Item condition matches pickup. Deposit refunded and trust scores updated for both parties.',
                      style: TextStyle(
                          color: AppColors.neonGreen,
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 8: Pick Me Options Modal Sheet
// ---------------------------------------------------------------------------

class _PickMeOptionsSheet extends StatelessWidget {
  final AppUser? user;
  const _PickMeOptionsSheet({this.user});

  @override
  Widget build(BuildContext context) {
    final hasProfileLocation =
        user?.latitude != null && user?.longitude != null;
    final profileLocationText = (user?.formattedAddress.isNotEmpty == true)
        ? user!.formattedAddress
        : (user?.society.isNotEmpty == true ? user!.society : '');

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.midnight,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppColors.glassLine)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.muted.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.cyan, AppColors.violet],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.near_me_rounded,
                      color: AppColors.midnight, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Share Pickup Location',
                        style: TextStyle(
                          color: AppColors.ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Choose how you want to pinpoint your pickup spot',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Option 1: Use Current GPS Location
            _optionTile(
              icon: Icons.my_location_rounded,
              iconColor: AppColors.cyan,
              title: 'Use my current GPS location',
              subtitle: 'Request browser GPS coordinates at your current spot',
              onTap: () => Navigator.of(context).pop('gps'),
            ),
            const SizedBox(height: 10),
            // Option 2: Use Saved Profile Location
            _optionTile(
              icon: Icons.person_pin_circle_rounded,
              iconColor: AppColors.neonGreen,
              title: 'Use my saved profile location',
              subtitle: hasProfileLocation
                  ? profileLocationText
                  : 'No location saved in profile yet (tap to set up)',
              onTap: () => Navigator.of(context).pop('profile'),
            ),
            const SizedBox(height: 10),
            // Option 3: Choose a location on the map
            _optionTile(
              icon: Icons.map_rounded,
              iconColor: AppColors.amber,
              title: 'Choose a location on the map',
              subtitle:
                  'Pan, zoom, or pick a neighborhood on the interactive map',
              onTap: () => Navigator.of(context).pop('map'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _optionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.glassLine),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: AppColors.muted, size: 14),
          ],
        ),
      ),
    );
  }
}

Widget _photoSlot({
  required String label,
  required bool filled,
  required Uint8List? imageBytes,
  String? imageUrl,
  String? badgeText,
  String? subtitle,
  bool isReadOnly = false,
  required VoidCallback onTap,
}) {
  final hasImage =
      imageBytes != null || (imageUrl != null && imageUrl.isNotEmpty);

  return GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      height: 110,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(
          color: filled
              ? (isReadOnly
                  ? AppColors.cyan.withValues(alpha: 0.6)
                  : AppColors.neonGreen.withValues(alpha: 0.6))
              : AppColors.glassLine,
          width: 1.4,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: filled
            ? [
                BoxShadow(
                  color: (isReadOnly ? AppColors.cyan : AppColors.neonGreen)
                      .withValues(alpha: 0.12),
                  blurRadius: 10,
                )
              ]
            : null,
      ),
      child: hasImage
          ? ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (imageBytes != null)
                    Image.memory(
                      imageBytes,
                      fit: BoxFit.cover,
                    )
                  else if (imageUrl != null && imageUrl.isNotEmpty)
                    Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppColors.midnight,
                        child: const Center(
                          child: Icon(Icons.handyman_rounded,
                              color: AppColors.cyan, size: 30),
                        ),
                      ),
                    ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.75),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color:
                            isReadOnly ? AppColors.cyan : AppColors.neonGreen,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isReadOnly
                                ? Icons.verified_rounded
                                : Icons.check_circle_rounded,
                            size: 12,
                            color: AppColors.midnight,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            badgeText ?? (isReadOnly ? 'Listing ✓' : 'Ready'),
                            style: const TextStyle(
                              color: AppColors.midnight,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 6,
                    left: 8,
                    right: 8,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(
                          isReadOnly
                              ? Icons.visibility_rounded
                              : Icons.sync_rounded,
                          color: Colors.white70,
                          size: 14,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: filled
                        ? AppColors.neonGreen.withValues(alpha: 0.15)
                        : AppColors.cyan.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    filled
                        ? Icons.check_circle_rounded
                        : Icons.add_a_photo_rounded,
                    size: 20,
                    color: filled ? AppColors.neonGreen : AppColors.cyan,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: filled ? FontWeight.w700 : FontWeight.w600,
                    color: filled ? AppColors.neonGreen : AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle ?? (filled ? 'Tap to change' : 'Camera or upload'),
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
    ),
  );
}

Widget _agreementRow(String k, String v) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(k,
            style: const TextStyle(fontSize: 13, color: AppColors.muted)),
        const SizedBox(width: 8),
        Flexible(
          child: Text(v,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink)),
        ),
      ],
    ),
  );
}

Widget neonStatusPill(BookingStatus status) {
  final (text, color) = switch (status) {
    BookingStatus.pending => ('Awaiting pickup', AppColors.amber),
    BookingStatus.active => ('Active loan', AppColors.neonGreen),
    BookingStatus.done => ('Completed', AppColors.muted),
    BookingStatus.cancelled => ('Cancelled', AppColors.red),
  };
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.08)],
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.4)),
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: 0.2),
          blurRadius: 8,
        )
      ],
    ),
    child: Text(text,
        style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.w700)),
  );
}

// ---------------------------------------------------------------------------
// MY ITEMS SCREEN
// ---------------------------------------------------------------------------

class MyItemsScreen extends StatefulWidget {
  const MyItemsScreen({super.key});
  @override
  State<MyItemsScreen> createState() => _MyItemsScreenState();
}

class _MyItemsScreenState extends State<MyItemsScreen>
    with SingleTickerProviderStateMixin {
  bool borrowingTab = true;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const ToolVerseLogo(
                              size: 34, circular: true, withGlow: true),
                          const SizedBox(width: 12),
                          ShaderMask(
                            shaderCallback: (bounds) =>
                                AppGradients.brandGradient.createShader(bounds),
                            child: Text(
                              'My borrows & lends',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const NotificationBellButton(),
                    ],
                  ),
                ),
                // Segment tabs
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.glassLine),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _neonSegTab(
                            'Borrowing',
                            borrowingTab,
                            () => setState(() => borrowingTab = true),
                          ),
                        ),
                        Expanded(
                          child: _neonSegTab(
                            'Lending',
                            !borrowingTab,
                            () => setState(() => borrowingTab = false),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: borrowingTab
                      ? _buildBorrowing(state)
                      : _buildLending(state),
                ),
              ],
            );
      },
    );
  }

  Widget _buildBorrowing(AppState state) {
    final uid = authService.currentUserId ?? '';
    final myEmail = (state.user?.email.isNotEmpty == true
            ? state.user!.email
            : (authService.currentUser?.email ?? ''))
        .trim()
        .toLowerCase();

    final borrows = state.bookings.where((b) {
      if (b.borrowerId.isNotEmpty && uid.isNotEmpty && b.borrowerId == uid) {
        return true;
      }
      if (myEmail.isNotEmpty &&
          b.borrowerEmail.trim().toLowerCase() == myEmail) {
        return true;
      }
      return false;
    }).toList();

    if (borrows.isEmpty) {
      return const NeonEmptyState(
        text:
            'You have not borrowed anything yet. Browse Home and tap "Request to borrow" on an item.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 90),
      itemCount: borrows.length,
      itemBuilder: (context, i) {
        final b = borrows[i];
        final lenderEmail = b.lenderEmail.isNotEmpty
            ? b.lenderEmail
            : (b.item.owner.contains('@') ? b.item.owner : '');
        final lenderLabel = b.item.owner.isNotEmpty
            ? (lenderEmail.isNotEmpty && b.item.owner != lenderEmail
                ? '${b.item.owner} ($lenderEmail)'
                : b.item.owner)
            : (lenderEmail.isNotEmpty ? lenderEmail : 'Owner');
        return _bookingTileWithActions(
          context,
          state,
          booking: b,
          isLender: false,
          subtitle: 'from $lenderLabel · ${_fmt(b.from)} → ${_fmt(b.to)}',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => BookingScreen(booking: b)),
          ),
        );
      },
    );
  }

  Widget _buildLending(AppState state) {
    final uid = authService.currentUserId ?? '';
    final myEmail = (state.user?.email.isNotEmpty == true
            ? state.user!.email
            : (authService.currentUser?.email ?? ''))
        .trim()
        .toLowerCase();

    final lends = state.bookings.where((b) {
      // Exclude if current user is the borrower
      if (b.borrowerId.isNotEmpty && uid.isNotEmpty && b.borrowerId == uid) {
        return false;
      }
      if (myEmail.isNotEmpty &&
          b.borrowerEmail.trim().toLowerCase() == myEmail) {
        return false;
      }

      if (b.lenderId.isNotEmpty && uid.isNotEmpty && b.lenderId == uid) {
        return true;
      }
      if (b.item.ownerId.isNotEmpty &&
          uid.isNotEmpty &&
          b.item.ownerId == uid) {
        return true;
      }
      if (myEmail.isNotEmpty &&
          (b.lenderEmail.trim().toLowerCase() == myEmail ||
              b.item.owner.trim().toLowerCase() == myEmail ||
              b.lenderId.trim().toLowerCase() == myEmail)) {
        return true;
      }
      if (state.items.any((i) => i.id == b.item.id && i.ownerId == uid)) {
        return true;
      }
      return false;
    }).toList();

    final mine = state.items.where((i) {
      if (i.ownerId.isNotEmpty && uid.isNotEmpty) return i.ownerId == uid;
      if (myEmail.isNotEmpty && i.owner.trim().toLowerCase() == myEmail) return true;
      return false;
    }).toList();

    if (lends.isEmpty && mine.isEmpty) {
      return const NeonEmptyState(
        text:
            'You have not listed anything yet. Tap + on Home to list your first item.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 90),
      children: [
        if (lends.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(bottom: 10, top: 4),
            child: Text(
              'Borrow Requests & Active Loans',
              style: TextStyle(
                color: AppColors.cyan,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          ...lends.map((b) => _bookingTileWithActions(
                context,
                state,
                booking: b,
                isLender: true,
                subtitle:
                    'Borrower: ${b.borrowerName.isNotEmpty ? (b.borrowerEmail.isNotEmpty && b.borrowerName != b.borrowerEmail ? "${b.borrowerName} (${b.borrowerEmail})" : b.borrowerName) : (b.borrowerEmail.isNotEmpty ? b.borrowerEmail : "Borrower")} (${_fmt(b.from)} → ${_fmt(b.to)})${b.note.isNotEmpty ? " · \"${b.note}\"" : ""}',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => BookingScreen(booking: b)),
                ),
              )),
          const SizedBox(height: 16),
        ],
        if (mine.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 10, top: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'My Listed Items',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  '${mine.length} item${mine.length == 1 ? "" : "s"}',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          ...mine.map((it) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.cardElevated, AppColors.card],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.glassLine),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: it.category.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: it.category.color.withValues(alpha: 0.2)),
                      ),
                      child: Icon(it.category.icon,
                          size: 18, color: it.category.color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(it.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: AppColors.ink,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14)),
                          Text('${it.category.label} · ₹${it.deposit} deposit',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.muted)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.neonGreen.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppColors.neonGreen.withValues(alpha: 0.3)),
                      ),
                      child: const Text(
                        'Listed',
                        style: TextStyle(
                          color: AppColors.neonGreen,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Delete item button
                    GestureDetector(
                      onTap: () => _confirmDeleteItem(context, state, it),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.red.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppColors.red.withValues(alpha: 0.3)),
                        ),
                        child: const Icon(Icons.delete_outline_rounded,
                            size: 16, color: AppColors.red),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ],
    );
  }

  void _confirmDeleteItem(BuildContext context, AppState state, Item item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.glassLine),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_forever_rounded,
                  color: AppColors.red, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Delete Listed Item?',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Remove "${item.name}" from your listings? This cannot be undone.',
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 13.5,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.muted)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await state.deleteItem(item.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('"${item.name}" removed from listings.'),
                      backgroundColor: AppColors.cardElevated,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ValidationFeedback.showWarning(
                    context,
                    'Failed to delete item: ${e.toString().replaceAll("Exception: ", "")}',
                    isError: true,
                  );
                }
              }
            },
            icon: const Icon(Icons.delete_forever_rounded, size: 16),
            label: const Text('Delete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime? d) =>
      d == null ? '—' : '${d.day}/${d.month}/${d.year}';
}


/// Booking tile with inline Cancel / Delete / Accept action buttons.
Widget _bookingTileWithActions(
  BuildContext context,
  AppState state, {
  required Booking booking,
  required String subtitle,
  required VoidCallback onTap,
  bool isLender = false,
}) {
  final canAccept = isLender && booking.status == BookingStatus.pending;
  final canCancel = !isLender && booking.status == BookingStatus.pending;
  final canDelete = booking.status == BookingStatus.cancelled ||
      booking.status == BookingStatus.done;

  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [AppColors.cardElevated, AppColors.card],
      ),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.glassLine),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.2),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      children: [
        // Main row (tappable)
        GestureDetector(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: booking.item.category.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: booking.item.category.color.withValues(alpha: 0.25)),
                  ),
                  child: Icon(booking.item.category.icon,
                      size: 18, color: booking.item.category.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(booking.item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w600,
                              fontSize: 14)),
                      Text(subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.muted)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                neonStatusPill(booking.status),
              ],
            ),
          ),
        ),
        // Action buttons row (only shown when relevant)
        if (canAccept || canCancel || canDelete) ...[
          Container(
            height: 1,
            color: AppColors.glassLine,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                const Spacer(),
                // Lender: Accept pending booking
                if (canAccept) ...[
                  GestureDetector(
                    onTap: () => _confirmAcceptBooking(context, state, booking),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppColors.neonGreen.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.neonGreen.withValues(alpha: 0.5)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_outline_rounded,
                              size: 14, color: AppColors.neonGreen),
                          SizedBox(width: 5),
                          Text(
                            'Accept Booking',
                            style: TextStyle(
                              color: AppColors.neonGreen,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                // Borrower: Cancel pending booking
                if (canCancel) ...[
                  GestureDetector(
                    onTap: () => _confirmCancelBooking(context, state, booking),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppColors.amber.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.amber.withValues(alpha: 0.4)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.cancel_outlined,
                              size: 14, color: AppColors.amber),
                          SizedBox(width: 5),
                          Text(
                            'Cancel Request',
                            style: TextStyle(
                              color: AppColors.amber,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if ((canAccept || canCancel) && canDelete) const SizedBox(width: 8),
                if (canDelete) ...[
                  GestureDetector(
                    onTap: () => _confirmDeleteBooking(context, state, booking),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppColors.red.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.red.withValues(alpha: 0.4)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.delete_outline_rounded,
                              size: 14, color: AppColors.red),
                          SizedBox(width: 5),
                          Text(
                            'Delete',
                            style: TextStyle(
                              color: AppColors.red,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    ),
  );
}

void _confirmAcceptBooking(
    BuildContext context, AppState state, Booking booking) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.glassLine),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.neonGreen.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.check_circle_outline_rounded,
                color: AppColors.neonGreen, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Accept Booking?',
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      content: Text(
        'Accept the borrow request for "${booking.item.name}"? This will mark the booking as active.',
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 13.5,
          height: 1.4,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Not yet',
              style: TextStyle(color: AppColors.muted)),
        ),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.of(ctx).pop();
            state.acceptBooking(booking);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      'Booking for "${booking.item.name}" accepted! ✅'),
                  backgroundColor: AppColors.cardElevated,
                ),
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.neonGreen.withValues(alpha: 0.2),
            foregroundColor: AppColors.neonGreen,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: AppColors.neonGreen.withValues(alpha: 0.5)),
            ),
            elevation: 0,
          ),
          icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
          label: const Text('Accept',
              style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
}

void _confirmCancelBooking(
    BuildContext context, AppState state, Booking booking) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.glassLine),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.cancel_outlined,
                color: AppColors.amber, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Cancel Request?',
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      content: Text(
        'Cancel your borrow request for "${booking.item.name}"? The status will be updated to cancelled.',
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 13.5,
          height: 1.4,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Keep it',
              style: TextStyle(color: AppColors.muted)),
        ),
        ElevatedButton.icon(
          onPressed: () async {
            Navigator.of(ctx).pop();
            try {
              await state.cancelBooking(booking.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Booking request cancelled.'),
                    backgroundColor: AppColors.cardElevated,
                  ),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ValidationFeedback.showWarning(
                  context,
                  'Failed to cancel booking: $e',
                  isError: true,
                );
              }
            }
          },
          icon: const Icon(Icons.cancel_outlined, size: 16),
          label: const Text('Cancel Request'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.amber,
            foregroundColor: AppColors.midnight,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    ),
  );
}

void _confirmDeleteBooking(
    BuildContext context, AppState state, Booking booking) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.glassLine),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.red.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.delete_forever_rounded,
                color: AppColors.red, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Delete Booking Record?',
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      content: Text(
        'Permanently delete this booking record for "${booking.item.name}"? Chat history will also be removed.',
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 13.5,
          height: 1.4,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel',
              style: TextStyle(color: AppColors.muted)),
        ),
        ElevatedButton.icon(
          onPressed: () async {
            Navigator.of(ctx).pop();
            try {
              await state.deleteBooking(booking.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Booking record deleted.'),
                    backgroundColor: AppColors.cardElevated,
                  ),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ValidationFeedback.showWarning(
                  context,
                  'Failed to delete booking: $e',
                  isError: true,
                );
              }
            }
          },
          icon: const Icon(Icons.delete_forever_rounded, size: 16),
          label: const Text('Delete'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.red,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _neonSegTab(String label, bool active, VoidCallback onTap) {
  return GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      height: 44,
      alignment: Alignment.center,
      decoration: active
          ? BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.cyan, AppColors.violet],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.cyan.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                )
              ],
            )
          : null,
      child: Text(
        label,
        style: TextStyle(
          color: active ? AppColors.midnight : AppColors.muted,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// PROFILE SCREEN
// ---------------------------------------------------------------------------

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final user = state.user;
    if (user == null) return const SizedBox.shrink();

    final listedCount = state.items.where((i) =>
        i.owner == user.name ||
        i.owner.toLowerCase() == 'you' ||
        (i.ownerId.isNotEmpty && i.ownerId == (authService.currentUserId ?? ''))).length;
    final activeLoans = state.bookings.where((b) => b.status == BookingStatus.active).length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isWide = width >= 640;
        final maxWidth = 1180.0;
        final hPadding = width > maxWidth
            ? (width - maxWidth) / 2
            : (isWide ? 24.0 : 12.0);

        final featureTiles = [
          _compactProfileTile(
            context,
            icon: Icons.edit_note_rounded,
            label: 'Profile details & photo',
            subtitle: 'Name, photo, contact info',
            color: AppColors.cyan,
            onTap: () => _showEditProfileDialog(context, state, user),
          ),
          _compactProfileTile(
            context,
            icon: Icons.place_outlined,
            label: 'Neighborhood & location',
            subtitle: user.formattedAddress.isNotEmpty
                ? user.formattedAddress
                : (user.society.isNotEmpty ? user.society : 'Choose on map'),
            color: AppColors.violet,
            onTap: () => _showNeighborhoodPicker(context, state, user),
          ),
          _compactProfileTile(
            context,
            icon: Icons.inventory_2_outlined,
            label: 'My listed items',
            subtitle: '$listedCount item${listedCount == 1 ? '' : 's'} shared',
            color: AppColors.amber,
            onTap: () => _showMyListedItemsSheet(context, state, user),
          ),
          _compactProfileTile(
            context,
            icon: Icons.notifications_outlined,
            label: 'Notifications',
            subtitle: state.unreadNotificationsCount > 0
                ? '${state.unreadNotificationsCount} new'
                : 'On · Live updates',
            color: state.unreadNotificationsCount > 0
                ? AppColors.red
                : AppColors.neonGreen,
            onTap: () => openNotificationCenter(context),
          ),
        ];

        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Full-width header ──────────────────────────────────────────
            SliverToBoxAdapter(
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(hPadding, 18, hPadding, 14),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0A0F22), Color(0xFF14073D)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  children: [
                    // Brand label
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        ToolVerseLogo(size: 18, circular: true),
                        SizedBox(width: 6),
                        Text('ToolVerse Profile',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.muted)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Avatar + info side-by-side
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Avatar
                        AnimatedGlowContainer(
                          glowColor: AppColors.cyan,
                          blurRadius: 20,
                          child: Container(
                            padding: const EdgeInsets.all(2.5),
                            decoration: BoxDecoration(
                              gradient: AppGradients.brandGradient,
                              shape: BoxShape.circle,
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(2.5),
                              decoration: const BoxDecoration(
                                color: AppColors.midnight,
                                shape: BoxShape.circle,
                              ),
                              child: Stack(
                                children: [
                                  Container(
                                    width: 62,
                                    height: 62,
                                    clipBehavior: Clip.antiAlias,
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [AppColors.amber, AppColors.violet],
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    alignment: Alignment.center,
                                    child: user.profilePic.isNotEmpty
                                        ? Image.network(
                                            user.profilePic,
                                            width: 62,
                                            height: 62,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Text(
                                              initials(user.name),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 22,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          )
                                        : Text(
                                            initials(user.name),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 22,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: GestureDetector(
                                      onTap: () => _showEditProfileDialog(context, state, user),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: AppColors.cyan,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: AppColors.midnight, width: 2),
                                        ),
                                        child: const Icon(Icons.edit_rounded, size: 10, color: AppColors.midnight),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Name + contact info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.name,
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppColors.ink,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              if (user.formattedAddress.isNotEmpty || user.society.isNotEmpty)
                                Row(children: [
                                  const Icon(Icons.place_rounded, size: 11, color: AppColors.muted),
                                  const SizedBox(width: 3),
                                  Expanded(
                                    child: Text(
                                      user.society.isNotEmpty ? user.society : user.formattedAddress,
                                      style: const TextStyle(color: AppColors.muted, fontSize: 11),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ]),
                              if (user.email.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Row(children: [
                                  const Icon(Icons.email_outlined, size: 11, color: AppColors.muted),
                                  const SizedBox(width: 3),
                                  Expanded(
                                    child: Text(user.email,
                                        style: const TextStyle(color: AppColors.muted, fontSize: 11),
                                        maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ),
                                ]),
                              ],
                              if (user.phone.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Row(children: [
                                  const Icon(Icons.phone_outlined, size: 11, color: AppColors.muted),
                                  const SizedBox(width: 3),
                                  Text(user.phone,
                                      style: const TextStyle(color: AppColors.muted, fontSize: 11)),
                                ]),
                              ],
                            ],
                          ),
                        ),
                        // Edit button
                        GestureDetector(
                          onTap: () => _showEditProfileDialog(context, state, user),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [
                                AppColors.cyan.withValues(alpha: 0.2),
                                AppColors.violet.withValues(alpha: 0.15),
                              ]),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.cyan.withValues(alpha: 0.45)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit_rounded, size: 13, color: AppColors.cyan),
                                SizedBox(width: 5),
                                Text('Edit',
                                    style: TextStyle(
                                        color: AppColors.cyan,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // ── Stats row inside header ─────────────────────────────
                    Row(
                      children: [
                        Expanded(child: _compactStatCard(
                          icon: Icons.inventory_2_rounded,
                          label: 'Items Listed',
                          value: '$listedCount',
                          color: AppColors.violet,
                        )),
                        const SizedBox(width: 14),
                        Expanded(child: _compactStatCard(
                          icon: Icons.repeat_rounded,
                          label: 'Active Loans',
                          value: '$activeLoans',
                          color: AppColors.cyan,
                        )),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Feature tiles ───────────────────────────────────────────────
            SliverPadding(
              padding: EdgeInsets.fromLTRB(hPadding, 14, hPadding, 0),
              sliver: isWide
                  ? SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 12,
                        mainAxisExtent: 74,
                      ),
                      delegate: SliverChildListDelegate(featureTiles),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: featureTiles[i],
                        ),
                        childCount: featureTiles.length,
                      ),
                    ),
            ),

            // ── Actions: Log out & Danger Zone ─────────────────────────────
            SliverPadding(
              padding: EdgeInsets.fromLTRB(hPadding, 14, hPadding, 90),
              sliver: SliverToBoxAdapter(
                child: isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildProfileLogoutCard(context, state)),
                          const SizedBox(width: 14),
                          Expanded(child: _buildProfileDangerZoneCard(context, state)),
                        ],
                      )
                    : Column(
                        children: [
                          _buildProfileLogoutCard(context, state),
                          const SizedBox(height: 12),
                          _buildProfileDangerZoneCard(context, state),
                        ],
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProfileLogoutCard(BuildContext context, AppState state) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.red.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.red.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.logout_rounded, size: 15, color: AppColors.red),
              ),
              const SizedBox(width: 8),
              const Text(
                'Log out',
                style: TextStyle(
                  color: AppColors.red,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Safely sign out from this device. You can sign back in anytime.',
            style: TextStyle(color: AppColors.muted, fontSize: 11.5, height: 1.35),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: () {
                state.logout();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const SplashScreen()),
                  (r) => false,
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    AppColors.red.withValues(alpha: 0.18),
                    AppColors.red.withValues(alpha: 0.08),
                  ]),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.red.withValues(alpha: 0.45)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout_rounded, size: 15, color: AppColors.red),
                    SizedBox(width: 7),
                    Text(
                      'Log out',
                      style: TextStyle(
                        color: AppColors.red,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileDangerZoneCard(BuildContext context, AppState state) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.red.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.red.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.warning_amber_rounded, size: 15, color: AppColors.red),
              ),
              const SizedBox(width: 8),
              const Text(
                'Danger Zone',
                style: TextStyle(
                  color: AppColors.red,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Permanently delete your account, items, bookings, and chats.',
            style: TextStyle(color: AppColors.muted, fontSize: 11.5, height: 1.35),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: () => _showDeleteAccountDialog(context, state),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    AppColors.red.withValues(alpha: 0.22),
                    AppColors.red.withValues(alpha: 0.12),
                  ]),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.red.withValues(alpha: 0.5)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.delete_forever_rounded, size: 15, color: AppColors.red),
                    SizedBox(width: 7),
                    Text(
                      'Delete My Account',
                      style: TextStyle(
                        color: AppColors.red,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact horizontal stat card used in the profile header.
Widget _compactStatCard({
  required IconData icon,
  required String label,
  required String value,
  required Color color,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: [
        color.withValues(alpha: 0.14),
        color.withValues(alpha: 0.05),
      ]),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withValues(alpha: 0.28)),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800, color: color, letterSpacing: -0.3)),
              const SizedBox(height: 2),
              Text(label,
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.muted),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Compact feature tile for profile screen.
Widget _compactProfileTile(
  BuildContext context, {
  required IconData icon,
  required String label,
  required String subtitle,
  required Color color,
  VoidCallback? onTap,
}) {
  return MouseRegion(
    cursor: onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
    child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AppColors.cardElevated, AppColors.card]),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.glassLine),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withValues(alpha: 0.28)),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.muted),
          ],
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// SHARED HELPERS / WIDGETS
// ---------------------------------------------------------------------------

InputDecoration neonFieldDecoration({
  String? hint,
  String? errorText,
  Widget? prefixIcon,
  Widget? suffixIcon,
  EdgeInsetsGeometry? contentPadding,
  String? counterText,
  Color accentColor = AppColors.cyan,
}) {
  return InputDecoration(
    hintText: hint,
    errorText: errorText,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    counterText: counterText,
    hintStyle: const TextStyle(color: AppColors.muted),
    errorStyle: const TextStyle(
      color: AppColors.red,
      fontSize: 12,
      fontWeight: FontWeight.w500,
    ),
    filled: true,
    fillColor: AppColors.surface,
    contentPadding: contentPadding ??
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: AppColors.glassLine),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: AppColors.glassLine),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: accentColor, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.red, width: 1.2),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.red, width: 1.5),
    ),
  );
}

// Keep old fieldDecoration as alias
InputDecoration fieldDecoration({
  String? hint,
  String? errorText,
  Widget? prefixIcon,
  Widget? suffixIcon,
  EdgeInsetsGeometry? contentPadding,
  String? counterText,
}) =>
    neonFieldDecoration(
      hint: hint,
      errorText: errorText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      contentPadding: contentPadding,
      counterText: counterText,
    );

ButtonStyle primaryButtonStyle() {
  return FilledButton.styleFrom(
    backgroundColor: AppColors.cyan,
    foregroundColor: AppColors.midnight,
    disabledBackgroundColor: AppColors.surface,
    disabledForegroundColor: AppColors.muted,
    padding: const EdgeInsets.symmetric(vertical: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
  );
}

Widget neonLabeled(String label, Widget field) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.muted,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        field,
      ],
    ),
  );
}

// keep old labeled as alias
Widget labeled(String label, Widget field) => neonLabeled(label, field);

Widget _neonDateField(String text, VoidCallback onTap) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassLine),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(text,
              style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.ink)),
          const Icon(Icons.calendar_month_rounded,
              size: 18, color: AppColors.cyan),
        ],
      ),
    ),
  );
}

Widget dateField(String text, VoidCallback onTap) => _neonDateField(text, onTap);

Widget _gradientBtn({
  required String label,
  required VoidCallback onTap,
  LinearGradient? gradient,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: gradient ?? AppGradients.brandGradient,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: (gradient?.colors.first ?? AppColors.cyan)
                .withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 15.5,
          letterSpacing: 0.2,
        ),
      ),
    ),
  );
}

Widget _loadingBtn() {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 15),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          AppColors.cyan.withValues(alpha: 0.4),
          AppColors.violet.withValues(alpha: 0.4),
        ],
      ),
      borderRadius: BorderRadius.circular(14),
    ),
    child: const SizedBox(
      width: 22,
      height: 22,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
      ),
    ),
  );
}

Widget _googleSignInBtn({required VoidCallback onTap, bool loading = false}) {
  return GestureDetector(
    onTap: loading ? null : onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: loading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.black87),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.network(
                  'https://lh3.googleusercontent.com/COxitqgJr1sJnIDe8-jiKhxDx1FrYbtRHKJ9zOIoTQ74UUKFLnvEvdfioImJbi-FXw',
                  width: 22,
                  height: 22,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.account_circle,
                    size: 22,
                    color: Color(0xFF4285F4),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Sign in with Google',
                  style: TextStyle(
                    color: Color(0xFF1F1F1F),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
    ),
  );
}

Widget _glassBackBtn(BuildContext context, {bool light = false}) {
  return GestureDetector(
    onTap: () => Navigator.of(context).maybePop(),
    child: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [AppColors.cardElevated, AppColors.card],
        ),
        border: Border.all(color: AppColors.glassLine),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Icon(Icons.arrow_back_rounded,
          size: 20, color: AppColors.ink),
    ),
  );
}

PreferredSizeWidget _neonAppBar(
  BuildContext context, {
  required String title,
  Widget? leading,
  List<Widget>? actions,
}) {
  return AppBar(
    backgroundColor: AppColors.midnight,
    foregroundColor: AppColors.ink,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: false,
    automaticallyImplyLeading: false,
    leading: leading != null
        ? Padding(padding: const EdgeInsets.all(10), child: leading)
        : null,
    title: Row(
      children: [
        const ToolVerseLogo(size: 26, circular: true),
        const SizedBox(width: 10),
        ShaderMask(
          shaderCallback: (bounds) =>
              AppGradients.brandGradient.createShader(bounds),
          child: Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ],
    ),
    actions: actions,
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(1),
      child: Container(
        height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.transparent,
              AppColors.cyan.withValues(alpha: 0.3),
              AppColors.violet.withValues(alpha: 0.3),
              Colors.transparent,
            ],
          ),
        ),
      ),
    ),
  );
}

Widget backButton(BuildContext context, {bool light = false}) =>
    _glassBackBtn(context, light: light);

Widget backIcon(BuildContext context) {
  return IconButton(
    icon: const Icon(Icons.arrow_back_rounded),
    onPressed: () => Navigator.of(context).maybePop(),
  );
}

// ---------------------------------------------------------------------------
// EMPTY STATE
// ---------------------------------------------------------------------------

class NeonEmptyState extends StatelessWidget {
  final String text;
  const NeonEmptyState({super.key, required this.text});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0x1500D4FF),
                    Color(0x158B5CF6),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search_off_rounded,
                  size: 44, color: AppColors.muted),
            ),
            const SizedBox(height: 18),
            Text(text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.muted, fontSize: 13.5, height: 1.5)),
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String text;
  const EmptyState({super.key, required this.text});
  @override
  Widget build(BuildContext context) => NeonEmptyState(text: text);
}

String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  final letters = parts.take(2).map((p) => p.isNotEmpty ? p[0] : '').join();
  return letters.toUpperCase();
}

void _showDeleteAccountDialog(BuildContext context, AppState state) {
  bool isDeleting = false;
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.red.withValues(alpha: 0.5)),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_forever_rounded,
                  color: AppColors.red, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Delete Account?',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppColors.red.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  _accountDeleteRow('All your listed items'),
                  _accountDeleteRow('All borrow & loan history'),
                  _accountDeleteRow('All chat messages'),
                  _accountDeleteRow('All notifications'),
                  _accountDeleteRow('Your account & profile data'),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'This action is permanent and cannot be reversed.',
              style: TextStyle(
                color: AppColors.red,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed:
                isDeleting ? null : () => Navigator.of(ctx).pop(),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.muted)),
          ),
          ElevatedButton.icon(
            onPressed: isDeleting
                ? null
                : () async {
                    setDialogState(() => isDeleting = true);
                    try {
                      await state.deleteAccount();
                      if (ctx.mounted) Navigator.of(ctx).pop();
                      if (context.mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                              builder: (_) => const SplashScreen()),
                          (r) => false,
                        );
                      }
                    } catch (e) {
                      setDialogState(() => isDeleting = false);
                      if (ctx.mounted) Navigator.of(ctx).pop();
                      if (context.mounted) {
                        ValidationFeedback.showWarning(
                          context,
                          'Account deletion failed: $e',
                          isError: true,
                        );
                      }
                    }
                  },
            icon: isDeleting
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.delete_forever_rounded, size: 16),
            label:
                Text(isDeleting ? 'Deleting…' : 'Yes, Delete Everything'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _accountDeleteRow(String text) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        const Icon(Icons.remove_circle_outline_rounded,
            size: 14, color: AppColors.red),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 12.5,
          ),
        ),
      ],
    ),
  );
}

void _showEditProfileDialog(BuildContext context, AppState state, AppUser user) {
  final nameCtrl = TextEditingController(text: user.name);
  final societyCtrl = TextEditingController(text: user.society);
  final emailCtrl = TextEditingController(text: user.email);
  final phoneCtrl = TextEditingController(text: user.phone);
  String previewPic = user.profilePic;

  double? selectedLat = user.latitude;
  double? selectedLng = user.longitude;
  String selectedAddress = user.formattedAddress;

  // Selected image from computer
  Uint8List? selectedImageBytes;
  String? selectedImageName;
  int? selectedImageSize;
  String? imageError;
  bool isSaving = false;

  final sampleAvatars = [
    'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200&fit=crop&q=80',
    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&fit=crop&q=80',
    'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=200&fit=crop&q=80',
    'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=200&fit=crop&q=80',
  ];

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModalState) {
        Future<void> pickProfileImage() async {
          try {
            final XFile? file =
                await ImagePicker().pickImage(source: ImageSource.gallery);
            if (file == null) return;

            final bytes = await file.readAsBytes();
            final name = file.name;

            final validation = StorageService.validateImage(
              bytes: bytes,
              fileName: name,
            );

            if (!validation.isValid) {
              setModalState(() {
                imageError = validation.errorMessage;
              });
              if (ctx.mounted) {
                ValidationFeedback.showWarning(
                  ctx,
                  validation.errorMessage ?? 'Invalid image file.',
                  isError: true,
                );
              }
              return;
            }

            setModalState(() {
              selectedImageBytes = bytes;
              selectedImageName = name;
              selectedImageSize = bytes.lengthInBytes;
              imageError = null;
            });
          } catch (e) {
            if (ctx.mounted) {
              ValidationFeedback.showWarning(
                ctx,
                'Could not access file manager: $e',
                isError: true,
              );
            }
          }
        }

        return Container(
          decoration: const BoxDecoration(
            color: AppColors.cardElevated,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: AppColors.glassLine)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.glassLine,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.edit_rounded,
                        color: AppColors.cyan, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Edit Profile',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: AppColors.muted),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Avatar preview & Picker
                Center(
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          Container(
                            width: 86,
                            height: 86,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              gradient: AppGradients.brandGradient,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: AppColors.cyan, width: 2.5),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      AppColors.cyan.withValues(alpha: 0.25),
                                  blurRadius: 18,
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: selectedImageBytes != null
                                ? Image.memory(
                                    selectedImageBytes!,
                                    width: 86,
                                    height: 86,
                                    fit: BoxFit.cover,
                                  )
                                : (previewPic.isNotEmpty
                                    ? Image.network(
                                        previewPic,
                                        width: 86,
                                        height: 86,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(
                                          Icons.person_rounded,
                                          size: 44,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        initials(nameCtrl.text.isNotEmpty
                                            ? nameCtrl.text
                                            : 'U'),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 30,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      )),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Tooltip(
                              message: 'Choose photo from computer',
                              child: InkWell(
                                onTap: pickProfileImage,
                                customBorder: const CircleBorder(),
                                child: Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: AppColors.cyan,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: AppColors.midnight, width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.cyan
                                            .withValues(alpha: 0.4),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt_rounded,
                                    size: 15,
                                    color: AppColors.midnight,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (selectedImageBytes != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: AppColors.neonGreen
                                    .withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle_rounded,
                                  color: AppColors.neonGreen, size: 14),
                              const SizedBox(width: 6),
                              ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 160),
                                child: Text(
                                  '${selectedImageName ?? "photo"} (${((selectedImageSize ?? 0) / (1024 * 1024)).toStringAsFixed(1)} MB)',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.ink,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              InkWell(
                                onTap: pickProfileImage,
                                child: const Text(
                                  'Replace',
                                  style: TextStyle(
                                    color: AppColors.cyan,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () {
                                  setModalState(() {
                                    selectedImageBytes = null;
                                    selectedImageName = null;
                                    selectedImageSize = null;
                                  });
                                },
                                child: const Icon(Icons.close_rounded,
                                    size: 14, color: AppColors.red),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        OutlinedButton.icon(
                          onPressed: pickProfileImage,
                          icon: const Icon(Icons.upload_file_rounded,
                              size: 16, color: AppColors.cyan),
                          label: const Text(
                            'Upload Photo from Computer',
                            style: TextStyle(
                              color: AppColors.cyan,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                                color:
                                    AppColors.cyan.withValues(alpha: 0.4)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ],
                      if (imageError != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          imageError!,
                          style: const TextStyle(
                              color: AppColors.red, fontSize: 11.5),
                        ),
                      ],
                      const SizedBox(height: 12),
                      const Text(
                        'Or choose an avatar below',
                        style: TextStyle(
                            color: AppColors.muted, fontSize: 11.5),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: sampleAvatars.map((url) {
                          final isSelected = previewPic == url &&
                              selectedImageBytes == null;
                          return GestureDetector(
                            onTap: () {
                              setModalState(() {
                                selectedImageBytes = null;
                                selectedImageName = null;
                                selectedImageSize = null;
                                previewPic = url;
                              });
                            },
                            child: Container(
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 5),
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.cyan
                                      : AppColors.glassLine,
                                  width: isSelected ? 2.5 : 1,
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Image.network(url, fit: BoxFit.cover),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                neonLabeled(
                  'Full name',
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: AppColors.ink),
                    decoration: neonFieldDecoration(
                      hint: 'Your name',
                      prefixIcon: const Icon(Icons.person_outline_rounded,
                          color: AppColors.cyan, size: 18),
                    ),
                  ),
                ),
                neonLabeled(
                  'Email address',
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: AppColors.ink),
                    decoration: neonFieldDecoration(
                      hint: 'e.g. name@example.com',
                      prefixIcon: const Icon(Icons.email_outlined,
                          color: AppColors.cyan, size: 18),
                    ),
                  ),
                ),
                neonLabeled(
                  'Phone number',
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: AppColors.ink),
                    decoration: neonFieldDecoration(
                      hint: 'e.g. +91 9876543210',
                      prefixIcon: const Icon(Icons.phone_outlined,
                          color: AppColors.cyan, size: 18),
                    ),
                  ),
                ),
                neonLabeled(
                  'Neighborhood Location (Map Pin)',
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (selectedLat != null && selectedLng != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.cyan.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.cyan.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.pin_drop_rounded,
                                  color: AppColors.cyan,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      selectedAddress.isNotEmpty
                                          ? selectedAddress
                                          : (societyCtrl.text.isNotEmpty
                                              ? societyCtrl.text
                                              : 'Pinned Map Location'),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppColors.ink,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Lat: ${selectedLat!.toStringAsFixed(4)}, Lng: ${selectedLng!.toStringAsFixed(4)}',
                                      style: const TextStyle(
                                        color: AppColors.muted,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () async {
                                  try {
                                    final res = await MapLocationPicker.show(
                                      context,
                                      initialLatitude: selectedLat,
                                      initialLongitude: selectedLng,
                                      initialAddress: selectedAddress.isNotEmpty
                                          ? selectedAddress
                                          : societyCtrl.text,
                                    );
                                    if (res != null) {
                                      setModalState(() {
                                        selectedLat = res.latitude;
                                        selectedLng = res.longitude;
                                        selectedAddress = res.address;
                                        if (societyCtrl.text.isEmpty ||
                                            societyCtrl.text == user.society) {
                                          societyCtrl.text = res.address;
                                        }
                                      });
                                    }
                                  } catch (err) {
                                    if (ctx.mounted) {
                                      ValidationFeedback.showWarning(
                                        ctx,
                                        'Could not open map: $err',
                                        isError: true,
                                      );
                                    }
                                  }
                                },
                                icon: const Icon(
                                  Icons.edit_location_alt_rounded,
                                  size: 15,
                                  color: AppColors.cyan,
                                ),
                                label: const Text(
                                  'Change',
                                  style: TextStyle(
                                    color: AppColors.cyan,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () async {
                            try {
                              final res = await MapLocationPicker.show(
                                context,
                                initialLatitude: selectedLat,
                                initialLongitude: selectedLng,
                                initialAddress: selectedAddress.isNotEmpty
                                    ? selectedAddress
                                    : societyCtrl.text,
                              );
                              if (res != null) {
                                setModalState(() {
                                  selectedLat = res.latitude;
                                  selectedLng = res.longitude;
                                  selectedAddress = res.address;
                                  if (societyCtrl.text.isEmpty ||
                                      societyCtrl.text == user.society) {
                                    societyCtrl.text = res.address;
                                  }
                                });
                              }
                            } catch (err) {
                              if (ctx.mounted) {
                                ValidationFeedback.showWarning(
                                  ctx,
                                  'Could not open map: $err',
                                  isError: true,
                                );
                              }
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.glassLine),
                            ),
                            child: Row(
                              children: const [
                                Icon(Icons.add_location_alt_rounded,
                                    color: AppColors.violet, size: 20),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Choose Location on Map',
                                    style: TextStyle(
                                      color: AppColors.cyan,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ),
                                Icon(Icons.chevron_right_rounded,
                                    color: AppColors.muted, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                neonLabeled(
                  'Neighborhood / Society',
                  TextField(
                    controller: societyCtrl,
                    style: const TextStyle(color: AppColors.ink),
                    decoration: neonFieldDecoration(
                      hint: 'e.g. Palm Meadows, Block C',
                      prefixIcon: const Icon(Icons.apartment_rounded,
                          color: AppColors.violet, size: 18),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: isSaving
                      ? _loadingBtn()
                      : _gradientBtn(
                          label: 'Save Changes',
                          onTap: () async {
                            final newName = nameCtrl.text.trim();
                            final newSociety = societyCtrl.text.trim();
                            final newEmail = emailCtrl.text.trim();
                            final newPhone = phoneCtrl.text.trim();
                            String finalPhoto = previewPic;

                            if (newName.isEmpty) {
                              ValidationFeedback.showWarning(
                                context,
                                'Name cannot be empty.',
                                isError: true,
                              );
                              return;
                            }

                            if (newEmail.isNotEmpty) {
                              final emailRegex = RegExp(
                                  r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                              if (!emailRegex.hasMatch(newEmail)) {
                                ValidationFeedback.showWarning(
                                  context,
                                  'Please enter a valid email address.',
                                  isError: true,
                                );
                                return;
                              }
                            }

                            if (newPhone.isNotEmpty) {
                              final digits =
                                  newPhone.replaceAll(RegExp(r'\D'), '');
                              if (digits.length < 8) {
                                ValidationFeedback.showWarning(
                                  context,
                                  'Phone number must contain at least 8 digits.',
                                  isError: true,
                                );
                                return;
                              }
                            }

                            setModalState(() => isSaving = true);

                            try {
                              if (selectedImageBytes != null &&
                                  selectedImageName != null) {
                                finalPhoto = await state.uploadProfilePicture(
                                  bytes: selectedImageBytes!,
                                  fileName: selectedImageName!,
                                );
                              }

                              await state.updateProfile(
                                name: newName,
                                society: newSociety.isNotEmpty
                                    ? newSociety
                                    : user.society,
                                profilePic: finalPhoto.isNotEmpty
                                    ? finalPhoto
                                    : (previewPic.isNotEmpty
                                        ? previewPic
                                        : user.profilePic),
                                email: newEmail,
                                phone: newPhone,
                                latitude: selectedLat,
                                longitude: selectedLng,
                                formattedAddress: selectedAddress.isNotEmpty
                                    ? selectedAddress
                                    : (selectedLat != null
                                        ? newSociety
                                        : user.formattedAddress),
                              );

                              if (ctx.mounted) {
                                Navigator.of(ctx).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text('Profile updated successfully! ✨'),
                                    backgroundColor: AppColors.cardElevated,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (ctx.mounted) {
                                setModalState(() => isSaving = false);
                                ValidationFeedback.showWarning(
                                  context,
                                  'Failed to update profile: $e',
                                  isError: true,
                                );
                              }
                            }
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

void _showNeighborhoodPicker(BuildContext context, AppState state, AppUser user) {
  final controller = TextEditingController(
    text: user.society.isNotEmpty
        ? user.society
        : (user.formattedAddress.isNotEmpty ? user.formattedAddress : ''),
  );
  bool isLocating = false;
  String? locateError;
  double? currentLat = user.latitude;
  double? currentLng = user.longitude;
  String currentAddress = user.formattedAddress;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModalState) {
        Future<void> detectExactGpsLocation() async {
          setModalState(() {
            isLocating = true;
            locateError = null;
          });

          try {
            final geoRes = await getBrowserCoordinates();
            if (geoRes.latitude != null && geoRes.longitude != null) {
              final lat = geoRes.latitude!;
              final lng = geoRes.longitude!;
              final revRes = await fetchReverseGeocode(lat, lng);
              final address = revRes.isSuccess
                  ? revRes.displayName
                  : 'Location (${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)})';

              setModalState(() {
                currentLat = lat;
                currentLng = lng;
                currentAddress = address;
                controller.text = address;
                isLocating = false;
                if (geoRes.errorMessage != null && geoRes.errorMessage!.isNotEmpty) {
                  locateError = geoRes.errorMessage;
                }
              });

              await state.updateProfile(
                name: user.name,
                society: address,
                latitude: lat,
                longitude: lng,
                formattedAddress: address,
              );

              if (ctx.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Exact location detected: "$address" 📍',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                      ),
                    ),
                    backgroundColor: AppColors.cardElevated,
                  ),
                );
              }
            } else {
              setModalState(() {
                isLocating = false;
                locateError = geoRes.errorMessage ??
                    'Could not detect GPS location. Please allow browser location access.';
              });
            }
          } catch (e) {
            setModalState(() {
              isLocating = false;
              locateError = 'Location detection error: $e';
            });
          }
        }

        return Container(
          decoration: const BoxDecoration(
            color: AppColors.cardElevated,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: AppColors.glassLine)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.glassLine,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.location_on_rounded, color: AppColors.violet, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Saved Neighborhood',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.muted),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              neonLabeled(
                'Enter Society or Community',
                TextField(
                  controller: controller,
                  style: const TextStyle(color: AppColors.ink),
                  decoration: neonFieldDecoration(
                    hint: 'e.g. Sobha Forest View, Indiranagar',
                    prefixIcon: const Icon(Icons.edit_location_alt_rounded, color: AppColors.violet, size: 18),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Option 1: Detect exact GPS location
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: isLocating ? null : detectExactGpsLocation,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10F7A0).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF10F7A0).withValues(alpha: 0.45),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (isLocating)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10F7A0)),
                          ),
                        )
                      else
                        const Icon(Icons.my_location_rounded, color: Color(0xFF10F7A0), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isLocating
                              ? 'Requesting browser GPS permission & locating…'
                              : 'Locate My Exact Position (GPS)',
                          style: const TextStyle(
                            color: Color(0xFF10F7A0),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: Color(0xFF10F7A0), size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Option 2: Pick on interactive map
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () async {
                  try {
                    final res = await MapLocationPicker.show(
                      context,
                      initialLatitude: currentLat,
                      initialLongitude: currentLng,
                      initialAddress: currentAddress.isNotEmpty
                          ? currentAddress
                          : controller.text,
                    );
                    if (res != null) {
                      setModalState(() {
                        currentLat = res.latitude;
                        currentLng = res.longitude;
                        currentAddress = res.address;
                        controller.text = res.address;
                      });
                      await state.updateProfile(
                        name: user.name,
                        society: res.address,
                        latitude: res.latitude,
                        longitude: res.longitude,
                        formattedAddress: res.address,
                      );
                      if (ctx.mounted) {
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Pinned location saved to "${res.address}" 📍',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13.5,
                              ),
                            ),
                            backgroundColor: AppColors.cardElevated,
                          ),
                        );
                      }
                    }
                  } catch (e) {
                    if (ctx.mounted) {
                      ValidationFeedback.showWarning(
                        ctx,
                        'Could not open map: $e',
                        isError: true,
                      );
                    }
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.cyan.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.cyan.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.map_rounded, color: AppColors.cyan, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Pick & Pin on Map',
                          style: TextStyle(
                            color: AppColors.cyan,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: AppColors.cyan, size: 18),
                    ],
                  ),
                ),
              ),
              if (locateError != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFBB00).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFFBB00).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFFFBB00)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          locateError!,
                          style: const TextStyle(
                            color: Color(0xFFFFBB00),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (currentAddress.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.glassLine),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.violet.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.pin_drop_rounded, size: 16, color: AppColors.violet),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'CURRENT PINNED LOCATION',
                              style: TextStyle(
                                color: AppColors.muted,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              currentAddress,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.ink,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: _gradientBtn(
                  label: 'Save Neighborhood',
                  onTap: () async {
                    final chosen = controller.text.trim();
                    if (chosen.isNotEmpty) {
                      await state.updateProfile(
                        name: user.name,
                        society: chosen,
                        latitude: currentLat,
                        longitude: currentLng,
                        formattedAddress: currentAddress.isNotEmpty ? currentAddress : chosen,
                      );
                      if (ctx.mounted) {
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Neighborhood updated to "$chosen" 📍',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13.5,
                              ),
                            ),
                            backgroundColor: AppColors.cardElevated,
                          ),
                        );
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

void _showMyListedItemsSheet(BuildContext context, AppState state, AppUser user) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setModalState) {
          final myListedItems = state.items.where((i) {
            return i.owner == user.name ||
                i.owner.toLowerCase() == 'you' ||
                (i.ownerId.isNotEmpty && i.ownerId == (authService.currentUserId ?? ''));
          }).toList();

          return Container(
            decoration: const BoxDecoration(
              color: AppColors.cardElevated,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(top: BorderSide(color: AppColors.glassLine)),
            ),
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.glassLine,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.inventory_2_rounded, color: AppColors.amber, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'My Listed Items',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.amber.withValues(alpha: 0.35)),
                      ),
                      child: Text(
                        '${myListedItems.length} listed',
                        style: const TextStyle(
                          color: AppColors.amber,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppColors.muted),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (myListedItems.isEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.glassLine),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.muted),
                        const SizedBox(height: 12),
                        const Text(
                          'No items listed yet',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Share your tools or gadgets with neighbors to earn deposit security and help your community.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.muted,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  // One-click add sample items for the user
                                  await state.publishItem(Item(
                                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                                    name: 'Bosch Cordless Drill 18V',
                                    category: ItemCategory.tools,
                                    owner: user.name,
                                    desc: 'Two batteries and a complete drill-bit set. Available anytime for neighbor pickup.',
                                    deposit: 500,
                                    imageUrl: 'https://images.unsplash.com/photo-1504148455328-c376907d081c?w=600&auto=format&fit=crop&q=80',
                                  ));
                                  setModalState(() {});
                                },
                                icon: const Icon(Icons.auto_awesome, size: 16, color: AppColors.cyan),
                                label: const Text(
                                  'Add Sample Item',
                                  style: TextStyle(color: AppColors.cyan, fontSize: 12.5, fontWeight: FontWeight.w700),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: AppColors.cyan.withValues(alpha: 0.4)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _gradientBtn(
                                label: '+ List Item',
                                onTap: () {
                                  Navigator.of(ctx).pop();
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const ListItemScreen()),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 280),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: myListedItems.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, idx) {
                        final item = myListedItems[idx];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.glassLine),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: item.imageUrl.isNotEmpty
                                    ? Image.network(
                                        item.imageUrl,
                                        width: 50,
                                        height: 50,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          width: 50,
                                          height: 50,
                                          color: item.category.color.withValues(alpha: 0.15),
                                          child: Icon(item.category.icon, color: item.category.color),
                                        ),
                                      )
                                    : Container(
                                        width: 50,
                                        height: 50,
                                        color: item.category.color.withValues(alpha: 0.15),
                                        child: Icon(item.category.icon, color: item.category.color),
                                      ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppColors.ink,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${item.category.label} • Deposit ₹${item.deposit}',
                                      style: const TextStyle(
                                        color: AppColors.muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.muted),
                                onPressed: () {
                                  Navigator.of(ctx).pop();
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => ItemDetailScreen(item: item)),
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded,
                                    size: 16, color: AppColors.red),
                                tooltip: 'Remove listing',
                                onPressed: () {
                                  showDialog(
                                    context: ctx,
                                    builder: (dlg) => AlertDialog(
                                      backgroundColor: AppColors.surface,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        side: const BorderSide(color: AppColors.glassLine),
                                      ),
                                      title: const Text('Remove listing?',
                                          style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700)),
                                      content: Text(
                                        'Remove "${item.name}" from your listings?',
                                        style: const TextStyle(color: AppColors.muted, fontSize: 13),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.of(dlg).pop(),
                                          child: const Text('Cancel', style: TextStyle(color: AppColors.muted)),
                                        ),
                                        ElevatedButton(
                                          onPressed: () async {
                                            Navigator.of(dlg).pop();
                                            try {
                                              await state.deleteItem(item.id);
                                              setModalState(() {});
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text('"${item.name}" removed from listings.'),
                                                    backgroundColor: AppColors.cardElevated,
                                                  ),
                                                );
                                              }
                                            } catch (e) {
                                              if (context.mounted) {
                                                ValidationFeedback.showWarning(
                                                  context,
                                                  'Failed to delete: ${e.toString().replaceAll("Exception: ", "")}',
                                                  isError: true,
                                                );
                                              }
                                            }
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.red,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                          child: const Text('Remove'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: _gradientBtn(
                      label: '+ List another item',
                      onTap: () {
                        Navigator.of(ctx).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ListItemScreen()),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      );
    },
  );
}
