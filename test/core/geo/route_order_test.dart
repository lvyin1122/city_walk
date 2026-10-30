import 'package:flutter_test/flutter_test.dart';
import 'package:mambo/core/geo/geo_point.dart';
import 'package:mambo/core/geo/route_order.dart';

void main() {
  test('orders a reversed line nearest-first without changing the input', () {
    const a = GeoPoint(0.001, 0);
    const b = GeoPoint(0.002, 0);
    const c = GeoPoint(0.003, 0);
    final input = [c, b, a];
    expect(orderForWalking(const GeoPoint(0, 0), input, (p) => p), [a, b, c]);
    expect(input, [c, b, a]);
  });

  test('returns an empty list for empty input', () {
    expect(orderForWalking<GeoPoint>(const GeoPoint(0, 0), [], (p) => p), isEmpty);
  });

  test('keeps the input order for ties', () {
    final input = [
      (name: 'first', point: const GeoPoint(0, -0.001)),
      (name: 'second', point: const GeoPoint(0, 0.001)),
      (name: 'third', point: const GeoPoint(0, 0.001)),
    ];
    expect(
      orderForWalking(const GeoPoint(0, 0), input, (p) => p.point).map((p) => p.name),
      ['first', 'second', 'third'],
    );
  });
}
