# 005: Release identity and Android signing

- **Status:** blocked
- **Priority:** P0
- **Owner:** Codex
- **Base branch:** chore/stabilize-foundation
- **Branch:** codex/005-release-identity-signing
- **Waiting for:** D3 (final application and bundle IDs), D9 (Android
  signing key)

## Goal

Android release builds carry the final application ID and are signed with
the upload key; the iOS target uses the final bundle ID.

## Background

- Google Play does not accept package names starting with `com.example`, and
  `android/app/build.gradle.kts` sets `applicationId = "com.example.mambo"`.
- The release build type signs with the debug key
  (`signingConfig = signingConfigs.getByName("debug")`, lines ~41–45).
- `ios/Runner.xcodeproj/project.pbxproj` sets
  `PRODUCT_BUNDLE_IDENTIFIER = com.example.mambo` (three Runner entries) and
  `com.example.mambo.RunnerTests` (three test entries).
- `android/.gitignore` already ignores `key.properties`, `*.jks` and
  `*.keystore`.
- `namespace` and the package of `MainActivity.kt` stay
  `com.example.mambo`: Play checks only the application ID, and moving the
  Kotlin package adds risk for no benefit now.

## Files or directories involved

- `android/app/build.gradle.kts`
- `android/key.properties.example` (new)
- `ios/Runner.xcodeproj/project.pbxproj`
- `README.md` (the Notes section and a new signing section)

## Implementation requirements

1. `build.gradle.kts`:
   - set `applicationId` to the value of D3 (Android);
   - read `android/key.properties` the same way `secrets.properties` is read
     at the top of the file (`storeFile`, `storePassword`, `keyAlias`,
     `keyPassword`);
   - add a `release` signing config built from those values;
   - the release build type uses that config when `key.properties` exists,
     and falls back to the debug config otherwise, so CI and local builds
     keep working. Add a short comment saying so.
2. `android/key.properties.example`: the four keys with placeholder values
   and a comment that the real file and the keystore must never be
   committed.
3. `project.pbxproj`: replace the three `com.example.mambo` bundle IDs with
   the D3 value (iOS) and the three `com.example.mambo.RunnerTests` IDs with
   `<D3 value>.RunnerTests`.
4. `README.md`: replace the note that calls `com.example.mambo` a placeholder,
   and add a short "Release signing (Android)" section: create the upload key
   with `keytool`, where `key.properties` and the keystore live, that Play App
   Signing is used, and that both files are git-ignored.

## Restrictions

- Never create, read or commit a keystore, `key.properties` or a password.
- Do not change `namespace`, the `MainActivity` package or
  `DEVELOPMENT_TEAM`.
- No other native changes. Mark the report `UNVERIFIED-NATIVE`.

## Tests to add or update

None in Dart. The maintainer runs
`flutter build appbundle --release --dart-define-from-file=.env` with the
real key, and an iOS archive on the Mac.

## Acceptance criteria

- `grep -rn "com.example" android/app/build.gradle.kts ios/Runner.xcodeproj`
  shows only `namespace`.
- CI's Android build is green without `key.properties`.
- The maintainer's signed `.aab` is accepted by the Play Console.

## Commands that must pass

```sh
flutter pub get
flutter analyze   # "No issues found!"
flutter test      # all pass
```

## Information Codex must report after completion

The report format in `AGENTS.md`, marked `UNVERIFIED-NATIVE`, plus every
identifier changed (file, old value, new value).
