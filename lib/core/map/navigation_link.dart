import 'package:flutter/foundation.dart';

import '../geo/geo_point.dart';

/// Walking directions to [destination] in the platform's map application.
Uri walkingDirectionsUri(
  GeoPoint destination, {
  required TargetPlatform platform,
}) {
  final coordinates =
      '${destination.latitude.toStringAsFixed(6)},'
      '${destination.longitude.toStringAsFixed(6)}';
  return platform == TargetPlatform.iOS
      ? Uri.https('maps.apple.com', '/', {
          'daddr': coordinates,
          'dirflg': 'w',
        })
      : Uri.https('www.google.com', '/maps/dir/', {
          'api': '1',
          'destination': coordinates,
          'travelmode': 'walking',
        });
}
