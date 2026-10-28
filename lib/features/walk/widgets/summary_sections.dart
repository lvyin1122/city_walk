import 'package:flutter/material.dart';
import 'package:mambo/core/format/formatters.dart';
import 'package:mambo/theme/tokens.dart';
import 'package:mambo/widgets/botanical.dart';
import 'package:mambo/widgets/fresh_surface.dart';

import '../domain/walk.dart';

/// Stops, tasks, time and distance of a finished walk.
class WalkStatsCard extends StatelessWidget {
  const WalkStatsCard({super.key, required this.walk});

  final Walk walk;

  @override
  Widget build(BuildContext context) {
    final timeSpent = walk.timeSpent;
    final planned = walk.plannedMinutes;
    final distance = walk.distanceKm;
    final rows = [
      (Icons.place_outlined, FreshColors.skyText, '地点', '${walk.collectedStops.length}/${walk.selectedStops.length}'),
      (Icons.task_alt, FreshColors.mintText, '任务', '${walk.completedTaskCount}'),
      (
        Icons.schedule_outlined,
        FreshColors.inkSoft,
        '时长',
        timeSpent != null
            ? formatElapsed(timeSpent)
            : planned != null
            ? formatMinutes(planned)
            : '--',
      ),
      (Icons.straighten, FreshColors.inkSoft, '距离', distance != null ? formatKilometers(distance) : '--'),
    ];
    final text = Theme.of(context).textTheme;
    return FreshCard(
      padding: const EdgeInsets.symmetric(horizontal: FreshSpace.lg, vertical: FreshSpace.sm),
      child: Column(
        children: [
          for (final (i, (icon, color, label, value)) in rows.indexed) ...[
            if (i > 0) const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: FreshSpace.md),
              child: Row(
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: FreshSpace.md),
                  Text(label, style: text.bodyMedium),
                  const Spacer(),
                  Text(value, style: text.titleMedium),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The AI-written story of the walk, with loading and retry states.
class WalkStoryCard extends StatelessWidget {
  const WalkStoryCard({
    super.key,
    required this.story,
    required this.failed,
    required this.onRetry,
  });

  /// Null while loading.
  final String? story;
  final bool failed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final story = this.story;
    final Widget body;
    if (failed) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('故事暂时没有写出来。', style: text.bodyMedium),
          TextButton(onPressed: onRetry, child: const Text('再试一次')),
        ],
      );
    } else if (story == null) {
      body = Row(
        children: [
          const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 1.2)),
          const SizedBox(width: FreshSpace.md),
          Expanded(child: Text('正在为你写下这次步行的故事…', style: text.bodyMedium)),
        ],
      );
    } else {
      body = Text(
        story.isNotEmpty ? story : '这次步行还没有故事。',
        style: text.bodyLarge!.copyWith(height: 1.9),
      );
    }

    return FreshCard(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned(
            right: -FreshSpace.sm,
            top: -FreshSpace.sm,
            child: Botanical(kind: BotanicalKind.blossom, size: 56, opacity: 0.6),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('你的步行故事', style: text.titleMedium),
              const SizedBox(height: FreshSpace.lg),
              AnimatedSwitcher(duration: FreshMotion.of(context), child: body),
            ],
          ),
        ],
      ),
    );
  }
}

/// A titled grid of photo thumbnails that open full size when tapped.
class PhotoGrid extends StatelessWidget {
  const PhotoGrid({
    super.key,
    required this.title,
    required this.photoUrls,
    required this.onTap,
  });

  final String title;
  final List<String> photoUrls;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: text.titleMedium),
        const SizedBox(height: FreshSpace.md),
        if (photoUrls.isEmpty)
          Text('本次步行暂无照片', style: text.bodySmall)
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: FreshSpace.sm,
              mainAxisSpacing: FreshSpace.sm,
            ),
            itemCount: photoUrls.length,
            itemBuilder: (context, index) {
              final url = photoUrls[index];
              return Semantics(
                button: true,
                label: '$title ${index + 1}',
                child: GestureDetector(
                  onTap: () => onTap(url),
                  child: ClipRRect(
                    borderRadius: FreshRadius.button,
                    child: Image.network(
                      url,
                      fit: BoxFit.cover,
                      loadingBuilder:
                          (context, child, progress) =>
                              progress == null
                                  ? child
                                  : ColoredBox(color: FreshColors.tint(FreshColors.line, 0.4)),
                      errorBuilder:
                          (context, error, stackTrace) => ColoredBox(
                            color: FreshColors.tint(FreshColors.line, 0.4),
                            child: const Icon(Icons.image_not_supported_outlined, color: FreshColors.inkSoft),
                          ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

/// One photo, full size and zoomable, on a rice-paper sheet.
Future<void> showPhotoViewer(BuildContext context, String imageUrl) {
  return showDialog<void>(
    context: context,
    builder:
        (context) => Dialog(
          insetPadding: const EdgeInsets.all(FreshSpace.md),
          child: Padding(
            padding: const EdgeInsets.all(FreshSpace.sm),
            child: ClipRRect(
              borderRadius: FreshRadius.button,
              child: InteractiveViewer(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder:
                      (context, child, progress) =>
                          progress == null
                              ? child
                              : const SizedBox(
                                height: 240,
                                child: Center(child: CircularProgressIndicator(strokeWidth: 1.2)),
                              ),
                  errorBuilder:
                      (context, error, stackTrace) => const SizedBox(
                        height: 160,
                        child: Center(child: Icon(Icons.image_not_supported_outlined, size: 40)),
                      ),
                ),
              ),
            ),
          ),
        ),
  );
}
