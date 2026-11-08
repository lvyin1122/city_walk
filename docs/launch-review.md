# Mambo launch review (2026-10-29)

Scope: both repositories (`city_walk` on `improve/stabilize-and-restyle`,
`mambo_backend` on `improve/stabilize`), read in full, with `flutter analyze`,
`flutter test`, `ruff` and `pytest` run on 2026-10-29. Questions asked: are the
services right for a worldwide launch (and mainland China), is the code clean
with legacy separated and gated, can it be deployed smoothly, can it be in
production in 3 days, is the walk flow easy to use while walking, and does the
product meet its users' needs. The work that follows from this review is in
`tasks/README.md` (app, plan, decisions) and
`../mambo_backend/tasks/README.md` (backend). This file is identical in both
repositories.

## 1. Answers in brief

1. **Services.** Right for a worldwide launch **outside mainland China**, with
   four changes: move the server off the legacy Google Places API (it also
   leaks the server key to every app user), make sure walk planning uses an
   official, fast model endpoint hosted outside Hong Kong, give Supabase a
   custom SMTP sender (and ideally a custom domain), and switch photo uploads
   to signed uploads. ImgBB is no longer used by any code; only its key is
   left. Mainland China needs a different stack and government filings and
   should not be part of 1.0.
2. **Code.** The walk flow is clean: typed models, one API client, a tested
   `WalkSession`, a contract test shared by both repositories, a style guard.
   Not gated: the older free-record flow in the app and eight unused public
   API fields on the server. Admin tools are already gated. One backend test
   depends on the calendar and fails since today, which blocks deploys.
3. **Deploy.** Not smooth yet. Everything from October sits on unmerged
   branches; production still runs the April backend. The deploy has no HTTPS
   setup in the repository, no rollback and manual server steps. The code
   organisation itself is good.
4. **Three days.** Feasible for "every P0 fixed, backend deployed, both apps
   submitted", if the Day-0 decisions are made today and the first device
   build on Day 1 works. iOS can be live about a day or two later. Android
   production can take two more weeks if the Play account is a new personal
   account. English UI is not part of the three days.
5. **Walking flow.** It works end to end and resumes correctly, but the walk
   screen is not built for walking: the main action sits at the top in a
   secondary style, map buttons are 44 dp, pause is an unlabeled icon, nothing
   says where the next stop is, a stop counts only within 20 m with no manual
   check-in, a 15-minute countdown swaps tasks, one photo can trigger two
   dialogs, and thin grey text is hard to read outdoors.
6. **Product.** The idea is distinctive (a generated walk with photo tasks and
   a story), but the "route" is not navigable, AI texts come back in English
   inside a Chinese app, there is no English UI for international travellers,
   nothing can be shared, nothing is measured, and two store rules for AI apps
   are not met yet (consent before sending data to AI; in-app reporting).

## 2. Where things stand

| | App (`city_walk`) | Backend (`mambo_backend`) |
|---|---|---|
| Newest code | `improve/stabilize-and-restyle` (pushed), `main` from 2026-09-11 | `improve/stabilize` (pushed), `main` from 2026-04-11, which is what production runs |
| Checks | analyze clean, 145 tests pass | ruff clean, 60 pass, 1 fails (`test_log_day` hard-codes 2026-10-28) |
| Built on a phone | never since the AGP 9.1 / Kotlin 2.4 / plugin upgrades; `Podfile.lock` missing | deploy needs Python 3.11, a gunicorn unit and `SUPABASE_JWT_SECRET` on the server |
| Store blockers | `com.example.mambo`, debug-key signing, no account deletion, no legal links, background-location permission, no AI consent, no in-app report | account deletion endpoint, report endpoint |

## 3. Services for a worldwide launch

| Service | Used for | Verdict | Why | Work |
|---|---|---|---|---|
| Google Maps SDK (app) | the maps | Keep | Mobile map loads are free; official Flutter plugin. Blocked in mainland China. | Restrict both keys (Day 0) |
| Google Places + Geocoding (server) | finding stops, addresses | Keep Google, change API | The server uses the legacy Places API, which Google froze on 2025-03-01 and which cannot be enabled on new Cloud projects. Photo URLs carry the server key (`google_maps_service.py:71-76`) and reach every app. `location`+`radius` only bias results, so stops can be kilometres away. | B06 |
| Supabase Auth | sign-in | Keep, configure | Works worldwide, but ISPs blocked `supabase.co` in the UAE (18 days, 2025-09), Yemen (2026-02) and India (2026-02/03). The built-in mail sender only reaches project members (about 2 mails an hour), so real sign-ups cannot be confirmed without custom SMTP. | Day 0 console; 027 |
| Cloudinary | photo upload and delivery | Keep for 1.0 | Global CDN, URL transforms for thumbnails. The unsigned preset compiled into the app lets anyone upload. | B10, 020 |
| ImgBB | nothing | Remove | No code uses it; the key is still in a local `.env` and in public git history. | Revoke (Day 0) |
| DashScope / Qwen (Alibaba Cloud, international) | tasks, photo checks, stories, reflections | Keep | Works worldwide and is also the natural provider for a China edition. Prompts force English output (`tasks.py:14`). | B08 |
| OpenAI-compatible endpoint | walk planning (`gpt-5.4`), scrapbook images | Change the setup | OpenAI blocks API traffic from mainland China, Hong Kong and Macau. The code is written for a proxy (`generate_image_vectorengine`, `max_tokens` fallback). GPT-5.4 is a large reasoning model; the app warns of a two-minute wait. | B07, D13, D14 |
| MongoDB | data | Keep | No indexes at all; every 10-second route upload scans a collection. | B04, Day 0 backups |
| EC2 + SSH deploy | API hosting | Keep for 1.0, harden | Simple and known; needs HTTPS, rollback and a region outside Hong Kong. | B09 |
| Crash reporting | — | Add Sentry | Nobody sees crashes or server errors today. | 003, 025, B13 |

