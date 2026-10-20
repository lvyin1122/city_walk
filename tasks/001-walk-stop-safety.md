# 001: Walk screen survives malformed stop data

- **Status:** ready (approved 2026-10-20)
- **Priority:** P0
- **Owner:** Codex
- **Base branch:** chore/stabilize-foundation
- **Branch:** codex/001-walk-stop-safety
- **Waiting for:** nothing

## Goal

Nothing the backend sends can crash or blank the walk screen. A malformed
stop is skipped and the rest of the walk keeps working; if the walk cannot be
shown at all, the user gets a retry button instead of an empty map.

## Background

`lib/features/walk/walk_map_page.dart` builds `LatLng` values straight from
raw JSON, for example
`LatLng(location['coordinates']['latitude'], location['coordinates']['longitude'])`.
If the backend sends an integer, a string or null, Dart throws a `TypeError`.
Several of these reads are inside `build()`, so one bad stop breaks the whole
screen in the middle of a walk. Stop names are read the same way:
`Text(_selectedLocation!['name'])` throws when the name is missing, and
`_collectedLocations.add(location['name'])` throws when it is not a string.

Raw reads to fix (line numbers as of commit d1dbe37):

| Line | What |
|---|---|
| ~151 | `collectedNames.add(location['name'])` in `_fetchWalkData` |
| ~299 | `LatLng(...)` in `_checkLocationsInRange` |
| ~306, ~311 | name added to `_collectedLocations`; `indexWhere` on raw items |
| ~918 | `LatLng(...)` for the initial camera position |
| ~929–935 | stop marker: `InfoWindow` title, `LatLng(...)` position, name lookup |
| ~952–958 | favourite marker: `InfoWindow` title and snippet, `LatLng(favorite['latitude'], ...)` |
| ~1278 | `Text(_selectedLocation!['name'])` |
| ~1404 | `LatLng(...)` for the estimated walking time |

If loading the walk fails, `_isLoadingWalk` becomes false with no stops, and
the map opens at `LatLng(0, 0)` with no way to retry.

`GeoPoint.tryParse` in `lib/core/geo/geo_point.dart` already parses
coordinates tolerantly (numbers, numeric strings, `latitude`/`longitude` or
`lat`/`lng` keys). This page stays on raw JSON on purpose until it is rebuilt
after the release, so the change must stay small and local.

## Files or directories involved

- `lib/features/walk/walk_map_page.dart`
- `lib/core/map/lat_lng.dart`
- `test/core/map/lat_lng_test.dart` (new)

## Implementation requirements

1. In `lib/core/map/lat_lng.dart`, add, with a doc comment:
   ```dart
   LatLng? latLngFromJson(Object? json) => GeoPoint.tryParse(json)?.toLatLng();
   ```
2. In `_fetchWalkData`:
   - Treat a `locations` value that is not a `List` as an empty list.
   - `_selectedLocations` keeps only items that are a `Map`, have
     `selected == true`, a `String` `name`, and coordinates for which
     `latLngFromJson(item['coordinates'])` is not null.
   - `debugPrint` how many selected stops were skipped, when any were.
   - Build `collectedNames` (line ~151) from the same filtered stops.
3. Replace the raw coordinate reads with `latLngFromJson`:
   - ~299, range check: skip a stop whose coordinates do not parse.
   - ~918, initial camera: the first stop that parses; otherwise
     `_userLocation`.
   - ~930, stop markers: leave out stops that do not parse.
   - ~955, favourite markers: parse the favourite map itself
     (`latLngFromJson(favorite)`) and leave out favourites that do not parse.
   - ~1404, estimated time: show `'未知'` when the coordinates do not parse.
4. Favourite `InfoWindow`: `title: favorite['name']?.toString() ?? '收藏地点'`,
   `snippet: favorite['description']?.toString() ?? ''`.
5. `indexWhere` at ~311: guard each item with `loc is Map &&`.
6. In `build()`, after the `_isLoadingWalk` check and before `PopScope`: if
   `_selectedLocations` is empty, return a `Scaffold` with a centred column
   containing the text `'这次漫步没能加载出来'` and two buttons:
   - `'重试'`: `setState(() => _isLoadingWalk = true);` then call
     `_fetchWalkData()`.
   - `'返回'`: `Navigator.of(context).pop()`.
7. In `_stopAllTimersAndSubscriptions`, wrap
   `_location.enableBackgroundMode(enable: false)` as
   `unawaited(... .catchError((Object e) { debugPrint(...); return false; }))`
   so a failure is logged instead of left unhandled.

## Restrictions

- Change only the three files above.
- Do not move the page to the `Walk` / `WalkStop` models.
- No other logic changes. Do not reformat lines you do not change.
- Keep `// ignore_for_file: avoid_dynamic_calls`.
- Do not touch `pubspec.yaml` or `pubspec.lock`.
- No UI text other than `'这次漫步没能加载出来'`, `'重试'`, `'返回'`,
  `'未知'` and `'收藏地点'`.

## Tests to add or update

`test/core/map/lat_lng_test.dart`: `latLngFromJson`

- returns the right `LatLng` for doubles, integers, numeric strings, and
  `lat`/`lng` keys;
- returns null for null, a value that is not a `Map`, a missing key, and a
  non-numeric string.

## Acceptance criteria

- `grep -n "\['coordinates'\]\['l" lib/features/walk/walk_map_page.dart`
  prints nothing.
- `grep -n "LatLng(favorite\[" lib/features/walk/walk_map_page.dart` prints
  nothing.
- `git diff --stat chore/stabilize-foundation` lists only the three files.
- When `getWalk` throws, the screen shows the retry message instead of a map.

## Commands that must pass

```sh
flutter pub get
flutter analyze   # "No issues found!"
flutter test      # all pass, more than 110 tests
```

## Information Codex must report after completion

The report format in `AGENTS.md`, plus each replaced read: its old line
number, the new line number, and what it does now when the data is bad.
