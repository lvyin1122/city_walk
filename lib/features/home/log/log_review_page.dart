import 'package:mambo/widgets/botanical.dart';
import 'package:mambo/widgets/fresh_surface.dart';
import 'widgets/review_parts.dart';
import 'package:mambo/theme/app_theme.dart';
import 'package:mambo/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../services/log_service.dart';
import 'log_entry_detail_page.dart';
import 'log_map.dart';
import 'log_review_result_page.dart';

const String _fallbackQuestion1 = '步行时你注意到了什么？';
const String _fallbackQuestion2 = '这次步行中最喜欢的瞬间是什么？';
const String _fallbackImageTagQuestion = '这些照片中，哪个瞬间最让你印象深刻？';

/// Result snapshot passed to LogReviewResultPage.
class LogReviewResult {
  LogReviewResult({
    required this.logs,
    required this.logTitle,
    required this.logDate,
    required this.logSummary,
    required this.overallQuestion,
    required this.overallAnswer,
    required this.followUpQuestion,
    required this.followUpAnswer,
    required this.imageTagQuestion,
    required this.imageTagAnswer,
    required this.finalSummary,
  });

  final List<Log> logs;
  final String logTitle;
  final String logDate;
  final String logSummary;
  final String overallQuestion;
  final String overallAnswer;
  final String followUpQuestion;
  final String followUpAnswer;
  final String imageTagQuestion;
  final String imageTagAnswer;
  final String finalSummary;

  /// All entries from all logs, sorted by timestamp.
  List<LogEntry> get allEntries {
    final entries = <LogEntry>[];
    for (final log in logs) {
      entries.addAll(log.entries);
    }
    entries.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return entries;
  }
}

class LogReviewPage extends StatefulWidget {
  const LogReviewPage({
    super.key,
    required this.dateKey,
    this.logsForDate,
  });

  final String dateKey;
  final List<Log>? logsForDate;

  @override
  State<LogReviewPage> createState() => _LogReviewPageState();
}

class _LogReviewPageState extends State<LogReviewPage> {
  final PageController _pageController = PageController();
  final LogService _logService = LogService();
  int _currentStep = 0;

  Log? _log;
  bool _isLoading = true;
  String? _error;
  bool _isRegeneratingOverall = false;
  bool _isUpdatingSummary = false;
  bool _isSavingReview = false;

  final TextEditingController _overallAnswerController = TextEditingController();
  final TextEditingController _followUpAnswerController = TextEditingController();
  final TextEditingController _imageTagAnswerController = TextEditingController();
  final TextEditingController _finalSummaryController = TextEditingController();

  int get _timezoneOffsetMinutes {
    final offset = DateTime.now().timeZoneOffset;
    return offset.inMinutes;
  }

  @override
  void initState() {
    super.initState();
    _fetchLog();
  }

