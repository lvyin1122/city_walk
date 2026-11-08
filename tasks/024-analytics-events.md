# 024: Analytics interface and event catalogue

- **Status:** draft
- **Priority:** P1
- **Owner:** Codex
- **Base branch:** improve/stabilize-and-restyle
- **Branch:** codex/024-analytics-events
- **Waiting for:** nothing for the interface; D19 (vendor) for a later card that
  connects it

## Goal

The app has one vendor-neutral way to record product events, and one agreed
list of the events that measure the walk funnel. Pages can start calling it;
choosing a vendor later changes one file.

## Background

- There are no analytics. The product question for 1.0 is the funnel
  "generate → start → reach a stop → finish", and its north-star metric is
  completed walks per week (`docs/product-ux-marketing-analysis.md`, 4.7 and 8).
- Card 003 created the same pattern for errors (`ErrorReporter` with a
  debug implementation in `lib/app/error_reporting.dart`).
- No personal data may be sent: no user id, e-mail, coordinates, addresses,
  photo URLs or free text.

## Files or directories involved

- `lib/app/analytics.dart` (new)
- `test/app/analytics_test.dart` (new)

## Implementation requirements

1. `enum AnalyticsEvent` with a `name` in snake_case:
   `aiConsent` (`granted`: bool), `walkGenerateRequested` (`minutes`,
   `keywordCount`), `walkGenerateSucceeded` (`stops`, `seconds`),
   `walkGenerateFailed` (`reason`: one of `location`, `network`, `limit`,
   `server`), `walkStarted` (`stops`), `stopReached` (`method`: `auto` or
   `manual`), `navigationOpened`, `taskPhotoChecked` (`accepted`: bool),
   `surpriseAdded`, `walkPaused`, `walkFinished` (`minutes`, `km` rounded to
   0.1, `stopsReached`, `stopsTotal`, `tasks`), `summaryViewed`, `reportSent`
   (`kind`).
2. `abstract interface class Analytics { void log(AnalyticsEvent event, [Map<String, Object> params]); }`,
   `class DebugAnalytics implements Analytics` (prints with `debugPrint` in
   debug builds only), and a settable `Analytics analytics = DebugAnalytics();`
   top-level for pages and tests.
3. `log` drops any parameter whose key is not in the event's allowed list
   (define the list next to each enum value), so nothing else can leak.

## Restrictions

- New files only; no page changes in this card (pages are wired by the cards
  that touch them next, and by the vendor card after D19).
- No new dependency.

## Tests to add or update

`analytics_test.dart`: allowed parameters pass, unknown ones are dropped;
every event name is unique snake_case; a fake `Analytics` set as `analytics`
receives calls.

## Acceptance criteria

- `grep -rn -E "email|latitude|longitude|userId" lib/app/analytics.dart` prints nothing.

## Commands that must pass

```sh
flutter pub get
flutter analyze   # "No issues found!"
flutter test      # all pass
```

## Information Codex must report after completion

The report format in `AGENTS.md`.
