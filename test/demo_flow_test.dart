import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mambo/services/demo_service.dart';
import 'package:mambo/services/demo_location.dart';

double _distanceMeters(LatLng a, LatLng b) {
  const r = 6371000.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(b.latitude - a.latitude);
  final dLng = rad(b.longitude - a.longitude);
  final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(rad(a.latitude)) *
          math.cos(rad(b.latitude)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return r * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
}

void main() {
  final demo = DemoService.instance;

  setUp(() {
    demo.isDemo = true;
    demo.reset();
  });

  test('full city-walk mock flow produces valid, connected data', () {
    // 1. Plan a walk.
    final gen = demo.generateWalk(duration: 45, keywords: ['culture']);
    final walk = gen['data']['generateWalkWithGpt']['walk'];
    final walkId = walk['Id'] as String;
    final locations = walk['locations'] as List;
    expect(walkId, isNotEmpty);
    expect(locations.length, greaterThanOrEqualTo(3));
    expect(walk['tasks'], isEmpty, reason: 'fresh walk has no tasks yet');
    expect(walk['totalDuration'], 45);
    for (final l in locations) {
      expect(l['coordinates']['latitude'], isA<double>());
      expect(l['coordinates']['longitude'], isA<double>());
    }

    // 2. Select a subset in the preview, start the walk.
    demo.selectLocations(walkId, [0, 1, 2]);
    demo.updateWalkStatus(walkId, 'in_progress');
    final selected = (demo.getWalk(walkId)['data']['walk']['locations'] as List)
        .where((l) => l['selected'] == true)
        .toList();
    expect(selected.length, 3);

    // 3. Live walk: collect locations + tracking coordinates.
    demo.collectLocation(walkId, 0);
    demo.collectLocation(walkId, 1);
    demo.collectLocation(walkId, 2);
    demo.addWalkCoordinate(walkId, 22.281, 114.159);
    demo.addWalkCoordinate(walkId, 22.282, 114.158);
    final tracking =
        demo.getWalkTracking(walkId)['data']['walkTracking']['coordinates']
            as List;
    expect(tracking.length, 2);

    // 4. Photo tasks: generate → verify (upload) → completion.
    var task = demo.generateTask(walkId)['data']['generateTaskWithGpt']['task'];
    expect(task['description'], isNotEmpty);
    expect(task['photosRequired'], 1);
    final verify = demo.verifyTask(
        walkId, '/tmp/photo1.jpg', '22.2816', '114.1543');
    expect(verify['data']['verifyTaskWithGpt']['success'], isTrue);
    expect(verify['data']['verifyTaskWithGpt']['taskStatus'], 'completed');

    // Second task + photo.
    demo.generateTask(walkId);
    demo.verifyTask(walkId, '/tmp/photo2.jpg', '22.2834', '114.1513');

    final images = demo.getAllTasksImages(walkId)['data']['getAllTasksImages']
        ['images'] as List;
    expect(images.length, 2);
    expect(images.first['url'], '/tmp/photo1.jpg');

    // 5. Favourite ("this surprised me") moments.
    demo.addFavoriteLocation(walkId, 22.2839, 114.1497, '/tmp/fav.jpg');
    final favs = demo.getFavoriteLocations(walkId)['data']
        ['getFavoriteLocations']['favoriteLocations'] as List;
    expect(favs.length, 1);
    expect(favs.first['photoUrl'], '/tmp/fav.jpg');

    // 6. Finish + summary.
    demo.updateWalkStats(walkId, 1.8, 900);
    demo.updateWalkStatus(walkId, 'completed');
    final finalWalk = demo.getWalk(walkId)['data']['walk'];
    expect(finalWalk['status'], 'completed');
    expect(finalWalk['distanceTraveled'], 1.8);
    expect(finalWalk['tasksCompleted'], 2);

    final summary =
        demo.generateWalkSummary(walkId)['data']['generateWalkSummary']
            ['summary'] as String;
    expect(summary, isNotEmpty);
    expect(summary, contains('Central'));
  });

  test('demo user is available while in demo mode', () {
    expect(demo.demoUser.id, DemoService.demoUserId);
    expect(demo.demoUser.userMetadata?['name'], 'Explorer');
  });

  test('simulator circles Central and passes within 20m of every stop', () {
    final sim = DemoLocationSimulator(route: demo.routePoints);
    // Collectible stops are the leading route points (the trailing one is a
    // routing-only waypoint).
    final stops = demo.routePoints.take(5).toList();
    final minDist = List<double>.filled(stops.length, double.infinity);

    // Start position counts, then walk ~2 full loops worth of steps.
    void record(LatLng p) {
      for (var i = 0; i < stops.length; i++) {
        final d = _distanceMeters(p, stops[i]);
        if (d < minDist[i]) minDist[i] = d;
      }
    }

    record(sim.current);
    for (var i = 0; i < 500; i++) {
      record(sim.step());
    }

    for (var i = 0; i < stops.length; i++) {
      expect(
        minDist[i],
        lessThanOrEqualTo(20.0),
        reason: 'stop $i never got within collection radius '
            '(closest ${minDist[i].toStringAsFixed(1)} m)',
      );
    }
    sim.dispose();
  });
}
