# Mambo (City Walk)

Flutter app for iOS and Android. The user picks keywords and a duration, the
backend generates a walk around them, and they walk it while completing
AI-checked photo tasks. Package name: `mambo`.

This file holds the rules for every agent in this repository: Claude, Codex
and Cursor. `CLAUDE.md` imports it and adds Claude's review role.
`.cursor/rules/codex-task-execution.mdc` points back here. If something here
conflicts with another file, this file wins.

Background and reasoning live in `docs/` (written in Traditional Chinese):
`product-ux-marketing-analysis.md` and `technical-review.md`.

## Commands

```sh
flutter pub get
flutter analyze                               # must report "No issues found!"
flutter test                                  # must pass
flutter run --dart-define-from-file=.env      # .env is git-ignored; see .env.example
```

Flutter 3.47.6 (pinned in `.github/workflows/ci.yml`). Use exactly this
version; check with `flutter --version`. CI runs analyze, test and an Android
debug build on every push and pull request.

On the maintainer's Linux machine:

- Flutter is at `~/development/flutter/bin/flutter` and is not on `PATH`.
- `flutter test` fails with "Connection closed before full header was
  received" unless localhost bypasses the shell's proxy:
  `NO_PROXY=127.0.0.1,localhost,::1 no_proxy=127.0.0.1,localhost,::1 flutter test`
- There is no Android SDK and no Xcode. Native builds are verified only by CI
  (Android) and on a Mac (iOS).

## Layout

```
lib/
  main.dart               start-up checks, error screens, auth wrapper
  app/env.dart            build-time configuration (String.fromEnvironment)
  core/
    api/                  ApiClient, ApiException
    geo/                  GeoPoint, distance, bearing, walking time
    map/                  GeoPoint <-> LatLng, camera fitting
    media/                photo picking, image compression
    format/               durations, distances, dates
  features/
    auth/                 sign in, sign up
    home/                 home page, setup form, history tab, profile, tutorial
      log/                free-form records (secondary flow)
    walk/
      domain/             Walk, WalkStop, WalkTask, SurpriseSpot
      data/               WalkRepository, WalkSummaryCache
      walk_preview.dart, walk_map_page.dart, walk_summary.dart
  services/               GraphQLService, GraphQLOperations (every document the app
                          sends), LogService, AuthService, CloudinaryService
  theme/, widgets/        colours, type, shared widgets
test/                     mirrors lib/; test/contract/ exports the operations for
                          the backend
tasks/                    task cards and the task board (tasks/README.md)
docs/                     analyses, Traditional Chinese
```

## Conventions

- **Backend calls go through `ApiClient`.** Never call `http` directly for
  the backend. It adds the access token, a timeout and error handling, and
  throws `ApiException`. `ApiException.toString()` is a user-facing Chinese
  sentence; log `details`, show `userMessage`. Third-party calls (Cloudinary
  uploads, downloading an image by URL) may use `http`, but always with a
  timeout.
- **Pages use repositories and typed models**, not `Map<String, dynamic>`.
  Add a field to the model and its `fromJson` rather than indexing JSON in a
  widget. Parsing is tolerant: skip a malformed item, do not throw.
- **GraphQL documents live in `GraphQLOperations`** and take their arguments
  as variables; nothing is spliced into a document. After changing one, run
  `UPDATE_CONTRACT=1 flutter test test/contract` and copy
  `test/contract/operations.json` to `mambo_backend/tests/app_operations.json`;
  the backend's contract test validates it against the schema.
- **Coordinates are `GeoPoint`** outside map widgets. Only code that builds a
  `GoogleMap` converts to `LatLng`. Distance and time estimates come from
  `core/geo`; do not write another haversine.
- **State**: `setState` in the page. No state-management package yet. Keep
  logic that can be a pure function out of the widget so it can be tested.
- **After every `await` in a `State`, check `mounted`** before `setState` or
  using `context`.
- **Every wait on the network or a sensor has a time limit** and fails with a
  readable message. No spinner may last forever.
- **No secrets in the client.** `Env` values are compiled into the app. The
  Google Maps keys live in git-ignored files (`android/secrets.properties`,
  `ios/Flutter/Secrets.xcconfig`).
- **Text**: UI strings are Simplified Chinese, hard-coded, until localisation
  is introduced. Code, comments and commit messages are English. Documents in
  `docs/` are Traditional Chinese. Task cards in `tasks/` are English.
- **Tests**: every pure function and every model gets a unit test. Widgets
  that need Supabase or a platform view (maps, camera) cannot be pumped in
  tests; keep them thin and take their inputs as parameters, as `WalkSetup`
  does.

## How work is organised

Work is split into task cards in `tasks/`. `tasks/README.md` is the board: each
card's status, the files it touches, and the decisions it waits for.

| Step | Who |
|---|---|
| Write the card, status `draft` | Claude |
| Approve it, status `ready` | the maintainer |
| Implement it, status `in progress` | Codex |
| Review the diff, status `in review` or `changes requested` | Claude |
| Fix the review comments | Codex |
| Accept on a device and merge, status `done` | the maintainer |

