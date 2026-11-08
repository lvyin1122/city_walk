# 021: Ask old builds to update

- **Status:** in review (approved and implemented in the maintainer-authorized P0 batch 2026-10-30; CI/device acceptance pending)
- **Priority:** P0 (only builds that contain it can ever be asked to update)
- **Owner:** Codex
- **Base branch:** improve/stabilize-and-restyle
- **Branch:** codex/021-update-prompt
- **Waiting for:** backend card B10 merged (contract); not at the same time as
  card 003 (`main.dart`) or another card that changes `pubspec.yaml` or
  `graphql_operations.dart`

## Goal

When the backend says a build is too old, the app shows a calm "please update"
screen instead of breaking in confusing ways. A network failure never blocks
the app.

## Background

- After 1.0 ships, API changes (signed uploads, batched route upload) will
  need old builds to update. Nothing in the app can learn that today.
- Backend card B10 adds a public query (use this exact document):

  ```graphql
  query AppConfig {
    appConfig { minimumVersion latestVersion }
  }
  ```

  Values are versions like `1.0.0`; an empty string means no requirement.
- The app's version is `version: 1.0.0+1` in `pubspec.yaml`; reading it at run
  time needs `package_info_plus`.
- Start-up: `AuthWrapper._checkSession` in `lib/main.dart:125-137` decides
  when the home or splash screen appears.
- `AppLinks.open` lives in `lib/app/links.dart` (card 016).

## Files or directories involved

- `pubspec.yaml`, `pubspec.lock` (`package_info_plus`)
- `lib/app/app_version.dart` (new)
- `lib/app/links.dart` (two store URL constants)
- `lib/main.dart`
- `lib/services/graphql_operations.dart`, `test/contract/operations.json`
- `lib/services/graphql_service.dart`
- `test/app/app_version_test.dart` (new)

## Implementation requirements

1. `flutter pub add package_info_plus`.
2. `app_version.dart`:
   - `int compareVersions(String a, String b)` on dot-separated numbers;
     missing parts count as 0; a build suffix (`+1`) and anything that is not a
     number are ignored;
   - `Future<bool> isUpdateRequired({required Future<String> Function() currentVersion, required Future<String> Function() minimumVersion})`:
     true only when the minimum is not empty and the current version is lower;
     any error or a 5-second timeout → false;
   - `class UpdateRequiredScreen extends StatelessWidget`: `PaperBackground`,
     a `Botanical`, title `请更新 Mambo`, text
     `这个版本已经停止支持，请到应用商店更新到最新版本后继续使用。`, and, when the
     store URL for the platform is not empty, an `ElevatedButton` `前往更新`
     that calls `AppLinks.open`.
3. `links.dart`: `static const appStoreUrl = '';` and
   `static const playStoreUrl = '';` with a comment that the maintainer fills
   them in after the store records exist (decision D3).
4. `GraphQLOperations.appConfig` = the document above in `all`; regenerate
   `operations.json`. `GraphQLService.minimumAppVersion()` returns
   `appConfig.minimumVersion` or `''`.
5. `main.dart`, `_checkSession`: run the session refresh and
   `isUpdateRequired(...)` (current version from `PackageInfo.fromPlatform()`)
   in parallel; keep a `bool _updateRequired`; `build` returns
   `UpdateRequiredScreen()` when it is true, before anything else.

## Restrictions

- Change only the files above. Never block start-up longer than 5 seconds.
- No UI text other than the strings above.

## Tests to add or update

`test/app/app_version_test.dart`: `compareVersions` (`1.0.0` < `1.0.1`,
`1.2` == `1.2.0`, `1.10.0` > `1.9.9`, `1.0.0+5` == `1.0.0`); `isUpdateRequired`
true / false / empty minimum / throwing minimum / slow minimum (fake async,
6 s) → false; `UpdateRequiredScreen` shows its texts and hides the button
while the URLs are empty.

## Acceptance criteria

- With the backend's `MIN_APP_VERSION=9.0.0` (staging), the app opens on the
  update screen; with it empty, the app starts normally; in airplane mode the
  app starts normally.

## Commands that must pass

```sh
flutter pub get
flutter analyze   # "No issues found!"
flutter test      # all pass
```

## Information Codex must report after completion

The report format in `AGENTS.md`, plus the `pubspec.lock` summary.
Maintainer: contract sync on the backend after merging.
