import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Service for capturing and managing photos
class PhotoService {
  final ImagePicker _picker = ImagePicker();

  /// Capture a photo using the camera
  Future<File?> capturePhoto({
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

      if (image == null) return null;

      return File(image.path);
    } catch (e) {
      debugPrint('Error capturing photo: $e');
      return null;
    }
  }

  /// Pick a photo from the gallery
  Future<File?> pickFromGallery({
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

      if (image == null) return null;

      return File(image.path);
    } catch (e) {
      debugPrint('Error picking photo: $e');
      return null;
    }
  }

  /// Save photo to app's document directory
  Future<File?> savePhoto(File photo, String filename) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final photosDir = Directory('${directory.path}/photos');

      if (!await photosDir.exists()) {
        await photosDir.create(recursive: true);
      }

      final savedPath = '${photosDir.path}/$filename';
      return await photo.copy(savedPath);
    } catch (e) {
      debugPrint('Error saving photo: $e');
      return null;
    }
  }

  /// Delete a saved photo
  Future<bool> deletePhoto(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error deleting photo: $e');
      return false;
    }
  }

  /// Get all saved photos
  Future<List<File>> getSavedPhotos() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final photosDir = Directory('${directory.path}/photos');

      if (!await photosDir.exists()) {
        return [];
      }

      final files = await photosDir.list().toList();
      return files
          .whereType<File>()
          .where((f) => f.path.endsWith('.jpg') || f.path.endsWith('.png'))
          .toList();
    } catch (e) {
      debugPrint('Error listing photos: $e');
      return [];
    }
  }
}

/// Provider for photo service
final photoServiceProvider = Provider<PhotoService>((ref) {
  return PhotoService();
});
