import 'package:flutter/material.dart';
import 'package:mambo/core/format/formatters.dart';
import 'package:mambo/features/walk/data/walk_repository.dart';
import 'package:mambo/features/walk/domain/walk.dart';

import '../../../services/auth_service.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
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
      return const Center(child: CircularProgressIndicator());
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
      child: ListView.builder(
        itemCount: _walks.length,
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
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              style: AppTextStyles.bodyText1,
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 12),
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

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => WalkSummary(walkId: walk.id, isNew: false),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
          child: Row(
            children: [
              Flexible(
                flex: 2,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      formatDayOfWeek(walk.createdAt),
                      style: AppTextStyles.headline4,
                    ),
                    Text(
                      formatMonthDay(walk.createdAt),
                      style: AppTextStyles.headline5,
                    ),
                    const SizedBox(height: 4),
                    _IconLabel(icon: Icons.timer, label: _duration),
                    const SizedBox(height: 4),
                    _IconLabel(icon: Icons.social_distance, label: _distance),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 100,
                color: AppColors.separatorColor,
                margin: const EdgeInsets.symmetric(horizontal: 12.0),
              ),
              Flexible(
                flex: 7,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatTimeOfDay(walk.createdAt),
                        style: AppTextStyles.bodyText2,
                      ),
                      Text(
                        walk.title.isNotEmpty ? walk.title : '城市漫步',
                        style: AppTextStyles.headline4,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (address.isNotEmpty)
                        Text(
                          address,
                          style: AppTextStyles.bodyText2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _Count(
                            icon: Icons.place,
                            tooltip: '到达的地点',
                            count: walk.collectedStops.length,
                          ),
                          const SizedBox(width: 16),
                          _Count(
                            icon: Icons.check_circle,
                            tooltip: '完成的任务',
                            count: walk.completedTaskCount,
                          ),
                          const SizedBox(width: 16),
                          _Count(
                            icon: Icons.favorite,
                            tooltip: '惊喜地点',
                            count: walk.surprises.length,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
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
        Icon(icon, size: 16, color: AppColors.primaryColor),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            style: AppTextStyles.bodyText2,
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
    required this.tooltip,
    required this.count,
  });

  final IconData icon;
  final String tooltip;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Row(
        children: [
          Icon(icon, size: 24, color: AppColors.primaryColor),
          const SizedBox(width: 4),
          Text('$count', style: AppTextStyles.bodyText1),
        ],
      ),
    );
  }
}
