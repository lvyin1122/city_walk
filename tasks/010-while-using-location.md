# 010: Track walks with "while using" location only

- **Status:** in review (approved and implemented in the maintainer-authorized P0 batch 2026-10-30; CI/device acceptance pending)
- **Priority:** P0
- **Owner:** Codex
- **Base branch:** improve/stabilize-and-restyle
- **Branch:** codex/010-while-using-location
- **Waiting for:** D6 (track with "while using" permission and the foreground
  service only; recommended yes). Supersedes card 004, which was written for
  the old walk page.

## Goal

A walk keeps recording while the phone is locked, through the location
foreground service, without asking for "Allow all the time". When location is
off or denied, the walk page says so and offers a retry instead of silently
recording nothing.

## Background

- `lib/features/walk/walk_map_page.dart`:
  - `initState` (line ~71-82) subscribes to `_location.onLocationChanged`
    before any permission has been checked, and calls `_configureLocation()`.
  - `_configureLocation` (line ~111-124) calls
    `_location.enableBackgroundMode(enable: true)`. In `location` 10.0.2
    (`lib/location.dart:77-84`) the default `requireBackgroundPermission: true`
    makes Android 10+ ask for "Allow all the time". With
    `requireBackgroundPermission: false` the plugin starts a foreground service
    of type location instead, which keeps updates flowing while the screen is
    locked.
  - A walk resumed from the home page never checks whether the location
    service is on or permission is granted; if not, no route is recorded and
    nothing tells the user.
- `android/app/src/main/AndroidManifest.xml:4` declares
  `ACCESS_BACKGROUND_LOCATION`. Keeping it triggers Google Play's
  background-location declaration and review even if the app never asks.
  `FOREGROUND_SERVICE` and `FOREGROUND_SERVICE_LOCATION` stay.
- `ios/Runner/Info.plist`: `UIBackgroundModes` contains `fetch`, which nothing
  uses (App Review 2.5.4 risk), and the "Always" usage descriptions
  `NSLocationAlwaysUsageDescription` and
  `NSLocationAlwaysAndWhenInUseUsageDescription` are never needed. The usage
  strings are generic ("This app needs ...").
- `location` 10.0.2 also offers `changeNotificationOptions(title:, subtitle:)`
  for the Android foreground-service notification.

## Files or directories involved

- `lib/features/walk/walk_map_page.dart`
- `android/app/src/main/AndroidManifest.xml`
- `ios/Runner/Info.plist`

## Implementation requirements

1. `walk_map_page.dart`:
   - add `String? _locationProblem;` (null when location works);
   - remove the `onLocationChanged.listen(...)` call from `initState`;
   - `_configureLocation()`:
     1. if `!await _location.serviceEnabled()` and
        `!await _location.requestService()`: set `_locationProblem` to
        `'手机定位服务未开启，路线暂时不会被记录。'` and return;
     2. `hasPermission()`; when `denied`, `requestPermission()`; unless the
        result is `granted` or `grantedLimited`: set `_locationProblem` to
        `'没有定位权限，路线暂时不会被记录。请在系统设置中允许 Mambo 使用定位。'`
        and return;
     3. set `_locationProblem = null`; `changeSettings(...)` as today;
        subscribe with `_locationSubscription ??= _location.onLocationChanged.listen(_onPosition, onError: ...)`;
     4. on Android only (`defaultTargetPlatform == TargetPlatform.android`):
        `changeNotificationOptions(title: '漫步进行中', subtitle: '正在记录你的路线，可在应用里暂停或结束')`;
     5. `enableBackgroundMode(enable: true, requireBackgroundPermission: false)`;
        a failure in 4 or 5 is logged with `debugPrint` and does not set
        `_locationProblem` (the walk still records while the app is open).
     Check `mounted` before every `setState`.
   - In `build`, directly below the first `MapPanel`, when `_locationProblem`
     is not null: a `MapPanel` with a `Row`: `Icon(Icons.location_off_outlined)`,
     the message in an `Expanded` `Text`, and
     `TextButton(onPressed: _configureLocation, child: Text('重试'))`.
2. `AndroidManifest.xml`: delete the `ACCESS_BACKGROUND_LOCATION` line only.
3. `Info.plist`:
   - remove `<string>fetch</string>` from `UIBackgroundModes` (keep `location`);
   - remove `NSLocationAlwaysUsageDescription` and
     `NSLocationAlwaysAndWhenInUseUsageDescription` (keys and values);
   - set these values (English for 1.0; App Review reads them):
     - `NSLocationWhenInUseUsageDescription`: `Mambo uses your location to plan a walk near you and to record the route you walk. Recording continues while the screen is locked until you pause or finish the walk.`
     - `NSCameraUsageDescription`: `Mambo uses the camera so you can take photos for walk tasks.`
     - `NSPhotoLibraryAddUsageDescription`: `Mambo saves the photos you take on a walk, and the scrapbook pages you create, to your photo library.`
     - `NSPhotoLibraryUsageDescription`: `Mambo lets you choose a photo from your library to complete a task or add it to a record.`

## Restrictions

- In `walk_map_page.dart` change only `initState`, `_configureLocation`, the
  new field and the new panel in `build`. Card 015 rebuilds the layout later.
- No other native change. No new dependency.
- No UI text other than the strings above.
- Mark the report `UNVERIFIED-NATIVE`.

## Tests to add or update

None can run in Dart (the page builds a `GoogleMap`). Device checks for the
maintainer, on Android 14+ and an iPhone:

1. Fresh install → start a walk: the system asks only for "while using"
   (Android: "Only this time / While using the app"; iOS: "Allow While Using
   App"). No "Allow all the time" prompt, ever.
2. Walk for 3 minutes with the screen locked, unlock: the route kept
   recording. Android shows the notification "漫步进行中".
3. Deny permission → the walk page shows the "没有定位权限…" panel; grant it in
   Settings, tap "重试": the panel disappears and the blue dot appears.

## Acceptance criteria

- `grep -n ACCESS_BACKGROUND_LOCATION android/app/src/main/AndroidManifest.xml` prints nothing.
- `grep -n -E "fetch|NSLocationAlways" ios/Runner/Info.plist` prints nothing.
- `grep -n "requireBackgroundPermission: false" lib/features/walk/walk_map_page.dart` prints one line.
- CI's Android build is green; the device checks pass.

## Commands that must pass

```sh
flutter pub get
flutter analyze   # "No issues found!"
flutter test      # all pass
```

## Information Codex must report after completion

The report format in `AGENTS.md`, marked `UNVERIFIED-NATIVE`, plus the full
diff of `AndroidManifest.xml` and `Info.plist` and the device checks above.

Maintainer, at submission: apps targeting Android 14+ must declare the
foreground-service types they use (Play Console → Monitor and improve → App
content). Declare `location`, describe the walk recording, and add a short
screen recording if the form asks for one.
