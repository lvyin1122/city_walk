# 003: Global error handlers

- **Status:** ready (approved 2026-10-20)
- **Priority:** P0
- **Owner:** Codex
- **Base branch:** chore/stabilize-foundation
- **Branch:** codex/003-global-error-handlers
- **Waiting for:** nothing. Connecting a crash-reporting service is a
  separate card after D7.

## Goal

Every uncaught error goes through one reporter, and release builds show a
friendly message instead of a grey box. Adding a crash-reporting service
later is a change in one place.

## Background

`lib/main.dart` installs no error handlers: no `FlutterError.onError`, no
`PlatformDispatcher.instance.onError`, no `ErrorWidget.builder`. After the
release nobody would see a crash, and a widget that throws in a release build
shows a grey area. The crash-reporting vendor is not chosen yet (D7 in
`tasks/README.md`), so this card adds a vendor-neutral interface with a
logging implementation.

## Files or directories involved

- `lib/main.dart`
- `lib/app/error_reporting.dart` (new)
- `test/app/error_reporting_test.dart` (new)

## Implementation requirements

1. `lib/app/error_reporting.dart` defines:
   - `abstract interface class ErrorReporter { void report(Object error, StackTrace? stack, {String? context}); }`
   - `class DebugErrorReporter implements ErrorReporter`, which writes the
     error, context and stack with `debugPrint`.
   - `class AppErrorWidget extends StatelessWidget`: a small `Material`
     widget with centred text `'这里出了点问题'`.
   - `void installErrorHandlers(ErrorReporter reporter)`, which sets:
     - `FlutterError.onError`: call `FlutterError.presentError(details)`,
       then `reporter.report(details.exception, details.stack, context: details.context?.toString())`;
     - `PlatformDispatcher.instance.onError`: report the error and return
       `true`;
     - only when `kReleaseMode` is true:
       `ErrorWidget.builder = (_) => const AppErrorWidget();`
2. `lib/main.dart`: call `installErrorHandlers(DebugErrorReporter())` right
   after `WidgetsFlutterBinding.ensureInitialized()`.

## Restrictions

- No new dependencies and no crash-reporting SDK.
- Do not change the start-up or auth flow in `main.dart` beyond the one call.
- Do not use `runZonedGuarded`.
- No UI text other than `'这里出了点问题'`.

## Tests to add or update

`test/app/error_reporting_test.dart`:

- with a fake `ErrorReporter`, an error passed to `FlutterError.onError`
  reaches the reporter with its stack;
- an error passed to `PlatformDispatcher.instance.onError` reaches the
  reporter and the handler returns `true`;
- `AppErrorWidget` renders `'这里出了点问题'` (pump it directly; do not rely on
  `kReleaseMode`).

Save the original `FlutterError.onError` and `PlatformDispatcher.instance.onError`
before each test and restore them in `tearDown`; the test framework fails a
test that leaves them changed.

## Acceptance criteria

- All handlers are installed before `runApp` on every start-up path in
  `main.dart`, including the configuration and Supabase error screens.
- The tests show errors reach the reporter.
- Debug builds still show Flutter's red error screen.
- `git diff --stat chore/stabilize-foundation` lists only the three files.

## Commands that must pass

```sh
flutter pub get
flutter analyze   # "No issues found!"
flutter test      # all pass
```

## Information Codex must report after completion

The report format in `AGENTS.md`, plus where in `main.dart` the handlers are
installed relative to each `runApp` call.
