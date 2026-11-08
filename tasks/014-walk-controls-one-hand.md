# 014: Walk-screen controls for one hand, outdoors

- **Status:** in review (approved and implemented in the maintainer-authorized P0 batch 2026-10-30; CI/device acceptance pending)
- **Priority:** P0
- **Owner:** Codex
- **Base branch:** improve/stabilize-and-restyle
- **Branch:** codex/014-walk-controls-one-hand
- **Waiting for:** nothing

## Goal

The widgets the walk screen needs exist, are tested, and are easy to hit and
read while walking with one hand in daylight: the main action is a 56 dp
button at the bottom, every other control is at least 48 dp, and the key
information (next stop, distance, task) is readable. Card 015 puts them on
the screen.

## Background

What a walker sees today (`lib/features/walk/walk_map_page.dart:464-658`,
`lib/features/walk/widgets/walk_panels.dart`):

- The most frequent action, "添加任务照片", is an outlined (secondary-looking)
  button inside the top panel (`TaskPanel`, `walk_panels.dart:148-158`), the
  part of the screen hardest to reach with a thumb.
- `MapButton` is 44 × 44 (`walk_panels.dart:293-296`), below Android's 48 dp
  minimum. "暂停并离开" is an icon-only `MapButton`.
- Nothing says where to go next: a stop's distance is shown only after tapping
  its marker (`StopDetail`).
- Labels use `labelMedium`/`labelSmall` (13/12 sp, weight 300, grey) — faint
  in sunlight. `FreshWeights.regular` (w400) is allowed by the style rules for
  exactly this case (`lib/theme/tokens.dart:124-125`).
- Style rules (`test/theme/style_rules_test.dart`) forbid weights above 400,
  shadows/elevation, borders thicker than a hairline, raw `Colors.*` (except
  `Colors.transparent`) and durations under 200 ms. Use `FreshColors`,
  `FreshSpace`, `FreshRadius`, `FreshMotion`, `MapPanel`, `SegmentedProgress`.
- Distances: `distanceMeters`, `walkingMinutes` (`lib/core/geo/geo_point.dart`),
  `formatKilometers` (`1.2 km`) and `formatMinutes` (`4 分钟`) in
  `lib/core/format/formatters.dart`.

## Files or directories involved

- `lib/features/walk/widgets/walk_controls.dart` (new)
- `lib/features/walk/widgets/walk_panels.dart` (`MapButton`, `WalkStatsLine` only)
- `lib/core/format/formatters.dart` (one new function)
- `test/features/walk/walk_controls_test.dart` (new)
- `test/core/format/formatters_test.dart`

## Implementation requirements

1. `formatters.dart`: `String formatDistance(double meters)`: round to 10 m
   (at least `10 米`), e.g. `320 米`; when the rounded value is 1,000 or more,
   `formatKilometers(meters / 1000)`.
2. `walk_panels.dart`:
   - `MapButton`: 48 × 48, icon size 22.
   - `WalkStatsLine`: optional `final String? stops;` — when set, a third item
     with `Icons.place_outlined` and semantics label `地点`; values use
     `titleMedium` with `fontWeight: FreshWeights.regular`.
