# 031: Localize error messages, start-up screens and the free record

- **Status:** draft
- **Priority:** P1
- **Owner:** Codex
- **Base branch:** improve/stabilize-and-restyle (after 028 is merged; after 034
  if that card moved the free-record files)
- **Branch:** codex/031-localize-remaining
- **Waiting for:** card 028; not at the same time as another card that
  changes `main.dart`

## Goal

The last Chinese literals in `lib/` move to the catalogue: API error messages,
the start-up error and update screens, and the free-record flow.

## Background

- `ApiException.userMessage` (`lib/core/api/api_exception.dart`) returns fixed
  Chinese sentences and has no `BuildContext`. Look the message up by
  `AppLanguage.tag` (`lib/app/l10n.dart`) through a small table generated from
  the catalogue keys `error*` (use `lookupAppLocalizations(Locale(...))` from
  the generated code).
- `StartupErrorApp` texts in `lib/main.dart`, `UpdateRequiredScreen`
  (`lib/app/app_version.dart`) and `AppErrorWidget`
  (`lib/app/error_reporting.dart`) have catalogue keys.
- The free-record files (`lib/features/walk/quick_start_map_page.dart`,
  `lib/features/home/log/`, or `lib/features/log/` after card 034) contain the
  remaining literals. Skip them if D15 removed the flow for good.
- Mechanical change: approved exception to the six-file limit.

## Files or directories involved

- `lib/core/api/api_exception.dart`
- `lib/main.dart`, `lib/app/app_version.dart`, `lib/app/error_reporting.dart`
- the free-record files listed above
- related tests

## Implementation requirements

1. Replace literals with catalogue keys (same rules as card 029).
2. `ApiException.userMessage` reads the current language's message.

## Restrictions

- Do not edit `lib/l10n/`. No behaviour change.

## Tests to add or update

- `api_client_test.dart`: with `AppLanguage.tag = 'en'`, a timeout's
  `userMessage` is English; with `zh-Hans`, the current Chinese sentence.

## Acceptance criteria

- The Chinese-literal count of card 028 is zero for all of `lib/` (outside
  `lib/l10n/` and the bilingual AI-consent paragraph).

## Commands that must pass

```sh
flutter pub get
flutter analyze   # "No issues found!"
flutter test      # all pass
```

## Information Codex must report after completion

The report format in `AGENTS.md`, plus the final literal count.
