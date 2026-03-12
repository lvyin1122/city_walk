import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

import '../../../services/log_service.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import 'log_entry_detail_page.dart';
import 'log_review_result_page.dart';

const String _fallbackQuestion1 = 'What did you notice during your walk?';
const String _fallbackQuestion2 = 'What was your favorite moment from this walk?';

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

  final TextEditingController _overallAnswerController = TextEditingController();
  final TextEditingController _followUpAnswerController = TextEditingController();
  final TextEditingController _finalSummaryController = TextEditingController();

  GoogleMapController? _mapController;

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
          _error = 'Failed to load log: $e';
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
    _finalSummaryController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  List<LogEntry> get _allEntries {
    if (_log == null) return [];
    final entries = List<LogEntry>.from(_log!.entries);
    entries.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return entries;
  }

  String get _logTitle {
    if (_log == null) return 'Review Your Day';
    final date = _log!.createdAt.toLocal();
    return DateFormat('EEEE, MMMM d, yyyy').format(date);
  }

  String get _logDate {
    if (_log == null) return '';
    final date = _log!.createdAt.toLocal();
    return DateFormat('EEEE, MMM d, yyyy').format(date);
  }

  String get _logSummary {
    if (_log == null) return '';
    return _log!.overallAiSummary ?? 'No summary yet.';
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

  LatLng _getCenter() {
    final allPoints = <LatLng>[];
    for (final e in _allEntries) {
      if (e.lat != null && e.lng != null) {
        allPoints.add(LatLng(e.lat!, e.lng!));
      }
    }
    final tracking = _log?.tracking;
    if (tracking != null) {
      for (final session in tracking.sessions) {
        for (final p in session.points) {
          allPoints.add(LatLng(p.lat, p.lng));
        }
      }
    }
    if (allPoints.isEmpty) return const LatLng(40.7851, -73.9683);
    double lat = 0, lng = 0;
    for (final pt in allPoints) {
      lat += pt.latitude;
      lng += pt.longitude;
    }
    return LatLng(lat / allPoints.length, lng / allPoints.length);
  }

  Set<Marker> _getMarkers() {
    final markers = <Marker>{};
    for (int i = 0; i < _allEntries.length; i++) {
      final e = _allEntries[i];
      if (e.lat != null && e.lng != null) {
        markers.add(
          Marker(
            markerId: MarkerId('entry_$i'),
            position: LatLng(e.lat!, e.lng!),
          ),
        );
      }
    }
    return markers;
  }

  Set<Polyline> _getTrackingPolylines() {
    final polylines = <Polyline>{};
    final tracking = _log?.tracking;
    if (tracking == null) return polylines;
    for (var i = 0; i < tracking.sessions.length; i++) {
      final session = tracking.sessions[i];
      final points = session.points
          .map((p) => LatLng(p.lat, p.lng))
          .toList();
      if (points.length >= 2) {
        polylines.add(
          Polyline(
            polylineId: PolylineId('track_$i'),
            points: points,
            color: AppColors.primaryColor,
            width: 4,
          ),
        );
      }
    }
    return polylines;
  }

  void _fitBounds() {
    final entries = _allEntries.where((e) => e.lat != null && e.lng != null).toList();
    final tracking = _log?.tracking;
    final allPoints = <LatLng>[];
    for (final e in entries) {
      allPoints.add(LatLng(e.lat!, e.lng!));
    }
    if (tracking != null) {
      for (final session in tracking.sessions) {
        for (final p in session.points) {
          allPoints.add(LatLng(p.lat, p.lng));
        }
      }
    }
    if (allPoints.isEmpty || _mapController == null) return;
    double minLat = allPoints.first.latitude;
    double maxLat = minLat;
    double minLng = allPoints.first.longitude;
    double maxLng = minLng;
    for (final pt in allPoints) {
      minLat = math.min(minLat, pt.latitude);
      maxLat = math.max(maxLat, pt.latitude);
      minLng = math.min(minLng, pt.longitude);
      maxLng = math.max(maxLng, pt.longitude);
    }
    const padding = 0.01;
    final bounds = LatLngBounds(
      southwest: LatLng(minLat - padding, minLng - padding),
      northeast: LatLng(maxLat + padding, maxLng + padding),
    );
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
  }

  Future<void> _onRegenerateOverallReflection() async {
    if (_log == null) return;
    setState(() => _isRegeneratingOverall = true);
    try {
      final updated = await _logService.regenerateReflectionQuestion(_log!.id);
      if (mounted && updated != null) {
        setState(() {
          _log = updated;
          _overallAnswerController.text = updated.overallAnswer;
          _followUpAnswerController.text = updated.followUpAnswer;
          _isRegeneratingOverall = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isRegeneratingOverall = false);
    }
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
              title: const Text('Edit Summary'),
              content: SizedBox(
                width: double.maxFinite,
                child: TextField(
                  controller: controller,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    hintText: 'Customize the summary...',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, controller.text.trim()),
                  child: const Text('Save'),
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
            const SnackBar(content: Text('Summary updated')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update summary')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUpdatingSummary = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _onFinishReview() async {
    if (_log == null) return;
    final overallAnswer = _overallAnswerController.text.trim();
    final followUpAnswer = _followUpAnswerController.text.trim();
    final finalSummary = _finalSummaryController.text.trim();

    try {
      await _logService.updateReflectionAnswers(
        logId: _log!.id,
        overallAnswer: overallAnswer.isNotEmpty ? overallAnswer : null,
        followUpAnswer: followUpAnswer.isNotEmpty ? followUpAnswer : null,
        overallReflection: finalSummary.isNotEmpty ? finalSummary : null,
      );
    } catch (_) {
      // Continue to result page even if save fails
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Review Your Day', style: AppTextStyles.headline2),
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: AppColors.textColor, size: 30),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Review Your Day', style: AppTextStyles.headline2),
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: AppColors.textColor, size: 30),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_error!, style: AppTextStyles.bodyText1),
          ),
        ),
      );
    }

    if (_log == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Review Your Day', style: AppTextStyles.headline2),
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: AppColors.textColor, size: 30),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Text(
            'No log found for this date.',
            style: AppTextStyles.bodyText1,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: _currentStep == 0 || _currentStep == 3
            ? Text('Review Your Day', style: AppTextStyles.headline2)
            : null,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textColor, size: 30),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              physics: const BouncingScrollPhysics(),
              itemCount: 4,
              onPageChanged: (index) => setState(() => _currentStep = index),
              itemBuilder: (context, index) {
                switch (index) {
                  case 0:
                    return _buildStep1();
                  case 1:
                    return _buildStep2();
                  // case 2:
                  //   return _buildStep3();
                  case 2:
                    return _buildStep4();
                  case 3:
                    return _buildStep5();
                  default:
                    return _buildStep1();
                }
              },
            ),
          ),
          _buildDotBar(),
          if (_currentStep == 3)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _onFinishReview,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    foregroundColor: AppColors.buttonTextColor,
                    backgroundColor: AppColors.primaryColor,
                  ),
                  child: const Text('Finish Review'),
                ),
              ),
            )
          else
            const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildDotBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (index) => _buildDot(index)),
        ),
      ),
    );
  }

  Widget _buildDot(int index) {
    return GestureDetector(
      onTap: () {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 6),
        width: _currentStep == index ? 16 : 8,
        height: 8,
        decoration: BoxDecoration(
          color: _currentStep == index
              ? AppColors.primaryColor
              : Colors.grey.shade400,
          borderRadius: BorderRadius.circular(4),
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

  Widget _buildLogEntryTile(LogEntry entry, Log log) {
    final timeStr = DateFormat('MMM d, h:mm a').format(entry.timestamp.toLocal());

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LogEntryDetailPage(entry: entry, log: log),
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
                  errorBuilder: (_, __, ___) => Container(
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

  Widget _buildStep1() {
    final entriesWithLogs = _entriesWithLogs;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _logTitle,
            style: AppTextStyles.headline2.copyWith(color: AppColors.primaryColor),
          ),
          const SizedBox(height: 8),
          Text(
            _logDate,
            style: AppTextStyles.subheadline1.copyWith(color: AppColors.secondaryColor),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'At a Glance',
                style: AppTextStyles.headline5.copyWith(color: AppColors.primaryColor),
              ),
              IconButton(
                icon: _isUpdatingSummary
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.edit),
                onPressed: _isUpdatingSummary ? null : _onEditSummary,
                color: AppColors.secondaryColor,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _logSummary.isEmpty ? 'No summary yet.' : _logSummary,
            style: AppTextStyles.bodyText1,
          ),
          const SizedBox(height: 24),
          Text(
            'Your Path',
            style: AppTextStyles.headline5.copyWith(color: AppColors.primaryColor),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 220,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _getCenter(),
                  zoom: 14,
                ),
                markers: _getMarkers(),
                polylines: _getTrackingPolylines(),
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                myLocationButtonEnabled: false,
                zoomGesturesEnabled: true,
                scrollGesturesEnabled: true,
                onMapCreated: (controller) {
                  _mapController = controller;
                  _fitBounds();
                },
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Your Moments',
            style: AppTextStyles.headline5.copyWith(color: AppColors.primaryColor),
          ),
          const SizedBox(height: 12),
          ...entriesWithLogs.map((p) => _buildLogEntryTile(p.entry, p.log)),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildQuestionCard({
    required String question,
    VoidCallback? onRefresh,
    required TextEditingController controller,
    bool isLoading = false,
    List<String> quickReplies = const [],
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 36),
                child: Text(
                  question,
                  style: AppTextStyles.headline5.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryColor,
                  ),
                ),
              ),
              if (onRefresh != null)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: IconButton(
                    icon: isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    onPressed: isLoading ? null : onRefresh,
                    color: AppColors.secondaryColor,
                  ),
                ),
            ],
          ),
        ),
        if (quickReplies.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: quickReplies
                .map(
                  (label) => ActionChip(
                    label: Text(label),
                    onPressed: () {
                      final current = controller.text.trim();
                      controller.text =
                          current.isEmpty ? label : '$current  $label';
                    },
                  ),
                )
                .toList(),
          ),
        ],
        const SizedBox(height: 16),
        TextField(
          controller: controller,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Write your reflection...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: _buildQuestionCard(
        question: _overallQuestion,
        onRefresh: _isRegeneratingOverall ? null : _onRegenerateOverallReflection,
        controller: _overallAnswerController,
        isLoading: _isRegeneratingOverall,
        quickReplies: _log?.quickReplies ?? [],
      ),
    );
  }

  Widget _buildStep4() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: _buildQuestionCard(
        question: _followUpQuestion,
        onRefresh: _isRegeneratingOverall ? null : _onRegenerateOverallReflection,
        controller: _followUpAnswerController,
        isLoading: _isRegeneratingOverall,
      ),
    );
  }

  Widget _buildStep5() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_logTitle, style: AppTextStyles.headline3),
          const SizedBox(height: 4),
          Text(_logDate, style: AppTextStyles.subheadline1),
          const SizedBox(height: 16),
          Text('At a Glance', style: AppTextStyles.headline5),
          const SizedBox(height: 4),
          Text(_logSummary.isEmpty ? '—' : _logSummary, style: AppTextStyles.bodyText1),
          const SizedBox(height: 16),
          Text('Looking Back', style: AppTextStyles.headline5),
          const SizedBox(height: 4),
          Text(
            _overallQuestion,
            style: AppTextStyles.bodyText2.copyWith(
              fontStyle: FontStyle.italic,
              color: AppColors.secondaryColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _overallAnswerController.text.trim().isEmpty ? '—' : _overallAnswerController.text.trim(),
            style: AppTextStyles.bodyText1,
          ),
          const SizedBox(height: 16),
          Text('Moments That Stayed', style: AppTextStyles.headline5),
          const SizedBox(height: 8),
          ..._allEntries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    e.imageUrl,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 80,
                      height: 80,
                      color: AppColors.separatorColor,
                      child: const Icon(Icons.image_not_supported),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    e.description ?? '—',
                    style: AppTextStyles.bodyText2,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          )),
          const SizedBox(height: 16),
          Text('A Moment to Notice', style: AppTextStyles.headline5),
          const SizedBox(height: 4),
          Text(
            _followUpQuestion,
            style: AppTextStyles.bodyText2.copyWith(
              fontStyle: FontStyle.italic,
              color: AppColors.secondaryColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _followUpAnswerController.text.trim().isEmpty ? '—' : _followUpAnswerController.text.trim(),
            style: AppTextStyles.bodyText1,
          ),
          const SizedBox(height: 24),
          Text('What Remains', style: AppTextStyles.headline5),
          const SizedBox(height: 8),
          TextField(
            controller: _finalSummaryController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Write what remains with you...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
