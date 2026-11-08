# 016: Outbound links and walking directions

- **Status:** in review (approved and implemented in the maintainer-authorized P0 batch 2026-10-30; CI/device acceptance pending)
- **Priority:** P0
- **Owner:** Codex
- **Base branch:** improve/stabilize-and-restyle
- **Branch:** codex/016-links-and-directions
- **Waiting for:** nothing

## Goal

The app can open a web page or the phone's map app safely, and can build a
walking-directions link to any stop. Cards 006 (legal links) and 015 ("导航"
on the walk screen) use this.

## Background

- There is no way to leave the app for a link: the next stop cannot be handed
  to Apple Maps or Google Maps, and the privacy policy cannot be opened.
- `url_launcher` 6.3.3 is already resolved in `pubspec.lock` as a transitive
  dependency of `supabase_flutter`, so adding it directly should not change the
  lock file beyond the dependency type.
- Universal links that need no extra Android `<queries>` entry when opened
  with `launchUrl` (no `canLaunchUrl` call):
  - Apple Maps: `https://maps.apple.com/?daddr=<lat>,<lng>&dirflg=w`
  - Google Maps: `https://www.google.com/maps/dir/?api=1&destination=<lat>,<lng>&travelmode=walking`
- Coordinates are `GeoPoint` (`lib/core/geo/geo_point.dart`).

## Files or directories involved

- `pubspec.yaml`, `pubspec.lock`
- `lib/app/links.dart` (new)
- `lib/core/map/navigation_link.dart` (new)
- `test/core/map/navigation_link_test.dart` (new)

## Implementation requirements

1. `flutter pub add url_launcher`.
2. `lib/app/links.dart`: `abstract final class AppLinks` with
   `static Future<bool> open(Uri uri)` that calls
   `launchUrl(uri, mode: LaunchMode.externalApplication)` and returns `false`
   instead of throwing (log the error with `debugPrint`). No URLs yet (card
   006 adds the legal ones).
3. `lib/core/map/navigation_link.dart`:
   `Uri walkingDirectionsUri(GeoPoint destination, {required TargetPlatform platform})`
   — Apple Maps on `TargetPlatform.iOS`, Google Maps otherwise; coordinates
   with 6 decimals; built with `Uri.https` so values are encoded.

## Restrictions

- Change only the files above. Do not call `canLaunchUrl` (it needs Android
  manifest `<queries>`; `AndroidManifest.xml` is owned by card 010).
- No UI in this card.

## Tests to add or update

`test/core/map/navigation_link_test.dart`: iOS → host `maps.apple.com`,
`daddr=22.284000,114.150000`, `dirflg=w`; Android → host `www.google.com`,
path `/maps/dir/`, `api=1`, `destination=22.284000,114.150000`,
`travelmode=walking`; both use `https`.

## Acceptance criteria

- `url_launcher` resolves to the same version as before in `pubspec.lock`, or
  the report explains the change.
- `grep -rn "canLaunchUrl" lib` prints nothing.

## Commands that must pass

```sh
flutter pub get
flutter analyze   # "No issues found!"
flutter test      # all pass
```

## Information Codex must report after completion

The report format in `AGENTS.md`, plus the `pubspec.yaml` constraint added
and a summary of the `pubspec.lock` diff.
