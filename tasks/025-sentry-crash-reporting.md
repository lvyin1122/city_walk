# 025: Crash reporting with Sentry

- **Status:** draft
- **Priority:** P1
- **Owner:** Codex
- **Base branch:** improve/stabilize-and-restyle (after 003 is merged)
- **Branch:** codex/025-sentry-crash-reporting
- **Waiting for:** D7 (vendor; Sentry recommended so app and backend card B13
  share one tool), card 003 (`ErrorReporter`); not at the same time as another
  card that changes `pubspec.yaml` or `main.dart`

## Goal

Crashes and uncaught errors from release builds reach Sentry without personal
data. Builds without a DSN behave exactly as today.

## Background

- Card 003 adds `ErrorReporter`, `DebugErrorReporter` and
  `installErrorHandlers(reporter)` in `lib/app/error_reporting.dart`, called
  from `lib/main.dart` right after `WidgetsFlutterBinding.ensureInitialized()`.
- Build-time configuration is in `lib/app/env.dart` and `.env.example`; a
  Sentry DSN is safe to ship in an app.
- The app handles location, photos and e-mail addresses: none of them may be
  attached to events.

## Files or directories involved

- `pubspec.yaml`, `pubspec.lock` (`sentry_flutter`)
- `lib/app/env.dart` (`SENTRY_DSN`, optional, not in `missing`)
- `.env.example`
- `lib/app/error_reporting.dart` (`SentryErrorReporter`)
- `lib/main.dart`
- `test/app/error_reporting_test.dart`

## Implementation requirements

1. `flutter pub add sentry_flutter`.
2. `Env.sentryDsn = String.fromEnvironment('SENTRY_DSN')`; `.env.example`
   gets `SENTRY_DSN=` with a comment.
3. `SentryErrorReporter implements ErrorReporter` forwarding to
   `Sentry.captureException(error, stackTrace: stack)` with `context` as a tag.
4. `main.dart`: when `Env.sentryDsn` is not empty,
   `await SentryFlutter.init((o) { o.dsn = ...; o.sendDefaultPii = false; o.tracesSampleRate = 0; o.beforeSend = <strip request, user and breadcrumbs with "http" in their category>; })`
   before `installErrorHandlers(SentryErrorReporter())`; otherwise keep
   `DebugErrorReporter`. Every `runApp` path stays covered.

## Restrictions

- No screenshots, no view hierarchy, no user feedback widget, no performance
  tracing. Change only the files above.

## Tests to add or update

`error_reporting_test.dart`: `SentryErrorReporter` passes error and stack to an
injected capture function (make it injectable); the `beforeSend` callback
removes `user` and `request` from a sample event.

## Acceptance criteria

- Without `SENTRY_DSN` (CI uses `.env.example`), no Sentry call happens.
- With a test DSN on a device, a deliberate `throw` in debug shows up in Sentry
  without user or request data (maintainer).

## Commands that must pass

```sh
flutter pub get
flutter analyze   # "No issues found!"
flutter test      # all pass
```

## Information Codex must report after completion

The report format in `AGENTS.md`, plus the `pubspec.lock` summary. Mark it
`UNVERIFIED-NATIVE` if the plugin changed native build files.
