# Task board

How cards are written, approved, implemented and reviewed is described in
`AGENTS.md` ("How work is organised"). New cards start from `_template.md`.

Only the maintainer and Claude normally edit this board. On 2026-10-30 the
maintainer explicitly authorized Codex to approve the P0 batch and implement
independent cards in parallel. This approval does not resolve missing release
identifiers, legal URLs, external credentials, or device acceptance.
Superseded cards stay superseded; dependency gates still apply. The maintainer
retains store deployment, signing identifiers/keys and legal URLs as blocked.
007 proceeds independently of postponed 006 because its backend is present;
006 must preserve the deletion row when it is later implemented.

The backend has its own board, `../mambo_backend/tasks/README.md` (cards
`B02`-`B13`, rules in `../mambo_backend/AGENTS.md`). Decisions (`D1`...) and
the launch plan for both repositories are kept here. The review behind this
plan is `docs/launch-review.md`.

**Statuses:** `draft` (written, waiting for approval) · `ready` (approved,
can start) · `in progress` · `in review` · `changes requested` · `done`
(accepted and merged) · `blocked` (waiting for a decision or another card) ·
`superseded` (replaced; do not implement).

**Integration branch:** `improve/stabilize-and-restyle`. Every card branches
from its latest commit when the card starts; the maintainer merges accepted
cards back into it and cuts release builds from it. `main` is fast-forwarded
to it when 1.0 is submitted.

**Target:** 1.0 submitted to both stores on Day 3 (2026-11-01). The earlier
target (2026-10-22) was missed. Release freeze: P0 only until submission.

**State on 2026-10-29:** `flutter analyze` clean, 145 tests pass. The
integration branch has never been built for a phone (AGP 9.1 / Kotlin 2.4
upgrades), and the backend it needs (token check, B-01) is not deployed:
production still runs the April backend from `main`.

## 3-day launch plan

"Production" here means: backend deployed with every P0 card, a signed release
build of the app submitted to both stores, and the review notes ready. Store
review is outside our control: iOS review usually takes 1-2 days; on Android a
personal Play account created after 2023-11-13 must first run a 14-day closed
test with at least 12 testers (D2). English UI, offline route upload and the
share card come after launch.

### Day 0 — today, 2026-10-29 (maintainer, about 3 hours)

1. Answer at least D2, D3, D8, D9, D12, D13, D15 (table below; each has a
   recommendation). Approve the Wave 1 cards of both boards (`draft` → `ready`).
2. Build the integration branch on one Android phone and one iPhone (Mac,
   Xcode 26, `pod install`, commit `ios/Podfile.lock`) and walk 5 minutes.
   Native build failures must surface today, not on Day 3.
3. Console work, none of it code:
   - **Keys:** revoke the ImgBB key; delete the unused `IMGBB_API_KEY` and
     `GOOGLE_MAPS_API_KEY` lines from your local `.env`; restrict the Android
     Maps key (package name + SHA-1 of upload and app-signing certificates) and
     the iOS key (bundle ID); give the server key API restrictions (Geocoding,
     Places API (New)), daily quotas and a budget alert (D17).
   - **Supabase:** custom SMTP (the built-in sender only delivers to project
     team members, about 2 mails an hour), SPF/DKIM on the sender domain,
     e-mail confirmation on, Site URL pointing at a simple "address
     confirmed" page; the "Reset password" template with `{{ .Token }}` for
     card 027. Recommended: a custom domain for the auth endpoint (ISPs in the
     UAE, Yemen and India blocked `supabase.co` for 8-18 days in 2025-26).
   - **Cloudinary:** restrict the current unsigned preset now (formats
     jpg/jpeg/png/webp/heic, 10 MB, incoming limit 2048 px, a fixed folder);
     create the signed preset of backend card B10.
   - **AI providers:** confirm `OPENAI_API_URL` is OpenAI's own endpoint, not
     a reseller; monthly spend caps and alerts on OpenAI and DashScope.
   - **MongoDB Atlas:** a tier with backups, backups on, IP access list
     limited to the API server, same region as the API (D14).
   - **Domain:** an API domain (e.g. `api.<your-domain>`) for HTTPS (B09).
   - **Stores:** App Store Connect record (bundle ID from D3, availability
     without "China mainland", D11), Play Console app, the reviewer demo
     account.

### Waves — what runs in parallel

Each line is one Codex agent on one card. Cards in the same wave share no
single-owner file (see the rules below the table).

