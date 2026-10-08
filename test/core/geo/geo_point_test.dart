import 'package:flutter_test/flutter_test.dart';
import 'package:mambo/core/geo/geo_point.dart';

void main() {
  // Reference points in Hong Kong.
  const starFerryCentral = GeoPoint(22.2870, 114.1610);
  const starFerryTsimShaTsui = GeoPoint(22.2937, 114.1687);

  group('distanceMeters', () {
    test('is zero for the same point', () {
      expect(distanceMeters(starFerryCentral, starFerryCentral), 0);
    });

    test('matches a known distance', () {
      // The two Star Ferry piers are about 1.09 km apart across the harbour.
      expect(
        distanceMeters(starFerryCentral, starFerryTsimShaTsui),
        closeTo(1090, 20),
      );
    });

    test('one degree of latitude is about 111.2 km', () {
      expect(
        distanceMeters(const GeoPoint(0, 0), const GeoPoint(1, 0)),
        closeTo(111195, 10),
      );
    });

    test('is symmetric', () {
      expect(
        distanceMeters(starFerryCentral, starFerryTsimShaTsui),
        distanceMeters(starFerryTsimShaTsui, starFerryCentral),
      );
    });

    test('resolves the 20 m check-in radius', () {
      // 0.0001 degrees of latitude is about 11 m.
      const here = GeoPoint(22.2800, 114.1580);
      expect(distanceMeters(here, const GeoPoint(22.2801, 114.1580)), lessThan(20));
      expect(
        distanceMeters(here, const GeoPoint(22.2803, 114.1580)),
        greaterThan(20),
      );
    });
  });

  test('pathLengthMeters sums the legs in order', () {
    const a = GeoPoint(0, 0);
    const b = GeoPoint(0.001, 0);
    const c = GeoPoint(0.001, 0.001);
    expect(pathLengthMeters([]), 0);
    expect(pathLengthMeters([a]), 0);
    expect(
      pathLengthMeters([a, b, c]),
      closeTo(distanceMeters(a, b) + distanceMeters(b, c), 1e-9),
    );
  });

  group('bearingDegrees', () {
    const origin = GeoPoint(22.28, 114.15);
    test('north, east, south, west', () {
      expect(bearingDegrees(origin, const GeoPoint(22.29, 114.15)), closeTo(0, 0.01));
      expect(bearingDegrees(origin, const GeoPoint(22.28, 114.16)), closeTo(90, 0.01));
      expect(bearingDegrees(origin, const GeoPoint(22.27, 114.15)), closeTo(180, 0.01));
      expect(bearingDegrees(origin, const GeoPoint(22.28, 114.14)), closeTo(270, 0.01));
    });
  });

  test('walkingMinutes assumes 5 km/h', () {
    expect(walkingMinutes(5000), closeTo(60, 1e-9));
    expect(walkingMinutes(250), closeTo(3, 1e-9));
  });

  group('GeoPoint.tryParse', () {
    test('reads both key spellings the backend uses', () {
      expect(
        GeoPoint.tryParse({'latitude': 22.28, 'longitude': 114.15}),
        const GeoPoint(22.28, 114.15),
      );
      expect(
        GeoPoint.tryParse({'lat': 22.28, 'lng': 114.15}),
        const GeoPoint(22.28, 114.15),
      );
    });

    test('accepts numbers sent as strings or integers', () {
      expect(
        GeoPoint.tryParse({'lat': '22.28', 'lng': 114}),
        const GeoPoint(22.28, 114),
      );
    });

    test('returns null when a coordinate is missing or malformed', () {
      expect(GeoPoint.tryParse(null), isNull);
      expect(GeoPoint.tryParse('22.28,114.15'), isNull);
      expect(GeoPoint.tryParse({'latitude': 22.28}), isNull);
      expect(GeoPoint.tryParse({'lat': 'north', 'lng': 114.15}), isNull);
    });
  });
}
