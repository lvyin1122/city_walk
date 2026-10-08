import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mambo/app/env.dart';

class CloudinaryService {
  /// Uploads [imageFile] and returns its public URL, or null when the upload
  /// fails.
  static Future<String?> uploadImage(File imageFile) async {
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

      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      final jsonResponse = json.decode(responseData);

      if (response.statusCode == 200) {
        return jsonResponse['secure_url'] as String?;
      }
      debugPrint('Cloudinary upload failed: ${jsonResponse['error']}');
      return null;
    } catch (e) {
      debugPrint('Error uploading to Cloudinary: $e');
      return null;
    }
  }
}
