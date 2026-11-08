# 028: Localization infrastructure and the full string catalogue

- **Status:** draft
- **Priority:** P1 (P0 if D12 says English ships in 1.0)
- **Owner:** Codex
- **Base branch:** improve/stabilize-and-restyle (after the P0 UI cards
  010-021 are merged, so the catalogue contains their strings)
- **Branch:** codex/028-localization-infrastructure
- **Waiting for:** D12 (languages: `zh` Simplified, `en`, and whether
  `zh_Hant` is included); not at the same time as another card that changes
  `pubspec.yaml`, `main.dart` or `api_client.dart`

## Goal

The app can show Simplified Chinese and English (and Traditional Chinese if
D12 says so), following the phone's language, and tells the backend which one
is in use. Every user-facing string exists in the catalogue with a translation,
so the follow-up cards 029-031 only swap literals for keys and never edit the
catalogue (no merge conflicts between them).

## Background

- `main.dart:19-20` fixes the locale: `initializeDateFormatting('zh_CN')`,
  `Intl.defaultLocale = 'zh_CN'`. There are no `localizationsDelegates`;
  about 300 Chinese literals are spread over `lib/`.
- The target users include international travellers who do not read Chinese
  (`docs/product-ux-marketing-analysis.md`, 4.2 and 5.8).
- `ApiClient` sends `X-App-Language` from `ApiClient.defaultLanguageTag`
  (card 012), which returns `zh-Hans`. The backend generates walk texts, tasks
  and stories in that language (cards B07, B08).
- `lib/core/api/api_client.dart` already imports `lib/app/env.dart`, so
  importing from `lib/app/` there is accepted.

## Files or directories involved

- `pubspec.yaml`, `pubspec.lock` (`flutter_localizations`, `generate: true`)
- `l10n.yaml` (new)
- `lib/l10n/app_zh.arb`, `lib/l10n/app_en.arb` (new; `app_zh_Hant.arb` if
  D12 includes it) and the generated `lib/l10n/app_localizations*.dart`
- `lib/app/l10n.dart` (new)
- `lib/main.dart`
- `lib/core/api/api_client.dart` (`defaultLanguageTag` only)
- `test/app/l10n_test.dart` (new)

Mechanical data files (ARB, generated code) do not count towards the
300-line limit.

## Implementation requirements

1. `pubspec.yaml`: `flutter_localizations: sdk: flutter` and
   `flutter: generate: true`. `l10n.yaml`: `arb-dir: lib/l10n`,
   `template-arb-file: app_zh.arb`, `output-localization-file: app_localizations.dart`,
   `output-class: AppLocalizations`, `nullable-getter: false`. Commit the
   generated files so CI needs no extra step.
2. Catalogue: every user-facing string literal in `lib/` (including SnackBar
   texts, dialog texts, tooltips, semantics labels, `Env.missing` screen) gets a
   key in `app_zh.arb` with its exact current text, grouped by prefix
   (`common`, `auth`, `splash`, `home`, `setup`, `tutorial`, `profile`,
   `history`, `preview`, `walk`, `summary`, `report`, `consent`, `log`,
   `error`, `update`, `format`). Interpolations become ICU placeholders
   (`已到达：{name}`). Each key has an `@key` entry with a one-line
   `description` saying where it appears. `app_en.arb` has a natural English
   translation of every key (short, calm, matching the app's tone).
3. `lib/app/l10n.dart`:
   - `extension L10nContext on BuildContext { AppLocalizations get l10n => AppLocalizations.of(this); }`
   - `abstract final class AppLanguage { static String tag = 'zh-Hans'; static String tagFor(Locale locale) }`
     mapping `zh` + `Hant` script or `TW`/`HK`/`MO` → `zh-Hant`, other `zh` →
     `zh-Hans`, `en` → `en`.
4. `main.dart`: both `MaterialApp`s get `localizationsDelegates` and
   `supportedLocales` from `AppLocalizations`; a `localeResolutionCallback`
   picks the best supported locale (Chinese → `zh` unless Traditional is
   supported and requested; else English if the phone prefers it; else `zh`),
   sets `AppLanguage.tag` and `Intl.defaultLocale`; date formatting is
   initialised for every supported locale.
5. `api_client.dart`: `defaultLanguageTag()` returns `AppLanguage.tag`.

## Restrictions

- Do not replace literals in pages here (cards 029-031 do that). The app must
  look exactly the same in Chinese after this card.
- No new dependency besides `flutter_localizations`.

## Tests to add or update

`test/app/l10n_test.dart`: every key of `app_zh.arb` exists in `app_en.arb`
(and `app_zh_Hant.arb`) with the same placeholders; no value is empty;
`AppLanguage.tagFor` for `zh_CN`, `zh_TW`, `zh_HK`, `zh-Hant`, `en_US`, `fr`;
a widget under `MaterialApp(locale: Locale('en'))` reads an English string
through `context.l10n`.

## Acceptance criteria

- A count of the Chinese literals in `lib/`
  (`grep -rnP "'[^']*[\x{4e00}-\x{9fff}][^']*'" lib --include='*.dart' | grep -v "lib/l10n/" | wc -l`)
  is reported; cards 029-031 bring it to zero.
- The app looks unchanged on a Chinese phone.

## Commands that must pass

```sh
flutter pub get
flutter analyze   # "No issues found!"
flutter test      # all pass
```

## Information Codex must report after completion

The report format in `AGENTS.md`, plus the number of keys and the literal
count above.
