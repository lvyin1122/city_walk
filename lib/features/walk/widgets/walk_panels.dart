import 'package:flutter/material.dart';
import 'package:mambo/core/format/formatters.dart';
import 'package:mambo/theme/tokens.dart';
import 'package:mambo/widgets/fresh_surface.dart';

import '../domain/walk.dart';

/// A translucent rice-paper panel that floats over the map.
class MapPanel extends StatelessWidget {
  const MapPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(FreshSpace.md),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: FreshMotion.of(context),
      curve: FreshMotion.curve,
      padding: padding,
      decoration: BoxDecoration(
        color: FreshColors.paper.withValues(alpha: 0.94),
        borderRadius: FreshRadius.card,
        border: FreshBorders.all,
      ),
      child: child,
    );
  }
}

/// Time and distance walked, side by side.
class WalkStatsLine extends StatelessWidget {
  const WalkStatsLine({super.key, required this.elapsed, required this.distanceKm});

  final Duration elapsed;
  final double distanceKm;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleMedium;
    Widget item(IconData icon, String value, String label) => Expanded(
      child: Semantics(
        label: '$label $value',
        excludeSemantics: true,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: FreshColors.inkSoft),
            const SizedBox(width: FreshSpace.sm),
            Text(value, style: style),
          ],
        ),
      ),
    );
    return Row(
      children: [
        item(Icons.schedule_outlined, formatElapsed(elapsed), '已步行'),
        Container(width: FreshBorders.hairlineWidth, height: 20, color: FreshColors.line),
        item(Icons.directions_walk_outlined, formatKilometers(distanceKm), '距离'),
      ],
    );
  }
}

/// The current photo task: countdown, description, progress and the button to
/// add a photo.
class TaskPanel extends StatelessWidget {
  const TaskPanel({
    super.key,
    required this.task,
    required this.loading,
    required this.uploading,
    required this.photosFulfilled,
    required this.countdownSeconds,
    required this.urgent,
    required this.onAddPhoto,
    required this.onNewTask,
  });

  final WalkTask? task;
  final bool loading;
  final bool uploading;
  final int photosFulfilled;
  final int countdownSeconds;
  final bool urgent;
  final VoidCallback onAddPhoto;
  final VoidCallback onNewTask;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: FreshSpace.lg),
        child: Center(
          child: SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 1.2),
          ),
        ),
      );
    }
    final task = this.task;
    final countdown =
        '${(countdownSeconds ~/ 60).toString().padLeft(2, '0')}:'
        '${(countdownSeconds % 60).toString().padLeft(2, '0')}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('此刻的拍摄任务', style: text.labelMedium),
            const Spacer(),
            if (task != null)
              AnimatedDefaultTextStyle(
                duration: FreshMotion.of(context),
                curve: FreshMotion.curve,
                style: text.labelMedium!.copyWith(
                  color: urgent ? FreshColors.error : FreshColors.body,
                ),
                child: Text('下个任务 $countdown'),
              ),
          ],
        ),
        const SizedBox(height: FreshSpace.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(task?.description ?? '暂时没有任务', style: text.bodyLarge),
            ),
            IconButton(
              icon: const Icon(Icons.autorenew, size: 20),
              tooltip: '换一个任务',
              onPressed: onNewTask,
            ),
          ],
        ),
        if (task != null && task.photosRequired > 0) ...[
          const SizedBox(height: FreshSpace.sm),
          SegmentedProgress(done: photosFulfilled, total: task.photosRequired),
        ],
        const SizedBox(height: FreshSpace.md),
        OutlinedButton.icon(
          onPressed: uploading || task == null ? null : onAddPhoto,
          icon:
              uploading
                  ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 1.2),
                  )
                  : const Icon(Icons.photo_camera_outlined, size: 20),
          label: Text(uploading ? '正在查看照片…' : '添加任务照片'),
        ),
      ],
    );
  }
}

/// Details of a stop the user tapped on the map.
class StopDetail extends StatelessWidget {
  const StopDetail({
    super.key,
    required this.stop,
    required this.walkingTime,
    required this.reached,
    required this.onShowPhotos,
    required this.onClose,
  });

  final WalkStop stop;
  final String walkingTime;
  final bool reached;
  final VoidCallback onShowPhotos;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(child: Text(stop.name, style: text.titleMedium)),
            if (stop.photoUrls.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.photo_library_outlined, size: 20),
                tooltip: '看看照片',
                onPressed: onShowPhotos,
              ),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              tooltip: '关闭',
              onPressed: onClose,
            ),
          ],
        ),
        if (stop.description.isNotEmpty)
          Text(stop.description, style: text.bodyMedium),
        const SizedBox(height: FreshSpace.sm),
        Text(
          reached ? '已到达' : '步行约 $walkingTime',
          style: text.labelMedium!.copyWith(
            color: reached ? FreshColors.mintText : FreshColors.body,
          ),
        ),
      ],
    );
  }
}

/// Stops reached, tasks completed and surprises found.
class WalkTally extends StatelessWidget {
  const WalkTally({
    super.key,
    required this.stopsReached,
    required this.stopsTotal,
    required this.tasksCompleted,
    required this.surprises,
  });

  final int stopsReached;
  final int stopsTotal;
  final int tasksCompleted;
  final int surprises;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget item(IconData icon, Color color, String value, String label) =>
        Expanded(
          child: Semantics(
            label: '$label $value',
            excludeSemantics: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(height: FreshSpace.xs),
                Text(value, style: text.titleMedium),
                Text(label, style: text.labelSmall),
              ],
            ),
          ),
        );
    return Row(
      children: [
        item(Icons.place_outlined, FreshColors.skyText, '$stopsReached/$stopsTotal', '地点'),
        item(Icons.task_alt, FreshColors.mintText, '$tasksCompleted', '任务'),
        item(
          surprises > 0 ? Icons.favorite : Icons.favorite_border,
          surprises > 0 ? const Color(0xFFD9788E) : FreshColors.inkSoft,
          '$surprises',
          '惊喜',
        ),
      ],
    );
  }
}

/// A small square button floating over the map.
class MapButton extends StatelessWidget {
  const MapButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: FreshColors.paper.withValues(alpha: 0.94),
        shape: RoundedRectangleBorder(
          borderRadius: FreshRadius.button,
          side: FreshBorders.hairline,
        ),
        child: InkWell(
          borderRadius: FreshRadius.button,
          onTap: onPressed,
          child: SizedBox.square(
            dimension: 44,
            child: Icon(icon, size: 20, color: FreshColors.ink),
          ),
        ),
      ),
    );
  }
}
