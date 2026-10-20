import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../geo/geo_point.dart';

/// Conversions between the app's [GeoPoint] and the map SDK's [LatLng].
/// Only map widgets should need these.
extension GeoPointToLatLng on GeoPoint {
  LatLng toLatLng() => LatLng(latitude, longitude);
}

extension LatLngToGeoPoint on LatLng {
  GeoPoint toGeoPoint() => GeoPoint(latitude, longitude);
}

/// A [LatLng] from JSON coordinates, or null when they cannot be read.
///
/// [json] uses the same shapes as [GeoPoint.tryParse]: `latitude`/`longitude`
/// or `lat`/`lng`, each a number or a numeric string.
LatLng? latLngFromJson(Object? json) => GeoPoint.tryParse(json)?.toLatLng();

/// Distance in metres between two map positions.
double latLngDistanceMeters(LatLng a, LatLng b) =>
    distanceMeters(a.toGeoPoint(), b.toGeoPoint());

/// Smallest bounds containing all [points], grown by [paddingDegrees] on each
/// side. Returns null for an empty list.
LatLngBounds? boundsOf(Iterable<LatLng> points, {double paddingDegrees = 0}) {
  if (points.isEmpty) return null;
  var minLat = points.first.latitude;
  var maxLat = minLat;
  var minLng = points.first.longitude;
  var maxLng = minLng;
  for (final point in points) {
    if (point.latitude < minLat) minLat = point.latitude;
    if (point.latitude > maxLat) maxLat = point.latitude;
    if (point.longitude < minLng) minLng = point.longitude;
    if (point.longitude > maxLng) maxLng = point.longitude;
  }
  return LatLngBounds(
    southwest: LatLng(minLat - paddingDegrees, minLng - paddingDegrees),
    northeast: LatLng(maxLat + paddingDegrees, maxLng + paddingDegrees),
  );
}

/// Camera move that shows all of [points] with [padding] pixels around them.
///
/// Returns null for an empty list. Bounds collapse to nothing when there is
/// a single distinct position, so that case centres on it at street level
/// instead.
CameraUpdate? cameraUpdateToFit(Iterable<LatLng> points, {double padding = 48}) {
  final bounds = boundsOf(points);
  if (bounds == null) return null;
  if (bounds.southwest == bounds.northeast) {
    return CameraUpdate.newLatLngZoom(bounds.southwest, 16);
  }
  return CameraUpdate.newLatLngBounds(bounds, padding);
}
