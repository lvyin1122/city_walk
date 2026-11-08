# 026: Keep the route when the connection drops

- **Status:** draft
- **Priority:** P1
- **Owner:** Codex
- **Base branch:** improve/stabilize-and-restyle (after 015 is merged)
- **Branch:** codex/026-offline-route-queue
- **Waiting for:** backend card B12 merged (contract), card 015
  (`walk_map_page.dart`)

## Goal

Route points recorded in a subway, a lift or abroad without data are kept on
the phone and uploaded later in batches, together with the walk's time and
distance; the app sends one request every 30 seconds instead of two every 10.

## Background

- `_onRecord` in `lib/features/walk/walk_map_page.dart` (every 10 s) sends
  `addWalkCoordinate` for one point and then `updateWalkStats`; a failure is
  only logged, so offline points are lost and the drawn route has gaps.
- Backend card B12 adds (use this exact document):

  ```graphql
  mutation RecordWalkProgress($walkId: String!, $points: [TrackPointInput!]!, $timeSpent: Int!, $distanceTraveled: Float!) {
    recordWalkProgress(walkId: $walkId, points: $points, timeSpent: $timeSpent, distanceTraveled: $distanceTraveled) {
      accepted
      walk { Id timeSpent distanceTraveled }
    }
  }
  ```

  `TrackPointInput { latitude, longitude, timestamp }` (ISO 8601 UTC), at most
  500 points per call; duplicates by timestamp are ignored, stats never go down.
- `shared_preferences` is available for small local storage.

## Files or directories involved

- `lib/features/walk/data/track_queue.dart` (new)
- `lib/features/walk/data/walk_repository.dart` (`recordProgress`)
- `lib/services/graphql_operations.dart`, `test/contract/operations.json`
- `lib/services/graphql_service.dart`
- `lib/features/walk/walk_map_page.dart` (`_onRecord`, `_saveProgress`, `_pause`)
- `test/features/walk/track_queue_test.dart` (new)

## Implementation requirements

1. `TrackQueue` (per walk id): `add(GeoPoint, DateTime)`, `peek(max)`,
   `remove(count)`, persisted in `SharedPreferences` under
   `track_queue_<walkId>` (JSON), capped at 5,000 points (drop the oldest).
2. Repository `recordProgress(walkId, points, elapsed, km)` → the mutation;
   returns `accepted`.
3. Page: `_onRecord` adds the current good fix to the queue every 10 s; every
   30 s (and on pause and finish) it sends up to 500 queued points with the
   stats; on success removes them; on failure keeps them and retries next
   time. Finishing waits up to 10 s for a last flush, then finishes anyway.
4. Stop sending `addWalkCoordinate` and `updateWalkStats` from the walk page
   (keep the repository methods; 1.0 backends still have them).

## Restrictions

- Change only the files above. No UI text. No new dependency.

## Tests to add or update

`track_queue_test.dart`: persistence across instances, order, cap at 5,000,
`peek`/`remove` semantics. Repository test: variables for 2 points.

## Acceptance criteria

- Device check: walk 5 minutes in airplane mode, reconnect, finish: the
  summary map shows the whole route.

## Commands that must pass

```sh
flutter pub get
flutter analyze   # "No issues found!"
flutter test      # all pass
```

## Information Codex must report after completion

The report format in `AGENTS.md`. Maintainer: contract sync on the backend.
