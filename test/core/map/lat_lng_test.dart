import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mambo/core/map/lat_lng.dart';

void main() {
  group('latLngFromJson', () {
    test('reads doubles, integers, numeric strings, and lat/lng keys', () {
      expect(
        latLngFromJson({'latitude': 22.28, 'longitude': 114.15}),
        const LatLng(22.28, 114.15),
      );
      expect(
        latLngFromJson({'latitude': 22, 'longitude': 114}),
        const LatLng(22.0, 114.0),
      );
      expect(
        latLngFromJson({'latitude': '22.28', 'longitude': '114.15'}),
        const LatLng(22.28, 114.15),
      );
      expect(
        latLngFromJson({'lat': 22.28, 'lng': 114.15}),
        const LatLng(22.28, 114.15),
      );
    });

    test('returns null when the value cannot be a position', () {
      expect(latLngFromJson(null), isNull);
      expect(latLngFromJson('22.28,114.15'), isNull);
      expect(latLngFromJson({'latitude': 22.28}), isNull);
      expect(latLngFromJson({'lat': 'north', 'lng': 114.15}), isNull);
    });
  });
}
