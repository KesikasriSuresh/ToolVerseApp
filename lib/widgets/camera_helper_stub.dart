import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Native fallback for non-web environments (Android, iOS, desktop).
/// Uses native device camera app directly.
Future<Uint8List?> captureLiveCameraPhoto(BuildContext context) async {
  try {
    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      imageQuality: 90,
    );
    if (file == null) return null;
    return await file.readAsBytes();
  } catch (e) {
    debugPrint('[CameraHelperStub] Error capturing camera photo: $e');
    return null;
  }
}
