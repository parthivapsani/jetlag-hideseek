import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// Service for capturing and managing photos (web-compatible, no dart:io)
class PhotoService {
  final ImagePicker _picker = ImagePicker();

  /// Capture a photo using the camera
  /// Returns an XFile (works on both web and mobile)
  Future<XFile?> capturePhoto({
    int maxWidth = 1920,
    int maxHeight = 1080,
    int quality = 85,
  }) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: maxWidth.toDouble(),
        maxHeight: maxHeight.toDouble(),
        imageQuality: quality,
        preferredCameraDevice: CameraDevice.rear,
      );

      return image;
    } catch (e) {
      debugPrint('Error capturing photo: $e');
      return null;
    }
  }

  /// Pick a photo from the gallery
  Future<XFile?> pickFromGallery({
    int maxWidth = 1920,
    int maxHeight = 1080,
    int quality = 85,
  }) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: maxWidth.toDouble(),
        maxHeight: maxHeight.toDouble(),
        imageQuality: quality,
      );

      return image;
    } catch (e) {
      debugPrint('Error picking photo: $e');
      return null;
    }
  }

  /// Read photo bytes from an XFile
  Future<Uint8List?> readPhotoBytes(XFile photo) async {
    try {
      return await photo.readAsBytes();
    } catch (e) {
      debugPrint('Error reading photo bytes: $e');
      return null;
    }
  }
}

/// Provider for photo service
final photoServiceProvider = Provider<PhotoService>((ref) {
  return PhotoService();
});
