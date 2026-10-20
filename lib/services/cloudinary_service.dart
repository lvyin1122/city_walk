import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mambo/app/env.dart';

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
  }) async {
    final ownsClient = client == null;
    final httpClient = client ?? http.Client();
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(
          'https://api.cloudinary.com/v1_1/${Env.cloudinaryCloudName}/image/upload',
        ),
      );
      request.fields['upload_preset'] = Env.cloudinaryUploadPreset;
      request.files.add(
        http.MultipartFile(
          'file',
          http.ByteStream(imageFile.openRead()),
          await imageFile.length(),
          filename: 'walk_photo_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      );

      // One limit covers sending the request and reading the response.
      Future<({int statusCode, String body})> sendAndRead() async {
        final response = await httpClient.send(request);
        return (
          statusCode: response.statusCode,
          body: await response.stream.bytesToString(),
        );
      }

      final pending = sendAndRead();
      final ({int statusCode, String body}) result;
      try {
        result = await pending.timeout(timeout);
      } on TimeoutException catch (e) {
        pending.ignore();
        debugPrint('Cloudinary upload timed out: $e');
        return null;
      }

      final Object? decoded = json.decode(result.body);
      final body = decoded is Map<String, dynamic> ? decoded : const {};

      if (result.statusCode == 200) {
        return body['secure_url'] as String?;
      }
      debugPrint('Cloudinary upload failed: ${body['error']}');
      return null;
    } catch (e) {
      debugPrint('Error uploading to Cloudinary: $e');
      return null;
    } finally {
      if (ownsClient) httpClient.close();
    }
  }
}