Only implement a card whose status is `ready` (or `changes requested`, when
fixing review comments). Do not implement `draft` or `blocked` cards. Codex
does not edit files in `tasks/`; the maintainer and Claude keep the board up
to date.

## Rules for implementing a task card

1. **Branch**: `codex/NNN-slug` (the card names it), from the base branch the
   card names. One card, one branch. Do not push unless told to.
2. **Scope**: change only the files the card lists. If another file has to
   change, stop and report why instead of changing it.
3. **Do not reformat code you did not change.** Do not run `dart format` on
   whole files; a reviewer must see only your change.
4. **Dependencies**: do not add, remove or upgrade a package unless the card
   says so. Otherwise `pubspec.yaml` and `pubspec.lock` stay unchanged.
5. **Native and CI files** (`android/`, `ios/`, `.github/`): change them only
   when the card says so, and mark the report `UNVERIFIED-NATIVE`, because
   they cannot be built on the maintainer's machine.
6. **UI text**: use exactly the strings in the card. If you need text the
   card does not give, stop and ask.
7. **Secrets**: never open, print, copy or edit `.env`, `.env.*` (except
   `.env.example`), `android/secrets.properties`, `android/key.properties`,
   `ios/Flutter/Secrets.xcconfig` or any keystore. Builds use
   `--dart-define-from-file=.env.example`.
8. **Lints**: do not add `// ignore` comments or lint exemptions.
9. **Commits**: conventional style in English, imperative mood, for example
   `fix(walk): skip malformed stops instead of crashing the walk screen`.
10. **Before reporting**: `flutter pub get`, `flutter analyze` ("No issues
    found!") and `flutter test` (all pass) on the final commit.
11. **Report and stop.** Use the format below. Do not start another card.

### Files only one card may change at a time

A card may start only when no other card that is `in progress`,
`in review` or `changes requested` lists the same file:

- `lib/features/walk/walk_map_page.dart`
- `lib/main.dart`
- `lib/features/home/user_profile.dart`
- `pubspec.yaml`, `pubspec.lock`
- `android/app/build.gradle.kts`, `android/app/src/main/AndroidManifest.xml`
- `ios/Runner/Info.plist`, `ios/Runner.xcodeproj/project.pbxproj`
- `.github/workflows/*`

### Size

A card changes at most about 300 lines (tests excluded) in at most 6 files.
Larger work is split into several cards.

### Report format

```
Task: NNN <title>
Branch / commit: <branch> <hash>
flutter --version: <first line>
flutter analyze: <last line>
flutter test: <last line, with the test count>
Files changed: <path +added -removed, one per line>
Done: <each requirement of the card, and where it was done (file:line)>
Deviations: <anything that differs from the card, and why; "none" if none>
Not verified: <what could not be checked here, e.g. device behaviour; UNVERIFIED-NATIVE if native files changed>
```

## Definition of done

- Every acceptance criterion in the card is met.
- `flutter analyze` reports no issues and `flutter test` passes.
- CI is green on the change.
- Native or UI changes were checked on a device by the maintainer.
- Claude's review has no open comments and the maintainer accepted it.

## Known debt

As of 2026-10-28. Task numbers refer to `tasks/`.

- **The branch `chore/stabilize-foundation` has not been built for a phone.**
  Its 12 commits upgrade AGP (9.1), Kotlin (2.4), `location` (10) and
  `google_maps_flutter` (2.18), among others. CI has never run on it and it
  has not been tested on a device.
- `features/walk/walk_map_page.dart` (about 1,900 lines) still reads raw JSON
  and owns four timers. It is exempt from `avoid_dynamic_calls` and will be
  rebuilt after the 1.0 release: a session controller, a tracking component
  with a local queue and batched upload, and small widgets. Until then it
  gets only small, targeted fixes through task cards (001, 004).
- The backend (`../mambo_backend`, branch `improve/stabilize`) now verifies
  the access token and rejects a `userId` that does not match it (B-01). It
  needs `SUPABASE_JWT_SECRET` on the server before it is deployed; app builds
  that do not send a token stop working then. The GitHub repository is
  public and its history contains the GraphQL endpoint.
- Release identity: `com.example.mambo` on both platforms; Android release
  builds are signed with the debug key (005).
- No account deletion (007), no privacy policy or terms links (006), no
  password reset.
- No global error handler and no crash reporting (003); no analytics.
- Android asks for "Allow all the time" location and iOS declares the unused
  `fetch` background mode (004).
- iOS: `Podfile.lock` is not committed. The UIScene migration has not been
  done, so build with Xcode 26: a build made with the iOS 27 SDK will crash at
  launch on iOS 27. The newer Google Maps iOS implementation is not adopted.
- Tracking sends one request per point every 10 seconds with no local queue,
  so points recorded without a connection are lost.
- The scrapbook quota is enforced only on the device.
- No localisation, no router or deep links.