| Wave | When | App cards (`city_walk`) | Backend cards (`mambo_backend`) |
|---|---|---|---|
| 1 | Day 1 (2026-10-30) | 003, 008, 010, 012, 013, 014, 016, 017, 018, 019 (D15); 005 if D3+D9 answered; P1 if capacity: 024, 027 | B02, B03 (first), B04, B05, B06, B09 |
| 2 | Day 2 (2026-10-31) | 015 (after 010, 013, 014, 016, 018); 006 (D8, 016, 017); 011 (D18; after 005); then one after another: 020 → 021 → 007 (they share `graphql_operations.dart`); P1: 022, 023 | B07 (after B06), B11 (after B05, P1), then B08 (after B07), B10 (after B02, B05); P1: B13 (D7) |
| 3 | Day 3 (2026-11-01) | leftovers of wave 2; contract sync; release builds; device smoke test; submission | deploy day (backend board) |
| 4 | After launch | 025, 026 (after B12), 027, 028 → 029/030/031 → 032, 033, 034 | B12 |

Critical path: B06 → B07 → B08 → deploy (backend); 010 + 013 + 014 + 016 +
018 → 015 (app); B10 → 020 → 021 (both must ship in 1.0, see the cards).

**Extra single-owner files for this launch** (on top of the list in
`AGENTS.md`): `lib/services/graphql_operations.dart` together with
`test/contract/operations.json` (cards 007, 018, 020, 021, 026). Cards 017
and 019 both change `lib/features/home/home_page.dart` in different methods;
they may run together, merge 019 first.

**Contract sync:** after 007, 018, 020, 021 or 026 is merged, the maintainer
copies `test/contract/operations.json` to the backend (steps on the backend
board). The backend card that adds the operation is merged first.

### Day 3 — release day (maintainer, Claude assists)

1. Backend deploy day, steps on the backend board.
2. Release builds from the integration branch: Android
   `flutter build appbundle --release --dart-define-from-file=.env` signed with
   the upload key (005), iOS archive with Xcode 26 → TestFlight.
3. Smoke test on both phones with the production backend: sign up (real
   inbox), consent dialog, generate in Hong Kong, start, `我到了`, a task photo,
   a surprise, pause and resume, finish, story, report a story, delete a test
   account. Also generate a walk at Apple Park (37.3349, -122.0090) from a
   simulator: App Review tests from there.
4. Submit. App Review notes: demo account; the AI consent appears after the
   tutorial and before the first walk; walks can be finished at any time
   without walking; `我到了` works within about 100 m of a stop. Play:
   data safety form, account-deletion URL (D8), foreground-service type
   declaration (`location`), content rating.


**P0 implementation review, 2026-10-30:** cards 003, 007, 010-021 are
implemented on `codex/p0-stability-integration`, with one scoped commit per
card and additional review fixes. Cards 005 and 006 remain blocked for the
maintainer; superseded 001/002/004/009 stay superseded. Backend reporting was
restored on `codex/B02-restore-content-reports` with the maintainer's explicit
approval, and the 31-operation app/backend contract was synchronized. Nothing
was pushed, deployed, accepted on a device or marked done. CI, native builds,
production configuration and maintainer/Claude acceptance remain pending.
Task documentation that was already uncommitted is preserved as local edits.

## App cards

