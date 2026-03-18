import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../services/log_service.dart';
import '../../../services/scrapbook_quota_service.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../widgets/curly_underline_headline.dart';
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

  String get _displayLogTitle {
    final logs = widget.result.logs;
    if (logs.isEmpty) return widget.result.logTitle;
    final date = logs.first.createdAt.toLocal();
    return DateFormat('yyyy年M月d日 EEEE', 'zh_CN').format(date);
  }

  String get _displayLogDate {
    final logs = widget.result.logs;
    if (logs.isEmpty) return widget.result.logDate;
    final date = logs.first.createdAt.toLocal();
    return DateFormat('yyyy年M月d日 EEEE', 'zh_CN').format(date);
  }

  Future<void> _onTapScrapbookPlaceholder() async {
    final canGen = await ScrapbookQuotaService.canGenerate();
    if (!canGen) {
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

  List<LatLng> _getAllPoints() {
    final allPoints = <LatLng>[];
    for (final e in widget.result.allEntries) {
      if (e.lat != null && e.lng != null) {
        allPoints.add(LatLng(e.lat!, e.lng!));
      }
    }
    for (final log in widget.result.logs) {
      final tracking = log.tracking;
      if (tracking != null) {
        for (final session in tracking.sessions) {
          for (final p in session.points) {
            allPoints.add(LatLng(p.lat, p.lng));
          }
        }
      }
    }
    return allPoints;
  }

  Set<Polyline> _getTrackingPolylines() {
    final polylines = <Polyline>{};
    var sessionIdx = 0;
    var hasTrackingPolyline = false;
    for (final log in widget.result.logs) {
      final tracking = log.tracking;
      if (tracking == null) continue;
      for (final session in tracking.sessions) {
        final points = _normalizeTrackingPoints(session.points);
        if (points.isEmpty) continue;
        hasTrackingPolyline = true;
        polylines.add(
          Polyline(
            polylineId: PolylineId('track_$sessionIdx'),
            points: points.length >= 2 ? points : [points.first, points.first],
            color: AppColors.primaryColor,
            width: 4,
            geodesic: true,
          ),
        );
        sessionIdx++;
      }
    }

    if (!hasTrackingPolyline) {
      final fallback = widget.result.allEntries
          .where((e) => e.lat != null && e.lng != null)
          .map((e) => LatLng(e.lat!, e.lng!))
          .toList();
      if (fallback.isNotEmpty) {
        final points = _collapseConsecutiveDuplicatePoints(fallback);
        polylines.add(
          Polyline(
            polylineId: const PolylineId('track_fallback'),
            points: points.length >= 2 ? points : [points.first, points.first],
            color: AppColors.primaryColor,
            width: 4,
            geodesic: true,
          ),
        );
      }
    }

    return polylines;
  }

  List<LatLng> _normalizeTrackingPoints(List<LogTrackingPoint> rawPoints) {
    final sorted = List<LogTrackingPoint>.from(rawPoints)
      ..sort((a, b) {
        final at = DateTime.tryParse(a.timestamp);
        final bt = DateTime.tryParse(b.timestamp);
        if (at != null && bt != null) return at.compareTo(bt);
        return 0;
      });
    final latLngs = sorted.map((p) => LatLng(p.lat, p.lng)).toList();
    return _collapseConsecutiveDuplicatePoints(latLngs);
  }

  List<LatLng> _collapseConsecutiveDuplicatePoints(List<LatLng> points) {
    if (points.isEmpty) return points;
    final collapsed = <LatLng>[points.first];
    for (var i = 1; i < points.length; i++) {
      final prev = collapsed.last;
      final current = points[i];
      if (prev.latitude == current.latitude && prev.longitude == current.longitude) {
        continue;
      }
      collapsed.add(current);
    }
    return collapsed;
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final entries = result.allEntries;
    final allPoints = _getAllPoints();
    final center = _getCenter(allPoints);
    final markers = _getMarkers(entries);

    return Scaffold(
      appBar: AppBar(
        title: Text('回顾完成', style: AppTextStyles.headline2),
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
              _displayLogTitle,
              style: AppTextStyles.headline2.copyWith(color: AppColors.primaryColor),
            ),
            const SizedBox(height: 8),
            Text(
              _displayLogDate,
              style: AppTextStyles.subheadline1.copyWith(color: AppColors.secondaryColor),
            ),
            const SizedBox(height: 24),
            _buildScrapbookSection(),
            const SizedBox(height: 24),
            curlyUnderlineHeadline('智能总结', AppTextStyles.headline5.copyWith(color: AppColors.primaryColor)),
            const SizedBox(height: 8),
            Text(
              result.logSummary.isEmpty ? '—' : result.logSummary,
              style: AppTextStyles.bodyText1,
            ),
            const SizedBox(height: 24),
            curlyUnderlineHeadline('足迹地图', AppTextStyles.headline5.copyWith(color: AppColors.primaryColor)),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 220,
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(target: center, zoom: 14),
                  markers: markers,
                  polylines: _getTrackingPolylines(),
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  myLocationButtonEnabled: false,
                  zoomGesturesEnabled: true,
                  scrollGesturesEnabled: true,
                  onMapCreated: (controller) {
                    _fitBounds(controller, allPoints);
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            curlyUnderlineHeadline('今日回顾', AppTextStyles.headline5.copyWith(color: AppColors.primaryColor)),
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
            curlyUnderlineHeadline('念念不忘的瞬间', AppTextStyles.headline5.copyWith(color: AppColors.primaryColor)),
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
            curlyUnderlineHeadline('值得留意的一刻', AppTextStyles.headline5.copyWith(color: AppColors.primaryColor)),
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
            curlyUnderlineHeadline('照片中的共鸣', AppTextStyles.headline5.copyWith(color: AppColors.primaryColor)),
            const SizedBox(height: 8),
            Text(
              result.imageTagQuestion,
              style: AppTextStyles.bodyText2.copyWith(
                fontStyle: FontStyle.italic,
                color: AppColors.secondaryColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              result.imageTagAnswer.isEmpty ? '—' : result.imageTagAnswer,
              style: AppTextStyles.bodyText1,
            ),
            const SizedBox(height: 24),
            curlyUnderlineHeadline('心中余韵', AppTextStyles.headline5.copyWith(color: AppColors.primaryColor)),
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
                child: const Text('返回首页'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  LatLng _getCenter(List<LatLng> allPoints) {
    if (allPoints.isEmpty) return const LatLng(40.7851, -73.9683);
    double lat = 0, lng = 0;
    for (final pt in allPoints) {
      lat += pt.latitude;
      lng += pt.longitude;
    }
    return LatLng(lat / allPoints.length, lng / allPoints.length);
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

  void _fitBounds(GoogleMapController controller, List<LatLng> allPoints) {
    if (allPoints.isEmpty) return;
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
    controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
  }

  void _showScrapbookFullScreen(String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => _ScrapbookFullScreenView(imageUrl: imageUrl),
      ),
    );
  }

  Widget _buildScrapbookSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        curlyUnderlineHeadline('今日手账封面', AppTextStyles.headline5.copyWith(color: AppColors.primaryColor)),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _isGenerating
              ? null
              : _scrapbookImageUrl != null
                  ? () => _showScrapbookFullScreen(_scrapbookImageUrl!)
                  : _onTapScrapbookPlaceholder,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            constraints: const BoxConstraints(maxHeight: 400, minHeight: 200),
            decoration: BoxDecoration(
              color: _scrapbookImageUrl != null ? Colors.transparent : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _scrapbookImageUrl != null ? Colors.transparent : AppColors.secondaryColor.withValues(alpha: 0.5),
                width: 2,
                strokeAlign: BorderSide.strokeAlignInside,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: _isGenerating
                ? const SizedBox(
                    height: 200,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 12),
                          Text('正在生成...', style: TextStyle(color: AppColors.secondaryColor)),
                        ],
                      ),
                    ),
                  )
                : _scrapbookImageUrl != null
                    ? Center(
                        child: Image.network(
                          _scrapbookImageUrl!,
                          fit: BoxFit.contain,
                          width: double.infinity,
                          errorBuilder: (_, __, ___) => _buildPlaceholderContent(),
                        ),
                      )
                    : SizedBox(
                        height: 200,
                        child: _buildPlaceholderContent(),
                      ),
          ),
        ),
        if (_scrapbookImageUrl != null && !_isGenerating) ...[
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _onTapScrapbookPlaceholder,
            icon: const Icon(Icons.refresh, size: 20, color: AppColors.primaryColor),
            label: Text(
              '重新生成',
              style: AppTextStyles.bodyText2.copyWith(color: AppColors.primaryColor),
            ),
          ),
        ],
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
            color: AppColors.secondaryColor.withValues(alpha: 0.7),
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

