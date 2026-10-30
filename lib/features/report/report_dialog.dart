import 'package:flutter/material.dart';
import 'package:mambo/core/api/api_exception.dart';
import 'package:mambo/theme/tokens.dart';

import 'report_repository.dart';

export 'report_repository.dart' show ReportKind;

Future<void> showReportDialog(
  BuildContext context, {
  required ReportKind kind,
  required String walkId,
  int? stopIndex,
  ReportRepository? repository,
}) async {
  final sent = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ReportDialog(
      kind: kind,
      walkId: walkId,
      stopIndex: stopIndex,
      repository: repository ?? ReportRepository(),
    ),
  );
  if (!context.mounted) return;
  if (sent == true) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('已收到，谢谢你的反馈')));
  }
}

class _ReportDialog extends StatefulWidget {
  const _ReportDialog({
    required this.kind,
    required this.walkId,
    required this.stopIndex,
    required this.repository,
  });

  final ReportKind kind;
  final String walkId;
  final int? stopIndex;
  final ReportRepository repository;

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  final _note = TextEditingController();
  String? _reason;
  String? _error;
  bool _sending = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reason;
    if (reason == null || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    final note = _note.text.trim();
    try {
      await widget.repository.send(
        kind: widget.kind,
        walkId: widget.walkId,
        stopIndex: widget.stopIndex,
        detail: note.isEmpty ? reason : '$reason\n$note',
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = error.userMessage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (widget.kind) {
      ReportKind.place => '报告这个地点',
      ReportKind.task => '报告这个任务',
      ReportKind.story => '报告这个故事',
    };
    final reasons = [
      '内容不当或令人不适',
      if (widget.kind == ReportKind.place) '地点不存在、已关闭或不安全',
      '和实际情况不符',
      '其他',
    ];
    return PopScope(
      canPop: !_sending,
      child: AlertDialog(
        title: Text(title),
        scrollable: true,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: FreshSpace.sm,
              runSpacing: FreshSpace.sm,
              children: [
                for (final reason in reasons)
                  ChoiceChip(
                    label: Text(reason),
                    selected: _reason == reason,
                    onSelected: _sending
                        ? null
                        : (selected) {
                            setState(() => _reason = selected ? reason : null);
                          },
                  ),
              ],
            ),
            const SizedBox(height: FreshSpace.md),
            TextField(
              controller: _note,
              enabled: !_sending,
              maxLength: 500,
              decoration: const InputDecoration(labelText: '补充说明（可选）'),
            ),
            if (_error != null)
              Text(
                _error!,
                style: Theme.of(context).textTheme.bodyMedium!
                    .copyWith(color: FreshColors.error),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _sending ? null : () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: _reason == null || _sending ? null : _submit,
            child: _sending
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 1.2),
                  )
                : const Text('提交'),
          ),
        ],
      ),
    );
  }
}
