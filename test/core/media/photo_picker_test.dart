import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mambo/core/media/photo_picker.dart';

class _FakePicker extends ImagePicker {
  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async => XFile('/photos/${source.name}.jpg');
}

void main() {
  Future<PickedPhoto?> pick(
    WidgetTester tester,
    String option, {
    required GallerySaver save,
    VoidCallback? onSaved,
  }) async {
    late Future<PickedPhoto?> result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) => Scaffold(body: TextButton(
        onPressed: () => result = pickPhoto(context, _FakePicker(),
          saveToGallery: save, onSavedToGallery: onSaved),
        child: const Text('open'),
      ))),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(option));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('a photo taken with the camera is saved to the gallery', (tester) async {
    final saved = <String>[];
    var told = 0;
    final photo = await pick(tester, '拍照',
      save: (path) async => saved.add(path), onSaved: () => told++);
    expect(photo!.source, ImageSource.camera);
    expect(saved, ['/photos/camera.jpg']);
    expect(told, 1);
  });

  testWidgets('a photo chosen from the gallery is not saved again', (tester) async {
    final saved = <String>[];
    final photo = await pick(tester, '从相册选择', save: (path) async => saved.add(path));
    expect(photo!.source, ImageSource.gallery);
    expect(saved, isEmpty);
  });

  testWidgets('a failed save still returns the photo and stays quiet', (tester) async {
    var told = 0;
    final photo = await pick(tester, '拍照',
      save: (_) async => throw Exception('denied'), onSaved: () => told++);
    expect(photo!.file.path, '/photos/camera.jpg');
    await tester.pump();
    expect(told, 0);
  });
}
