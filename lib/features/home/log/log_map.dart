import 'package:mambo/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mambo/core/map/lat_lng.dart';

import '../../../services/log_service.dart';

/// Positions of [session] in time order, without consecutive duplicates.
List<LatLng> sessionPath(LogTrackingSession session) {
  final sorted = List<LogTrackingPoint>.of(session.points)..sort((a, b) {
    final at = DateTime.tryParse(a.timestamp);
    final bt = DateTime.tryParse(b.timestamp);
    return at != null && bt != null ? at.compareTo(bt) : 0;
  });
  return _withoutConsecutiveDuplicates([
    for (final point in sorted) LatLng(point.lat, point.lng),
  ]);
}

/// Positions where [entries] were recorded, in the given order.
List<LatLng> entryPositions(Iterable<LogEntry> entries) => [
  for (final entry in entries)
    if (entry.lat != null && entry.lng != null) LatLng(entry.lat!, entry.lng!),
];

/// Every position known for [logs] and [entries]: where entries were
/// recorded and every tracked point. Used to frame the map.
List<LatLng> logPositions(Iterable<Log> logs, Iterable<LogEntry> entries) => [
  ...entryPositions(entries),
  for (final log in logs)
    for (final session in log.tracking?.sessions ?? const <LogTrackingSession>[])
      for (final point in session.points) LatLng(point.lat, point.lng),
];

/// One line per tracking session of [logs]. When nothing was tracked, a
/// single line connecting [entries] instead, so the day still has a shape.
Set<Polyline> logPolylines(Iterable<Log> logs, Iterable<LogEntry> entries) {
  final paths = <List<LatLng>>[
    for (final log in logs)
      for (final session
          in log.tracking?.sessions ?? const <LogTrackingSession>[])
        sessionPath(session),
  ]..removeWhere((path) => path.isEmpty);

  if (paths.isEmpty) {
    final fallback = _withoutConsecutiveDuplicates(entryPositions(entries));
    if (fallback.isNotEmpty) paths.add(fallback);
  }

  return {
    for (final (index, path) in paths.indexed)
      Polyline(
        polylineId: PolylineId('track_$index'),
        // A single point is doubled so that it still renders as a dot.
        points: path.length >= 2 ? path : [path.first, path.first],
        color: FreshColors.sky,
        width: 3,
        geodesic: true,
      ),
  };
}

List<LatLng> _withoutConsecutiveDuplicates(List<LatLng> points) {
  final result = <LatLng>[];
  for (final point in points) {
    if (result.isEmpty || result.last != point) result.add(point);
  }
  return result;
}

/// Small map of a day's records: a marker per entry and the tracked path.
///
/// Build it only when [logPositions] is not empty; an empty map has nothing
/// to centre on.
class LogMap extends StatelessWidget {
  const LogMap({
    super.key,
    required this.logs,
    required this.entries,
    this.height = 220,
  });

  final List<Log> logs;
  final List<LogEntry> entries;
  final double height;

  @override
  Widget build(BuildContext context) {
    final positions = logPositions(logs, entries);
    final markerPositions = entryPositions(entries);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: height,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: positions.isNotEmpty ? positions.first : const LatLng(0, 0),
            zoom: 14,
          ),
          markers: {
            for (final (index, position) in markerPositions.indexed)
              Marker(markerId: MarkerId('entry_$index'), position: position),
          },
          polylines: logPolylines(logs, entries),
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          myLocationButtonEnabled: false,
          zoomGesturesEnabled: true,
          scrollGesturesEnabled: true,
          onMapCreated: (controller) {
            final update = cameraUpdateToFit(positions);
            if (update == null) return;
            // The map needs a laid-out size before it can fit bounds.
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              try {
                await controller.animateCamera(update);
              } catch (e) {
                debugPrint('Could not fit the record map: $e');
              }
            });
          },
        ),
      ),
    );
  }
}
