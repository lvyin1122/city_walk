import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mambo/features/home/log/log_map.dart';
import 'package:mambo/services/log_service.dart';

LogTrackingPoint point(double lat, double lng, String time) =>
    LogTrackingPoint(lat: lat, lng: lng, timestamp: '2026-10-07T$time:00Z');

LogEntry entry(double? lat, double? lng) => LogEntry(
  id: 'e',
  imageUrl: '',
  timestamp: DateTime.utc(2026, 10, 7),
  lat: lat,
  lng: lng,
);

Log logWith(List<LogTrackingSession> sessions, {List<LogEntry> entries = const []}) => Log(
  id: 'log',
  createdAt: DateTime.utc(2026, 10, 7),
  entries: entries,
  tracking: sessions.isEmpty ? null : LogTracking(logId: 'log', sessions: sessions),
);

void main() {
  test('sessionPath orders by time and drops consecutive duplicates', () {
    final path = sessionPath(
      LogTrackingSession(
        points: [
          point(22.30, 114.10, '10:02'),
          point(22.28, 114.10, '10:00'),
          point(22.28, 114.10, '10:01'),
        ],
      ),
    );

    expect(path, const [LatLng(22.28, 114.10), LatLng(22.30, 114.10)]);
  });

  test('logPolylines draws one line per tracked session', () {
    final log = logWith([
      LogTrackingSession(points: [point(1, 1, '10:00'), point(2, 2, '10:01')]),
      LogTrackingSession(points: [point(3, 3, '11:00'), point(4, 4, '11:01')]),
    ]);

    expect(logPolylines([log], const []), hasLength(2));
  });

  test('logPolylines connects the entries when nothing was tracked', () {
    final entries = [entry(1, 1), entry(null, null), entry(2, 2)];

    final polylines = logPolylines([logWith(const [])], entries);

    expect(polylines.single.points, const [LatLng(1, 1), LatLng(2, 2)]);
  });

  test('a single known position still renders', () {
    final polylines = logPolylines([logWith(const [])], [entry(1, 1)]);
    expect(polylines.single.points, hasLength(2));
  });

  test('logPositions is empty when nothing has a position', () {
    expect(logPositions([logWith(const [])], [entry(null, null)]), isEmpty);
  });

  test('logPositions covers entries and tracked points', () {
    final log = logWith([
      LogTrackingSession(points: [point(3, 3, '10:00')]),
    ]);
    expect(logPositions([log], [entry(1, 1)]), hasLength(2));
  });
}
