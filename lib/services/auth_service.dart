import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'api_service.dart';

class AuthUser {
  final String uid;
  final String? phoneNumber;
  final String? email;
  final String? photoURL;
  final String? displayName;

  AuthUser({
    required this.uid,
    this.phoneNumber,
    this.email,
    this.photoURL,
    this.displayName,
  });
}

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final ApiService _api = ApiService();
  String? _lastErrorMessage;
  String? _pendingPhoneNumber;
  String? _pendingEmail;
  String? _pendingPhotoURL;
  String? _pendingDisplayName;

  // -------------------------------------------------------------------------
  // Getters
  // -------------------------------------------------------------------------

  String? get currentUserId => _api.currentUserId;
  AuthUser? get currentUser => currentUserId != null
      ? AuthUser(
          uid: currentUserId!,
          phoneNumber: _pendingPhoneNumber,
          email: _pendingEmail,
          photoURL: _pendingPhotoURL,
          displayName: _pendingDisplayName,
        )
      : null;
  String? get lastErrorMessage => _lastErrorMessage;
  String? get pendingEmail => _pendingEmail;
  String? get pendingPhoneNumber => _pendingPhoneNumber;
  String? get photoURL => _pendingPhotoURL;

  // -------------------------------------------------------------------------
  // Email Validation
  // -------------------------------------------------------------------------

  static bool isValidEmail(String raw) {
    final clean = raw.trim();
    if (clean.isEmpty) return false;
    final emailRegex =
        RegExp(r'^[a-zA-Z0-9.!#$%&’*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)+$');
    return emailRegex.hasMatch(clean);
  }

  // -------------------------------------------------------------------------
  // Send OTP for Email via FastAPI backend
  // -------------------------------------------------------------------------

  Future<void> sendEmailOtp(
    String email, {
    required Function(String) onError,
    VoidCallback? onCodeSent,
  }) async {
    _lastErrorMessage = null;
    final cleanEmail = email.trim().toLowerCase();
    if (!isValidEmail(cleanEmail)) {
      final msg = '[invalid-email] Please enter a valid email address.';
      _lastErrorMessage = msg;
      onError(msg);
      return;
    }

    _pendingEmail = cleanEmail;

    try {
      await _api.sendEmailOtp(cleanEmail);
      notifyListeners();
      onCodeSent?.call();
    } catch (e) {
      final friendlyMsg = _formatGeneralError(e);
      _lastErrorMessage = friendlyMsg;
      onError(friendlyMsg);
    }
  }

  // -------------------------------------------------------------------------
  // Verify OTP for Email via FastAPI backend
  // -------------------------------------------------------------------------

  Future<bool> verifyEmailOtp(
    String code, {
    String? email,
    Function(String)? onError,
  }) async {
    _lastErrorMessage = null;
    final trimmedCode = code.trim();
    if (trimmedCode.length != 6) {
      final msg =
          '[invalid-verification-code] Please enter the complete 6-digit code.';
      _lastErrorMessage = msg;
      onError?.call(msg);
      return false;
    }

    final targetEmail = email?.trim().toLowerCase() ?? _pendingEmail;
    if (targetEmail == null || targetEmail.isEmpty) {
      final msg =
          '[session-expired] No pending verification session found. Please enter your email again.';
      _lastErrorMessage = msg;
      onError?.call(msg);
      return false;
    }

    try {
      await _api.verifyEmailOtp(targetEmail, trimmedCode);
      notifyListeners();
      return true;
    } catch (e) {
      final friendlyMsg = _formatGeneralError(e);
      _lastErrorMessage = friendlyMsg;
      onError?.call(friendlyMsg);
      return false;
    }
  }

  // -------------------------------------------------------------------------
  // Google One-Tap / Popup Sign-In
  // -------------------------------------------------------------------------

  Future<bool> signInWithGoogle({
    Function(String)? onError,
  }) async {
    _lastErrorMessage = null;
    try {
      final googleProvider = GoogleAuthProvider();
      googleProvider.addScope('email');
      googleProvider.addScope('profile');

      UserCredential credential;
      if (kIsWeb) {
        credential =
            await FirebaseAuth.instance.signInWithPopup(googleProvider);
      } else {
        credential =
            await FirebaseAuth.instance.signInWithProvider(googleProvider);
      }

      final user = credential.user;
      if (user == null || user.email == null || user.email!.isEmpty) {
        final msg = 'Failed to retrieve Google account credentials.';
        _lastErrorMessage = msg;
        onError?.call(msg);
        return false;
      }

      final idToken = await user.getIdToken();
      await _api.googleLogin(
        email: user.email!,
        name: user.displayName,
        profilePic: user.photoURL,
        googleId: user.uid,
        idToken: idToken,
      );

      _pendingEmail = user.email!;
      _pendingPhotoURL = user.photoURL;
      _pendingDisplayName = user.displayName;
      notifyListeners();
      return true;
    } catch (e) {
      final friendlyMsg = _formatGeneralError(e);
      _lastErrorMessage = friendlyMsg;
      onError?.call(friendlyMsg);
      return false;
    }
  }

  // -------------------------------------------------------------------------
  // Phone Number Sanitization / Formatting (E.164 format)
  // -------------------------------------------------------------------------

  static String? formatPhoneNumber(String raw) {
    var cleaned = raw.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (cleaned.isEmpty) return null;
    if (!cleaned.startsWith('+')) {
      if (cleaned.length == 10) {
        cleaned = '+91$cleaned';
      } else {
        cleaned = '+$cleaned';
      }
    }
    final e164Regex = RegExp(r'^\+[1-9]\d{6,14}$');
    if (!e164Regex.hasMatch(cleaned)) {
      return null;
    }
    return cleaned;
  }

  // -------------------------------------------------------------------------
  // Send OTP via FastAPI backend
  // -------------------------------------------------------------------------

  Future<void> sendOtp(
    String phoneNumber, {
    required Function(String) onError,
    VoidCallback? onCodeSent,
  }) async {
    _lastErrorMessage = null;
    final formattedNumber = formatPhoneNumber(phoneNumber);
    if (formattedNumber == null) {
      final msg =
          '[invalid-phone-number] Please enter a valid phone number with country code (e.g. +91 98765 43210).';
      _lastErrorMessage = msg;
      onError(msg);
      return;
    }

    _pendingPhoneNumber = formattedNumber;

    try {
      await _api.sendOtp(formattedNumber);
      notifyListeners();
      onCodeSent?.call();
    } catch (e) {
      final friendlyMsg = _formatGeneralError(e);
      _lastErrorMessage = friendlyMsg;
      onError(friendlyMsg);
    }
  }

  // -------------------------------------------------------------------------
  // Verify OTP via FastAPI backend
  // -------------------------------------------------------------------------

  Future<bool> verifyOtp(
    String smsCode, {
    String? phone,
    Function(String)? onError,
  }) async {
    _lastErrorMessage = null;
    final code = smsCode.trim();
    if (code.length != 6) {
      final msg =
          '[invalid-verification-code] Please enter the complete 6-digit OTP code.';
      _lastErrorMessage = msg;
      onError?.call(msg);
      return false;
    }

    final targetPhone = phone ?? _pendingPhoneNumber;
    if (targetPhone == null || targetPhone.isEmpty) {
      final msg =
          '[session-expired] No pending verification session found. Please request a new verification code.';
      _lastErrorMessage = msg;
      onError?.call(msg);
      return false;
    }

    try {
      await _api.verifyOtp(targetPhone, code);
      notifyListeners();
      return true;
    } catch (e) {
      final friendlyMsg = _formatGeneralError(e);
      _lastErrorMessage = friendlyMsg;
      onError?.call(friendlyMsg);
      return false;
    }
  }

  // -------------------------------------------------------------------------
  // Anonymous Sign In via FastAPI backend
  // -------------------------------------------------------------------------

  Future<String?> signInAnonymously() async {
    _lastErrorMessage = null;
    try {
      final data = await _api.signInAnonymously();
      notifyListeners();
      return data['uid'] as String?;
    } catch (e) {
      _lastErrorMessage = _formatGeneralError(e);
      return null;
    }
  }

  // -------------------------------------------------------------------------
  // Sign out
  // -------------------------------------------------------------------------

  Future<void> signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    await _api.logout();
    await _api.clearAuthToken();
    _pendingPhoneNumber = null;
    _pendingEmail = null;
    _pendingPhotoURL = null;
    _pendingDisplayName = null;
    _lastErrorMessage = null;
    notifyListeners();
  }

  // -------------------------------------------------------------------------
  // Error Formatting Helpers
  // -------------------------------------------------------------------------

  String _formatGeneralError(dynamic e) {
    final str = e.toString().replaceAll('Exception: ', '').replaceAll('Error: ', '');
    if (str.contains('operation-not-allowed')) {
      return 'Google Sign-In is not enabled yet in your Firebase Console. Go to Firebase Console -> Authentication -> Sign-in method and enable Google.';
    }
    if (str.contains('network') || str.contains('XMLHttpRequest') || str.contains('Connection refused')) {
      return '[network-error] Network connection failed. Please ensure the ToolVerse backend server is running.';
    }
    return str;
  }
}
