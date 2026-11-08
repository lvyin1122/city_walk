# 022: Numbered stops in walking order on the preview; safe start

- **Status:** draft
- **Priority:** P1
- **Owner:** Codex
- **Base branch:** improve/stabilize-and-restyle (after 013 is merged)
- **Branch:** codex/022-preview-walking-order
- **Waiting for:** card 013 (`orderForWalking`)

## Goal

The preview shows the walk as a route: stops numbered 1, 2, 3… in walking
order on the map and in the stop panel, with the time estimate along that
order. Starting a walk can no longer leave it "in progress" without stops.

## Background

- `lib/features/walk/walk_preview.dart` draws default pins tinted by hue
  (line ~269-281) with no order; the stop panel shows only the name; the
  estimate (`estimateWalkMinutes`, line ~22-27) follows the backend's order.
- `WalkRepository.startWalk` (`lib/features/walk/data/walk_repository.dart:77-80`)
  sets the status to `in_progress` first and selects the stops second. If the
  second call fails, the home page offers to resume a walk that has no
  selected stops, and the walk page shows "这次漫步没能加载出来".
- `orderForWalking(start, items, positionOf)` exists in
  `lib/core/geo/route_order.dart` (card 013).
- Google Maps markers accept PNG bytes: `BitmapDescriptor.bytes(bytes, width: …)`.
  Style rules: hairline strokes only (`strokeWidth` ≤ 1), no raw `Colors.*`,
  weights ≤ 400.

## Files or directories involved

- `lib/core/map/numbered_marker.dart` (new)
- `lib/features/walk/walk_preview.dart`
- `lib/features/walk/data/walk_repository.dart` (`startWalk` only)
- `test/core/map/numbered_marker_test.dart` (new)
- `test/features/walk/walk_repository_test.dart`

## Implementation requirements

1. `numbered_marker.dart`: `Future<Uint8List> numberedMarkerPng(int number, {required Color fill, required Color text, double size = 36, double pixelRatio = 3})`
   drawing a filled circle with a 1 px `FreshColors.paper` ring and the
   number centred (`FontWeight.w400`) via `ui.PictureRecorder`; and
   `Future<BitmapDescriptor> numberedMarker(...)` wrapping it with
   `BitmapDescriptor.bytes(png, width: size)`, cached by (number, fill, text).
2. `walk_preview.dart`:
   - the walking order is `orderForWalking(start, walk.stops, (s) => s.position)`
     with `start` = the user's position when known, else the first stop;
     recompute when the first position arrives;
   - selected stops get `numberedMarker(n, fill: FreshColors.sky, text: FreshColors.onSky)`,
     deselected ones `fill: FreshColors.line, text: FreshColors.ink` (alpha as
     today); fall back to today's hue pins until the bitmaps are ready;
   - the stop panel title becomes `第 {n} 站 · {name}`;
   - `estimateWalkMinutes` receives the selected stops in walking order.
3. `walk_repository.dart`, `startWalk`: call `selectLocations` first, then
   `updateWalkStatus(in_progress)`.

## Restrictions

- Change only the files above. The walk page keeps its markers (a later card
  may reuse `numberedMarker` there).
- No new dependency. No UI text other than `第 {n} 站 · {name}`.

## Tests to add or update

- `numbered_marker_test.dart`: returns non-empty PNG bytes (PNG signature) for
  1 and 12; the cache returns the same instance for the same arguments.
- `walk_repository_test.dart`: `startWalk` calls `selectLocations` before
  `updateWalkStatus`; when `selectLocations` throws, `updateWalkStatus` is not
  called.

## Acceptance criteria

- Device check: numbers on the map follow a sensible walking order from the
  user; deselecting a stop renumbers the rest.

## Commands that must pass

```sh
flutter pub get
flutter analyze   # "No issues found!"
flutter test      # all pass
```

## Information Codex must report after completion

The report format in `AGENTS.md`.
