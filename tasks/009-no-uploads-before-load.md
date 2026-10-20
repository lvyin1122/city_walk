# 009: No progress uploads before the walk has loaded

- **Status:** blocked (approved 2026-10-20; starts when 001 is merged)
- **Priority:** P0
- **Owner:** Codex
- **Base branch:** chore/stabilize-foundation, after card 001 is merged
- **Branch:** codex/009-no-uploads-before-load
- **Waiting for:** card 001 merged (both change `walk_map_page.dart`)

## Goal

Opening a walk never overwrites its saved time and distance, even when
loading fails or is slow. Resuming a paused walk always continues from the
numbers the backend had.

## Background

Line numbers are from the card 001 branch (`96f6e43`).

`lib/features/walk/walk_map_page.dart`, `initState` (~103–112), starts
`_startLocationHistoryTracking()` and `_startWalkStatsUpdateTimer()` at the
same time as `_fetchWalkData()`, without waiting for it. Every 10 seconds
`_updateWalkStats` (~264) sends:

- `distanceTraveled: _distanceWalked`
- `timeSpent: _stopwatch.elapsed.inSeconds + _initialTimeSpent`

Both `_distanceWalked` and `_initialTimeSpent` stay 0 until `_fetchWalkData`
restores them from the backend (~193–206). So, when a paused walk is resumed:

- if `getWalk` fails, the screen shows "这次漫步没能加载出来" (card 001),
  and every 10 seconds the backend's saved time and distance are replaced
  by the seconds spent on that screen and 0 km. A later "重试" then restores
  those wrong values, and the progress is lost for good;
- if `getWalk` takes longer than 10 seconds (the API timeout is 30 seconds),
  the first upload overwrites the saved numbers in the same way.

The 10-second location timer (`_startLocationHistoryTracking`, ~603) also
adds to the distance and uploads coordinates while no walk is shown. Pausing
(`_onWillPop`, ~1793) calls `_updateWalkStats()` too, so it has the same
problem. Finishing (~1837) is only reachable from the loaded map and needs no
change.

The stopwatch starts in `initState` (`_startTimer`, ~593) and is restarted
only when the backend returns `timeSpent` (~195–196), so time spent on the
loading or error screen can be counted as walking time.

## Files or directories involved

- `lib/features/walk/walk_map_page.dart`

## Implementation requirements

1. Add a field next to `_initialTimeSpent`:
   `bool _progressRestored = false;` with a one-line comment: no progress is
   uploaded until the saved time and distance have been read.
2. In `_fetchWalkData`, on a successful load:
   - restart the stopwatch on every successful load
     (`_stopwatch..reset()..start();`), not only when `timeSpent` is
     present, so time on the loading or error screen is not counted;
   - set `_progressRestored = true;` right after `_initialTimeSpent` and
     `_distanceWalked` have been restored, before anything is awaited.
3. `_updateWalkStats`: return immediately when `!_progressRestored`. This
   covers the 10-second timer and the pause path.
4. The `_startLocationHistoryTracking` timer callback: return immediately
   when `!_progressRestored`. No distance is added, no path point is
   recorded and no coordinate is uploaded before then.

## Restrictions

- Change only `walk_map_page.dart`, and only the places above.
- Do not change the timer intervals, the finish path or any UI.
- Do not reformat lines you do not change. Keep
  `// ignore_for_file: avoid_dynamic_calls`.

## Tests to add or update

None: the page builds a `GoogleMap` and cannot be pumped in tests. Put this
device check in the report for the maintainer:

1. Start a walk, walk for about 2 minutes, and pause it ("暂停并离开").
   Note the time and distance shown on the walk screen just before pausing.
2. Turn on airplane mode and open the walk from the home page's resume card.
   The error screen appears. Wait 30 seconds.
3. Turn airplane mode off and tap "重试". The time and distance continue from
   the numbers in step 1 on the walk screen, not from 0.

## Acceptance criteria

- `_updateWalkStats` and the location-history timer callback both start with
  the `_progressRestored` check.
- `_progressRestored` is set in exactly one place, in `_fetchWalkData`.
- The device check above passes.
- `git diff --stat` lists only `walk_map_page.dart`.

## Commands that must pass

```sh
flutter pub get
flutter analyze   # "No issues found!"
flutter test      # all pass
```

## Information Codex must report after completion

The report format in `AGENTS.md`, plus the line numbers of the three checks
and of the place `_progressRestored` is set, and the device check above.
