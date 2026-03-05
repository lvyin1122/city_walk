import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:intl/intl.dart';

import '../../../services/log_service.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import 'log_review_result_page.dart';

/// Dummy reflection questions for steps 2 and 4.
const List<String> _reflectionQuestions2 = [
  'What did you notice during your walk?',
  'How did you feel while walking?',
  'Was there anything surprising or memorable?',
  'What would you do differently next time?',
];

const List<String> _reflectionQuestions4 = [
  'What was your favorite moment?',
  'How would you describe this experience to a friend?',
  'What made this walk special?',
  'What did you learn from this walk?',
];

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
  const LogReviewPage({super.key, required this.logs});

  final List<Log> logs;

  @override
  State<LogReviewPage> createState() => _LogReviewPageState();
}

class _LogReviewPageState extends State<LogReviewPage> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  int _question2Index = 0;
  int _question4Index = 0;
  final TextEditingController _answer2Controller = TextEditingController();
  final TextEditingController _answer4Controller = TextEditingController();
  final TextEditingController _finalSummaryController = TextEditingController();

  GoogleMapController? _mapController;

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
    final entries = <LogEntry>[];
    for (final log in widget.logs) {
      entries.addAll(log.entries);
    }
    entries.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return entries;
  }

  String get _logTitle {
    if (widget.logs.isEmpty) return 'Log Review';
    final date = widget.logs.first.createdAt.toLocal();
    return 'Walk on ${DateFormat('EEEE, MMMM d, yyyy').format(date)}';
  }

  String get _logDate {
    if (widget.logs.isEmpty) return '';
    final date = widget.logs.first.createdAt.toLocal();
    return DateFormat('EEEE, MMM d, yyyy').format(date);
  }

  String get _logSummary {
    final parts = <String>[];
    for (final log in widget.logs) {
      for (final entry in log.entries) {
        if (entry.description != null && entry.description!.trim().isNotEmpty) {
          parts.add(entry.description!.trim());
        }
      }
    }
    return parts.join(' ');
  }

  LatLng _getCenter() {
    final entries = _allEntries.where((e) => e.lat != null && e.lng != null).toList();
    if (entries.isEmpty) return const LatLng(40.7851, -73.9683);
    double lat = 0, lng = 0;
    for (final e in entries) {
      lat += e.lat!;
      lng += e.lng!;
    }
    return LatLng(lat / entries.length, lng / entries.length);
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

  void _fitBounds() {
    final entries = _allEntries.where((e) => e.lat != null && e.lng != null).toList();
    if (entries.isEmpty || _mapController == null) return;
    double minLat = entries.first.lat!;
    double maxLat = minLat;
    double minLng = entries.first.lng!;
    double maxLng = minLng;
    for (final e in entries) {
      minLat = math.min(minLat, e.lat!);
      maxLat = math.max(maxLat, e.lat!);
      minLng = math.min(minLng, e.lng!);
      maxLng = math.max(maxLng, e.lng!);
    }
    const padding = 0.01;
    final bounds = LatLngBounds(
      southwest: LatLng(minLat - padding, minLng - padding),
      northeast: LatLng(maxLat + padding, maxLng + padding),
    );
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
  }

  void _onFinishReview() {
    final result = LogReviewResult(
      logs: widget.logs,
      logTitle: _logTitle,
      logDate: _logDate,
      logSummary: _logSummary,
      question2: _reflectionQuestions2[_question2Index],
      answer2: _answer2Controller.text.trim(),
      question4: _reflectionQuestions4[_question4Index],
      answer4: _answer4Controller.text.trim(),
      finalSummary: _finalSummaryController.text.trim(),
    );
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => LogReviewResultPage(result: result),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.logs.isEmpty) {
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
            'No logs to review.',
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

  Widget _buildStep1() {
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
            'Map',
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
        ],
      ),
    );
  }

  Widget _buildQuestionCard({
    required String question,
    required VoidCallback onRefresh,
    required TextEditingController controller,
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
                  icon: const Icon(Icons.refresh),
                  onPressed: onRefresh,
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
        question: _reflectionQuestions2[_question2Index],
        onRefresh: () {
          setState(() {
            _question2Index = (_question2Index + 1) % _reflectionQuestions2.length;
          });
        },
        controller: _answer2Controller,
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
        question: _reflectionQuestions4[_question4Index],
        onRefresh: () {
          setState(() {
            _question4Index = (_question4Index + 1) % _reflectionQuestions4.length;
          });
        },
        controller: _answer4Controller,
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
          Text('Log Summary', style: AppTextStyles.headline5),
          const SizedBox(height: 4),
          Text(_logSummary.isEmpty ? '—' : _logSummary, style: AppTextStyles.bodyText1),
          const SizedBox(height: 16),
          Text('Reflection 1', style: AppTextStyles.headline5),
          const SizedBox(height: 4),
          Text(
            _reflectionQuestions2[_question2Index],
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
          Text('Photos & Reflections', style: AppTextStyles.headline5),
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
          Text('Reflection 2', style: AppTextStyles.headline5),
          const SizedBox(height: 4),
          Text(
            _reflectionQuestions4[_question4Index],
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
          Text('Final Summary', style: AppTextStyles.headline5),
          const SizedBox(height: 8),
          TextField(
            controller: _finalSummaryController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Write your final summary...',
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
