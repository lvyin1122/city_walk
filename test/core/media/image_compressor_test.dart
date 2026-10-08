import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mambo/core/media/image_compressor.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('compressor_test');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  File fileOfSize(int bytes) {
    return File('${tempDir.path}/photo.jpg')..writeAsBytesSync(Uint8List(bytes));
  }

  test('returns the original when it is already small enough', () async {
    final original = fileOfSize(100 * 1024);
    var encodeCalls = 0;

    final result = await compressImage(
      original,
      encode: (path, edge, quality) async {
        encodeCalls++;
        return Uint8List(1);
      },
    );

    expect(result.path, original.path);
    expect(encodeCalls, 0);
  });

  test('stops at the first step that fits, starting from the best quality', () async {
    final original = fileOfSize(4 * 1024 * 1024);
    final tried = <(int, int)>[];

    final result = await compressImage(
      original,
      encode: (path, edge, quality) async {
        tried.add((edge, quality));
        // Pretend the size shrinks with the edge length. With a 128 KB
        // (131,072 byte) limit, 1280 gives 140,800 bytes and 1024 gives
        // 112,640, so 1024 is the first step that fits.
        return Uint8List(edge * 110);
      },
    );

    expect(tried, [(1600, 80), (1280, 75), (1024, 70)]);
    expect(await result.length(), 1024 * 110);
    expect(result.path, isNot(original.path));
    // The old implementation derived the quality from the size ratio, which
    // gave quality 3 for a 4 MB photo.
    expect(tried.every((step) => step.$2 >= 50), isTrue);
  });

  test('falls back to the smallest result when nothing fits', () async {
    final original = fileOfSize(4 * 1024 * 1024);

    final result = await compressImage(
      original,
      encode: (path, edge, quality) async => Uint8List(edge * 1000),
    );

    expect(await result.length(), compressionSteps.last.edge * 1000);
  });

  test('returns the original when the encoder cannot read the image', () async {
    final original = fileOfSize(4 * 1024 * 1024);

    final result = await compressImage(
      original,
      encode: (path, edge, quality) async => null,
    );

    expect(result.path, original.path);
  });
}
