import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mambo/core/geo/geo_point.dart';
import 'package:mambo/core/map/navigation_link.dart';

void main() {
  const destination = GeoPoint(22.284, 114.15);

  test('iOS opens HTTPS Apple Maps walking directions with six decimals', () {
    final uri = walkingDirectionsUri(
      destination,
      platform: TargetPlatform.iOS,
    );

    expect(uri.scheme, 'https');
    expect(uri.host, 'maps.apple.com');
    expect(uri.queryParameters, {
      'daddr': '22.284000,114.150000',
      'dirflg': 'w',
    });
  });

  test('other platforms open HTTPS Google Maps walking directions', () {
    for (final platform in TargetPlatform.values.where(
      (platform) => platform != TargetPlatform.iOS,
    )) {
      final uri = walkingDirectionsUri(destination, platform: platform);

      expect(uri.scheme, 'https');
      expect(uri.host, 'www.google.com');
      expect(uri.path, '/maps/dir/');
      expect(uri.queryParameters, {
        'api': '1',
        'destination': '22.284000,114.150000',
        'travelmode': 'walking',
      });
    }
  });
}
