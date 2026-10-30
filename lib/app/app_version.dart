import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mambo/theme/tokens.dart';
import 'package:mambo/widgets/botanical.dart';
import 'package:mambo/widgets/fresh_surface.dart';

import 'links.dart';

/// Compares numeric version parts, ignoring build metadata and other text.
int compareVersions(String a, String b) {
  List<int> parts(String value) => value.split('+').first.split('.').map((part) {
    final number = RegExp(r'\d+').firstMatch(part)?.group(0);
    return int.tryParse(number ?? '') ?? 0;
  }).toList();
  final left = parts(a);
  final right = parts(b);
  final length = left.length > right.length ? left.length : right.length;
  for (var i = 0; i < length; i++) {
    final result = (i < left.length ? left[i] : 0)
        .compareTo(i < right.length ? right[i] : 0);
    if (result != 0) return result;
  }
  return 0;
}

/// Checks both versions within one deadline; unavailable checks permit startup.
Future<bool> isUpdateRequired({
  required Future<String> Function() currentVersion,
  required Future<String> Function() minimumVersion,
}) async {
  try {
    final versions = await Future.wait([
      Future<String>.sync(currentVersion),
      Future<String>.sync(minimumVersion),
    ]).timeout(const Duration(seconds: 5));
    return versions[1].trim().isNotEmpty &&
        compareVersions(versions[0], versions[1].trim()) < 0;
  } catch (_) {
    return false;
  }
}

class UpdateRequiredScreen extends StatelessWidget {
  const UpdateRequiredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    final storeUrl = switch (platform) {
      TargetPlatform.iOS => AppLinks.appStoreUrl,
      TargetPlatform.android => AppLinks.playStoreUrl,
      _ => '',
    };
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: PaperBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(FreshSpace.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Botanical(kind: BotanicalKind.ginkgo, size: 64),
                  const SizedBox(height: FreshSpace.xl),
                  Text('请更新 Mambo', style: text.headlineMedium),
                  const SizedBox(height: FreshSpace.md),
                  Text(
                    '这个版本已经停止支持，请到应用商店更新到最新版本后继续使用。',
                    style: text.bodyLarge,
                  ),
                  if (storeUrl.isNotEmpty) ...[
                    const SizedBox(height: FreshSpace.lg),
                    ElevatedButton(
                      onPressed: () => AppLinks.open(Uri.parse(storeUrl)),
                      child: const Text('前往更新'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
