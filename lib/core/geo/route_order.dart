import 'geo_point.dart';

/// Finds a walking order, not the shortest route, by nearest neighbour.
/// Equal distances keep the input order; the input itself is unchanged.
List<T> orderForWalking<T>(
  GeoPoint start,
  Iterable<T> items,
  GeoPoint Function(T item) positionOf,
) {
  final remaining = items.toList();
  final ordered = <T>[];
  var position = start;
  while (remaining.isNotEmpty) {
    var nearest = 0;
    var nearestDistance = distanceMeters(position, positionOf(remaining.first));
    for (var i = 1; i < remaining.length; i++) {
      final distance = distanceMeters(position, positionOf(remaining[i]));
      if (distance < nearestDistance) {
        nearest = i;
        nearestDistance = distance;
      }
    }
    final next = remaining.removeAt(nearest);
    ordered.add(next);
    position = positionOf(next);
  }
  return ordered;
}
