# 015: Put the new controls on the walk screen

- **Status:** in review (approved and implemented in the maintainer-authorized P0 batch 2026-10-30; CI/device acceptance pending)
- **Priority:** P0
- **Owner:** Codex
- **Base branch:** improve/stabilize-and-restyle (after 010, 013, 014, 016 and
  018 are merged)
- **Branch:** codex/015-wire-walk-screen
- **Waiting for:** cards 010, 013, 014, 016, 018

## Goal

During a walk the screen answers "where next, how far, what do I photograph"
at a glance; everything the walker taps is in the bottom half; a stop can be
checked in by hand; directions open in the phone's map app; the task no longer
counts down and swaps itself; one photo no longer triggers two dialogs.

## Background

After the cards this one waits for:

- `WalkSession` (013) has `acceptFix`, `reachStopsNear(..., accuracyMeters:)`,
  `planRoute`, `routePlanned`, `numberOf`, `nextStop`, `canCheckIn`,
  `checkIn`, and still the countdown (`taskWindow`, `taskWarning`,
  `countdownSeconds`, `tick`, `countdownUrgent`, `CountdownEvent`).
- `walk_controls.dart` (014) has `WalkTouch`, `NextStopCard`, `TaskCard`
  (with `onReport`), `WalkActionBar`, `LocationNotice`; `WalkStatsLine` takes
  `stops`; `MapButton` is 48 dp.
- `AppLinks.open(Uri)` (`lib/app/links.dart`) and
  `walkingDirectionsUri(GeoPoint, platform:)`
  (`lib/core/map/navigation_link.dart`) exist (016).
- `showReportDialog(context, kind: ReportKind..., walkId:, stopIndex:)`
  (`lib/features/report/report_dialog.dart`) exists (018).
- `walk_map_page.dart` (010) has `_locationProblem` and a simple notice panel.

Today in `lib/features/walk/walk_map_page.dart`:

- `build` (line ~464-540) stacks the stats, the `TaskPanel` and the tapped
  stop at the top, the `WalkTally` and `_actions` at the bottom. The
  `GoogleMap` has no `padding`, so the bottom panels cover the Google logo,
  which the Maps terms require to stay visible.
- `_onSecond` (line ~200-215) ticks the 15-minute task countdown and swaps the
  task when it runs out; the guide says "慢慢走，慢慢看".
- `_onPosition` (line ~217-230) uses every fix as-is; `_onRecord` (line
  ~242-258) records `_position` every 10 s.
- `_addTaskPhoto` (line ~292-318) shows the verdict dialog, then, when the task
  is complete, a second "任务完成" dialog.
- `_pickAndUploadPhoto` compresses photos to 128 KB (`compressImage` default),
  so the summary shows small, soft images.

## Files or directories involved

- `lib/features/walk/walk_map_page.dart`
- `lib/features/walk/widgets/walk_panels.dart` (delete `TaskPanel` and
  `WalkTally`; add `onReport` to `StopDetail`)
- `lib/features/walk/session/walk_session.dart` (delete the countdown)
- `lib/features/walk/widgets/walk_dialogs.dart` (`showTaskCompleted`,
  `showWalkGuide`)
- `test/features/walk/walk_session_test.dart` (remove countdown tests)

## Implementation requirements

