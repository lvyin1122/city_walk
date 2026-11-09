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

/// A place the user tapped on the map: what it is, how far it is, and
/// directions or a nearby manual check-in. Stops have no order; this card
/// shows only while one is selected.
///
/// Needs a bounded height: the description scrolls inside the card and
/// shrinks when space is short, so the buttons always stay visible.
class StopCard extends StatelessWidget {
  const StopCard({
    super.key,
    required this.stop,
    required this.onClose,
    this.distanceMeters,
    this.reached = false,
    this.canCheckIn = false,
    this.onNavigate,
    this.onCheckIn,
    this.onShowPhotos,
    this.onReport,
  });

  final WalkStop stop;
  final double? distanceMeters;
  final bool reached;
  final bool canCheckIn;
  final VoidCallback onClose;
  final VoidCallback? onNavigate;
  final VoidCallback? onCheckIn;
  final VoidCallback? onShowPhotos;
  final VoidCallback? onReport;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final meters = distanceMeters;
    final minutes = meters == null ? 0 : walkingMinutes(meters).round();
    final status = reached
        ? '已到达'
        : meters == null
        ? '正在定位…'
        : '${formatDistance(meters)} · ${minutes < 1 ? '就在附近' : '步行约 ${formatMinutes(minutes)}'}';
    final style = OutlinedButton.styleFrom(
      minimumSize: const Size(0, WalkTouch.secondary),
      padding: const EdgeInsets.symmetric(horizontal: FreshSpace.sm),
    );
    const iconBox = BoxConstraints(minWidth: 48, minHeight: 48);
    final action = reached
        ? null
        : canCheckIn && onCheckIn != null
        ? FilledButton(style: style, onPressed: onCheckIn, child: const Text('我到了'))
        : onNavigate != null
        ? OutlinedButton.icon(style: style, onPressed: onNavigate,
            icon: const Icon(Icons.near_me_outlined, size: 20), label: const Text('导航'))
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: [
          Expanded(child: Text(stop.name.isEmpty ? '未命名地点' : stop.name,
            style: text.titleMedium!.copyWith(fontWeight: FreshWeights.regular),
            maxLines: 2, overflow: TextOverflow.ellipsis)),
          if (stop.photoUrls.isNotEmpty && onShowPhotos != null)
            IconButton(constraints: iconBox,
              icon: const Icon(Icons.photo_library_outlined, size: 20),
              tooltip: '看看照片', onPressed: onShowPhotos),
          if (onReport != null)
            IconButton(constraints: iconBox,
              icon: const Icon(Icons.flag_outlined, size: 20),
              tooltip: '报告这个地点', onPressed: onReport),
          IconButton(constraints: iconBox,
            icon: const Icon(Icons.close, size: 20),
            tooltip: '关闭', onPressed: onClose),
        ]),
        if (stop.description.isNotEmpty)
          Flexible(child: ScrollingText(stop.description,
            style: text.bodyMedium!, maxLines: 3)),
        const SizedBox(height: FreshSpace.sm),
        Row(children: [
          Expanded(child: Text(status, style: text.bodyMedium!.copyWith(
            color: reached ? FreshColors.mintText : null))),
          if (action != null) ...[const SizedBox(width: FreshSpace.sm), action],
        ]),
      ],
    );
  }
}

/// A persistent photo task with a thumb-sized camera action.
///
/// Needs a bounded height: a long description scrolls inside the card.
class TaskCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final task = this.task;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: [
          Expanded(child: Text('拍摄任务',
            style: text.labelMedium!.copyWith(fontWeight: FreshWeights.regular))),
          if (onReport != null)
            IconButton(constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              icon: const Icon(Icons.flag_outlined), tooltip: '报告这个任务',
              onPressed: onReport),
          IconButton(constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: const Icon(Icons.autorenew), tooltip: '换一个任务',
            onPressed: loading ? null : onNewTask),
        ]),
        if (loading && task == null)
          Row(children: [
            const _SmallSpinner(),
            const SizedBox(width: FreshSpace.sm),
            Expanded(child: Text('正在想一个新任务…', style: text.bodyLarge)),
          ])
        else if (task == null)
          Text('暂时没有任务', style: text.bodyLarge)
        else
          Flexible(child: ScrollingText(task.description,
            style: text.bodyLarge!.copyWith(color: FreshColors.ink), maxLines: 4)),
        if (task != null && task.photosRequired > 0) ...[
          const SizedBox(height: FreshSpace.sm),
          SegmentedProgress(done: photosFulfilled, total: task.photosRequired),
          Text('$photosFulfilled/${task.photosRequired} 张', style: text.bodyMedium),
        ],
        const SizedBox(height: FreshSpace.md),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, WalkTouch.primary)),
          onPressed: uploading || task == null ? null : onAddPhoto,
          icon: uploading ? const _SmallSpinner() : const Icon(Icons.photo_camera_outlined),
          label: Text(uploading ? '正在查看照片…' : '拍任务照片'),
        ),
      ],
    );
  }
}

/// Text that is at most [maxLines] high and scrolls inside its card when it
/// is longer. Put it in a [Flexible] so it also gives way on short screens.
class ScrollingText extends StatefulWidget {
  const ScrollingText(this.text, {super.key, required this.style, required this.maxLines});

  final String text;
  final TextStyle style;
  final int maxLines;

  @override
  State<ScrollingText> createState() => _ScrollingTextState();
}

class _ScrollingTextState extends State<ScrollingText> {
  final _controller = ScrollController();

  @override
  void didUpdateWidget(ScrollingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new text starts at its beginning.
    if (oldWidget.text != widget.text && _controller.hasClients) _controller.jumpTo(0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = widget.style.fontSize ?? 14;
    final lineHeight = MediaQuery.textScalerOf(context).scale(fontSize) * (widget.style.height ?? 1.2);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: lineHeight * widget.maxLines + 1),
      child: Scrollbar(
        controller: _controller,
        child: SingleChildScrollView(
          controller: _controller,
          child: Text(widget.text, style: widget.style),
        ),
      ),
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
