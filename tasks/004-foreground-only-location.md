# 004: Ask only for "while using" location

- **Status:** blocked
- **Priority:** P0
- **Owner:** Codex
- **Base branch:** chore/stabilize-foundation
- **Branch:** codex/004-foreground-only-location
- **Waiting for:** D6 (the maintainer confirms "while using" only), and
  card 001 merged (both change `walk_map_page.dart`)

## Goal

Walks keep recording while the phone is locked, through the location
foreground service, without asking for "Allow all the time". This avoids
Google Play's background-location declaration and review, and App Review
questions about background modes that are not used.

## Background

- `lib/features/walk/walk_map_page.dart:125` calls
  `_location.enableBackgroundMode(enable: true)`. The default
  `requireBackgroundPermission: true` makes Android 10+ ask for "Allow all
  the time".
- `location` 10.0.2 accepts `requireBackgroundPermission: false`: a
  foreground service of type location keeps location access in the
  background without that permission (see the plugin's
  `MethodCallHandlerImpl.kt`, lines 190–197).
- `android/app/src/main/AndroidManifest.xml` declares
  `ACCESS_BACKGROUND_LOCATION`. Keeping it in the manifest triggers Play's
  background-location declaration even if the app never asks for it.
- On iOS the plugin requests "When in use" whenever
  `NSLocationWhenInUseUsageDescription` exists, and background mode only sets
  `allowsBackgroundLocationUpdates`. `ios/Runner/Info.plist` also declares
  the `fetch` background mode, which nothing uses (an App Review 2.5.4 risk),
  and two "Always" usage descriptions that are never needed.

## Files or directories involved

- `lib/features/walk/walk_map_page.dart` (line ~125 only)
- `android/app/src/main/AndroidManifest.xml`
- `ios/Runner/Info.plist`

## Implementation requirements

1. `walk_map_page.dart:~125`:
   `await _location.enableBackgroundMode(enable: true, requireBackgroundPermission: false);`
2. `AndroidManifest.xml`: remove the `ACCESS_BACKGROUND_LOCATION` line. Keep
   `FOREGROUND_SERVICE` and `FOREGROUND_SERVICE_LOCATION`.
3. `Info.plist`:
   - remove `<string>fetch</string>` from `UIBackgroundModes` (keep
     `location`);
   - remove `NSLocationAlwaysUsageDescription` and
     `NSLocationAlwaysAndWhenInUseUsageDescription`;
   - set these usage descriptions. They stay in English for 1.0 because App
     Review reads them; a Chinese translation comes with localisation.
     - `NSLocationWhenInUseUsageDescription`: `Mambo uses your location to plan a walk near you and to record the route you walk. Recording continues while the screen is locked until you pause or finish the walk.`
     - `NSCameraUsageDescription`: `Mambo uses the camera so you can take photos for walk tasks.`
     - `NSPhotoLibraryAddUsageDescription`: `Mambo saves the photos you take on a walk and your walk summaries to your photo library.`
     - `NSPhotoLibraryUsageDescription`: `Mambo lets you choose a photo from your library to complete a task or add it to a record.`

## Restrictions

- Change only the three files above, and only the lines named.
- No other native changes.
- Mark the report `UNVERIFIED-NATIVE`.

## Tests to add or update

None can run in Dart. Put this device check in the report for the
maintainer: start a walk, lock the phone for 3 minutes while walking, unlock,
and confirm the path kept recording. Do it on Android 14 or later and on an
iPhone.

## Acceptance criteria

- `grep -n ACCESS_BACKGROUND_LOCATION android/app/src/main/AndroidManifest.xml`
  prints nothing.
- `grep -n "fetch\|NSLocationAlways" ios/Runner/Info.plist` prints nothing.
- CI's Android build is green.
- On both devices, no "Allow all the time" prompt appears, and the device
  check passes.

## Commands that must pass

```sh
flutter pub get
flutter analyze   # "No issues found!"
flutter test      # all pass
```

## Information Codex must report after completion

The report format in `AGENTS.md`, marked `UNVERIFIED-NATIVE`, plus the full
diff of `AndroidManifest.xml` and `Info.plist` and the device check above.
