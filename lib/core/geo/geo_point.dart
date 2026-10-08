import 'dart:math' as math;

/// A position on Earth in decimal degrees.
///
/// The app's own coordinate type, so that models and services do not depend
/// on a map SDK.
class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  /// Reads `{"latitude": ..., "longitude": ...}` or `{"lat": ..., "lng": ...}`.
  /// Returns null when either coordinate is missing or not a number.
  static GeoPoint? tryParse(Object? json) {
    if (json is! Map) return null;
    final latitude = _asDouble(json['latitude'] ?? json['lat']);
    final longitude = _asDouble(json['longitude'] ?? json['lng']);
    if (latitude == null || longitude == null) return null;
    return GeoPoint(latitude, longitude);
  }

  @override
  bool operator ==(Object other) =>
      other is GeoPoint &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'GeoPoint($latitude, $longitude)';
}

const double _earthRadiusMeters = 6371000;

/// Great-circle distance between [a] and [b] in metres (haversine formula).
double distanceMeters(GeoPoint a, GeoPoint b) {
  final lat1 = _radians(a.latitude);
  final lat2 = _radians(b.latitude);
  final dLat = lat2 - lat1;
  final dLng = _radians(b.longitude - a.longitude);

  final h =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return _earthRadiusMeters * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
}

/// Total length in metres of the path through [points], in order.
double pathLengthMeters(List<GeoPoint> points) {
  var total = 0.0;
  for (var i = 1; i < points.length; i++) {
    total += distanceMeters(points[i - 1], points[i]);
  }
  return total;
}

/// Initial compass bearing from [from] to [to]: 0 is north, 90 is east.
double bearingDegrees(GeoPoint from, GeoPoint to) {
  final lat1 = _radians(from.latitude);
  final lat2 = _radians(to.latitude);
  final dLng = _radians(to.longitude - from.longitude);

  final y = math.sin(dLng) * math.cos(lat2);
  final x =
      math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}

/// Average walking speed used for time estimates: 5 km/h.
const double walkingSpeedMetersPerMinute = 5000 / 60;

/// Minutes needed to walk [meters] at [walkingSpeedMetersPerMinute].
double walkingMinutes(double meters) => meters / walkingSpeedMetersPerMinute;

double _radians(double degrees) => degrees * math.pi / 180;

double? _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  return value == null ? null : double.tryParse(value.toString());
}
