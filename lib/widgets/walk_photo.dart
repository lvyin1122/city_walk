import 'dart:io';

import 'package:flutter/material.dart';

/// Renders a walk photo whether it's a remote URL (real backend) or a local
/// file path (demo mode, where "upload" just hands back the picked file).
class WalkPhoto extends StatelessWidget {
  const WalkPhoto({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;

  bool get _isRemote =>
      url.startsWith('http://') || url.startsWith('https://');

  @override
  Widget build(BuildContext context) {
    if (_isRemote) {
      return Image.network(
        url,
        fit: fit,
        width: width,
        height: height,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            width: width,
            height: height,
            color: Colors.grey[200],
            child: const Center(child: CircularProgressIndicator()),
          );
        },
        errorBuilder: (context, error, stackTrace) => Container(
          width: width,
          height: height,
          color: Colors.grey[200],
          child: const Icon(Icons.error_outline, color: Colors.grey),
        ),
      );
    }
    return Image.file(
      File(url),
      fit: fit,
      width: width,
      height: height,
      errorBuilder: (context, error, stackTrace) => Container(
        width: width,
        height: height,
        color: Colors.grey[200],
        child: const Icon(Icons.image_not_supported, color: Colors.grey),
      ),
    );
  }
}
