import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// A photo the user took or chose, and where it came from.
typedef PickedPhoto = ({XFile file, ImageSource source});

/// Asks whether to take a photo or choose one from the gallery, then returns
/// the photo. Returns null when the user cancels at either step.
Future<PickedPhoto?> pickPhoto(BuildContext context, ImagePicker picker) async {
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
  return (file: photo, source: source);
}
