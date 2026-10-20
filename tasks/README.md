# Task board

How cards are written, approved, implemented and reviewed is described in
`AGENTS.md` ("How work is organised"). New cards start from `_template.md`.

Only the maintainer and Claude edit this board. Codex reports when a card is
finished; it does not change statuses.

**Statuses:** `draft` (written, waiting for approval) · `ready` (approved,
can start) · `in progress` · `in review` · `changes requested` · `done`
(accepted and merged) · `blocked` (waiting for a decision or another card).

**Base branch:** `chore/stabilize-foundation` until it is merged into `main`,
then `main`.

**Target:** 1.0 submitted to both stores by 2026-10-22. Release freeze: P0
only until then.

## Codex cards

| # | Card | Priority | Status | Waiting for | Files it changes |
|---|---|---|---|---|---|
| 001 | [Walk screen survives malformed stop data](001-walk-stop-safety.md) | P0 | changes requested | review 1: 2 fixes | `walk_map_page.dart`, `core/map/lat_lng.dart`, new test |
| 002 | [Time limits on waits that can hang](002-bound-hanging-waits.md) | P0 | ready | | `home_page.dart`, `cloudinary_service.dart`, `log_review_result_page.dart`, new test |
| 003 | [Global error handlers](003-global-error-handlers.md) | P0 | ready | | `main.dart`, new `app/error_reporting.dart`, new test |
| 004 | [Ask only for "while using" location](004-foreground-only-location.md) | P0 | blocked | D6; 009 merged | `walk_map_page.dart`, `AndroidManifest.xml`, `Info.plist` |
| 005 | [Release identity and Android signing](005-release-identity-signing.md) | P0 | blocked | D3, D9 | `android/app/build.gradle.kts`, new `android/key.properties.example`, `project.pbxproj`, `README.md` |
| 006 | [Privacy policy and terms links](006-legal-links.md) | P0 | blocked | D8 | `pubspec.yaml`, `pubspec.lock`, new `app/links.dart`, `user_profile.dart`, `sign_up_page.dart`, new test |
| 007 | [Account deletion](007-account-deletion.md) | P0 | blocked | D4 (B-02 contract); 006 merged | `graphql_service.dart`, new `features/account/`, `user_profile.dart`, new tests |
| 008 | [CI builds both release targets](008-ci-release-builds.md) | P1 | ready | D5 (CI must be able to run) | `.github/workflows/ci.yml` |
| 009 | [No progress uploads before the walk has loaded](009-no-uploads-before-load.md) | P0 | draft | approval; 001 merged | `walk_map_page.dart` |

Can run at the same time: 001, 002, 003 and 008 share no files.
`walk_map_page.dart` is changed by 001, 009 and 004, in that order, one at a
time. 007 waits for 006 (both change `user_profile.dart`).

## Work that is not for Codex

| Item | Owner | Notes |
|---|---|---|
| M0: get CI to run on `chore/stabilize-foundation` | maintainer | Needs D5: the GitHub repository is read-only for the maintainer's account |
| M0: build on a Mac with Xcode 26, `pod install`, commit `ios/Podfile.lock` | maintainer | Claude diagnoses any failure |
| M0: one full walk on an Android phone and an iPhone | maintainer | Generate, collect a stop, photo task, summary |
| B-01: backend verifies the access token and stops trusting `userId` | backend owner, Claude designs | Backend repository is not on this machine (D4) |
| B-02: backend `deleteAccount` mutation | backend owner, Claude writes the contract | Unblocks 007 |
| Revoke the ImgBB key; rotate and restrict the Google Maps key | maintainer | Both are in the public git history |
| Store listings, privacy labels, Data safety form, reviewer demo account, submission | maintainer | Claude drafts the data inventory |
| `docs/release-checklist.md` (Traditional Chinese) | Claude | Smoke test for the release candidate |

## Open decisions

The maintainer fills in the answer column. A card marked `blocked` names the
decisions it needs.

| # | Decision | Answer |
|---|---|---|
| D1 | What "publish by 2026-10-22" means: live in the stores, submitted for review, or TestFlight and a Play test track. Which stores. | |
| D2 | Accounts: is the Apple Developer Program membership for team `RNY2J769W6` active? Is the Google Play account personal or an organisation, and when was it created? A personal account created after 2023-11-13 must run a 14-day closed test with at least 12 testers before production. | |
| D3 | Final application ID for Android and bundle ID for iOS (cannot change after the first Play upload) and the store name. | |
| D4 | Backend: who ships B-01 and B-02 by the target date, and can Claude get the backend repository? Does walk generation work outside Hong Kong (Apple reviewers are in the US)? Is launching without B-01 acceptable? | |
| D5 | How CI gets to run on the branch: write access from the repository owner, or a fork under the maintainer's account. | |
| D6 | Track walks with "while using" permission and the foreground service only, without "Allow all the time". Recommended: yes. | |
| D7 | Crash reporting for 1.0: Sentry, Firebase Crashlytics, or none. | |
| D8 | URLs for the privacy policy, terms, support page and web account-deletion page; who writes and hosts them; a demo account for App Review. | |
| D9 | Android signing: who creates and keeps the upload key; use Play App Signing. | |
| D10 | Housekeeping: Xcode version on the Mac; Supabase email confirmation and Site URL; password reset out of scope for 1.0. (macOS CI minutes are free while the repository is public.) | |