1. **Layout.** `build` returns, inside the existing `PopScope`/`Scaffold`, a
   `Stack` of the `GoogleMap` and a `SafeArea` `Column` (padding
   `FreshSpace.md`):
   1. a `MapPanel` with a `Row`: `Expanded(WalkStatsLine(elapsed, distanceKm, stops: '{reached}/{total}'))`
      and the guide `MapButton` (`Icons.info_outline`, `使用说明`);
   2. `LocationNotice(message: _locationProblem!, actionLabel: '重试', onAction: _configureLocation)`
      when `_locationProblem != null` (replaces 010's simple panel);
   3. the tapped stop's `StopDetail` panel, as today, now with `onReport`;
   4. `Spacer()`;
   5. a right-aligned row of `MapButton`s (zoom in/out on iOS only, as today,
      and "回到我的位置");
   6. a `MapPanel` with `NextStopCard` (see 3), a `Divider`, and `TaskCard`;
   7. `WalkActionBar` wired to `_pause`, `_addSurprise`, `_finish`, with
      `surpriseMarked`/`uploadingSurprise` as in today's `_actions`.
   Delete `_actions`. Give the `GoogleMap`
   `padding: const EdgeInsets.only(top: 72, bottom: 320)` so the logo and the
   camera fit stay above the bottom panels.
2. **Positions.** `_onPosition` keeps `_position` up to date for every fix,
   then passes it to `session.acceptFix(point, accuracyMeters: data.accuracy, time: …)`
   (`data.time` is milliseconds since the epoch). Only an accepted fix:
   becomes `_lastGoodFix`; on the first one calls `session.planRoute(point)`;
   is used for `reachStopsNear(point, accuracyMeters: data.accuracy)` (each
   newly reached stop is collected as today and shows `已到达：{name}`); and
   triggers `takeFinishSuggestion`. `_onRecord` records and uploads
   `_lastGoodFix` instead of `_position`.
3. **Next stop.** `NextStopCard(stop: session.nextStop, number: session.numberOf(next), distanceMeters: distance from _position, canCheckIn: session.canCheckIn(next, _position), onNavigate: …, onCheckIn: …)`.
   - Navigate: `AppLinks.open(walkingDirectionsUri(next.position, platform: Theme.of(context).platform))`;
     when it returns false show `无法打开地图应用`.
   - Check in: when `session.checkIn(next)` returns true, collect the stop as
     in `_collect`, show `已到达：{name}`, then `takeFinishSuggestion`.
   - Stop markers: `InfoWindow` title `{number}. {name}` once the route is
     planned.
4. **Tasks without a countdown.** `_onSecond` only redraws the clock. Delete
   the countdown from `WalkSession` (`taskWindow`, `taskWarning`,
   `countdownSeconds`, `_warned`, `tick`, `countdownUrgent`, `CountdownEvent`
   and the countdown lines in `startTask`) and its tests. `TaskCard` gets
   `onReport: () => showReportDialog(context, kind: ReportKind.task, walkId: widget.walkId)`
   when there is a task.
5. **One dialog per photo.** In `_addTaskPhoto`: rejected → `showPhotoVerdict`
   as today; accepted but not complete → success sound and a SnackBar with the
   model's message, or `这张照片符合任务` when it is empty; completed →
   success sound, `showTaskCompleted(context, message: check.message)`, then
   `_nextTask()`. `showTaskCompleted` gets `{String message = ''}` and shows
   it instead of `下一个小小的挑战正在路上。` when not empty.
6. **Photos.** `compressImage(File(picked.file.path), maxBytes: 450 * 1024)`.
7. **Stop report.** `StopDetail` gets `VoidCallback? onReport`; when set, an
   `IconButton(Icons.flag_outlined, tooltip: '报告这个地点')` before the close
   button; the page passes
   `() => showReportDialog(context, kind: ReportKind.place, walkId: widget.walkId, stopIndex: stop.index)`.
8. **Guide.** In `showWalkGuide`, the description of `到达地点` becomes
   `走到地点附近会自动打卡；定位不准时，点「我到了」。`
9. Delete `TaskPanel` and `WalkTally` from `walk_panels.dart` once unused.

## Restrictions

- Change only the files above. Keep every backend call, timer interval and
  the pause/finish behaviour as they are.
- No new dependency. No UI text other than the strings above.
- After every `await` in the `State`, check `mounted`.

## Tests to add or update

- `walk_session_test.dart`: remove the countdown tests; everything else
  passes.
- The page builds a `GoogleMap` and cannot be pumped. Device checks for the
  maintainer (an iPhone SE-sized phone and a large Android phone, system font
  size at the largest standard setting):
  1. Start a walk: the bottom panel shows `下一站 · 第 1 站`, a distance and
     `步行约 … 分钟`; `导航` opens Apple Maps (iOS) / Google Maps (Android)
     with walking directions.
  2. Stand within ~100 m of a stop: `我到了` appears; tapping it turns the
     marker mint and the card moves to the next stop.
  3. Take a task photo that is accepted but not the last one: only a
     SnackBar. Complete the task: exactly one dialog.
  4. No countdown anywhere; the Google logo is visible above the panels;
     nothing overflows.
  5. With one hand, every control is reachable with the thumb.

## Acceptance criteria

- `grep -rn -E "countdown|CountdownEvent|taskWindow" lib/` prints nothing.
- `grep -n -E "TaskPanel|WalkTally" lib/ -r` prints nothing.
- `grep -n "maxBytes: 450 \* 1024" lib/features/walk/walk_map_page.dart` prints one line.
- Device checks pass.

## Commands that must pass

```sh
flutter pub get
flutter analyze   # "No issues found!"
flutter test      # all pass
```

## Information Codex must report after completion

The report format in `AGENTS.md`, plus the line ranges of the new `build`,
`_onPosition`, `_checkIn` and `_navigateTo`.