**Mainland China.** Not in 1.0 (D11). A China edition needs: an ICP filing
tied to a Chinese entity and mainland hosting (App Store Connect checks the
number for the China storefront), a generative-AI filing for the AI features,
AMap instead of Google Maps and Places (with GCJ-02 coordinates), a
China-reachable sign-in (phone OTP), China-hosted storage, Qwen in the Beijing
region, and the Chinese Android stores. Most of that is paperwork measured in
weeks. Seams that make it cheaper later already exist or are added by the
cards: `GeoPoint` instead of map types, Places isolated in
`google_maps_service.py`, a model-provider switch (B07), provider-neutral
signed uploads (B10), a vendor-neutral error reporter (003). Missing: one map
widget for the whole app (five screens build `GoogleMap` directly).

## 4. Code cleanliness and legacy

- **Clean:** `ApiClient` (one place for token, timeout, errors);
  `GraphQLOperations` with variables only and an exported contract;
  typed models with tolerant parsing; `WalkSession` with unit tests; theme
  tokens and a style-rule test; backend split into `api/`, `llm/`, `models/`,
  `services/`, ownership checks on every resolver, generic error masking.
- **Legacy, not gated (app):** the free-record flow (`quick_start_map_page.dart`
  695 lines, `features/home/log/`, `log_service.dart`,
  `scrapbook_quota_service.dart` with a client-side `admin@mambo.com`
  bypass). It is a second product with its own tracking pipeline and the
  most expensive AI call. → hide it for 1.0 (019), move it to
  `features/log/` (034).
- **Legacy, not gated (server):** `inProgressWalk`, `logTracking`,
  `addImageToTask`, `removeImageFromTask`, `createLocationPoint`,
  `removeFavoriteLocation`, `addLog`, `generateReflectionQuestions` are public
  and unused by the app. → B11, with a test that fails when a new unused
  public field appears.
- **Gated correctly:** admin pages, GraphiQL and prompt testers
  (`ADMIN_PAGES=1` plus password); admin GraphQL fields (`require_admin`).
- **Smaller debt:** `AZURE_OPENAI_*` variables that point at DashScope; an empty
  `map_generator/` directory left on disk; graphene 2 is unmaintained (upgrade
  after 1.0); tutorial PNGs of 8.4 MB in English (023).

## 5. Deployability and organisation

- Production deploys from `main` on push, after the tests. Today the tests
  fail (B03), and `main` lacks six months of fixes.
- The deploy rsyncs over the live directory and restarts; a failed health
  check leaves the broken code running. HTTPS and the systemd unit are not in
  the repository. B09 adds release directories with automatic rollback, a
  unit template, the Caddy (HTTPS) configuration and a runbook.
- `gunicorn` has 16 threads; one slow walk generation holds a thread for up to
  a minute. B09 raises threads; B07 makes generation fast; B05 caps abuse.
- App: CI runs analyze, tests and an Android debug build. Release builds are
  not checked (008); signing and identifiers wait for decisions (005, D3, D9).
- Organisation: clear layers, `AGENTS.md` rules, task cards, a contract
  test across the two repositories. The contract copy between repositories is
  manual; the boards describe the sync step.

## 6. Can it be in production in three days?

| Condition | Why it matters |
|---|---|
| D2, D3, D8, D9, D12, D13, D15 answered on Day 0 | Identifiers, signing and legal URLs block store work; D13/D15 change what gets built |
| Integration branch builds on a phone on Day 0-1 | It never has; native failures found on Day 3 would sink the plan |
| 4-6 Codex agents in parallel, Claude reviewing the same day | 25 P0 cards: 16 in the app, 9 in the backend |
| Server prepared on Day 2 (domain, HTTPS, Python 3.11) | Deploy day must only merge and verify |
| Store accounts ready | A new personal Play account needs a 14-day closed test with 12 testers |

Expected outcome: Day 3 submission on both stores; iOS live around Day 4-5;
Android production on Day 3-10 for an organisation account, around Day 17 for
a new personal account. English UI, offline route upload, the share card and
analytics follow in the week after.

## 7. The walk session: flow and touch targets

