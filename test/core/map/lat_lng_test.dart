import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mambo/core/geo/geo_point.dart';
import 'package:mambo/core/map/lat_lng.dart';

void main() {
  test('GeoPoint and LatLng convert both ways', () {
    const point = GeoPoint(22.28, 114.15);
    expect(point.toLatLng(), const LatLng(22.28, 114.15));
    expect(point.toLatLng().toGeoPoint(), point);
  });

  group('boundsOf', () {
    test('contains every point, grown by the padding', () {
      final bounds = boundsOf(const [
        LatLng(22.30, 114.10),
        LatLng(22.20, 114.20),
      ], paddingDegrees: 0.01)!;

      expect(bounds.southwest.latitude, closeTo(22.19, 1e-9));
      expect(bounds.southwest.longitude, closeTo(114.09, 1e-9));
      expect(bounds.northeast.latitude, closeTo(22.31, 1e-9));
      expect(bounds.northeast.longitude, closeTo(114.21, 1e-9));
    });

    test('is null for no points', () {
      expect(boundsOf(const []), isNull);
      expect(cameraUpdateToFit(const []), isNull);
    });
  });
}
