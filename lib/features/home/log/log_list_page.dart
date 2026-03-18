import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_text_styles.dart';
import '../../../theme/app_colors.dart';
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
      setState(() {
        _logs = logs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '加载记录失败：$e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('我的记录', style: AppTextStyles.headline2),
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textColor, size: 30),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(_error!, style: AppTextStyles.bodyText1),
                ),
              )
              : _logs.isEmpty
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text('暂无记录。', style: AppTextStyles.bodyText1),
                ),
              )
              : RefreshIndicator(
                onRefresh: _fetchLogs,
                child: _buildTimeline(),
              ),
    );
  }

  Widget _buildTimeline() {
    final grouped = _groupLogsByMonthAndDate(_logs);
    final monthKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
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
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      child: Text(
        label,
        style: AppTextStyles.headline2.copyWith(color: AppColors.primaryColor),
      ),
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

    return Padding(
      padding: const EdgeInsets.only(top: 12.0, bottom: 8.0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateLabel,
                  style: AppTextStyles.headline5.copyWith(
                    color: AppColors.secondaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      creationTime,
                      style: AppTextStyles.bodyText2.copyWith(
                        fontSize: 12,
                        color: AppColors.secondaryColor,
                      ),
                    ),
                    if (startingTimeStr != null &&
                        startingTimeStr != creationTime) ...[
                      Text(
                        ' （开始于 $startingTimeStr）',
                        style: AppTextStyles.bodyText2.copyWith(
                          fontSize: 12,
                          color: AppColors.secondaryColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => LogReviewPage(
                    dateKey: dateKey,
                    logsForDate: logs,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.rate_review, size: 16),
            label: Text(
              '回顾',
              style: AppTextStyles.bodyText2.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: AppColors.secondaryColor,
              side: BorderSide(color: AppColors.secondaryColor.withOpacity(0.5)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