class _ScrapbookFullScreenView extends StatefulWidget {
  const _ScrapbookFullScreenView({required this.imageUrl});

  final String imageUrl;

  @override
  State<_ScrapbookFullScreenView> createState() => _ScrapbookFullScreenViewState();
}

class _ScrapbookFullScreenViewState extends State<_ScrapbookFullScreenView> {
  bool _isSaving = false;
  bool _isSharing = false;

  Future<Uint8List?> _fetchImageBytes() async {
    final response = await http.get(Uri.parse(widget.imageUrl));
    if (response.statusCode == 200) {
      return Uint8List.fromList(response.bodyBytes);
    }
    return null;
  }

  Future<void> _saveToGallery() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final bytes = await _fetchImageBytes();
      if (bytes == null || !mounted) return;
      final result = await ImageGallerySaver.saveImage(
        bytes,
        quality: 100,
        name: 'scrapbook_cover_${DateTime.now().millisecondsSinceEpoch}',
      );
      if (mounted) {
        final success = result['isSuccess'] == true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? '已保存到相册' : '保存失败'),
            backgroundColor: success ? Colors.green : null,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _shareImage() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    try {
      final bytes = await _fetchImageBytes();
      if (bytes == null || !mounted) return;
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/scrapbook_share_${DateTime.now().millisecondsSinceEpoch}.png');
      await tempFile.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(tempFile.path)]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分享失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.7),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: _isSaving
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.save_alt, color: Colors.white),
            onPressed: _isSaving ? null : _saveToGallery,
            tooltip: '保存到相册',
          ),
          IconButton(
            icon: _isSharing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.share, color: Colors.white),
            onPressed: _isSharing ? null : _shareImage,
            tooltip: '分享',
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(
            widget.imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return const Center(
                child: Icon(Icons.error_outline, size: 48, color: Colors.white),
              );
            },
          ),
        ),
      ),
    );
  }
}
