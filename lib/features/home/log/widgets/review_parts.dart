import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mambo/theme/tokens.dart';
import 'package:mambo/widgets/botanical.dart';
import 'package:mambo/widgets/curly_underline_headline.dart';
import 'package:mambo/widgets/fresh_surface.dart';

import '../../../../services/log_service.dart';

/// Thin step indicator; tapping a dot jumps to that step.
class StepDots extends StatelessWidget {
  const StepDots({super.key, required this.count, required this.current, this.onTap});

  final int count;
  final int current;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          Semantics(
            button: onTap != null,
            selected: i == current,
            label: '第 ${i + 1} 步',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap == null ? null : () => onTap!(i),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                child: AnimatedContainer(
                  duration: FreshMotion.of(context, FreshMotion.gentle),
                  curve: FreshMotion.curve,
                  width: i == current ? 20 : 6,
                  height: 3,
                  decoration: BoxDecoration(
                    color: i == current ? FreshColors.sky : FreshColors.line,
                    borderRadius: const BorderRadius.all(Radius.circular(2)),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// A square photo thumbnail with a quiet placeholder.
class Thumbnail extends StatelessWidget {
  const Thumbnail(this.url, {super.key, this.size = 88});

  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: FreshRadius.button,
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder:
            (_, _, _) => Container(
              width: size,
              height: size,
              color: FreshColors.tint(FreshColors.line, 0.5),
              child: const Icon(Icons.image_not_supported_outlined, size: 20),
            ),
      ),
    );
  }
}

/// One recorded moment in the review list.
class LogEntryTile extends StatelessWidget {
  const LogEntryTile({super.key, required this.entry, required this.onTap});

  final LogEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final time = DateFormat('M月d日 HH:mm', 'zh_CN').format(entry.timestamp.toLocal());
    final address = entry.address ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: FreshSpace.md),
      child: FreshCard(
        padding: const EdgeInsets.all(FreshSpace.sm),
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Thumbnail(entry.imageUrl),
            const SizedBox(width: FreshSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: FreshSpace.xs),
                  Text(
                    entry.description?.isNotEmpty == true ? entry.description! : '没有写下文字',
                    style: text.bodyMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: FreshSpace.sm),
                  if (address.isNotEmpty)
                    Text(address, style: text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(time, style: text.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A reflection question, quick replies and the answer field.
class ReflectionQuestion extends StatelessWidget {
  const ReflectionQuestion({
    super.key,
    required this.question,
    required this.controller,
    this.onRefresh,
    this.refreshing = false,
    this.quickReplies = const [],
    this.botanical = BotanicalKind.sprig,
  });

  final String question;
  final TextEditingController controller;
  final VoidCallback? onRefresh;
  final bool refreshing;
  final List<String> quickReplies;
  final BotanicalKind botanical;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        FreshSpace.page + 8,
        FreshSpace.xxl,
        FreshSpace.page,
        FreshSpace.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: const Alignment(0.6, 0),
            child: Botanical(kind: botanical, size: 72, opacity: 0.75),
          ),
          const SizedBox(height: FreshSpace.xl),
          AnimatedSwitcher(
            duration: FreshMotion.of(context),
            child: Text(question, key: ValueKey(question), style: text.headlineSmall),
          ),
          if (onRefresh != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: refreshing ? null : onRefresh,
                icon:
                    refreshing
                        ? const SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 1.2))
                        : const Icon(Icons.autorenew, size: 18),
                label: const Text('换一组问题'),
              ),
            ),
          const SizedBox(height: FreshSpace.lg),
          if (quickReplies.isNotEmpty) ...[
            Wrap(
              spacing: FreshSpace.sm,
              runSpacing: FreshSpace.sm,
              children: [
                for (final label in quickReplies)
                  ActionChip(
                    label: Text(label),
                    onPressed: () {
                      final current = controller.text.trim();
                      controller.text = current.isEmpty ? label : '$current  $label';
                    },
                  ),
              ],
            ),
            const SizedBox(height: FreshSpace.lg),
          ],
          TextField(
            controller: controller,
            minLines: 1,
            maxLines: 6,
            decoration: const InputDecoration(labelText: '写下你的感受…'),
          ),
        ],
      ),
    );
  }
}

/// A headed block of the review summary: the question in soft grey and the
/// answer below it.
class ReviewSection extends StatelessWidget {
  const ReviewSection({super.key, required this.title, this.question, this.answer, this.child});

  final String title;
  final String? question;
  final String? answer;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final answer = this.answer?.trim() ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: FreshSpace.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          curlyUnderlineHeadline(title, text.titleMedium!),
          const SizedBox(height: FreshSpace.sm),
          if (question != null && question!.isNotEmpty) ...[
            Text(question!, style: text.bodySmall),
            const SizedBox(height: FreshSpace.xs),
          ],
          if (this.answer != null) Text(answer.isEmpty ? '—' : answer, style: text.bodyLarge),
          ?child,
        ],
      ),
    );
  }
}
