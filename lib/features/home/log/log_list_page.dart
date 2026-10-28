import 'package:mambo/widgets/botanical.dart';
import 'package:mambo/widgets/fresh_surface.dart';
import 'package:mambo/theme/app_theme.dart';
import 'package:mambo/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/log_service.dart';
import 'log_review_page.dart';

/// Groups logs by month and date for timeline display.
/// Keys: monthKey = "yyyy-MM", dateKey = "yyyy-MM-dd"
Map<String, Map<String, List<Log>>> _groupLogsByMonthAndDate(List<Log> logs) {
  final sorted = List<Log>.from(logs)
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  final Map<String, Map<String, List<Log>>> grouped = {};

  for (final log in sorted) {
    final d = log.createdAt.toLocal();
    final monthKey = '${d.year}-${d.month.toString().padLeft(2, '0')}';
    final dateKey =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    grouped.putIfAbsent(monthKey, () => {});
    grouped[monthKey]!.putIfAbsent(dateKey, () => []);
    grouped[monthKey]![dateKey]!.add(log);
  }

  // Sort dates within each month (newest first)
  for (final monthEntry in grouped.entries) {
    final dates =
        monthEntry.value.keys.toList()..sort((a, b) => b.compareTo(a));
    final sortedMonth = <String, List<Log>>{};
    for (final d in dates) {
      sortedMonth[d] = monthEntry.value[d]!;
    }
    grouped[monthEntry.key] = sortedMonth;
  }

  return grouped;
}

/// Timeline of free-form records. Shown inside [HistoryTab], which provides
/// the app bar.
class LogListPage extends StatefulWidget {
  const LogListPage({super.key});

  @override
  State<LogListPage> createState() => _LogListPageState();
}

class _LogListPageState extends State<LogListPage> {
  final LogService _logService = LogService();
  bool _isLoading = true;
  String? _error;
  List<Log> _logs = [];

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final logs = await _logService.getLogs();
      if (!mounted) return;
      setState(() {
        _logs = logs;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '加载记录失败：$e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 1.2));
    }
    final message = _error ?? (_logs.isEmpty ? '还没有记录。\n在「漫步」里点「直接开始记录」，随意走走。' : null);
    if (message != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(FreshSpace.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Botanical(kind: BotanicalKind.ginkgo, size: 72),
              const SizedBox(height: FreshSpace.lg),
              Text(message, style: context.text.bodyMedium, textAlign: TextAlign.center),
              if (_error != null) ...[
                const SizedBox(height: FreshSpace.lg),
                OutlinedButton(onPressed: _fetchLogs, child: const Text('重试')),
              ],
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      color: FreshColors.sky,
      backgroundColor: FreshColors.paper,
      onRefresh: _fetchLogs,
      child: _buildTimeline(),
    );
  }

  Widget _buildTimeline() {
    final grouped = _groupLogsByMonthAndDate(_logs);
    final monthKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(FreshSpace.page, FreshSpace.md, FreshSpace.page, FreshSpace.xxl),
      itemCount: _timelineItemCount(grouped, monthKeys),
      itemBuilder:
          (context, index) => _buildTimelineItem(grouped, monthKeys, index),
    );
  }

  int _timelineItemCount(
    Map<String, Map<String, List<Log>>> grouped,
    List<String> monthKeys,
  ) {
    int count = 0;
    for (final monthKey in monthKeys) {
      count += 1; // month header
      for (final _ in grouped[monthKey]!.keys) {
        count += 1; // day row only
      }
    }
    return count;
  }

  Widget _buildTimelineItem(
    Map<String, Map<String, List<Log>>> grouped,
    List<String> monthKeys,
    int index,
  ) {
    int remaining = index;
    for (final monthKey in monthKeys) {
      if (remaining == 0) {
        return _buildMonthHeader(monthKey);
      }
      remaining -= 1;

      for (final dateKey in grouped[monthKey]!.keys) {
        if (remaining == 0) {
          final logs = grouped[monthKey]![dateKey]!;
          return _buildDayRow(dateKey, logs);
        }
        remaining -= 1;
      }
    }
    return const SizedBox.shrink();
  }

  Widget _buildMonthHeader(String monthKey) {
    final parts = monthKey.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final date = DateTime(year, month, 1);
    final label = DateFormat('yyyy年M月', 'zh_CN').format(date);

    return Padding(
      padding: const EdgeInsets.only(top: FreshSpace.xl, bottom: FreshSpace.md),
      child: Text(label, style: context.text.headlineSmall),
    );
  }

  Widget _buildDayRow(String dateKey, List<Log> logs) {
    final parts = dateKey.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final day = int.parse(parts[2]);
    final date = DateTime(year, month, day);
    final dateLabel = DateFormat('M月d日 EEEE', 'zh_CN').format(date);

    // Use primary (most recent) log for times
    final primaryLog = logs.first;
    final creationTime =
        DateFormat('HH:mm', 'zh_CN').format(primaryLog.createdAt.toLocal());

    DateTime? startTime;
    for (final log in logs) {
      if (log.entries.isNotEmpty) {
        final entries = List<LogEntry>.from(log.entries)
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
        final first = entries.first.timestamp.toLocal();
        if (startTime == null || first.isBefore(startTime)) {
          startTime = first;
        }
      }
    }
    final startingTimeStr =
        startTime != null ? DateFormat('HH:mm', 'zh_CN').format(startTime) : null;

    final time =
        startingTimeStr != null && startingTimeStr != creationTime
            ? '$creationTime （开始于 $startingTimeStr）'
            : creationTime;
    return Padding(
      padding: const EdgeInsets.only(bottom: FreshSpace.md),
      child: FreshCard(
        padding: const EdgeInsets.symmetric(horizontal: FreshSpace.lg, vertical: FreshSpace.md),
        onTap:
            () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (context) => LogReviewPage(dateKey: dateKey, logsForDate: logs),
              ),
            ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dateLabel, style: context.text.titleSmall),
                  const SizedBox(height: 2),
                  Text(time, style: context.text.bodySmall),
                ],
              ),
            ),
            Text('回顾', style: context.text.labelLarge!.copyWith(color: FreshColors.skyText)),
            const SizedBox(width: FreshSpace.xs),
            const Icon(Icons.chevron_right, size: 18, color: FreshColors.skyText),
          ],
        ),
      ),
    );
  }
}