3. `walk_controls.dart`:
   - `abstract final class WalkTouch { static const double primary = 56; static const double secondary = 48; }`
   - `NextStopCard({required WalkStop? stop, int? number, double? distanceMeters, bool canCheckIn = false, VoidCallback? onNavigate, VoidCallback? onCheckIn})`:
     - `stop == null`: `Icon(Icons.task_alt)` in `FreshColors.mintText` and
       `所有地点都到达了`; no buttons.
     - otherwise three lines: `下一站` or `下一站 · 第 {number} 站`
       (`labelMedium`, w400); the stop name or `未命名地点` (`titleMedium`,
       w400, one line, ellipsis); the distance line — `正在定位…` when
       `distanceMeters` is null, `{formatDistance} · 就在附近` when the walking
       time rounds to less than one minute, else
       `{formatDistance} · 步行约 {formatMinutes(minutes)}`.
     - trailing button, at least `WalkTouch.secondary` high: when
       `canCheckIn` and `onCheckIn != null`, `FilledButton` `我到了`;
       otherwise, when `onNavigate != null`, `OutlinedButton.icon` with
       `Icons.near_me_outlined` and `导航`.
   - `TaskCard` (StatefulWidget) `({required WalkTask? task, required bool loading, required bool uploading, required int photosFulfilled, required VoidCallback onAddPhoto, required VoidCallback onNewTask, VoidCallback? onReport})`:
     - header: `拍摄任务` (`labelMedium`, w400), then, right-aligned,
       `IconButton(Icons.flag_outlined, tooltip: '报告这个任务')` only when
       `onReport != null`, and `IconButton(Icons.autorenew, tooltip: '换一个任务')`
       (disabled while `loading`);
     - body: while `loading` and no task, a 16 px spinner and `正在想一个新任务…`;
       no task: `暂时没有任务`; else the description in `bodyLarge` (ink),
       two lines with ellipsis, the full text after a tap (tap again
       collapses);
     - when `photosRequired > 0`: `SegmentedProgress` and `{done}/{required} 张`;
     - a full-width `FilledButton.icon`, height `WalkTouch.primary`:
       `Icons.photo_camera_outlined` and `拍任务照片`; while `uploading`, a
       16 px spinner and `正在查看照片…`; disabled while uploading or without
       a task.
   - `WalkActionBar({required bool surpriseMarked, required bool uploadingSurprise, required VoidCallback onPause, required VoidCallback onSurprise, required VoidCallback onFinish})`:
     one row, every button at least `WalkTouch.secondary` high:
     `OutlinedButton.icon(Icons.pause, '暂停')`; an `Expanded`
     `OutlinedButton.icon` with the heart and `这里让我惊喜` / `已记下惊喜` /
     `上传中…` (same states and pink tint as `_actions` in
     `walk_map_page.dart:626-658`, disabled while uploading); and
     `OutlinedButton('结束')`.
   - `LocationNotice({required String message, required String actionLabel, required VoidCallback onAction})`:
     a `MapPanel` with `Icons.location_off_outlined` in `FreshColors.error`,
     the message (`bodyMedium`, ink) and a `TextButton(actionLabel)`.

## Restrictions

- Do not touch `walk_map_page.dart`, `TaskPanel`, `WalkTally` or
  `StopDetail` (card 015 swaps them).
- No new dependency. No UI text other than the strings above.
- No weight above `FreshWeights.regular`.

## Tests to add or update

- `formatters_test.dart`: `formatDistance` 4 → `10 米`, 123 → `120 米`,
  994 → `990 米`, 999 → `1.0 km`, 1234 → `1.2 km`.
- `walk_controls_test.dart` (pump inside `MaterialApp(theme: AppTheme.light())`;
  set `tester.view.physicalSize = Size(1080, 1920)`,
  `devicePixelRatio = 3`, reset in `addTearDown`):
  - `NextStopCard` at 320 m shows `320 米 · 步行约 4 分钟`; null distance shows
    `正在定位…`; `canCheckIn` shows `我到了` and calls `onCheckIn`; otherwise
    `导航` calls `onNavigate`; `stop: null` shows `所有地点都到达了` and no
    button;
  - `TaskCard`: the `拍任务照片` button is at least 56 high and disabled without
    a task; tapping the description toggles between 2 lines and all lines; the
    flag button appears only with `onReport`;
  - `WalkActionBar`: all three buttons at least 48 high; label follows
    `surpriseMarked`/`uploadingSurprise`;
  - with `MediaQuery` `textScaler: TextScaler.linear(1.3)`, a 150-character
    task, a 40-character stop name and the action bar in a 360-wide column
    render without an exception (`tester.takeException()` is null);
  - every `IconButton` and `MapButton` hit area is at least 48 × 48.

## Acceptance criteria

- `test/theme/style_rules_test.dart` passes.
- `git diff --stat` lists only the five files.

## Commands that must pass

```sh
flutter pub get
flutter analyze   # "No issues found!"
flutter test      # all pass
```

## Information Codex must report after completion

The report format in `AGENTS.md`, plus a screenshot-free description of the
measured heights (from the tests) of each button.
