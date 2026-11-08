# 029: Localize sign-in, splash, home, setup, tutorial, profile and history

- **Status:** draft
- **Priority:** P1
- **Owner:** Codex
- **Base branch:** improve/stabilize-and-restyle (after 028 is merged)
- **Branch:** codex/029-localize-entry-screens
- **Waiting for:** card 028; not at the same time as another card that
  changes `user_profile.dart` (006, 007)

## Goal

Every string on the screens before a walk comes from `context.l10n`, so these
screens read naturally in English on an English phone and are unchanged in
Chinese.

## Background

Card 028 put every string of `lib/` into `lib/l10n/app_zh.arb` (with English in
`app_en.arb`) and added `context.l10n`. This card only replaces literals with
the existing keys. Mechanical change: approved exception to the six-file limit.

## Files or directories involved

- `lib/splash_screen.dart`
- `lib/features/auth/sign_in_page.dart`, `sign_up_page.dart`,
  `auth_error_messages.dart`, `auth_form_layout.dart`
- `lib/features/home/home_page.dart`, `walk_setup.dart`,
  `tutorial_slides.dart`, `user_profile.dart`, `history_tab.dart`
- `lib/features/home/walk_history/` (all files)
- tests under `test/features/auth/` and `test/features/home/` that look for
  Chinese text (update them to pump with the `zh` locale and the delegates)

## Implementation requirements

1. Replace each user-facing literal in these files with the matching key from
   `app_zh.arb`. When a function has no `BuildContext` (for example
   `signInErrorMessage` in `auth_error_messages.dart`), pass
   `AppLocalizations` in as a parameter.
2. If a string has no key, stop and report it (do not edit the ARB files).
3. Keyword chips are not changed here (card 032).

## Restrictions

- Do not edit `lib/l10n/`. Do not change layout, logic or style.

## Tests to add or update

- Existing widget tests keep passing under `Locale('zh')`.
- Add one test per screen family that pumps it under `Locale('en')` and finds
  an English title (sign-in, walk setup, profile).

## Acceptance criteria

- The Chinese-literal count of card 028 is zero for every file listed.
- On an English phone (maintainer): splash, sign-in, setup, profile and
  history are in English; on a Chinese phone nothing changed.

## Commands that must pass

```sh
flutter pub get
flutter analyze   # "No issues found!"
flutter test      # all pass
```

## Information Codex must report after completion

The report format in `AGENTS.md`, plus any string that had no key.
