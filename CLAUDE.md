# Mambo (City Walk)

Flutter app for iOS and Android. The user picks keywords and a duration, the
backend generates a walk around them, and they walk it while completing
AI-checked photo tasks. Package name: `mambo`.

Background and reasoning live in `docs/` (written in Traditional Chinese):
`product-ux-marketing-analysis.md` and `technical-review.md`.

## Commands

```sh
flutter pub get
flutter analyze                               # must report no issues
flutter test                                  # must pass
flutter run --dart-define-from-file=.env      # .env is git-ignored; see .env.example
```

Flutter 3.47.6 (pinned in `.github/workflows/ci.yml`). CI runs analyze, test
and an Android debug build on every push and pull request.

## Layout

```
lib/
  app/env.dart            build-time configuration (String.fromEnvironment)
  core/
    api/                  ApiClient, ApiException, gqlString
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
  services/               GraphQLService, LogService, AuthService, CloudinaryService
test/                     mirrors lib/
```

## Conventions

- **Backend calls go through `ApiClient`.** Never call `http` directly. It adds
  the access token, a timeout and error handling, and throws `ApiException`.
  `ApiException.toString()` is a user-facing Chinese sentence; log
  `details`, show `userMessage`.
- **Pages use repositories and typed models**, not `Map<String, dynamic>`.
  Add a field to the model and its `fromJson` rather than indexing JSON in a
  widget. Parsing is tolerant: skip a malformed item, do not throw.
- **Inline GraphQL strings go through `gqlString`.** Prefer GraphQL variables
  when the argument types are known.
- **Coordinates are `GeoPoint`** outside map widgets. Only code that builds a
  `GoogleMap` converts to `LatLng`. Distance and time estimates come from
  `core/geo`; do not write another haversine.
- **State**: `setState` in the page. No state-management package yet. Keep
  logic that can be a pure function out of the widget so it can be tested.
- **After every `await` in a `State`, check `mounted`** before `setState` or
  using `context`.
- **No secrets in the client.** `Env` values are compiled into the app. The
  Google Maps keys live in git-ignored files (`android/secrets.properties`,
  `ios/Flutter/Secrets.xcconfig`).
- **Text**: UI strings are Simplified Chinese, hard-coded, until localisation
  is introduced. Code, comments and commit messages are English. Documents in
  `docs/` are Traditional Chinese.
- **Tests**: every pure function and every model gets a unit test. Widgets
  that need Supabase or a platform view (maps, camera) cannot be pumped in
  tests; keep them thin and take their inputs as parameters, as `WalkSetup`
  does.

## Known debt

- `features/walk/walk_map_page.dart` (about 1,900 lines) still reads raw JSON
  and owns four timers. It is exempt from `avoid_dynamic_calls` and is the
  next thing to rebuild: a session controller, a tracking component with a
  local queue and batched upload, and small widgets.
- The backend does not verify the access token yet and still trusts the
  `userId` argument.
- No localisation, no router or deep links, no crash reporting.
- Native builds are verified only by CI; the UIScene migration and the newer
  Google Maps iOS implementation have not been done.
