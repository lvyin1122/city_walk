import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens links outside Mambo without interrupting the current walk on failure.
abstract final class AppLinks {
  static Future<bool> open(Uri uri) async {
    try {
      return await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      ).timeout(const Duration(seconds: 10));
    } catch (error) {
      debugPrint('Could not open external link: ${error.runtimeType}');
      return false;
    }
  }
}
