import 'package:flutter_test/flutter_test.dart';
import 'package:mambo/core/geo/geo_point.dart';
import 'package:mambo/features/walk/domain/photo_check.dart';
import 'package:mambo/features/walk/domain/walk.dart';
import 'package:mambo/features/walk/session/walk_session.dart';

const _a = GeoPoint(22.3303, 114.1602);
const _b = GeoPoint(22.3310, 114.1620);
const _c = GeoPoint(22.3296, 114.1634);

Walk _walk({
  List<WalkTask> tasks = const [],
  bool bCollected = false,
  Duration? timeSpent,
}) => Walk(
  id: 'w1',
  timeSpent: timeSpent,
  distanceKm: timeSpent == null ? null : 1.5,
  stops: [
    const WalkStop(index: 0, name: 'A', position: _a, selected: true),
    const WalkStop(index: 1, name: 'Skipped', position: _c),
    WalkStop(index: 2, name: 'B', position: _b, selected: true, collected: bCollected),
  ],
  tasks: tasks,
);

void main() {
  group('resume', () {
    test('keeps only the chosen stops and their progress', () {
      final session = WalkSession.resume(
        _walk(bCollected: true, timeSpent: const Duration(minutes: 20)),
      );

      expect(session.stops.map((s) => s.name), ['A', 'B']);
      expect(session.reachedStops, {2});
      expect(session.elapsedBefore, const Duration(minutes: 20));
      expect(session.distanceKm, 1.5);
      expect(session.firstStopPosition, _a);
    });

    test('continues an open task with its photos', () {
      final session = WalkSession.resume(
        _walk(
          tasks: const [
            WalkTask(description: 'old', status: 'completed', photosRequired: 1, photosFulfilled: 1),
            WalkTask(description: 'open', status: 'in_progress', photosRequired: 3, photosFulfilled: 2),
          ],
        ),
      );

      expect(session.task!.description, 'open');
      expect(session.photosFulfilled, 2);
      expect(session.tasksCompleted, 1);
    });

    test('has no task when the last one was completed', () {
      final session = WalkSession.resume(
        _walk(tasks: const [WalkTask(description: 'done', status: 'completed', photosRequired: 1)]),
      );
      expect(session.task, isNull);
    });
  });

  group('reaching stops', () {
    test('reports each stop once, only within the radius', () {
      final session = WalkSession.resume(_walk());

      expect(session.reachStopsNear(const GeoPoint(22.3307, 114.1602)), isEmpty); // ~44 m
      expect(session.reachStopsNear(const GeoPoint(22.3304, 114.1602)).single.name, 'A');
      expect(session.reachStopsNear(_a), isEmpty);
      expect(session.allStopsReached, isFalse);
    });

    test('a failed upload can be retried', () {
      final session = WalkSession.resume(_walk());
      final stop = session.reachStopsNear(_a).single;

      session.unreach(stop);

      expect(session.reachStopsNear(_a).single, stop);
    });

    test('suggests finishing once, when the last stop is reached', () {
      final session = WalkSession.resume(_walk());
      session.reachStopsNear(_a);
      expect(session.takeFinishSuggestion(), isFalse);

      session.reachStopsNear(_b);

      expect(session.takeFinishSuggestion(), isTrue);
      expect(session.takeFinishSuggestion(), isFalse);
    });

    test('does not suggest finishing again after a resume', () {
      final session = WalkSession.resume(_walk(bCollected: true))..reachStopsNear(_a);
      expect(session.takeFinishSuggestion(), isTrue);

      final resumed = WalkSession.resume(
        Walk(
          id: 'w1',
          stops: const [
            WalkStop(index: 0, name: 'A', position: _a, selected: true, collected: true),
          ],
        ),
      );
      expect(resumed.takeFinishSuggestion(), isFalse);
    });
  });

  test('the route adds up distance but earlier points are not counted twice', () {
    final session = WalkSession.resume(_walk(timeSpent: Duration.zero))..distanceKm = 1.0;

    session.recordPathPoint(_a);
    session.recordPathPoint(_b);
    session.restoreEarlierPath(const [_c]);

    expect(session.path, [_c, _a, _b]);
    expect(session.distanceKm, closeTo(1.0 + distanceMeters(_a, _b) / 1000, 1e-9));
  });

  group('GPS fixes', () {
    final time = DateTime.utc(2026, 10, 30);
    const nearby = GeoPoint(22.33039, 114.1602); // ~10 m
    const jump = GeoPoint(22.3348, 114.1602); // ~500 m

    test('accepts a first accurate fix and a walking step', () {
      final session = WalkSession.resume(_walk());
      expect(session.acceptFix(_a, accuracyMeters: 10, time: time), isTrue);
      expect(session.acceptFix(nearby, time: time.add(const Duration(seconds: 10))), isTrue);
    });

    test('rejects poor accuracy and does not move the baseline', () {
      final session = WalkSession.resume(_walk());
      expect(session.acceptFix(_a, accuracyMeters: 80, time: time), isFalse);
      expect(session.acceptFix(jump, accuracyMeters: 10, time: time), isTrue);
    });

    test('rejects jumps without affecting the following walking step', () {
      final session = WalkSession.resume(_walk())..acceptFix(_a, time: time);
      expect(session.acceptFix(jump, time: time.add(const Duration(seconds: 10))), isFalse);
      expect(session.acceptFix(nearby, time: time.add(const Duration(seconds: 20))), isTrue);
    });

    test('uses only the available accuracy and timestamp information', () {
      final session = WalkSession.resume(_walk());
      expect(session.acceptFix(_a), isTrue);
      expect(session.acceptFix(jump, accuracyMeters: 40), isTrue);
      expect(session.acceptFix(nearby, time: time), isTrue);
      expect(session.acceptFix(_a), isTrue);
    });

    test('rejects stale timestamps and non-finite accuracy', () {
      final session = WalkSession.resume(_walk())..acceptFix(_a, time: time);
      expect(session.acceptFix(nearby, time: time), isFalse);
      expect(session.acceptFix(nearby, time: time.subtract(const Duration(seconds: 1))), isFalse);
      expect(session.acceptFix(_a, accuracyMeters: double.nan), isFalse);
    });
  });

  group('accuracy-aware arrival', () {
    test('reaches at 30 metres with five-metre accuracy', () {
      final session = WalkSession.resume(_walk());
      expect(session.reachStopsNear(const GeoPoint(22.33057, 114.1602), accuracyMeters: 5).single.name, 'A');
    });

    test('reaches at 50 metres with 20-metre accuracy', () {
      final session = WalkSession.resume(_walk());
      expect(session.reachStopsNear(const GeoPoint(22.33075, 114.1602), accuracyMeters: 20).single.name, 'A');
    });

    test('caps the accuracy allowance at 25 metres', () {
      final session = WalkSession.resume(_walk());
      expect(session.reachStopsNear(const GeoPoint(22.33093, 114.1602), accuracyMeters: 100), isEmpty);
    });
  });

  group('walking order and manual check-in', () {
    test('plans once from the start and skips reached stops', () {
      final session = WalkSession.resume(_walk());
      expect(session.routePlanned, isFalse);
      expect(session.walkingOrder.map((s) => s.name), ['A', 'B']);
      session.planRoute(_b);
      expect(session.routePlanned, isTrue);
      expect(session.walkingOrder.map((s) => s.name), ['B', 'A']);
      final first = session.walkingOrder.first;
      final last = session.walkingOrder.last;
      expect(session.numberOf(first), 1);
      expect(session.numberOf(last), 2);
      expect(session.numberOf(const WalkStop(index: 99, name: 'other', position: _a)), isNull);
      expect(session.nextStop, first);
      session.planRoute(_a);
      expect(session.nextStop, first);
      expect(session.checkIn(first), isTrue);
      expect(session.checkIn(first), isFalse);
      expect(session.nextStop, last);
      expect(session.takeFinishSuggestion(), isFalse);
      session.checkIn(last);
      expect(session.nextStop, isNull);
      expect(session.takeFinishSuggestion(), isTrue);
      expect(session.takeFinishSuggestion(), isFalse);
    });

    test('requires a known position within 120 metres and an unreached stop', () {
      final session = WalkSession.resume(_walk());
      final stop = session.stops.first;
      expect(session.canCheckIn(stop, null), isFalse);
      expect(session.canCheckIn(stop, const GeoPoint(22.3312, 114.1602)), isTrue); // ~100 m
      expect(session.canCheckIn(stop, const GeoPoint(22.33165, 114.1602)), isFalse); // ~150 m
      session.checkIn(stop);
      expect(session.canCheckIn(stop, _a), isFalse);
    });

    test('an empty walk has no next stop before or after planning', () {
      final session = WalkSession.resume(const Walk(id: 'empty'));
      expect(session.nextStop, isNull);
      session.planRoute(_a);
      expect(session.walkingOrder, isEmpty);
      expect(session.nextStop, isNull);
    });
  });

  group('tasks', () {
    WalkSession withTask(int required) =>
        WalkSession.resume(_walk())
          ..startTask(WalkTask(description: 't', photosRequired: required));

    test('uses the backend count of accepted photos', () {
      final session = withTask(3);

      final completed = session.applyPhotoCheck(
        const PhotoCheck(accepted: true, photosFulfilled: 2, taskStatus: 'in_progress'),
      );

      expect(completed, isFalse);
      expect(session.photosFulfilled, 2);
    });

    test('a rejected photo changes nothing', () {
      final session = withTask(2);
      expect(session.applyPhotoCheck(const PhotoCheck(accepted: false)), isFalse);
      expect(session.photosFulfilled, 0);
    });

    test('completing a task counts it once', () {
      final session = withTask(1);

      expect(
        session.applyPhotoCheck(
          const PhotoCheck(accepted: true, photosFulfilled: 1, taskStatus: 'completed'),
        ),
        isTrue,
      );
      expect(session.tasksCompleted, 1);
      expect(session.applyPhotoCheck(const PhotoCheck(accepted: true)), isFalse);
      expect(session.tasksCompleted, 1);
    });

  });

  test('surprise spots nearby are recognised', () {
    final session = WalkSession.resume(_walk())
      ..surprises = [const SurpriseSpot(position: _a, photoUrl: 'x')];

    expect(session.hasSurpriseNear(const GeoPoint(22.33035, 114.1602)), isTrue);
    expect(session.hasSurpriseNear(_b), isFalse);
    expect(session.hasSurpriseNear(null), isFalse);
  });
}
