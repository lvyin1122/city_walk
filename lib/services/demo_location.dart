import 'dart:async';
import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Simulates GPS movement for demo mode by walking a closed loop of waypoints
/// forever — the in-app equivalent of Xcode's "City Run" simulated location,
/// but pinned to Hong Kong Central and guaranteed to pass through each demo
/// walk stop so proximity-collection triggers naturally.
class DemoLocationSimulator {
  DemoLocationSimulator({
    required this.route,
    this.stepMeters = 12,
    this.tick = const Duration(seconds: 1),
  })  : assert(route.length >= 2),
        _current = route.first;

  /// Ordered loop of waypoints. The path returns from the last point back to
  /// the first, so the movement circles indefinitely.
  final List<LatLng> route;

  /// How far to advance along the route on each [tick].
  final double stepMeters;
  final Duration tick;

  final StreamController<LatLng> _controller =
      StreamController<LatLng>.broadcast();
  Timer? _timer;
  int _segIndex = 0;
  double _segProgressMeters = 0;
  LatLng _current;

  Stream<LatLng> get stream => _controller.stream;
  LatLng get current => _current;

  void start() {
    _timer?.cancel();
    // Emit the starting fix immediately so the map has something to show.
    if (!_controller.isClosed) _controller.add(_current);
    _timer = Timer.periodic(tick, (_) => step());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    stop();
    _controller.close();
  }

  Future<LatLng> getLocation() async => _current;

  /// Advance one step along the loop, emit and return the new position.
  /// Public so it can be driven deterministically in tests.
  LatLng step() {
    var remaining = stepMeters;
    // Walk forward, hopping across waypoints if a single step overshoots them.
    while (remaining > 0) {
      final a = route[_segIndex];
      final b = route[(_segIndex + 1) % route.length];
      final segLen = _distanceMeters(a, b);
      final segRemaining = segLen - _segProgressMeters;
      if (segLen == 0) {
        _segIndex = (_segIndex + 1) % route.length;
        _segProgressMeters = 0;
        continue;
      }
      if (remaining < segRemaining) {
        _segProgressMeters += remaining;
        remaining = 0;
      } else {
        remaining -= segRemaining;
        _segIndex = (_segIndex + 1) % route.length;
        _segProgressMeters = 0;
      }
    }

    final a = route[_segIndex];
    final b = route[(_segIndex + 1) % route.length];
    final segLen = _distanceMeters(a, b);
    final t = segLen == 0 ? 0.0 : (_segProgressMeters / segLen);
    _current = LatLng(
      a.latitude + (b.latitude - a.latitude) * t,
      a.longitude + (b.longitude - a.longitude) * t,
    );
    if (!_controller.isClosed) _controller.add(_current);
    return _current;
  }

  static double _distanceMeters(LatLng p1, LatLng p2) {
    const earthRadius = 6371000.0;
    final dLat = _toRad(p2.latitude - p1.latitude);
    final dLng = _toRad(p2.longitude - p1.longitude);
    final lat1 = _toRad(p1.latitude);
    final lat2 = _toRad(p2.latitude);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
    return earthRadius * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }

  static double _toRad(double deg) => deg * (math.pi / 180);
}
