# 008: CI builds both release targets

- **Status:** ready (approved 2026-10-20)
- **Priority:** P1
- **Owner:** Codex
- **Base branch:** chore/stabilize-foundation
- **Branch:** codex/008-ci-release-builds
- **Waiting for:** D5 to verify it (CI must be able to run on the
  repository). The repository is public, so GitHub-hosted macOS runners
  cost nothing.

## Goal

Every pull request proves that both native projects compile in release
mode, because the maintainer's machine cannot build either.

## Background

`.github/workflows/ci.yml` runs analyze, test and an Android **debug** build.
Nothing builds iOS on pull requests; `.github/workflows/dart.yml` is a manual
unsigned iOS build. The iOS build must use Xcode 26: the UIScene migration is
not done, and an app built with the iOS 27 SDK crashes at launch on iOS 27
(see "Known debt" in `AGENTS.md`).

## Files or directories involved

- `.github/workflows/ci.yml`

## Implementation requirements

1. In the `build-android` job, after the debug build, add
   `flutter build appbundle --release --dart-define-from-file=.env.example`.
   Without `key.properties` the release build is signed with the debug key,
   which is enough to prove it compiles.
2. Add a `build-ios` job (`needs: analyze-and-test`) on a macOS runner that:
   - selects Xcode 26.x explicitly (for example with
     `maxim-lobanov/setup-xcode@v1`) and prints `xcodebuild -version`;
   - installs Flutter 3.47.6 with the same `subosito/flutter-action` step as
     the other jobs;
   - runs `flutter pub get` and
     `flutter build ios --release --no-codesign --dart-define-from-file=.env.example`.
3. Keep the existing jobs and `FLUTTER_VERSION` unchanged otherwise.

## Restrictions

- Change only `ci.yml`. Do not touch `dart.yml`.
- No secrets. Mark the report `UNVERIFIED-NATIVE`.

## Tests to add or update

None. The workflow run is the test.

## Acceptance criteria

- All jobs are green on the pull request.
- The iOS job log shows Xcode 26.x.

## Commands that must pass

The CI run on the pull request, plus locally:

```sh
flutter analyze   # "No issues found!"
flutter test      # all pass
```

## Information Codex must report after completion

The report format in `AGENTS.md`, marked `UNVERIFIED-NATIVE`, plus a link to
the run, how long each job took, and the Xcode version it used.
