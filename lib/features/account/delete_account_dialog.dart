import 'package:flutter/material.dart';
import 'package:mambo/core/api/api_exception.dart';
import 'package:mambo/theme/tokens.dart';

/// Requires a second, typed confirmation before deleting the account.
class DeleteAccountDialog extends StatefulWidget {
  const DeleteAccountDialog({super.key, required this.onDelete});

  final Future<void> Function() onDelete;

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  final _confirmation = TextEditingController();
  bool _confirming = false;
  bool _deleting = false;
  String? _error;

  @override
  void dispose() {
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_deleting || _confirmation.text.trim() != '删除') return;
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await widget.onDelete();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _error = error.userMessage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_deleting,
      child: AlertDialog(
        title: const Text('删除账号'),
        scrollable: true,
        content: _confirming
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('请输入「删除」确认'),
                  TextField(
                    controller: _confirmation,
                    enabled: !_deleting,
                    onChanged: (_) => setState(() {}),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: FreshSpace.md),
                    Text(
                      _error!,
                      style: Theme.of(context).textTheme.bodyMedium!
                          .copyWith(color: FreshColors.error),
                    ),
                  ],
                ],
              )
            : const Text('删除后，你的漫步记录、照片和轨迹都会被永久删除，无法恢复。'),
        actions: [
          TextButton(
            onPressed: _deleting
                ? null
                : () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          if (!_confirming)
            TextButton(
              onPressed: () => setState(() => _confirming = true),
              child: const Text('继续'),
            )
          else
            TextButton(
              onPressed: _deleting || _confirmation.text.trim() != '删除'
                  ? null
                  : _delete,
              style: TextButton.styleFrom(foregroundColor: FreshColors.error),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_deleting) ...[
                    const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 1.2),
                    ),
                    const SizedBox(width: FreshSpace.sm),
                  ],
                  const Text('永久删除'),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
