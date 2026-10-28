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
      expect(session.countdownSeconds, WalkSession.taskWindow.inSeconds);
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

      expect(session.reachStopsNear(const GeoPoint(22.3306, 114.1602)), isEmpty); // ~33 m
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

    test('the countdown warns at five minutes and then expires', () {
      final session = withTask(2)..countdownSeconds = 301;

      expect(session.tick(), CountdownEvent.fiveMinutesLeft);
      expect(session.countdownUrgent, isTrue);
      session.countdownSeconds = 1;
      expect(session.tick(), CountdownEvent.expired);
      expect(session.countdownSeconds, WalkSession.taskWindow.inSeconds);
    });

    test('a finished task does not count down', () {
      final session = withTask(1)..photosFulfilled = 1;
      final before = session.countdownSeconds;
      expect(session.tick(), CountdownEvent.none);
      expect(session.countdownSeconds, before);
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
