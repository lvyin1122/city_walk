import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../services/log_service.dart';
import '../../../services/scrapbook_quota_service.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../post_auth_choice_page.dart';
import 'log_review_page.dart';

class LogReviewResultPage extends StatefulWidget {
  const LogReviewResultPage({super.key, required this.result});

  final LogReviewResult result;

  @override
  State<LogReviewResultPage> createState() => _LogReviewResultPageState();
}

class _LogReviewResultPageState extends State<LogReviewResultPage> {
  String? _scrapbookImageUrl;
  bool _isGenerating = false;
  String? _scrapbookError;

  Future<void> _onTapScrapbookPlaceholder() async {
    final canGen = await ScrapbookQuotaService.canGenerate();
    // if (!canGen) {
    if (false) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('今日生成次数已用完，明天再来吧'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    final logId = widget.result.logs.isNotEmpty ? widget.result.logs.first.id : null;
    if (logId == null) return;

    setState(() {
      _isGenerating = true;
      _scrapbookError = null;
    });

    try {
      final url = await LogService().generateScrapbookImage(logId);
      if (mounted) {
        if (url != null) {
          await ScrapbookQuotaService.recordGeneration();
          setState(() {
            _scrapbookImageUrl = url;
            _isGenerating = false;
          });
        } else {
          setState(() {
            _scrapbookError = '生成失败，请稍后重试';
            _isGenerating = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_scrapbookError!)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _scrapbookError = e.toString();
          _isGenerating = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('生成失败：${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final entries = result.allEntries;
    final center = _getCenter(entries);
    final markers = _getMarkers(entries);

    return Scaffold(
      appBar: AppBar(
        title: Text('Review Complete', style: AppTextStyles.headline2),
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textColor, size: 30),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              result.logTitle,
              style: AppTextStyles.headline2.copyWith(color: AppColors.primaryColor),
            ),
            const SizedBox(height: 8),
            Text(
              result.logDate,
              style: AppTextStyles.subheadline1.copyWith(color: AppColors.secondaryColor),
            ),
            const SizedBox(height: 24),
            _buildScrapbookSection(),
            const SizedBox(height: 24),
            Text('Log Summary', style: AppTextStyles.headline5),
            const SizedBox(height: 8),
            Text(
              result.logSummary.isEmpty ? '—' : result.logSummary,
              style: AppTextStyles.bodyText1,
            ),
            const SizedBox(height: 24),
            Text('Map', style: AppTextStyles.headline5),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 220,
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(target: center, zoom: 14),
                  markers: markers,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  myLocationButtonEnabled: false,
                  zoomGesturesEnabled: true,
                  scrollGesturesEnabled: true,
                  onMapCreated: (controller) {
                    _fitBounds(controller, entries);
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('Reflection', style: AppTextStyles.headline5),
            const SizedBox(height: 8),
            Text(
              result.overallQuestion,
              style: AppTextStyles.bodyText2.copyWith(
                fontStyle: FontStyle.italic,
                color: AppColors.secondaryColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              result.overallAnswer.isEmpty ? '—' : result.overallAnswer,
              style: AppTextStyles.bodyText1,
            ),
            const SizedBox(height: 24),
            Text('Photos & Reflections', style: AppTextStyles.headline5),
            const SizedBox(height: 12),
            ...entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.description ?? '—',
                          style: AppTextStyles.bodyText2,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )),
            const SizedBox(height: 24),
            Text('Follow-Up', style: AppTextStyles.headline5),
            const SizedBox(height: 8),
            Text(
              result.followUpQuestion,
              style: AppTextStyles.bodyText2.copyWith(
                fontStyle: FontStyle.italic,
                color: AppColors.secondaryColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              result.followUpAnswer.isEmpty ? '—' : result.followUpAnswer,
              style: AppTextStyles.bodyText1,
            ),
            const SizedBox(height: 24),
            Text('Final Summary', style: AppTextStyles.headline5),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                result.finalSummary.isEmpty ? '—' : result.finalSummary,
                style: AppTextStyles.bodyText1,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (context) => const PostAuthChoicePage(),
                    ),
                    (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  foregroundColor: AppColors.buttonTextColor,
                  backgroundColor: AppColors.primaryColor,
                ),
                child: const Text('Back to Home'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  LatLng _getCenter(List<LogEntry> entries) {
    final valid = entries.where((e) => e.lat != null && e.lng != null).toList();
    if (valid.isEmpty) return const LatLng(40.7851, -73.9683);
    double lat = 0, lng = 0;
    for (final e in valid) {
      lat += e.lat!;
      lng += e.lng!;
    }
    return LatLng(lat / valid.length, lng / valid.length);
  }

  Set<Marker> _getMarkers(List<LogEntry> entries) {
    final markers = <Marker>{};
    for (int i = 0; i < entries.length; i++) {
      final e = entries[i];
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

  void _fitBounds(GoogleMapController controller, List<LogEntry> entries) {
    final valid = entries.where((e) => e.lat != null && e.lng != null).toList();
    if (valid.isEmpty) return;
    double minLat = valid.first.lat!;
    double maxLat = minLat;
    double minLng = valid.first.lng!;
    double maxLng = minLng;
    for (final e in valid) {
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
    controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
  }

  Widget _buildScrapbookSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('今日手账封面', style: AppTextStyles.headline5.copyWith(color: AppColors.primaryColor)),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _isGenerating ? null : _onTapScrapbookPlaceholder,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 200,
            decoration: BoxDecoration(
              color: _scrapbookImageUrl != null ? Colors.transparent : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _scrapbookImageUrl != null ? Colors.transparent : AppColors.secondaryColor.withOpacity(0.5),
                width: 2,
                strokeAlign: BorderSide.strokeAlignInside,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: _isGenerating
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text('正在生成...', style: TextStyle(color: AppColors.secondaryColor)),
                      ],
                    ),
                  )
                : _scrapbookImageUrl != null
                    ? Image.network(
                        _scrapbookImageUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (_, __, ___) => _buildPlaceholderContent(),
                      )
                    : _buildPlaceholderContent(),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholderContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.auto_awesome,
            size: 48,
            color: AppColors.secondaryColor.withOpacity(0.7),
          ),
          const SizedBox(height: 12),
          Text(
            '轻触生成今日手账封面',
            style: AppTextStyles.bodyText1.copyWith(
              color: AppColors.secondaryColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
