import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_text_styles.dart';
import '../../../theme/app_colors.dart';
import '../../../services/log_service.dart';
import 'log_entry_detail_page.dart';
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
        _error = 'Failed to load logs: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Logs', style: AppTextStyles.headline2),
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
                  child: Text('No logs yet.', style: AppTextStyles.bodyText1),
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
      for (final dateKey in grouped[monthKey]!.keys) {
        count += 1; // date header
        for (final log in grouped[monthKey]![dateKey]!) {
          count += log.entries.length; // log entries
        }
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
          return _buildDateHeader(dateKey, logs);
        }
        remaining -= 1;

        final logs = grouped[monthKey]![dateKey]!;
        for (final log in logs) {
          if (remaining < log.entries.length) {
            final entries = List<LogEntry>.from(log.entries)
              ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
            return _buildLogEntryTile(entries[remaining]);
          }
          remaining -= log.entries.length;
        }
      }
    }
    return const SizedBox.shrink();
  }

  Widget _buildMonthHeader(String monthKey) {
    final parts = monthKey.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final date = DateTime(year, month, 1);
    final label = DateFormat('MMMM yyyy').format(date);

    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      child: Text(
        label,
        style: AppTextStyles.headline2.copyWith(color: AppColors.primaryColor),
      ),
    );
  }

  Widget _buildDateHeader(String dateKey, List<Log> logs) {
    final parts = dateKey.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final day = int.parse(parts[2]);
    final date = DateTime(year, month, day);
    final label = DateFormat('EEEE, MMM d').format(date);

    return Padding(
      padding: const EdgeInsets.only(top: 12.0, bottom: 8.0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.headline5.copyWith(
                color: AppColors.secondaryColor,
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => LogReviewPage(dateKey: dateKey),
                ),
              );
            },
            icon: const Icon(Icons.rate_review, size: 16),
            label: Text(
              'Review',
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

  Widget _buildLogEntryTile(LogEntry entry) {
    final timeStr = DateFormat(
      'MMM d, h:mm a',
    ).format(entry.timestamp.toLocal());

    return Padding(
      padding: const EdgeInsets.only(left: 8.0, right: 8.0, bottom: 8.0),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LogEntryDetailPage(entry: entry),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  entry.imageUrl,
                  width: 96,
                  height: 96,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (_, __, ___) => Container(
                        width: 96,
                        height: 96,
                        color: AppColors.separatorColor,
                        child: const Icon(Icons.image_not_supported, size: 24),
                      ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      entry.description ?? '',
                      style: AppTextStyles.bodyText2,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (entry.address != null &&
                            entry.address!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 12,
                                color: AppColors.secondaryColor,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  entry.address!,
                                  style: AppTextStyles.bodyText2.copyWith(
                                    fontSize: 12,
                                    color: AppColors.secondaryColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          timeStr,
                          style: AppTextStyles.bodyText2.copyWith(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