| # | Card | Priority | Wave | Status | Waiting for | Files it changes |
|---|---|---|---|---|---|---|
| 001 | [Walk screen survives malformed stop data](001-walk-stop-safety.md) | P0 | — | superseded | done in the walk page rebuild | |
| 002 | [Time limits on waits that can hang](002-bound-hanging-waits.md) | P0 | — | superseded | included in the integration branch (d00cd7f) | |
| 003 | [Global error handlers](003-global-error-handlers.md) | P0 | 1 | in review | | `main.dart`, new `app/error_reporting.dart`, new test |
| 004 | [Ask only for "while using" location](004-foreground-only-location.md) | P0 | — | superseded | replaced by 010 | |
| 005 | [Release identity and Android signing](005-release-identity-signing.md) | P0 | 1-2 | blocked | D3 (Android ID; iOS done in PR #2), D9 | `android/app/build.gradle.kts`, new `android/key.properties.example`, `project.pbxproj`, `README.md` |
| 006 | [Privacy policy and terms links](006-legal-links.md) | P0 | 2 | blocked | D8, 016, 017 | `app/links.dart`, `user_profile.dart`, `sign_up_page.dart`, new test |
| 007 | [Account deletion](007-account-deletion.md) | P0 | 2-3 | in review | B02 present locally; 006 postponed, serialize profile edits | `graphql_operations.dart` (+ `operations.json`), `graphql_service.dart`, new `features/account/`, `user_profile.dart`, new tests |
| 008 | [CI builds both release targets](008-ci-release-builds.md) | P1 (run on Day 1) | 1 | ready | D5 | `.github/workflows/ci.yml` |
| 009 | [No progress uploads before the walk has loaded](009-no-uploads-before-load.md) | P0 | — | superseded | done in the walk page rebuild | |
| 010 | [Track walks with "while using" location only](010-while-using-location.md) | P0 | 1 | in review | D6 | `walk_map_page.dart`, `AndroidManifest.xml`, `Info.plist` |
| 011 | [iPhone only for 1.0](011-iphone-only.md) | P0 | 2 | in review | D18; not with 005 | `project.pbxproj` |
| 012 | [API client: language header and limit messages](012-api-language-and-limits.md) | P0 | 1 | in review | | `core/api/api_client.dart`, `core/api/api_exception.dart`, test |
| 013 | [Walk session for real streets](013-walk-session-real-streets.md) | P0 | 1 | in review | | `session/walk_session.dart`, new `core/geo/route_order.dart`, tests |
| 014 | [Walk-screen controls for one hand, outdoors](014-walk-controls-one-hand.md) | P0 | 1 | in review | | new `widgets/walk_controls.dart`, `widgets/walk_panels.dart`, `core/format/formatters.dart`, tests |
| 015 | [Put the new controls on the walk screen](015-wire-walk-screen.md) | P0 | 2 | in review | 010, 013, 014, 016, 018 | `walk_map_page.dart`, `walk_panels.dart`, `walk_session.dart`, `walk_dialogs.dart`, test |
| 016 | [Outbound links and walking directions](016-links-and-directions.md) | P0 | 1 | in review | | `pubspec.yaml`/`.lock`, new `app/links.dart`, new `core/map/navigation_link.dart`, test |
| 017 | [Ask before sending personal data to AI services](017-ai-data-consent.md) | P0 | 1 | in review | D13 (provider names) | new `features/consent/ai_consent.dart`, `home_page.dart`, test |
| 018 | [Report a problem with a generated place, task or story](018-report-a-problem.md) | P0 | 1 | in review | (B02 for live use) | new `features/report/`, `graphql_operations.dart` (+ `operations.json`), `graphql_service.dart`, `summary_sections.dart`, `walk_summary.dart`, tests |
| 019 | [Hide the free-record flow behind a build flag](019-gate-free-record.md) | P0 | 1 | in review | D15 | `app/env.dart`, `.env.example`, `home_page.dart` (one line), `history_tab.dart`, test |
| 020 | [Signed photo uploads](020-signed-photo-uploads.md) | P0 | 2 | in review | B10 | `cloudinary_service.dart`, `graphql_operations.dart` (+ `operations.json`), `graphql_service.dart`, `app/env.dart`, `.env.example`, `README.md`, test |
| 021 | [Ask old builds to update](021-update-prompt.md) | P0 | 2 | in review | B10; not with 003 | `pubspec.yaml`/`.lock`, new `app/app_version.dart`, `app/links.dart`, `main.dart`, `graphql_operations.dart` (+ `operations.json`), `graphql_service.dart`, test |
| 022 | [Numbered stops in walking order on the preview; safe start](022-preview-walking-order.md) | P1 | 2 | draft | 013 | new `core/map/numbered_marker.dart`, `walk_preview.dart`, `walk_repository.dart`, tests |
| 023 | [A Chinese text tutorial and an 8 MB smaller app](023-text-tutorial.md) | P1 | 2 | draft | not with another `pubspec.yaml` card | `tutorial_slides.dart`, `pubspec.yaml`, test |
| 024 | [Analytics interface and event catalogue](024-analytics-events.md) | P1 | 1 | draft | (D19 for the vendor) | new `app/analytics.dart`, test |
| 025 | [Crash reporting with Sentry](025-sentry-crash-reporting.md) | P1 | 4 | draft | D7, 003 | `pubspec.yaml`/`.lock`, `app/env.dart`, `.env.example`, `app/error_reporting.dart`, `main.dart`, test |
| 026 | [Keep the route when the connection drops](026-offline-route-queue.md) | P1 | 4 | draft | B12, 015 | new `data/track_queue.dart`, `walk_repository.dart`, `graphql_operations.dart` (+ `operations.json`), `graphql_service.dart`, `walk_map_page.dart`, test |
| 027 | [Password reset with an e-mail code](027-password-reset.md) | P1 | 1 or 4 | draft | Supabase template (Day 0) | `auth_service.dart`, new `reset_password_page.dart`, `sign_in_page.dart`, `auth_error_messages.dart`, tests |
| 028 | [Localization infrastructure and the full string catalogue](028-localization-infrastructure.md) | P1 | 4 | draft | D12; after 010-021 | `pubspec.yaml`/`.lock`, new `l10n.yaml`, new `lib/l10n/`, new `app/l10n.dart`, `main.dart`, `api_client.dart`, test |
| 029 | [Localize sign-in, splash, home, setup, tutorial, profile and history](029-localize-entry-screens.md) | P1 | 4 | draft | 028 | entry screens (see card) |
| 030 | [Localize the preview, the walk screen and the summary](030-localize-walk-screens.md) | P1 | 4 | draft | 028 | walk screens and formatters (see card) |
| 031 | [Localize error messages, start-up screens and the free record](031-localize-remaining.md) | P1 | 4 | draft | 028 (after 034) | see card |
| 032 | [Keywords as stable codes with localized labels](032-keyword-codes.md) | P1 | 4 | draft | 028 | `keywords.dart`, `walk_setup.dart`, `home_page.dart`, tests |
| 033 | [Share a finished walk as a card](033-share-card.md) | P2 | 4 | draft | | new `widgets/share_card.dart`, `walk_summary.dart`, test |
| 034 | [Move the free-record code into its own feature folder](034-move-free-record.md) | P2 | 4 | draft | 019 | moves only (see card) |

## Backend cards (detail on the backend board)

| # | Card | Priority | Wave | Waiting for |
|---|---|---|---|---|
| B02 | Account deletion and content reports | P0 | 1 | |
| B03 | Log-flow test that does not depend on today's date (CI is red until merged) | P0 | 1 | |
| B04 | Mongo indexes and a one-step route upsert | P0 | 1 | |
| B05 | Per-user limits on AI operations | P0 | 1 | D16 |
| B06 | Places API (New): nearby stops, local names, no key in URLs | P0 | 1 | D17 |
| B07 | Faster walk generation sized to the duration, in the user's language | P0 | 2 | B06, D13 |
| B08 | Tasks, photo checks and stories in the user's language; keep the story | P0 | 3 | B07 |
| B09 | Deploy: TLS, systemd, releases with rollback | P0 | 1 | D14 |
| B10 | Signed photo uploads and the minimum app version | P0 | 3 | B02, B05 |
| B11 | Gate the API fields the app does not use | P1 | 2 | B05 |
| B12 | Batch route upload and walk-status checks | P1 | 4 | B04, B08 |
| B13 | Error tracking with Sentry | P1 | 3 | D7, B11 |

## Work that is not for Codex

| Item | Owner | When | Notes |
|---|---|---|---|
| Decisions and console work of Day 0 | maintainer | Day 0 | See "Day 0" above |
| Device build of the integration branch, `pod install`, commit `ios/Podfile.lock` | maintainer | Day 0-1 | Claude diagnoses any native failure |
| M0: get CI to run on the integration branch | maintainer | Day 0-1 | Needs D5 |
| Review every Codex diff against its card | Claude | Days 1-3 | Per `CLAUDE.md` |
| Privacy policy and terms drafts (data inventory: location, route, photos, e-mail, AI processors Alibaba Cloud and OpenAI, Google, Supabase, Cloudinary, MongoDB) | Claude | Day 1 | Maintainer hosts them (D8) |
| Store privacy labels / Play data-safety answers | Claude drafts, maintainer submits | Day 2 | From the same inventory |
| `docs/release-checklist.md` (Traditional Chinese) | Claude | Day 2 | The Day 3 smoke test, step by step |
| Contract sync after 007, 018, 020, 021, 026 | maintainer | after each | Steps on the backend board |
| Backend deploy day | maintainer, Claude assists | Day 3 | Steps on the backend board |
| Store listings, screenshots, demo account, submission | maintainer | Day 2-3 | Chinese listing with an English description |
| Live-key checks the cards name (Places, model latency, report reaches Mongo) | maintainer | Day 2-3 | Codex cannot reach live services |

## Open decisions

The maintainer fills in the answer column. A card marked `blocked` names the
decisions it needs. Recommendations come from `docs/launch-review.md`.

| # | Decision | Recommendation | Answer |
|---|---|---|---|
| D1 | What "publish" means for 1.0, and which stores. | Both stores, submitted on Day 3; iOS can be live a day or two later; Android depends on D2. | |
| D2 | Is the Apple Developer membership (team `RNY2J769W6`) active? Is the Google Play account personal or an organisation, and when was it created? | Check today. A personal Play account created after 2023-11-13 needs a 14-day closed test with 12+ testers before production: start it on Day 3. | |
| D3 | Final Android application ID and iOS bundle ID (cannot change after the first upload) and the store name. | Reverse DNS of a domain you own, e.g. `com.<domain>.mambo`, same on both platforms; store name "Mambo 漫步". | iOS (2026-11-08, PR #2): bundle ID `app.mambo`, home-screen and App Store name MamboWalk. Android application ID still open. |
| D4 | Backend owner and launch without B-01? | Settled by this plan: B-01 is done, B02-B10 ship before Day 3, deploy on Day 3. | |
| D5 | How CI gets to run on the branch (write access or a fork). | Write access for the maintainer's account. | |
| D6 | Track walks with "while using" permission and the foreground service only. | Yes (card 010). | Yes — recommended default adopted for the approved P0 batch (2026-10-30). |
| D7 | Crash reporting for 1.0: Sentry, Firebase Crashlytics, or none. | Sentry for app and backend (cards 025, B13); can land right after submission. | |
| D8 | URLs for privacy policy, terms, support and web account deletion; who writes and hosts them; demo account for App Review. | Claude drafts on Day 1; host as static pages on your domain; a support e-mail address; demo account created on Day 2. | |
| D9 | Android signing: who creates and keeps the upload key; Play App Signing. | Maintainer creates it, stores it in a password manager plus an offline copy; Play App Signing on. | |
| D10 | Xcode version; Supabase e-mail confirmation and Site URL; password reset in 1.0? | Xcode 26.x; confirmation on with custom SMTP (required); password reset via card 027, in 1.0 if Day 1 has room, else right after. | |
| D11 | Launch markets. | Worldwide **except mainland China** (untick "China mainland" in App Store Connect; no Chinese Android stores). Hong Kong, Macau and Taiwan are fine. A China edition is a separate project (ICP filing, generative-AI filing, AMap, China-hosted backend and auth). | |
| D12 | UI languages of 1.0. | Simplified Chinese only for 1.0 (AI content follows it after B07/B08); English (and optionally Traditional Chinese) in 1.1 with cards 028-032. | Simplified Chinese only for the P0 batch; localization remains P1. |
| D13 | Which model plans walks, and which OpenAI endpoint. | Official OpenAI endpoint only. On Day 2 compare `gpt-5.4` with `WALK_REASONING_EFFORT=low` against `WALK_PROVIDER=dashscope`, `WALK_MODEL=qwen-plus` on five locations; keep the faster one whose stops are real. If OpenAI is dropped entirely, remove it from the consent text (017) and the privacy policy. | |
| D14 | Hosting for 1.0 and region. | Keep the single EC2 instance, hardened by B09; region outside mainland China and Hong Kong (OpenAI blocks both), e.g. Singapore or Tokyo; Atlas in the same region. Containers after launch. | |
| D15 | Free-record flow (记录, reflection questions, scrapbook) in 1.0. | Hide it (card 019): older code, a second tracking pipeline, the most expensive AI call. Bring it back merged into the walk summary later. | Hide for 1.0 — recommended default adopted for the approved P0 batch (2026-10-30). |
| D16 | Per-user daily AI limits. | Accept the defaults in B05 (20 walks, 80 tasks, 150 photo checks, 3 scrapbook images a day). | |
| D17 | Which Google Cloud project production uses for Places. | A dedicated production project with Places API (New), Geocoding and the Maps SDKs enabled; B06 is then mandatory (legacy Places cannot be enabled on new projects). | |
| D18 | iPhone only for 1.0. | Yes (card 011). | Yes — recommended default adopted for the approved P0 batch (2026-10-30). |
| D19 | Analytics vendor. | PostHog behind the interface of card 024; decide after launch. | |

## Later (not carded yet)

- Withdraw/revoke flows beyond 006 (export my data).
- Numbered markers and the planned route line on the walk page itself
  (reuse `numberedMarker` from 022).
- Tasks tied to the next stop (needs a backend card).
- Saved walks and "walk this again" for residents; weekly suggestion.
- Public route page and deep links for shared walks (after 033).
- Stop photos through a server-side photo proxy (backend board, "Later").
- A China edition: see `docs/launch-review.md`, section 3.
