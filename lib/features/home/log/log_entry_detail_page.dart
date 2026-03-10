import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_text_styles.dart';
import '../../../theme/app_colors.dart';
import '../../../services/log_service.dart';

class LogEntryDetailPage extends StatelessWidget {
  final LogEntry entry;
  final Log? log;

  const LogEntryDetailPage({super.key, required this.entry, this.log});

  LatLng _getCenter() {
    final points = <LatLng>[];
    if (entry.lat != null && entry.lng != null) {
      points.add(LatLng(entry.lat!, entry.lng!));
    }
    final tracking = log?.tracking;
    if (tracking != null) {
      for (final session in tracking.sessions) {
        for (final p in session.points) {
          points.add(LatLng(p.lat, p.lng));
        }
      }
    }
    if (points.isEmpty) return const LatLng(40.7851, -73.9683);
    double lat = 0, lng = 0;
    for (final pt in points) {
      lat += pt.latitude;
      lng += pt.longitude;
    }
    return LatLng(lat / points.length, lng / points.length);
  }

  Set<Polyline> _getTrackingPolylines() {
    final polylines = <Polyline>{};
    final tracking = log?.tracking;
    if (tracking == null) return polylines;
    for (var i = 0; i < tracking.sessions.length; i++) {
      final session = tracking.sessions[i];
      final points = session.points.map((p) => LatLng(p.lat, p.lng)).toList();
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

  @override
  Widget build(BuildContext context) {
    final timeStr =
        DateFormat('EEEE, MMM d, yyyy · h:mm a').format(entry.timestamp.toLocal());
    final hasLocation = entry.lat != null && entry.lng != null;
    final hasTracking = log?.tracking != null &&
        log!.tracking!.sessions.any((s) => s.points.length >= 2);
    final showMap = hasLocation || hasTracking;

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: Colors.white,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Icon(Icons.arrow_back, color: AppColors.textColor, size: 22),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Image.network(
                entry.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: AppColors.separatorColor,
                  child: const Center(
                    child: Icon(Icons.image_not_supported, size: 64),
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Question (no section title)
                if (entry.question != null && entry.question!.isNotEmpty) ...[
                  Text(
                    entry.question!,
                    style: AppTextStyles.bodyText1.copyWith(
                      fontSize: 12,
                      height: 1.5,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                // Reflection text
                if (entry.description != null && entry.description!.isNotEmpty) ...[
                  Text(
                    'Reflection',
                    style: AppTextStyles.headline5.copyWith(
                      color: AppColors.primaryColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    entry.description!,
                    style: AppTextStyles.bodyText1.copyWith(
                      fontSize: 17,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                // Address
                if (entry.address != null && entry.address!.isNotEmpty) ...[
                  Text(
                    'Location',
                    style: AppTextStyles.headline5.copyWith(
                      color: AppColors.primaryColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 20,
                        color: AppColors.secondaryColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          entry.address!,
                          style: AppTextStyles.bodyText1.copyWith(
                            fontSize: 16,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
                // Timestamp
                Text(
                  'Date & Time',
                  style: AppTextStyles.headline5.copyWith(
                    color: AppColors.primaryColor,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 18,
                      color: AppColors.secondaryColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeStr,
                      style: AppTextStyles.bodyText2.copyWith(
                        fontSize: 15,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Map
                if (showMap) ...[
                  Text(
                    'Map',
                    style: AppTextStyles.headline5.copyWith(
                      color: AppColors.primaryColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      height: 220,
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: _getCenter(),
                          zoom: 15,
                        ),
                        markers: hasLocation
                            ? {
                                Marker(
                                  markerId: const MarkerId('entry'),
                                  position: LatLng(entry.lat!, entry.lng!),
                                ),
                              }
                            : {},
                        polylines: _getTrackingPolylines(),
                        zoomControlsEnabled: false,
                        mapToolbarEnabled: false,
                        myLocationButtonEnabled: false,
                        zoomGesturesEnabled: true,
                        scrollGesturesEnabled: true,
                      ),
                    ),
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
