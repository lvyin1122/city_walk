import 'package:flutter/material.dart';
import 'package:mambo/theme/tokens.dart';
import 'package:mambo/widgets/botanical.dart';

/// Explains the walk page. Shown the first time and from the info button.
Future<void> showWalkGuide(BuildContext context) {
  final text = Theme.of(context).textTheme;
  Widget item(IconData icon, String title, String description) => Padding(
    padding: const EdgeInsets.only(bottom: FreshSpace.lg),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: FreshColors.skyText),
        const SizedBox(width: FreshSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: text.titleSmall),
              const SizedBox(height: 2),
              Text(description, style: text.bodySmall),
            ],
          ),
        ),
      ],
    ),
  );
  return showDialog<void>(
    context: context,
    builder:
        (context) => AlertDialog(
          icon: const Botanical(kind: BotanicalKind.sprig, size: 48),
          title: const Text('慢慢走，慢慢看'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              item(Icons.place_outlined, '到达地点', '走近标记点，到达后它会变成薄荷绿。'),
              item(Icons.photo_camera_outlined, '完成任务', '按提示拍下你注意到的细节。'),
              item(Icons.favorite_border, '惊喜地点', '遇到让你心动的角落，就把它记下来。'),
              item(Icons.spa_outlined, '享受旅程', '每个转角都藏着故事，不必着急。'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('知道了'),
            ),
          ],
        ),
  );
}

/// The model's verdict on a task photo.
Future<void> showPhotoVerdict(BuildContext context, {required bool accepted, required String message}) {
  return showDialog<void>(
    context: context,
    builder:
        (context) => AlertDialog(
          title: Text(accepted ? '拍得真好' : '再试一次吧'),
          content: Text(message.isEmpty ? (accepted ? '这张照片符合任务。' : '这张照片好像和任务不太相关。') : message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('好的'),
            ),
          ],
        ),
  );
}

/// Celebrates a completed task.
Future<void> showTaskCompleted(BuildContext context) {
  final text = Theme.of(context).textTheme;
  return showDialog<void>(
    context: context,
    builder:
        (context) => AlertDialog(
          icon: const Botanical(kind: BotanicalKind.blossom, size: 64),
          title: const Text('任务完成'),
          content: Text('下一个小小的挑战正在路上。', style: text.bodyMedium, textAlign: TextAlign.center),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('继续漫步'),
            ),
          ],
        ),
  );
}

/// Asks whether to pause and leave. Returns true to leave.
Future<bool> confirmPause(BuildContext context) async {
  final leave = await showDialog<bool>(
    context: context,
    builder:
        (context) => AlertDialog(
          title: const Text('暂停步行？'),
          content: const Text('进度会保存下来，你可以稍后在首页继续这次步行。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('继续步行'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('暂停并离开'),
            ),
          ],
        ),
  );
  return leave ?? false;
}

/// Asks whether to finish the walk, showing what was done. [finish] runs
/// inside the dialog so a failure keeps it open; returns true when finished.
Future<bool> confirmFinish(
  BuildContext context, {
  required List<String> summary,
  required Future<bool> Function() finish,
}) async {
  final finished = await showDialog<bool>(
    context: context,
    builder: (context) => _FinishDialog(summary: summary, finish: finish),
  );
  return finished ?? false;
}

class _FinishDialog extends StatefulWidget {
  const _FinishDialog({required this.summary, required this.finish});

  final List<String> summary;
  final Future<bool> Function() finish;

  @override
  State<_FinishDialog> createState() => _FinishDialogState();
}

class _FinishDialogState extends State<_FinishDialog> {
  bool _saving = false;

  Future<void> _finish() async {
    setState(() => _saving = true);
    final ok = await widget.finish();
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AlertDialog(
      title: const Text('结束这次漫步？'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in widget.summary)
            Padding(
              padding: const EdgeInsets.only(bottom: FreshSpace.xs),
              child: Text(line, style: text.bodyMedium),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('继续步行'),
        ),
        TextButton(
          onPressed: _saving ? null : _finish,
          child: Text(_saving ? '正在保存…' : '结束步行'),
        ),
      ],
    );
  }
}

/// Offered once every stop is reached. Returns true to finish now.
Future<bool> suggestFinish(BuildContext context) async {
  final finish = await showDialog<bool>(
    context: context,
    builder:
        (context) => AlertDialog(
          icon: const Botanical(kind: BotanicalKind.ginkgo, size: 56),
          title: const Text('所有地点都到达了'),
          content: const Text('要现在结束这次漫步吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('再走走'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('结束步行'),
            ),
          ],
        ),
  );
  return finish ?? false;
}

/// The stop's photos from the map provider.
Future<void> showStopPhotos(BuildContext context, List<String> urls) {
  return showDialog<void>(
    context: context,
    builder:
        (context) => Dialog(
          insetPadding: const EdgeInsets.all(FreshSpace.lg),
          child: Stack(
            children: [
              ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.all(FreshSpace.md),
                itemCount: urls.length,
                separatorBuilder: (_, _) => const SizedBox(height: FreshSpace.md),
                itemBuilder:
                    (context, index) => ClipRRect(
                      borderRadius: FreshRadius.button,
                      child: Image.network(
                        urls[index],
                        fit: BoxFit.cover,
                        loadingBuilder:
                            (context, child, progress) =>
                                progress == null
                                    ? child
                                    : const SizedBox(
                                      height: 200,
                                      child: Center(
                                        child: CircularProgressIndicator(strokeWidth: 1.2),
                                      ),
                                    ),
                        errorBuilder:
                            (context, error, stackTrace) => const SizedBox(
                              height: 120,
                              child: Center(child: Icon(Icons.image_not_supported_outlined)),
                            ),
                      ),
                    ),
              ),
              Positioned(
                top: FreshSpace.sm,
                right: FreshSpace.sm,
                child: IconButton.filledTonal(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: '关闭',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
  );
}
