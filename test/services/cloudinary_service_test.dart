import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mambo/services/cloudinary_service.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('cloudinary_service_test');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<File> imageFile() {
    return File('${tempDir.path}/photo.jpg').writeAsBytes([1, 2, 3, 4]);
  }

  test('returns the secure_url from a 200 response', () async {
    final client = MockClient(
      (_) async => http.Response(
        '{"secure_url": "https://example.com/a.jpg"}',
        200,
      ),
    );

    final url = await CloudinaryService.uploadImage(
      await imageFile(),
      client: client,
    );

    expect(url, 'https://example.com/a.jpg');
  });

  test('returns null from a 400 response', () async {
    final client = MockClient(
      (_) async => http.Response('{"error":"rejected"}', 400),
    );

    final url = await CloudinaryService.uploadImage(
      await imageFile(),
      client: client,
    );

    expect(url, isNull);
  });

  test('returns null when the client never responds', () async {
    final client = MockClient((_) => Completer<http.Response>().future);

    final url = await CloudinaryService.uploadImage(
      await imageFile(),
      client: client,
      timeout: const Duration(milliseconds: 100),
    ).timeout(const Duration(seconds: 2));

    expect(url, isNull);
  });
}
