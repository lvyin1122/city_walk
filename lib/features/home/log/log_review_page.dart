import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
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
    required this.question2,
    required this.answer2,
    required this.question4,
    required this.answer4,
    required this.finalSummary,
  });

  final List<Log> logs;
  final String logTitle;
  final String logDate;
  final String logSummary;
  final String question2;
  final String answer2;
  final String question4;
  final String answer4;
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
  bool _isRegenerating2 = false;
  bool _isRegenerating4 = false;

  final TextEditingController _answer2Controller = TextEditingController();
  final TextEditingController _answer4Controller = TextEditingController();
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
            _answer2Controller.text = log.reflectionQuestions.isNotEmpty
                ? log.reflectionQuestions[0].answer
                : '';
            if (log.reflectionQuestions.length > 1) {
              _answer4Controller.text = log.reflectionQuestions[1].answer;
            }
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
    _answer2Controller.dispose();
    _answer4Controller.dispose();
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
    if (_log == null) return 'Log Review';
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
    final parts = <String>[];
    for (final entry in _log!.entries) {
      if (entry.description != null && entry.description!.trim().isNotEmpty) {
        parts.add(entry.description!.trim());
      }
    }
    return parts.join(' ');
  }

  String get _question2 {
    if (_log == null || _log!.reflectionQuestions.isEmpty) return _fallbackQuestion1;
    return _log!.reflectionQuestions[0].question.isEmpty
        ? _fallbackQuestion1
        : _log!.reflectionQuestions[0].question;
  }

  String get _question4 {
    if (_log == null || _log!.reflectionQuestions.length < 2) return _fallbackQuestion2;
    return _log!.reflectionQuestions[1].question.isEmpty
        ? _fallbackQuestion2
        : _log!.reflectionQuestions[1].question;
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

  Future<void> _onRegenerateQuestion2() async {
    if (_log == null) return;
    setState(() => _isRegenerating2 = true);
    try {
      final updated = await _logService.regenerateReflectionQuestion(
        _log!.id,
        0,
      );
      if (mounted && updated != null) {
        setState(() {
          _log = updated;
          _isRegenerating2 = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isRegenerating2 = false);
    }
  }

  Future<void> _onRegenerateQuestion4() async {
    if (_log == null) return;
    setState(() => _isRegenerating4 = true);
    try {
      final updated = await _logService.regenerateReflectionQuestion(
        _log!.id,
        1,
      );
      if (mounted && updated != null) {
        setState(() {
          _log = updated;
          _isRegenerating4 = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isRegenerating4 = false);
    }
  }

  Future<void> _onFinishReview() async {
    if (_log == null) return;
    final answer2 = _answer2Controller.text.trim();
    final answer4 = _answer4Controller.text.trim();
    final finalSummary = _finalSummaryController.text.trim();

    try {
      await _logService.updateReflectionAnswers(
        logId: _log!.id,
        reflectionAnswers: [answer2, answer4],
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
      question2: _question2,
      answer2: answer2,
      question4: _question4,
      answer4: answer4,
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
          title: Text('Log Review', style: AppTextStyles.headline2),
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
          title: Text('Log Review', style: AppTextStyles.headline2),
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
          title: Text('Log Review', style: AppTextStyles.headline2),
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
        title: Text('Log Review', style: AppTextStyles.headline2),
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
              itemCount: 5,
              onPageChanged: (index) => setState(() => _currentStep = index),
              itemBuilder: (context, index) {
                switch (index) {
                  case 0:
                    return _buildStep1();
                  case 1:
                    return _buildStep2();
                  case 2:
                    return _buildStep3();
                  case 3:
                    return _buildStep4();
                  case 4:
                    return _buildStep5();
                  default:
                    return _buildStep1();
                }
              },
            ),
          ),
          _buildDotBar(),
          if (_currentStep == 4)
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
          children: List.generate(5, (index) => _buildDot(index)),
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
          Text(
            'Summary',
            style: AppTextStyles.headline5.copyWith(color: AppColors.primaryColor),
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
        question: _question2,
        onRefresh: _isRegenerating2 ? null : _onRegenerateQuestion2,
        controller: _answer2Controller,
        isLoading: _isRegenerating2,
      ),
    );
  }

  Widget _buildStep3() {
    final entries = _allEntries;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: MasonryGridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final entry = entries[index];
          final height = 140.0 + (index % 3) * 40.0;
          return GestureDetector(
            onTap: () => _showImageDialog(entry),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: height,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      entry.imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: height,
                      errorBuilder: (_, __, ___) => Container(
                      color: AppColors.separatorColor,
                      height: 150,
                      child: const Icon(Icons.image_not_supported, size: 48),
                    ),
                  ),
                  if (entry.description != null && entry.description!.trim().isNotEmpty)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withOpacity(0.7),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: Text(
                          entry.description!,
                          style: AppTextStyles.bodyText2.copyWith(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showImageDialog(LogEntry entry) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      entry.imageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppColors.separatorColor,
                        height: 200,
                        child: const Icon(Icons.image_not_supported, size: 64),
                      ),
                    ),
                  ),
                  if (entry.description != null && entry.description!.trim().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      width: double.infinity,
                      child: Text(
                        entry.description!,
                        style: AppTextStyles.bodyText1,
                      ),
                    ),
                  ],
                ],
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep4() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: _buildQuestionCard(
        question: _question4,
        onRefresh: _isRegenerating4 ? null : _onRegenerateQuestion4,
        controller: _answer4Controller,
        isLoading: _isRegenerating4,
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
            _question2,
            style: AppTextStyles.bodyText2.copyWith(
              fontStyle: FontStyle.italic,
              color: AppColors.secondaryColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _answer2Controller.text.trim().isEmpty ? '—' : _answer2Controller.text.trim(),
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
            _question4,
            style: AppTextStyles.bodyText2.copyWith(
              fontStyle: FontStyle.italic,
              color: AppColors.secondaryColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _answer4Controller.text.trim().isEmpty ? '—' : _answer4Controller.text.trim(),
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
