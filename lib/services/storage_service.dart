import 'dart:typed_data';
import 'api_service.dart';

/// Result object for pre-upload validation.
class StorageValidationResult {
  final bool isValid;
  final String? errorMessage;

  const StorageValidationResult({required this.isValid, this.errorMessage});

  factory StorageValidationResult.success() =>
      const StorageValidationResult(isValid: true);

  factory StorageValidationResult.error(String message) =>
      StorageValidationResult(isValid: false, errorMessage: message);
}

/// Service for uploading image files to Cloudinary via FastAPI with validation.
class StorageService {
  StorageService._internal();
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;

  final ApiService _api = ApiService();

  /// Maximum allowed file size: 10 MB (10,485,760 bytes)
  static const int maxFileSizeBytes = 10 * 1024 * 1024;

  /// Allowed image file extensions
  static const Set<String> allowedExtensions = {'jpg', 'jpeg', 'png', 'webp'};

  /// Validate image bytes, file name, and file size before upload.
  static StorageValidationResult validateImage({
    required Uint8List bytes,
    required String fileName,
    int maxSizeBytes = maxFileSizeBytes,
  }) {
    if (bytes.isEmpty) {
      return StorageValidationResult.error('The selected image file is empty.');
    }

    if (bytes.lengthInBytes > maxSizeBytes) {
      final sizeMb = (bytes.lengthInBytes / (1024 * 1024)).toStringAsFixed(1);
      final maxMb = (maxSizeBytes / (1024 * 1024)).toStringAsFixed(0);
      return StorageValidationResult.error(
        'Image size exceeds the $maxMb MB limit (selected: $sizeMb MB). Please select a smaller photo.',
      );
    }

    final ext = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase().trim()
        : '';

    if (ext.isEmpty || !allowedExtensions.contains(ext)) {
      return StorageValidationResult.error(
        'Unsupported file format. Please upload a JPG, JPEG, PNG, or WebP image.',
      );
    }

    return StorageValidationResult.success();
  }

  /// Upload an item photo to Cloudinary via FastAPI backend.
  Future<String> uploadItemImage({
    required Uint8List bytes,
    required String fileName,
    required String userId,
  }) async {
    final validation = validateImage(bytes: bytes, fileName: fileName);
    if (!validation.isValid) {
      throw ArgumentError(validation.errorMessage);
    }

    return _api.uploadImage(
      bytes: bytes,
      fileName: fileName,
      category: 'item_photo',
    );
  }

  /// Upload a user profile picture to Cloudinary via FastAPI backend.
  Future<String> uploadProfilePicture({
    required Uint8List bytes,
    required String fileName,
    required String userId,
  }) async {
    final validation = validateImage(bytes: bytes, fileName: fileName);
    if (!validation.isValid) {
      throw ArgumentError(validation.errorMessage);
    }

    return _api.uploadImage(
      bytes: bytes,
      fileName: fileName,
      category: 'profile_picture',
    );
  }
}
