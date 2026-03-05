import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../services/log_service.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../post_auth_choice_page.dart';
import 'log_review_page.dart';

class LogReviewResultPage extends StatelessWidget {
  const LogReviewResultPage({super.key, required this.result});

  final LogReviewResult result;

  @override
  Widget build(BuildContext context) {
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
            Text('Reflection 1', style: AppTextStyles.headline5),
            const SizedBox(height: 8),
            Text(
              result.question2,
              style: AppTextStyles.bodyText2.copyWith(
                fontStyle: FontStyle.italic,
                color: AppColors.secondaryColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              result.answer2.isEmpty ? '—' : result.answer2,
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
            Text('Reflection 2', style: AppTextStyles.headline5),
            const SizedBox(height: 8),
            Text(
              result.question4,
              style: AppTextStyles.bodyText2.copyWith(
                fontStyle: FontStyle.italic,
                color: AppColors.secondaryColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              result.answer4.isEmpty ? '—' : result.answer4,
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
}
