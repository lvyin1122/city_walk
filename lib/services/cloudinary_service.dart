import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mambo/services/graphql_service.dart';

class CloudinaryService {
  /// Uploads [imageFile] and returns its public URL, or null when the upload
  /// fails or takes longer than [timeout].
  ///
  /// [client] is used by tests. When it is omitted, a client is created for
  /// this upload and closed afterwards, including when the upload fails.
  static Future<String?> uploadImage(
    File imageFile, {
    http.Client? client,
    Duration timeout = const Duration(seconds: 60),
    Future<UploadSignature> Function()? signatureSource,
  }) async {
    final ownsClient = client == null;
    final httpClient = client ?? http.Client();
    final elapsed = Stopwatch()..start();
    bool expired = false;

    void checkDeadline() {
      if (expired || elapsed.elapsed >= timeout) {
        throw TimeoutException('Upload deadline reached', timeout);
      }
    }

    Future<({int statusCode, String body})> signAndUpload() async {
      final signature = await (signatureSource ?? GraphQLService().createUploadSignature)();
      checkDeadline();
      final length = await imageFile.length();
      checkDeadline();
      final request = http.MultipartRequest(
        'POST',
        Uri.https('api.cloudinary.com', '/v1_1/${signature.cloudName}/image/upload'),
      );
      request.fields.addAll({
        'api_key': signature.apiKey,
        'timestamp': signature.timestamp.toString(),
        'signature': signature.signature,
        'folder': signature.folder,
        'upload_preset': signature.uploadPreset,
      });
      request.files.add(
        http.MultipartFile(
          'file',
          http.ByteStream(imageFile.openRead()),
          length,
          filename: 'walk_photo_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      );
      final response = await httpClient.send(request);
      return (
        statusCode: response.statusCode,
        body: await response.stream.bytesToString(),
      );
    }

    try {
      // The signature, file preparation, send and response share one deadline.
      final result = await signAndUpload().timeout(timeout, onTimeout: () {
        expired = true;
        throw TimeoutException('Upload deadline reached', timeout);
      });
      if (result.statusCode != 200) {
        debugPrint('Cloudinary upload failed (HTTP ${result.statusCode})');
        return null;
      }
      final Object? decoded = json.decode(result.body);
      return decoded is Map && decoded['secure_url'] is String
          ? decoded['secure_url'] as String
          : null;
    } catch (error) {
      // Exceptions can contain signatures or photo URLs; log only their type.
      debugPrint('Cloudinary upload failed (${error.runtimeType})');
      return null;
    } finally {
      elapsed.stop();
      if (ownsClient) httpClient.close();
    }
  }
}