  Future<void> _fetchLog() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final log = await _logService.getLogForReview(
        widget.dateKey,
        _timezoneOffsetMinutes,
      );
      if (mounted) {
        setState(() {
          _log = log;
          _isLoading = false;
          if (log != null) {
            _overallAnswerController.text = log.overallAnswer;
            _followUpAnswerController.text = log.followUpAnswer;
            _imageTagAnswerController.text = log.imageTagAnswer;
            if (log.overallReflection != null &&
                log.overallReflection!.trim().isNotEmpty) {
              _finalSummaryController.text = log.overallReflection!;
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '加载记录失败：$e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _overallAnswerController.dispose();
    _followUpAnswerController.dispose();
    _imageTagAnswerController.dispose();
    _finalSummaryController.dispose();
    super.dispose();
  }

  List<LogEntry> get _allEntries {
    if (_log == null) return [];
    final entries = List<LogEntry>.from(_log!.entries);
    entries.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return entries;
  }

  String get _logTitle {
    if (_log == null) return '回顾你的一天';
    final date = _log!.createdAt.toLocal();
    return DateFormat('yyyy年M月d日 EEEE', 'zh_CN').format(date);
  }

  String get _logDate {
    if (_log == null) return '';
    final date = _log!.createdAt.toLocal();
    return DateFormat('yyyy年M月d日 EEEE', 'zh_CN').format(date);
  }

  String get _logSummary {
    if (_log == null) return '';
    return _log!.overallAiSummary ?? '暂无总结';
  }

  String get _overallQuestion {
    if (_log == null) return _fallbackQuestion1;
    final q = _log!.overallQuestion;
    return q.isEmpty ? _fallbackQuestion1 : q;
  }

  String get _followUpQuestion {
    if (_log == null) return _fallbackQuestion2;
    final q = _log!.followUpQuestion;
    return q.isEmpty ? _fallbackQuestion2 : q;
  }

  String get _imageTagQuestion {
    if (_log == null) return _fallbackImageTagQuestion;
    final q = _log!.imageTagQuestion;
    return q.isEmpty ? _fallbackImageTagQuestion : q;
  }

  Future<void> _onRegenerateOverallReflection() async {
    if (_log == null) return;
    setState(() => _isRegeneratingOverall = true);
    try {
      final updated = await _logService.regenerateReflectionQuestion(_log!.id);
      if (!mounted) return;
      setState(() {
        if (updated != null) {
          _log = updated;
          // Keep whatever the user has typed; only fill in empty fields.
          _fillIfEmpty(_overallAnswerController, updated.overallAnswer);
          _fillIfEmpty(_followUpAnswerController, updated.followUpAnswer);
          _fillIfEmpty(_imageTagAnswerController, updated.imageTagAnswer);
        }
        _isRegeneratingOverall = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isRegeneratingOverall = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('换一组问题失败：$e')));
    }
  }

  void _fillIfEmpty(TextEditingController controller, String text) {
    if (controller.text.trim().isEmpty) controller.text = text;
  }

  Future<void> _onEditSummary() async {
    if (_log == null) return;
    final controller = TextEditingController(
      text: _log!.overallAiSummary ?? '',
    );
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('编辑总结'),
              content: SizedBox(
                width: double.maxFinite,
                child: TextField(
                  controller: controller,
                  maxLines: 6,
                  decoration: const InputDecoration(labelText: '自定义总结…'),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, controller.text.trim()),
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );
    // Defer disposal until after the dialog tree has fully torn down
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });
    if (result == null || !mounted) return;

    setState(() => _isUpdatingSummary = true);
    try {
      final updated = await _logService.updateOverallAiSummary(
        _log!.id,
        result,
      );
      if (mounted) {
        setState(() {
          _isUpdatingSummary = false;
          if (updated != null) _log = updated;
        });
        if (updated != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('总结已更新')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('更新总结失败')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUpdatingSummary = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('错误：${e.toString()}')),
        );
      }
    }
  }

  Future<void> _onFinishReview() async {
    if (_log == null) return;
    final overallAnswer = _overallAnswerController.text.trim();
    final followUpAnswer = _followUpAnswerController.text.trim();
    final imageTagAnswer = _imageTagAnswerController.text.trim();
    final finalSummary = _finalSummaryController.text.trim();

    if (_isSavingReview) return;
    setState(() => _isSavingReview = true);
    try {
      await _logService.updateReflectionAnswers(
        logId: _log!.id,
        overallAnswer: overallAnswer.isNotEmpty ? overallAnswer : null,
        followUpAnswer: followUpAnswer.isNotEmpty ? followUpAnswer : null,
        imageTagAnswer: imageTagAnswer.isNotEmpty ? imageTagAnswer : null,
        overallReflection: finalSummary.isNotEmpty ? finalSummary : null,
      );
    } catch (e) {
      // Stay on the page so nothing the user wrote is lost.
      if (!mounted) return;
      setState(() => _isSavingReview = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('回顾没有保存成功，请重试：$e')));
      return;
    }

    final result = LogReviewResult(
      logs: [_log!],
      logTitle: _logTitle,
      logDate: _logDate,
      logSummary: _logSummary,
      overallQuestion: _overallQuestion,
      overallAnswer: overallAnswer,
      followUpQuestion: _followUpQuestion,
      followUpAnswer: followUpAnswer,
      imageTagQuestion: _imageTagQuestion,
      imageTagAnswer: imageTagAnswer,
      finalSummary: finalSummary,
    );
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => LogReviewResultPage(result: result),
        ),
      );
    }
  }

  AppBar _appBar({bool withTitle = true}) => AppBar(
    title: withTitle ? const Text('回顾你的一天') : null,
    backgroundColor: Colors.transparent,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back),
      tooltip: '返回',
      onPressed: () => Navigator.pop(context),
    ),
  );

  Widget _message(String message) => Center(
    child: Padding(
      padding: const EdgeInsets.all(FreshSpace.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Botanical(kind: BotanicalKind.ginkgo, size: 64),
          const SizedBox(height: FreshSpace.lg),
          Text(message, style: context.text.bodyMedium, textAlign: TextAlign.center),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _error != null || _log == null) {
      return Scaffold(
        appBar: _appBar(),
        body: PaperBackground(
          child:
              _isLoading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 1.2))
                  : _message(_error ?? '未找到该日期的记录。'),
        ),
      );
    }

    final steps = [
      _buildOverview(),
      ReflectionQuestion(
        question: _overallQuestion,
        controller: _overallAnswerController,
        onRefresh: _onRegenerateOverallReflection,
        refreshing: _isRegeneratingOverall,
        quickReplies: _log?.quickReplies ?? const [],
      ),
      ReflectionQuestion(
        question: _followUpQuestion,
        controller: _followUpAnswerController,
        onRefresh: _onRegenerateOverallReflection,
        refreshing: _isRegeneratingOverall,
        botanical: BotanicalKind.bamboo,
      ),
      ReflectionQuestion(
        question: _imageTagQuestion,
        controller: _imageTagAnswerController,
        onRefresh: _onRegenerateOverallReflection,
        refreshing: _isRegeneratingOverall,
        quickReplies: _log?.imageTagQuickReplies ?? const [],
        botanical: BotanicalKind.ginkgo,
      ),
      _buildSummaryStep(),
    ];
    final isLast = _currentStep == steps.length - 1;

    return Scaffold(
      appBar: _appBar(withTitle: _currentStep == 0 || isLast),
      body: PaperBackground(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentStep = index),
                children: steps,
              ),
            ),
            StepDots(
              count: steps.length,
              current: _currentStep,
              onTap:
                  (index) => _pageController.animateToPage(
                    index,
                    duration: FreshMotion.of(context),
                    curve: FreshMotion.curve,
                  ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(FreshSpace.page, FreshSpace.sm, FreshSpace.page, FreshSpace.lg),
                child: SizedBox(
                  width: double.infinity,
                  child:
                      isLast
                          ? ElevatedButton(
                            onPressed: _isSavingReview ? null : _onFinishReview,
                            child: Text(_isSavingReview ? '正在保存…' : '完成回顾'),
                          )
                          : OutlinedButton(
                            onPressed:
                                () => _pageController.nextPage(
                                  duration: FreshMotion.of(context),
                                  curve: FreshMotion.curve,
                                ),
                            child: const Text('下一步'),
                          ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// All entries from logsForDate or _log, with their parent Log, sorted by timestamp.
  List<({LogEntry entry, Log log})> get _entriesWithLogs {
    final logs = widget.logsForDate ?? (_log != null ? [_log!] : <Log>[]);
    final pairs = <({LogEntry entry, Log log})>[];
    for (final log in logs) {
      for (final entry in log.entries) {
        pairs.add((entry: entry, log: log));
      }
    }
    pairs.sort((a, b) => a.entry.timestamp.compareTo(b.entry.timestamp));
    return pairs;
  }

  Widget _buildOverview() {
    final text = context.text;
    return ListView(
      padding: const EdgeInsets.fromLTRB(FreshSpace.page + 8, FreshSpace.lg, FreshSpace.page, FreshSpace.xxl),
      children: [
        FreshHeading(_logTitle, subtitle: _logDate, botanical: BotanicalKind.sprig),
        const SizedBox(height: FreshSpace.xxl),
        FreshCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('AI 总结', style: text.labelMedium)),
                  IconButton(
                    icon:
                        _isUpdatingSummary
                            ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 1.2))
                            : const Icon(Icons.edit_outlined, size: 18),
                    tooltip: '编辑总结',
                    onPressed: _isUpdatingSummary ? null : _onEditSummary,
                  ),
                ],
              ),
              Text(_logSummary.isEmpty ? '暂无总结' : _logSummary, style: text.bodyLarge!.copyWith(height: 1.9)),
            ],
          ),
        ),
        const SizedBox(height: FreshSpace.xxl),
        if (logPositions([_log!], _allEntries).isNotEmpty) ...[
          Text('你的足迹', style: text.titleMedium),
          const SizedBox(height: FreshSpace.md),
          LogMap(logs: [_log!], entries: _allEntries),
          const SizedBox(height: FreshSpace.xxl),
        ],
        Text('记录的瞬间', style: text.titleMedium),
        const SizedBox(height: FreshSpace.md),
        for (final pair in _entriesWithLogs)
          LogEntryTile(
            entry: pair.entry,
            onTap:
                () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (context) => LogEntryDetailPage(entry: pair.entry, log: pair.log)),
                ),
          ),
      ],
    );
  }

  Widget _buildSummaryStep() {
    final text = context.text;
    return ListView(
      padding: const EdgeInsets.fromLTRB(FreshSpace.page + 8, FreshSpace.lg, FreshSpace.page, FreshSpace.xxl),
      children: [
        Text(_logTitle, style: text.headlineSmall),
        const SizedBox(height: FreshSpace.xs),
        Text(_logDate, style: text.bodySmall),
        const SizedBox(height: FreshSpace.xxl),
        ReviewSection(title: '智能总结', answer: _logSummary),
        ReviewSection(title: '今日回顾', question: _overallQuestion, answer: _overallAnswerController.text),
        ReviewSection(
          title: '念念不忘的瞬间',
          child: Column(
            children: [
              for (final entry in _allEntries)
                Padding(
                  padding: const EdgeInsets.only(bottom: FreshSpace.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Thumbnail(entry.imageUrl, size: 72),
                      const SizedBox(width: FreshSpace.md),
                      Expanded(
                        child: Text(
                          entry.description?.isNotEmpty == true ? entry.description! : '—',
                          style: text.bodyMedium,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        ReviewSection(title: '值得留意的一刻', question: _followUpQuestion, answer: _followUpAnswerController.text),
        ReviewSection(title: '照片中的共鸣', question: _imageTagQuestion, answer: _imageTagAnswerController.text),
        ReviewSection(
          title: '心中余韵',
          child: TextField(
            controller: _finalSummaryController,
            minLines: 1,
            maxLines: 6,
            decoration: const InputDecoration(labelText: '写下心中所留…'),
          ),
        ),
      ],
    );
  }
}
