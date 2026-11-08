# 019: Hide the free-record flow behind a build flag

- **Status:** in review (approved and implemented in the maintainer-authorized P0 batch 2026-10-30; CI/device acceptance pending)
- **Priority:** P0 if D15 is "hide for 1.0" (recommended); otherwise drop the card
- **Owner:** Codex
- **Base branch:** improve/stabilize-and-restyle
- **Branch:** codex/019-gate-free-record
- **Waiting for:** D15

## Goal

1.0 ships one clear product, the generated walk. The free-form record flow
("不需要路线？直接开始记录", History → 记录, AI reflection questions and the
scrapbook cover) stays in the code but is off unless the build sets
`ENABLE_FREE_RECORD=true`.

## Background

- The free-record flow is the older "v2" product: `QuickStartMapPage`
  (`lib/features/walk/quick_start_map_page.dart`, 695 lines, raw
  `GraphQLService` calls and `LatLng` state, no tests),
  `lib/features/home/log/` (list, review wizard, result, detail),
  `lib/services/log_service.dart` and `lib/services/scrapbook_quota_service.dart`.
  It records its own route through a second backend pipeline
  (`startLogTracking`/`addLogTrackingPoint`), and its scrapbook cover is the
  most expensive AI call, limited only on the device with an `admin@mambo.com`
  bypass (`scrapbook_quota_service.dart:13-16`).
- It is reachable from exactly two places:
  - `lib/features/home/home_page.dart:202`, `onStartFreeRecord: _startFreeRecord`
    (`WalkSetup` shows the button only when the callback is not null,
    `walk_setup.dart:148-157`);
  - `lib/features/home/history_tab.dart`, the second tab `记录`
    (`LogListPage`).
- Build-time flags live in `lib/app/env.dart` (`String.fromEnvironment` /
  `bool.fromEnvironment`), documented in `.env.example`, injected with
  `--dart-define-from-file`.

## Files or directories involved

- `lib/app/env.dart`
- `.env.example`
- `lib/features/home/home_page.dart` (line ~202 only)
- `lib/features/home/history_tab.dart`
- `test/app/env_test.dart` (new)

## Implementation requirements

1. `env.dart`: `static const enableFreeRecord = bool.fromEnvironment('ENABLE_FREE_RECORD');`
   with a doc comment ("the free-form record flow; off for 1.0"). Not part of
   `missing`.
2. `.env.example`: `ENABLE_FREE_RECORD=false` with a one-line comment.
3. `home_page.dart`: `onStartFreeRecord: Env.enableFreeRecord ? _startFreeRecord : null,`.
4. `history_tab.dart`: when `Env.enableFreeRecord` is false, show the same app
   bar title `历史` without a `TabBar`, and `WalkHistoryPage` as the body;
   when true, exactly today's two-tab layout.

## Restrictions

- Do not delete or move any free-record file (card 034 moves them later).
- Change only the files above. No UI text changes.
- Note: card 017 also changes `home_page.dart` (other methods); keep to line
  ~202 to avoid conflicts.

## Tests to add or update

`test/app/env_test.dart`: without a define, `Env.enableFreeRecord` is false
and `Env.missing` does not mention it.

## Acceptance criteria

- `flutter run --dart-define-from-file=.env.example`: no "直接开始记录" button,
  History shows only walks.
- With `--dart-define=ENABLE_FREE_RECORD=true` both come back.
- `grep -rn "enableFreeRecord" lib` shows env.dart, home_page.dart and
  history_tab.dart only.

## Commands that must pass

```sh
flutter pub get
flutter analyze   # "No issues found!"
flutter test      # all pass
```

## Information Codex must report after completion

The report format in `AGENTS.md`.
