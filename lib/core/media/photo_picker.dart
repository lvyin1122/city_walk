import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';

/// A photo the user took or chose, and where it came from.
typedef PickedPhoto = ({XFile file, ImageSource source});

/// Saves a photo file to the system gallery.
typedef GallerySaver = Future<void> Function(String path);

Future<void> _saveWithGal(String path) =>
    Gal.putImage(path).timeout(const Duration(seconds: 30));

/// Asks whether to take a photo or choose one from the gallery, then returns
/// the photo. Returns null when the user cancels at either step.
///
/// A photo taken with the camera is also saved to the user's gallery. The
/// save runs in the background, so the caller can upload at once even while
/// the system shows its photo-library prompt; [onSavedToGallery] runs when it
/// succeeded. A failed save is only logged.
Future<PickedPhoto?> pickPhoto(
  BuildContext context,
  ImagePicker picker, {
  VoidCallback? onSavedToGallery,
  @visibleForTesting GallerySaver saveToGallery = _saveWithGal,
}) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (BuildContext context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('拍照'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('从相册选择'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
  if (source == null) return null;

  final photo = await picker.pickImage(source: source);
  if (photo == null) return null;
  if (source == ImageSource.camera) {
    unawaited(_keepCopy(photo.path, saveToGallery, onSavedToGallery));
  }
  return (file: photo, source: source);
}

Future<void> _keepCopy(
  String path,
  GallerySaver save,
  VoidCallback? onSaved,
) async {
  try {
    await save(path);
    onSaved?.call();
  } catch (e) {
    debugPrint('Failed to save photo to gallery: $e');
  }
}
