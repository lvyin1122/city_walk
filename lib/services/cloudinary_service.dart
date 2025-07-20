import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class CloudinaryService {
  // Primary upload method using Cloudinary
  static Future<String?> uploadImage(File imageFile) async {
    try {
      final cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME']!;
      final uploadPreset = dotenv.env['CLOUDINARY_UPLOAD_PRESET']!;

      // Create multipart request
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload'),
      );

      // Add upload preset
      request.fields['upload_preset'] = uploadPreset;

      // Add the image file
      final fileStream = http.ByteStream(imageFile.openRead());
      final fileLength = await imageFile.length();

      final multipartFile = http.MultipartFile(
        'file',
        fileStream,
        fileLength,
        filename: 'walk_photo_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      request.files.add(multipartFile);

      // Send the request
      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      final jsonResponse = json.decode(responseData);

      if (response.statusCode == 200) {
        return jsonResponse['secure_url'];
      } else {
        print('Cloudinary upload failed: ${jsonResponse['error']}');
        // Fallback to imgbb
        return await _uploadToImgbb(imageFile);
      }
    } catch (e) {
      print('Error uploading to Cloudinary: $e');
      // Fallback to imgbb
      return await _uploadToImgbb(imageFile);
    }
  }

  // Fallback upload method using imgbb
  static Future<String?> _uploadToImgbb(File imageFile) async {
    try {
      final String apiKey = dotenv.env['IMGBB_API_KEY']!;
      final String base64Image = base64Encode(await imageFile.readAsBytes());

      final response = await http.post(
        Uri.parse('https://api.imgbb.com/1/upload'),
        body: {'key': apiKey, 'image': base64Image},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return data['data']['url'];
      }
      return null;
    } catch (e) {
      print('Error uploading to imgbb: $e');
      return null;
    }
  }
}
