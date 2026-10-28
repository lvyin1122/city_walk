import 'package:mambo/theme/app_theme.dart';
import 'package:mambo/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:mambo/core/format/formatters.dart';
import 'package:mambo/features/walk/data/walk_repository.dart';
import 'package:mambo/features/walk/domain/walk.dart';
import 'package:mambo/widgets/botanical.dart';
import 'package:mambo/widgets/fresh_surface.dart';

import '../../../services/auth_service.dart';
import '../../walk/walk_summary.dart';

/// List of completed walks. Shown inside [HistoryTab], which provides the
/// app bar.
class WalkHistoryPage extends StatefulWidget {
  const WalkHistoryPage({super.key});

  @override
  State<WalkHistoryPage> createState() => _WalkHistoryPageState();
}

class _WalkHistoryPageState extends State<WalkHistoryPage> {
  final WalkRepository _repository = WalkRepository();
  bool _isLoading = true;
  String? _error;
  List<Walk> _walks = [];

  @override
  void initState() {
    super.initState();
    _fetchCompletedWalks();
  }

  Future<void> _fetchCompletedWalks() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final user = AuthService().getCurrentUser();
    if (user == null) {
      setState(() {
        _error = '用户未登录。';
        _isLoading = false;
      });
      return;
    }
    try {
      final walks = await _repository.getCompletedWalks(user.id);
      if (!mounted) return;
      setState(() {
        _walks = walks;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '加载已完成的步行失败：$e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 1.2));
    }
    if (_error != null) {
      return _CenteredMessage(
        message: _error!,
        actionLabel: '重试',
        onAction: _fetchCompletedWalks,
      );
    }
    if (_walks.isEmpty) {
      return const _CenteredMessage(message: '还没有完成的步行。\n去「漫步」生成你的第一条路线吧。');
    }
    return RefreshIndicator(
      onRefresh: _fetchCompletedWalks,
      color: FreshColors.sky,
      backgroundColor: FreshColors.paper,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(FreshSpace.page, FreshSpace.xl, FreshSpace.page, FreshSpace.xxl),
        itemCount: _walks.length,
        separatorBuilder: (_, _) => const SizedBox(height: FreshSpace.md),
        itemBuilder: (context, index) => WalkHistoryCard(walk: _walks[index]),
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(FreshSpace.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Botanical(kind: BotanicalKind.bamboo, size: 72),
            const SizedBox(height: FreshSpace.lg),
            Text(
              message,
              style: context.text.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: FreshSpace.lg),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// One completed walk in the history list.
class WalkHistoryCard extends StatelessWidget {
  const WalkHistoryCard({super.key, required this.walk});

  final Walk walk;

  String get _duration {
    final timeSpent = walk.timeSpent;
    if (timeSpent != null) return formatElapsed(timeSpent);
    final planned = walk.plannedMinutes;
    return planned != null ? formatMinutes(planned) : '--';
  }

  String get _distance {
    final distance = walk.distanceKm;
    return distance != null ? formatKilometers(distance) : '--';
  }

  @override
  Widget build(BuildContext context) {
    final address = formatUserAddress(walk.userAddress);

    final text = context.text;
    return FreshCard(
      padding: const EdgeInsets.symmetric(vertical: FreshSpace.lg, horizontal: FreshSpace.md),
      onTap:
          () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (context) => WalkSummary(walkId: walk.id, isNew: false),
            ),
          ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            SizedBox(
              width: 84,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(formatDayOfWeek(walk.createdAt), style: text.bodySmall),
                  Text(formatMonthDay(walk.createdAt), style: text.titleLarge),
                  const SizedBox(height: FreshSpace.sm),
                  _IconLabel(icon: Icons.schedule_outlined, label: _duration),
                  _IconLabel(icon: Icons.straighten, label: _distance),
                ],
              ),
            ),
            Container(
              width: FreshBorders.hairlineWidth,
              color: FreshColors.line,
              margin: const EdgeInsets.symmetric(horizontal: FreshSpace.md),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(formatTimeOfDay(walk.createdAt), style: text.bodySmall),
                  const SizedBox(height: 2),
                  Text(
                    walk.title.isNotEmpty ? walk.title : '城市漫步',
                    style: text.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (address.isNotEmpty)
                    Text(
                      address,
                      style: text.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: FreshSpace.md),
                  Row(
                    children: [
                      _Count(
                        icon: Icons.place_outlined,
                        color: FreshColors.skyText,
                        tooltip: '到达的地点',
                        count: walk.collectedStops.length,
                      ),
                      const SizedBox(width: FreshSpace.lg),
                      _Count(
                        icon: Icons.task_alt,
                        color: FreshColors.mintText,
                        tooltip: '完成的任务',
                        count: walk.completedTaskCount,
                      ),
                      const SizedBox(width: FreshSpace.lg),
                      _Count(
                        icon: Icons.favorite_border,
                        color: const Color(0xFFD9788E),
                        tooltip: '惊喜地点',
                        count: walk.surprises.length,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconLabel extends StatelessWidget {
  const _IconLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 14, color: FreshColors.inkSoft),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            style: context.text.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.count,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: FreshSpace.xs),
          Text('$count', style: context.text.bodyMedium),
        ],
      ),
    );
  }
}
