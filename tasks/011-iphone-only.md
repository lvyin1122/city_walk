# 011: iPhone only for 1.0

- **Status:** in review (approved and implemented in the maintainer-authorized P0 batch 2026-10-30; CI/device acceptance pending)
- **Priority:** P0
- **Owner:** Codex
- **Base branch:** improve/stabilize-and-restyle
- **Branch:** codex/011-iphone-only
- **Waiting for:** D18 (ship 1.0 for iPhone only; recommended yes). Must not run
  at the same time as card 005, which also changes `project.pbxproj`.

## Goal

The iOS build targets iPhone only, so App Review does not test it as an iPad
app and the store listing needs no iPad screenshots. iPads can still run it in
iPhone compatibility mode.

## Background

- `ios/Runner.xcodeproj/project.pbxproj` sets `TARGETED_DEVICE_FAMILY = "1,2"`
  (iPhone and iPad) in three build configurations (lines ~479, ~612, ~665).
- Every screen is designed for a portrait phone: `main.dart:18` locks the
  orientation to portrait, and the walk page stacks phone-sized panels over the
  map. An iPad build is reviewed on an iPad, and the 13-inch iPad screenshots
  become mandatory in App Store Connect.

## Files or directories involved

- `ios/Runner.xcodeproj/project.pbxproj`

## Implementation requirements

1. Replace every `TARGETED_DEVICE_FAMILY = "1,2";` with
   `TARGETED_DEVICE_FAMILY = 1;` (three occurrences). Change nothing else.

## Restrictions

- Only this file, only these lines. Mark the report `UNVERIFIED-NATIVE`.

## Tests to add or update

None in Dart. The maintainer archives the app on the Mac and checks that
App Store Connect lists only iPhone screenshot sizes as required.

## Acceptance criteria

- `grep -c 'TARGETED_DEVICE_FAMILY = 1;' ios/Runner.xcodeproj/project.pbxproj` prints `3`.
- `grep -n '"1,2"' ios/Runner.xcodeproj/project.pbxproj` prints nothing.

## Commands that must pass

```sh
flutter pub get
flutter analyze   # "No issues found!"
flutter test      # all pass
```

## Information Codex must report after completion

The report format in `AGENTS.md`, marked `UNVERIFIED-NATIVE`, with the diff.
