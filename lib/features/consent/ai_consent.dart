import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';

/// The versioned permission to share the disclosed data with AI providers.
abstract final class AiConsent {
  static const _key = 'ai_consent_v1';
  static const _storageTimeout = Duration(seconds: 5);
  static Future<bool>? _pending;

  static Future<bool> isGranted() async {
    final prefs = await SharedPreferences.getInstance().timeout(_storageTimeout);
    return prefs.getBool(_key) ?? false;
  }

  static Future<void> grant() async {
    final prefs = await SharedPreferences.getInstance().timeout(_storageTimeout);
    if (!await prefs.setBool(_key, true).timeout(_storageTimeout)) {
      throw StateError('Could not persist AI data consent');
    }
  }

  static Future<void> revoke() async {
    final prefs = await SharedPreferences.getInstance().timeout(_storageTimeout);
    if (!await prefs.remove(_key).timeout(_storageTimeout)) {
      throw StateError('Could not revoke AI data consent');
    }
  }
}

/// Explains the data and processors before a user chooses whether to continue.
class AiConsentDialog extends StatelessWidget {
  const AiConsentDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('AI 服务与你的数据'),
      scrollable: true,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('为了生成路线、拍摄任务和漫步故事，Mambo 会把以下内容发送给第三方 AI 服务处理：'),
          const SizedBox(height: FreshSpace.md),
          const Text('• 你的大致位置和附近的地址'),
          const Text('• 你选择或输入的关键词'),
          const Text('• 你拍摄的任务照片和写下的文字'),
          const SizedBox(height: FreshSpace.md),
          const Text('这些服务是阿里云通义千问（Qwen）和 OpenAI，只用于为你生成内容。Mambo 不会出售你的数据。详情见隐私政策。'),
          const SizedBox(height: FreshSpace.md),
          Text(
            'Mambo sends your approximate location and nearby address, the keywords you choose, and the task photos and notes you add to third-party AI services (Alibaba Cloud Qwen and OpenAI) to plan walks, create photo tasks and write walk stories. They are used only to generate content for you.',
            style: context.text.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('不同意'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('同意并继续'),
        ),
      ],
    );
  }
}

/// Shares a pending request so simultaneous entry points show one dialog.
Future<bool> ensureAiConsent(BuildContext context) {
  return AiConsent._pending ??= _requestConsent(context).whenComplete(() {
    AiConsent._pending = null;
  });
}

Future<bool> _requestConsent(BuildContext context) async {
  try {
    final granted = await AiConsent.isGranted();
    if (!context.mounted) return false;
    if (granted) return true;
    final agreed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AiConsentDialog(),
    );
    if (!context.mounted || agreed != true) return false;
    await AiConsent.grant();
    if (!context.mounted) return false;
    return true;
  } catch (error) {
    debugPrint('Could not verify AI data consent: ${error.runtimeType}');
    return false;
  }
}