| Finding | Where | Effect | Card |
|---|---|---|---|
| Main action ("添加任务照片") is an outlined button in the top panel | `walk_panels.dart:148-158` | Hardest place to reach with a thumb, looks secondary | 014, 015 |
| Map buttons 44 × 44; pause is an icon-only button | `walk_panels.dart:293`, `walk_map_page.dart:630` | Below Android's 48 dp; unclear critical action | 014, 015 |
| No next stop, direction or navigation; stops unnumbered | `walk_map_page.dart:542-595` | The "route" cannot be followed | 013, 014, 015, 016, 022 |
| Reach radius 20 m, no manual check-in; GPS accuracy ignored | `walk_session.dart:44`, `walk_map_page.dart:217-230` | Stops missed among tall buildings; distance grows while standing | 013, 015 |
| 15-minute task countdown that swaps the task | `walk_session.dart:47-48`, `:150-163` | Pressure that contradicts "慢慢走，慢慢看" | 015 |
| Accepted photo → verdict dialog, then "任务完成" dialog | `walk_map_page.dart:292-318` | Two modal dialogs while walking | 015 |
| Text weight 300, 12-15 sp, grey | `app_theme.dart` text theme | Faint in sunlight | 014 (w400 for walk labels) |
| Panels cover the Google logo | `walk_map_page.dart:542` (no `padding`) | Maps terms require the logo | 015 |
| Location permission never checked on the walk page | `walk_map_page.dart:71-124` | A resumed walk can record nothing, silently | 010 |
| AI task and verdict texts in English | `tasks.py:14`, `walk_summary.py` | Mixed languages on one screen | B07, B08 |
| Photos compressed to 128 KB | `image_compressor.dart:29` | Soft images in the summary | 015 |

Target for the walk screen: the primary action is a 56 dp full-width button in
the bottom third; every other control is at least 48 dp with a text label;
key information uses weight 400 and at least 15 sp in ink colour; nothing
overflows at 360 × 640 with the text scaled 1.3×; one dialog at most per
action.

## 8. Does it meet its users' needs?

Target users (from `product-ux-marketing-analysis.md`): overseas Chinese
travellers, international independent travellers, and people living in a new
city (the retention anchor).

| Need | Today | After the P0 cards | Later |
|---|---|---|---|
| A walk near me that fits my time | Generated, but 10+ stops whatever the duration, slow | Duration-sized, nearby, real places, fast (B06, B07) | Route library per city |
| Know where to go | Markers only | Next stop, distance, one-tap directions, check-in (013-016) | Route line on the map |
| Content in my language | Chinese UI, English AI texts | All Chinese (B07, B08) | English and Traditional Chinese (028-032) |
| Calm exploration | Countdown and auto-swap | No countdown (015) | Tasks tied to each stop |
| Something to keep and share | Story and photos in the app | (same) | Share card (033), public route page |
| Trust and safety | No way to flag a wrong or unsafe place | Report button (018) | Night-time hints, place feedback loop |
| Reasons to come back | None | (same) | Saved walks, "walk again", weekly suggestion |

Key improvements, in order: make the route navigable; fast, nearby, real
places; one language end to end, then English; calm tasks; a shareable result;
measure the funnel (024) before adding features.

## 9. Sources (checked 2026-10-29)

- Google, Places API legacy status and migration:
  <https://developers.google.com/maps/legacy>,
  <https://developers.google.com/maps/documentation/places/web-service/migrate-overview>
- Google Maps Platform pricing: <https://developers.google.com/maps/billing-and-pricing/pricing>
- Supabase, regional network blocks (UAE, Yemen, India):
  <https://supabase.com/blog/navigating-regional-network-blocks>;
  TechCrunch on India: <https://www.techcrunch.com/2026/02/27/india-disrupts-access-to-popular-developer-platform-supabase-with-blocking-order/>
- Supabase built-in SMTP limits (third-party guide):
  <https://developers.brevo.com/docs/supabase-smtp-integration.md>
- OpenAI blocking mainland China, Hong Kong and Macau:
  <https://www.theregister.com/2024/06/25/openai_unsupported_countries/>,
  <https://scmp.com/tech/policy/article/3267971/tech-war-openai-further-block-access-mainland-china-hong-kong-based-developers>
- GPT-5.4: <https://en.wikipedia.org/wiki/GPT-5.4>
- Apple guideline 5.1.2(i), third-party AI consent:
  <https://techcrunch.com/2025/11/13/apples-new-app-review-guidelines-clamp-down-on-apps-sharing-personal-data-with-third-party-ai>
- App Store Connect, China mainland filing numbers:
  <https://developer.apple.com/help/app-store-connect/reference/app-information/>,
  <https://developer.apple.com/forums/thread/743661>
- China's generative-AI filing (via Apple Intelligence's filing):
  <https://www.iclarified.com/101474/apple-intelligence-registered-for-public-use-in-china>
- Google Play, AI-generated content (in-app reporting):
  <https://support.google.com/googleplay/android-developer/answer/13985936>
- Google Play, foreground service declarations:
  <https://support.google.com/googleplay/android-developer/answer/13392821>
