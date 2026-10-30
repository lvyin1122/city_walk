import 'package:flutter/material.dart';
import 'package:mambo/core/format/formatters.dart';
import 'package:mambo/core/geo/geo_point.dart';
import 'package:mambo/theme/tokens.dart';
import 'package:mambo/widgets/fresh_surface.dart';

import '../domain/walk.dart';
import 'walk_panels.dart';

abstract final class WalkTouch {
  static const double primary = 56;
  static const double secondary = 48;
}

/// The next place to walk to, with directions or a nearby manual check-in.
class NextStopCard extends StatelessWidget {
  const NextStopCard({
    super.key,
    required this.stop,
    this.number,
    this.distanceMeters,
    this.canCheckIn = false,
    this.onNavigate,
    this.onCheckIn,
  });

  final WalkStop? stop;
  final int? number;
  final double? distanceMeters;
  final bool canCheckIn;
  final VoidCallback? onNavigate;
  final VoidCallback? onCheckIn;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final stop = this.stop;
    if (stop == null) {
      return Row(children: [
        const Icon(Icons.task_alt, color: FreshColors.mintText),
        const SizedBox(width: FreshSpace.sm),
        Expanded(child: Text('所有地点都到达了', style: text.bodyLarge)),
      ]);
    }
    final meters = distanceMeters;
    final minutes = meters == null ? 0 : walkingMinutes(meters).round();
    final distance = meters == null
        ? '正在定位…'
        : '${formatDistance(meters)} · ${minutes < 1 ? '就在附近' : '步行约 ${formatMinutes(minutes)}'}';
    final style = OutlinedButton.styleFrom(
      minimumSize: const Size(0, WalkTouch.secondary),
      padding: const EdgeInsets.symmetric(horizontal: FreshSpace.sm),
    );
    return Row(children: [
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(number == null ? '下一站' : '下一站 · 第 $number 站',
            style: text.labelMedium!.copyWith(fontWeight: FreshWeights.regular)),
          Text(stop.name.isEmpty ? '未命名地点' : stop.name,
            style: text.titleMedium!.copyWith(fontWeight: FreshWeights.regular),
            maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(distance, style: text.bodyMedium),
        ],
      )),
      if ((canCheckIn && onCheckIn != null) || onNavigate != null)
        const SizedBox(width: FreshSpace.sm),
      if (canCheckIn && onCheckIn != null)
        FilledButton(style: style, onPressed: onCheckIn, child: const Text('我到了'))
      else if (onNavigate != null)
        OutlinedButton.icon(style: style, onPressed: onNavigate,
          icon: const Icon(Icons.near_me_outlined, size: 20), label: const Text('导航')),
    ]);
  }
}

/// A persistent photo task with a thumb-sized camera action.
class TaskCard extends StatefulWidget {
  const TaskCard({
    super.key,
    required this.task,
    required this.loading,
    required this.uploading,
    required this.photosFulfilled,
    required this.onAddPhoto,
    required this.onNewTask,
    this.onReport,
  });

  final WalkTask? task;
  final bool loading;
  final bool uploading;
  final int photosFulfilled;
  final VoidCallback onAddPhoto;
  final VoidCallback onNewTask;
  final VoidCallback? onReport;

  @override
  State<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard> {
  bool _expanded = false;

  @override
  void didUpdateWidget(TaskCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.task != widget.task) _expanded = false;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final task = widget.task;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: [
          Expanded(child: Text('拍摄任务',
            style: text.labelMedium!.copyWith(fontWeight: FreshWeights.regular))),
          if (widget.onReport != null)
            IconButton(constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              icon: const Icon(Icons.flag_outlined), tooltip: '报告这个任务',
              onPressed: widget.onReport),
          IconButton(constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: const Icon(Icons.autorenew), tooltip: '换一个任务',
            onPressed: widget.loading ? null : widget.onNewTask),
        ]),
        if (widget.loading && task == null)
          Row(children: [
            const _SmallSpinner(),
            const SizedBox(width: FreshSpace.sm),
            Expanded(child: Text('正在想一个新任务…', style: text.bodyLarge)),
          ])
        else if (task == null)
          Text('暂时没有任务', style: text.bodyLarge)
        else
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _expanded = !_expanded),
            child: Text(task.description,
              style: text.bodyLarge!.copyWith(color: FreshColors.ink),
              maxLines: _expanded ? null : 2,
              overflow: _expanded ? null : TextOverflow.ellipsis),
          ),
        if (task != null && task.photosRequired > 0) ...[
          const SizedBox(height: FreshSpace.sm),
          SegmentedProgress(done: widget.photosFulfilled, total: task.photosRequired),
          Text('${widget.photosFulfilled}/${task.photosRequired} 张', style: text.bodyMedium),
        ],
        const SizedBox(height: FreshSpace.md),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, WalkTouch.primary)),
          onPressed: widget.uploading || task == null ? null : widget.onAddPhoto,
          icon: widget.uploading ? const _SmallSpinner() : const Icon(Icons.photo_camera_outlined),
          label: Text(widget.uploading ? '正在查看照片…' : '拍任务照片'),
        ),
      ],
    );
  }
}

/// Pause, capture a surprise, or finish without reaching across the map.
class WalkActionBar extends StatelessWidget {
  const WalkActionBar({
    super.key,
    required this.surpriseMarked,
    required this.uploadingSurprise,
    required this.onPause,
    required this.onSurprise,
    required this.onFinish,
  });

  final bool surpriseMarked;
  final bool uploadingSurprise;
  final VoidCallback onPause;
  final VoidCallback onSurprise;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final style = OutlinedButton.styleFrom(
      minimumSize: const Size(0, WalkTouch.secondary),
      padding: const EdgeInsets.symmetric(horizontal: FreshSpace.sm),
    );
    return Row(children: [
      OutlinedButton.icon(style: style, onPressed: onPause,
        icon: const Icon(Icons.pause, size: 20), label: const Text('暂停')),
      const SizedBox(width: FreshSpace.sm),
      Expanded(child: OutlinedButton.icon(
        style: style.copyWith(backgroundColor: WidgetStatePropertyAll(
          surpriseMarked ? FreshColors.tint(FreshColors.pink, 0.35) : FreshColors.paper)),
        onPressed: uploadingSurprise ? null : onSurprise,
        icon: uploadingSurprise ? const _SmallSpinner()
          : Icon(surpriseMarked ? Icons.favorite : Icons.favorite_border, size: 20),
        label: Text(uploadingSurprise ? '上传中…' : surpriseMarked ? '已记下惊喜' : '这里让我惊喜',
          textAlign: TextAlign.center),
      )),
      const SizedBox(width: FreshSpace.sm),
      OutlinedButton(style: style, onPressed: onFinish, child: const Text('结束')),
    ]);
  }
}

class LocationNotice extends StatelessWidget {
  const LocationNotice({
    super.key,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => MapPanel(child: Row(children: [
    const Icon(Icons.location_off_outlined, color: FreshColors.error),
    const SizedBox(width: FreshSpace.sm),
    Expanded(child: Text(message,
      style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: FreshColors.ink))),
    TextButton(onPressed: onAction, child: Text(actionLabel)),
  ]));
}

class _SmallSpinner extends StatelessWidget {
  const _SmallSpinner();

  @override
  Widget build(BuildContext context) => const SizedBox.square(
    dimension: 16,
    child: CircularProgressIndicator(strokeWidth: 1.2),
  );
}
