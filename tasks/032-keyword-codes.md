# 032: Keywords as stable codes with localized labels

- **Status:** draft
- **Priority:** P1
- **Owner:** Codex
- **Base branch:** improve/stabilize-and-restyle (after 028 is merged)
- **Branch:** codex/032-keyword-codes
- **Waiting for:** card 028 (the catalogue must contain the nine keyword labels
  as `setupKeyword*` keys; if it does not, stop and report)

## Goal

The interest chips are stable codes shown in the user's language, and the
backend receives clean keyword text (no emoji) in the same language as the
rest of the request.

## Background

- `lib/features/home/keywords.dart:1-11` is a list of Chinese strings with
  emoji (`'🏃 探险'`, `'🍽️ 美食'`, …). `home_page.dart` keeps a
  `List<bool>` parallel to it and sends the selected strings, emoji included,
  joined by spaces (`graphql_service.dart:49`).
- Custom keywords typed by the user are sent as typed
  (`parseCustomKeywords`, `keywords.dart:13-26`, tested in
  `test/features/home/keywords_test.dart`).

## Files or directories involved

- `lib/features/home/keywords.dart`
- `lib/features/home/walk_setup.dart`
- `lib/features/home/home_page.dart` (keyword state only)
- `test/features/home/keywords_test.dart`
- `test/features/home/walk_setup_test.dart`

## Implementation requirements

1. `enum TravelKeyword { adventure, streetCulture, uniqueExperience, landmarks, localVibe, culture, nature, food, heritage }`
   with `emoji` and `String label(AppLocalizations l10n)`; the chip shows
   `'$emoji ${label(l10n)}'`.
2. `WalkSetup` and `HomePage` keep a `Set<TravelKeyword>` instead of
   `List<bool>`; the order of chips stays as today.
3. The backend receives the labels without emoji, in the current language,
   followed by the custom keywords, joined with `, `.

## Restrictions

- Change only the files above; do not edit `lib/l10n/`.

## Tests to add or update

- `keywords_test.dart`: every keyword has a non-empty label in `zh` and `en`;
  the request text for {food, nature} + custom `咖啡` is `美食, 自然, 咖啡` in
  `zh`; no emoji in the request text.
- `walk_setup_test.dart` keeps passing (update it to the new state type).

## Acceptance criteria

- `grep -n "travelKeywords" lib -r` prints nothing.

## Commands that must pass

```sh
flutter pub get
flutter analyze   # "No issues found!"
flutter test      # all pass
```

## Information Codex must report after completion

The report format in `AGENTS.md`.
