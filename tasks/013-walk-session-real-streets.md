# 013: Walk session for real streets

- **Status:** in review (approved and implemented in the maintainer-authorized P0 batch 2026-10-30; CI/device acceptance pending)
- **Priority:** P0
- **Owner:** Codex
- **Base branch:** improve/stabilize-and-restyle
- **Branch:** codex/013-walk-session-real-streets
- **Waiting for:** nothing

## Goal

The walk logic copes with real GPS in a dense city: bad fixes neither add
distance nor tick off stops, a stop counts as reached a little further out
when the fix is uncertain, the user can check in by hand near a stop, and the
session knows the walking order and the next stop. Logic only; card 015
connects it to the screen.

## Background

`lib/features/walk/session/walk_session.dart` (172 lines, unit-tested in
`test/features/walk/walk_session_test.dart`):

- `reachRadiusMeters = 20` (line ~44). Among tall buildings GPS error is often
  20-50 m, so a user standing at a stop may never "reach" it, and there is no
  manual way to mark it.
- `recordPathPoint` (line ~109-112) adds the straight distance between every
  recorded point. `LocationData.accuracy` and `time` are ignored
  (`walk_map_page.dart`, `_onPosition`), so a jumpy fix adds distance and a
  person standing still slowly "walks".
- `stops` are in the backend's order; there is no notion of the next stop, so
  the screen cannot say where to go.
- `GeoPoint`, `distanceMeters`, `bearingDegrees` live in
  `lib/core/geo/geo_point.dart`. Do not write another haversine.
- The task countdown (`taskWindow`, `tick`, `CountdownEvent`,
  `countdownSeconds`) is still used by `walk_map_page.dart` and the
  `TaskPanel`; card 015 removes it. Do not touch it here.

## Files or directories involved

- `lib/features/walk/session/walk_session.dart`
- `lib/core/geo/route_order.dart` (new)
- `test/features/walk/walk_session_test.dart`
- `test/core/geo/route_order_test.dart` (new)

## Implementation requirements

1. `lib/core/geo/route_order.dart`:
   `List<T> orderForWalking<T>(GeoPoint start, Iterable<T> items, GeoPoint Function(T item) positionOf)`
   — greedy nearest neighbour from `start`; ties keep the input order; an
   empty input gives an empty list. Doc comment: "a walking order, not the
   shortest route".
2. `WalkSession` constants (with doc comments):
   `reachRadiusMeters = 35`, `maxAccuracyMeters = 40`,
   `maxWalkingSpeedMetersPerSecond = 4`, `checkInRadiusMeters = 120`.
3. `bool acceptFix(GeoPoint point, {double? accuracyMeters, DateTime? time})`:
   false when `accuracyMeters` is above `maxAccuracyMeters`; false when the
   speed from the last accepted fix (both with `time`) is above
   `maxWalkingSpeedMetersPerSecond`; otherwise remembers the fix and returns
   true. A fix without accuracy or time is judged only on what it has.
4. `reachStopsNear(GeoPoint position, {double? accuracyMeters})`: the radius is
   `reachRadiusMeters + min(accuracyMeters ?? 0, 25)`. Behaviour otherwise as
   today (each stop reported once; `unreach` still works).
5. Walking order:
   - `void planRoute(GeoPoint start)`: orders `stops` with `orderForWalking`
     once; later calls do nothing. Before it is called the order is `stops`.
   - `List<WalkStop> get walkingOrder`, `bool get routePlanned`,
     `int? numberOf(WalkStop stop)` (1-based position in `walkingOrder`).
   - `WalkStop? get nextStop`: the first stop in `walkingOrder` that is not
     reached; null when all are reached.
6. Manual check-in:
   - `bool canCheckIn(WalkStop stop, GeoPoint? position)`: not reached, a
     position is known, and `distanceMeters(position, stop.position) <= checkInRadiusMeters`.
   - `bool checkIn(WalkStop stop)`: marks it reached; returns true only the
     first time.
7. `takeFinishSuggestion` keeps working for stops reached by check-in.

## Restrictions

- Change only the files above. Do not change the countdown API or anything
  `walk_map_page.dart` uses today; `flutter analyze` must stay clean on this
  branch without touching the page.
- Pure Dart: no Flutter imports in `walk_session.dart` or `route_order.dart`.

## Tests to add or update

- `route_order_test.dart`: three points in a line given in reverse order come
  back nearest-first; empty input; ties keep input order.
- `walk_session_test.dart` (add groups, keep the existing tests):
  - `acceptFix`: accuracy 80 m → false; a jump of 500 m in 10 s → false; a
    10 m step in 10 s → true; first fix with accuracy 10 m → true;
  - `reachStopsNear`: 30 m away with accuracy 5 → reached; 50 m away with
    accuracy 20 → reached (35 + 20); 70 m away with accuracy 100 → not reached
    (35 + 25);
  - `planRoute` orders stops from the start, is idempotent, `numberOf` and
    `nextStop` follow it and skip reached stops; `nextStop` is null when all
    are reached;
  - `canCheckIn` at 100 m → true, at 150 m → false, already reached → false;
    `checkIn` returns true once and makes `takeFinishSuggestion()` true when
    it was the last stop.

## Acceptance criteria

- All new behaviour is covered by the tests above.
- `git diff --stat` lists only the four files.

## Commands that must pass

```sh
flutter pub get
flutter analyze   # "No issues found!"
flutter test      # all pass
```

## Information Codex must report after completion

The report format in `AGENTS.md`.
