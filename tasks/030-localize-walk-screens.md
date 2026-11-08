# 030: Localize the preview, the walk screen and the summary

- **Status:** draft
- **Priority:** P1
- **Owner:** Codex
- **Base branch:** improve/stabilize-and-restyle (after 028 is merged)
- **Branch:** codex/030-localize-walk-screens
- **Waiting for:** card 028; not at the same time as another card that
  changes `walk_map_page.dart`

## Goal

Every string from the walk preview to the summary, including units and dates,
comes from `context.l10n` or a locale-aware formatter.

## Background

Same procedure as card 029 (keys exist after 028; replace literals only;
mechanical exception to the six-file limit). Formatters in
`lib/core/format/formatters.dart` hard-code `分钟`, `小时`, `米`, `km` and the
weekdays `周日`…`周六`; they need the `format*` keys from the catalogue
(pass `AppLocalizations` in) and `DateFormat` with the current locale.

## Files or directories involved

- `lib/features/walk/walk_preview.dart`, `walk_map_page.dart`, `walk_summary.dart`
- `lib/features/walk/widgets/` (`walk_panels.dart`, `walk_controls.dart`,
  `walk_dialogs.dart`, `summary_sections.dart`)
- `lib/features/report/report_dialog.dart`
- `lib/features/consent/ai_consent.dart` (the Chinese paragraph only; the
  English paragraph stays visible in every language)
- `lib/core/format/formatters.dart`
- related tests under `test/features/walk/`, `test/features/report/`,
  `test/features/consent/` and `test/core/format/`

## Implementation requirements

1. Replace literals with catalogue keys; pass `AppLocalizations` to
   formatters (`formatMinutes`, `formatDistance`, `formatDayOfWeek`, …).
2. Distances stay metric in every language (`m`/`km` in English).
3. If a string has no key, stop and report it.

## Restrictions

- Do not edit `lib/l10n/`. No layout or logic change.

## Tests to add or update

- Existing tests pass under `Locale('zh')`; formatter tests cover `en`
  (`45 min`, `1 h 20 min`, `320 m`, `Wed`).
- `walk_controls_test.dart` adds one English pass (no overflow at
  `TextScaler.linear(1.3)` with English labels).

## Acceptance criteria

- The Chinese-literal count of card 028 is zero for every file listed.
- Device check in English (maintainer): a full walk shows no Chinese except
  AI content generated before the language changed.

## Commands that must pass

```sh
flutter pub get
flutter analyze   # "No issues found!"
flutter test      # all pass
```

## Information Codex must report after completion

The report format in `AGENTS.md`, plus any string that had no key.
