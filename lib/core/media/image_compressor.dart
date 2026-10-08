import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Encodes the image at [path] as JPEG, scaled so that its shorter edge is
/// about [edge] pixels, at JPEG [quality] (1-100). Returns null on failure.
typedef ImageEncoder =
    Future<Uint8List?> Function(String path, int edge, int quality);

/// Sizes tried in order, from best to smallest.
const List<({int edge, int quality})> compressionSteps = [
  (edge: 1600, quality: 80),
  (edge: 1280, quality: 75),
  (edge: 1024, quality: 70),
  (edge: 800, quality: 65),
  (edge: 640, quality: 60),
  (edge: 480, quality: 50),
];

/// Returns a JPEG version of [file] no larger than [maxBytes] when possible.
///
/// The image is scaled down in steps rather than only lowering the JPEG
/// quality: a full-resolution photo at single-digit quality is far uglier
/// than a smaller photo at normal quality and the same size. If even the
/// smallest step is too large, that smallest result is returned.
Future<File> compressImage(
  File file, {
  int maxBytes = 128 * 1024,
  ImageEncoder encode = _encodeWithPlugin,
}) async {
  if (await file.length() <= maxBytes) return file;

  Uint8List? smallest;
  for (final step in compressionSteps) {
    final bytes = await encode(file.path, step.edge, step.quality);
    if (bytes == null) continue;
    smallest = bytes;
    if (bytes.length <= maxBytes) break;
  }
  if (smallest == null) return file;

  final compressed = File('${file.path}_compressed.jpg');
  await compressed.writeAsBytes(smallest);
  return compressed;
}

Future<Uint8List?> _encodeWithPlugin(String path, int edge, int quality) {
  return FlutterImageCompress.compressWithFile(
    path,
    minWidth: edge,
    minHeight: edge,
    quality: quality,
  );
}
