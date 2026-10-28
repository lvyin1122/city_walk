# Mambo improvement plan: fix, connect, simplify, restyle

## Context

Two repositories live in `/home/heyu/Projects/mambo`:
- **`city_walk/`**: the Flutter app. The newest code is on branch `codex/002-bound-hanging-waits`.
- **`mambo_backend/`**: the Flask + graphene 2 + MongoDB GraphQL API, on `main`.

You asked for three things:
1. Find errors, make both sides run and talk to each other cleanly, and add tests.
2. Simplify the code and how it is organised.
3. Restyle the app as "Japanese Fresh" (日系清新风).

Your decisions:
- I implement the changes myself, not as Codex task cards.
- The backend keeps graphene 2 on a pinned Python 3.11.
- The backend starts checking the Supabase login token now.
- The backend's dev/admin HTML pages are turned off in production but not restyled.

What the audit found. The backend has no tests and no authentication. Its Docker setup cannot serve traffic. Some GraphQL fields are always null, and some mutations always crash. On the app side, the code is reasonably organised and tested, but the theme is a single purple seed colour with inline styles everywhere.

**Doc first:** step 0 of the work is to commit this plan as `docs/improvement-plan.md` in both repos, before any code changes. Each phase then ends with a short changelog entry in that file.

---

## Phase 0: Branches and baseline

- **city_walk:**
  - Create `improve/stabilize-and-restyle` from `codex/002-bound-hanging-waits`.
  - Cherry-pick `96f6e43` from `codex/001`, the fix that keeps a malformed stop from crashing the walk screen.
  - Merge `afa595a` (docs) from `chore/stabilize-foundation`.
  - Delete the stray untracked file named `1` after checking what it is.
- **mambo_backend:** create `improve/stabilize` from `main`.
- **Baseline:**
  - App: `NO_PROXY=127.0.0.1,localhost,::1 no_proxy=… ~/development/flutter/bin/flutter analyze && … flutter test`.
  - Backend: `uv venv -p 3.11 && uv pip install -r requirements.txt && python -c "import app"`.

## Phase 1: Backend fixes so it runs (mambo_backend)

**Run and deploy**
- Make port 8000 the only port everywhere: `app/run.py`, `Dockerfile` (`python:3.11-slim` + gunicorn), `docker-compose.yml` and `task-definition.json`.
- `debug` comes from an env var, defaulting to off.
- Use the single env name `MONGO_URI` everywhere. Compose currently uses `MONGODB_URI`.
- Add `.env.example` listing every variable that is actually read:
  - `MONGO_URI`
  - `AZURE_OPENAI_*`, which really point at DashScope; document that.
  - `DASHSCOPE_API_KEY`
  - `OPENAI_API_KEY` and `OPENAI_API_URL`
  - `GOOGLE_MAPS_API_KEY`
  - `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` and `SUPABASE_JWT_SECRET`
  - `CLOUDINARY_*`
  - `ADMIN_PAGES`
- Remove the unused `GRAPHQL_ENDPOINT` and `IMGBB_API_KEY` from the deploy workflow.
- Stop printing the Mongo URI (`app/__init__.py:34`, `app/db.py:12`) and raw LLM output (`gpt_service.py:292`).
- Set logging to INFO. `db.py` currently sets the global level to DEBUG.
- Give every external client a timeout:
  - OpenAI/Azure clients: 60s, `max_retries=1`
  - `googlemaps.Client`: 10s
  - `map_generator` HTTP calls
- Fix the README run command to `python -m app.run`.

**GraphQL bugs**

| Problem | Fix |
|---|---|
| `TaskType.createdTime`, `photosRequired` and `photosFulfilled` are always null (`schema.py:42-47`) | Add resolvers that read `created_time`, `photos_required` and `photos_fulfilled` |
| `inProgressWalk` calls a method that doesn't exist (`schema.py:236`) | Call `get_latest_in_progress_walk` |
| `verifyTaskWithGPT` requires latitude and longitude (`schema.py:675`), but the app leaves them out when it has no GPS fix | Make them optional |
| `updateWalkStats` and `selectLocations` return partial walks (`schema.py:727`, `766`) | Build every `WalkType` in one helper, `walk_to_type(doc)`, which also removes about 15 copy-pasted blocks |
| Optional arguments with no Python default raise `TypeError` (`addFavoriteLocation.photoUrl`, `selectLocations.locationIndexes`) | Add `=None` defaults |
| `collectLocation` raises `KeyError` on older walks that have no `index` (`models/walk.py:151`) | Fall back to the stop's position in the list |
| A bad id makes `ObjectId(...)` crash | One `parse_object_id()` helper that raises a clear GraphQL error |
| A missing walk crashes `generateTaskWithGPT` and `selectLocations` | Return clear errors |
| A GPT failure is saved as a task and counted in `tasks_total` | Don't save it; return the error |
| `removeImageFromTask` filters on a string `_id` and never removes anything (`walk.py:282`) | Filter on `ObjectId` |
| `createLocationPoint` never saves its new point (`location_tracking.py`) | Write the point to the database |
| `generate_walk` sends `max_tokens` and `temperature` to a GPT-5-family model (`gpt_service.py:844`) | Send `max_completion_tokens` and no temperature, unless `OPENAI_API_URL` points at a compatible proxy (keep a fallback) |
| Error masking in image calls (`gpt_service.py:1760`, `1940`) | Let the parsed API message through |
| Operator-precedence bug in the `name` expression (`supabase_service.py:38`) | Add the missing parentheses |
| `createdAt` is sent as `str(datetime)` | Send ISO 8601 in UTC with a `Z` suffix. The app already parses ISO, so change `domain/walk.dart` to `.toLocal()` |

**Authentication (B-01)**
- Add `app/auth.py`: verify `Authorization: Bearer <jwt>` with PyJWT.
  - Use HS256 with `SUPABASE_JWT_SECRET` and audience `authenticated`.
  - Fall back to JWKS if the project uses asymmetric keys.
- Put the verified `user_id` in the GraphQL context via `GraphQLView.as_view(get_context=...)`.
- Add a `require_user(info)` helper. Every resolver that takes `userId` checks that it matches the token, or uses the token's id when `userId` is left out.
- Every `walkId`/`logId` mutation checks that the document belongs to the caller.
- `logs` without a `userId` no longer returns every user's logs.
- Turn GraphiQL off unless `ADMIN_PAGES=1`.
- Restrict CORS to an env allow-list. The mobile app is not affected by CORS.
- `AUTH_DISABLED=1` lets local development run without tokens. Startup refuses that setting when `FLASK_ENV=production`.

**Dev pages**
- Register the HTML pages and the `/generate-summary`, `/generate-task` and `/api/test-reflection-prompts` routes only when `ADMIN_PAGES=1`.
- Delete the unused `/generate-map` route.

## Phase 2: Backend reorganisation (no API changes)

- Split `app/schema.py` (1,365 lines) into `app/graphql/`:
  - `types.py`
  - `walk_queries.py` and `walk_mutations.py`
  - `log_mutations.py`
  - `schema.py`, which assembles them
  - `converters.py`, holding `walk_to_type` and `log_to_type` (the latter merges `schema.py:407-452` with `1071-1114`)
- Split `app/gpt/gpt_service.py` (1,979 lines):
  - `app/llm/client.py`: one cached client factory and one base-URL helper, replacing three copies.
  - `app/llm/walk_generation.py`, `task_generation.py`, `reflection.py` and `images.py`.
  - `app/llm/prompts/`: prompt text kept apart from code.
- Delete dead code, about 900 lines:
  - In `gpt_service.py`: `process_request`, `_city_walk_planner`, `_task_matcher`, `_text_analysis`, `generate_itinerary`, `generate_photo_task`, `optimize_route`, `calculate_distance` and the chat history.
  - The `Walk`/`Location`/`Task` classes.
  - Unused Supabase and Maps helpers.
  - Unused imports.
  - The `map_generator/` folder, once confirmed unused (only `/generate-map` used it).
- Remove the log-text builder duplicated three times.
- Reuse one `SupabaseService` per request and cache user lookups. This removes the N+1 Admin API calls.
- Requirements:
  - Pin every version.
  - Drop `folium`, `matplotlib` and `numpy` if `map_generator` goes.
  - Add `PyJWT` and `gunicorn`.
  - Put `pytest`, `mongomock` and `ruff` in a new `requirements-dev.txt`.

## Phase 3: Backend tests and CI

- Add `tests/` with pytest and `mongomock`, patching the `mongo.db` used by the app factory.
- LLM, Maps, Supabase and Cloudinary are faked with monkeypatch.
- `test_contract.py` runs every one of the 25 operations the app sends, copied from `graphql_service.dart` / `log_service.dart`, against the schema. It checks that each operation validates and that each selected field resolves. This is the guard that keeps the app and backend connected.
- `test_auth.py`:
  - A missing, invalid or expired token is rejected.
  - A `userId` that doesn't match the token is rejected.
  - Another user's `walkId` is rejected.
  - `AUTH_DISABLED` works only outside production.
- `test_walk_flow.py`: generate a walk (stubbed LLM), select stops, start, generate a task, verify it with and without coordinates, collect a stop, update stats and complete. Asserts the task fields are not null.
- `test_log_flow.py`: add a log entry, get the log for review, update the answers.
- Add a `.github/workflows/test.yml` job on Python 3.11 that runs `ruff check` and `pytest`. `deploy.yml` waits for it to pass.

## Phase 4: App fixes and connection (city_walk)

- `graphql_service.dart:153`: keep leaving out latitude and longitude when there is no fix. The backend now accepts that.
- `walk_map_page.dart:1875`: null-safe read of `['walk']['favoriteLocations']`.
- `domain/walk.dart:80`: parse `createdAt` as UTC and convert it to local time.
- Add a `test/contract/` test that keeps every operation string in one list. The backend's `test_contract.py` reads the same list from `city_walk/test/contract/operations.json`, generated by a small Dart test, so both sides fail if they drift apart.
- Add tests:
  - `WalkTask` parsing with `photosRequired` and `photosFulfilled`.
  - `createdAt` time zone handling.
  - The verify call building its variables without coordinates.
- Update `AGENTS.md` "Known debt": B-01 done, the backend repo is available, and the new backend run commands.

## Phase 5: Simplify the app (behaviour unchanged)

- `walk_map_page.dart` (1,904 lines, reads raw JSON, owns four timers). Step towards the planned rebuild, without a full rewrite:
  - Move parsing onto the typed `Walk` and `WalkTask` models (`features/walk/domain/walk.dart`) through `WalkRepository`.
  - Pull out `WalkSessionController` (timers, stats, tracking upload) as a plain class with unit tests.
  - Split the dialogs and bottom panels into `features/walk/widgets/`.
  - Afterwards remove its exemption from `avoid_dynamic_calls`.
- Move the remaining raw-map handling in `graphql_service.dart` (840 lines) into the repositories. Turn the walk operations' string building into GraphQL variables, matching the log operations.
- Split `log_review_page.dart` (896 lines) and `walk_summary.dart` (662 lines) into section widgets.
- Delete `app_text_styles.dart` and `app_colors.dart` and replace them with the new theme (Phase 6).

## Phase 6: Japanese Fresh restyle (Flutter mapping of the style rules)

The style guide is written in Tailwind terms. In Flutter it becomes a design-token layer plus Material component themes, so most screens change by deleting their inline styles.

**New `lib/theme/`**
- **`tokens.dart`:**
  - Colours:
    - Rice White `#fafaf8`
    - Sky Blue `#64b5f6`
    - Mint `#98d8c8`
    - Pink `#ffb7c5`
    - Powder Blue `#b8d4e3`
    - Text `#4a5568` / `#7a8a9e` / `#b0b8c4`
    - Border `#d4d4cf`
  - Spacing: section 96–160 for the "Ma" breathing room, card padding 32–40, gaps 16/24/32/48.
  - Corner radii: 8 (lg) and 12 (xl) only.
  - Durations: 500ms with `Curves.easeInOut`.
  - Hairline: 0.5–1px at 30–40% opacity.
- **`app_theme.dart`**, which builds `ThemeData`:
  - `scaffoldBackgroundColor` is rice white.
  - The text theme uses only `FontWeight.w200` and `w300`. No bold anywhere.
  - `fontFamily` stays the platform system font (PingFang SC on iOS, Noto Sans CJK on Android, both with light weights). This avoids bundling a ~10 MB CJK font and avoids Roboto/Inter.
  - Button themes: flat with elevation 0, radius 8, a `#d4d4cf` 40% hairline border, and primary `#64b5f6` at 90% with white text. Pressed state changes opacity; no ripple splash.
  - `InputDecorationTheme`: `UnderlineInputBorder` only. Enabled `#d4d4cf`, focused `#64b5f6` at 1px. Floating labels; no fill.
  - Cards, dialogs, bottom sheets, `NavigationBar`, FAB and AppBar all have elevation 0, `shadowColor` transparent, surface tint off, and a hairline border at radius 12.
  - `SnackBar`, `Chip`, `Slider` and progress indicators use the light palette.
  - `pageTransitionsTheme` uses a slow 500ms fade.
- **`reduced_motion.dart`:** reads `MediaQuery.disableAnimations` and drops durations to zero when it is set.

**New `lib/widgets/`**
- `botanical.dart`: 3–4 line drawings (leaf sprig, ginkgo, bamboo stem, branch) painted with `CustomPainter` at stroke 0.8 in muted green or blue. No new dependency. One per major screen, placed off-centre.
- `paper_background.dart`: a faint linen texture, a cached `CustomPainter` noise pattern at low opacity.
- `fresh_card.dart`: a white card with a hairline border, used everywhere instead of nested cards.
- `curly_underline_headline.dart` becomes a hairline wave at 1px, plus an optional botanical accent.

**Screen-by-screen pass.** Replace inline `Colors.*`, bold weights, `BoxShadow`, elevation 4, radius 16/20/4 and outlined inputs with theme tokens. Add whitespace and off-centre headline placement.

| Order | Screen | Inline colours | Notes |
|---|---|---|---|
| 1 | Splash | | |
| 2 | Sign in / sign up | | Underline inputs; keep the `AuthFormLayout` overflow test passing |
| 3 | Home + walk setup | | |
| 4 | Walk preview | | |
| 5 | Walk map | 54 | Map overlays use rice-white panels at 90% opacity with a hairline border |
| 6 | Walk summary | | |
| 7 | History | | |
| 8 | Log list, detail, review, result | | |
| 9 | Profile, tutorial | | |
| 10 | `StartupErrorApp` in `main.dart` | | Gets the theme too |

Google Map markers and the route line get new colours (sky blue route, mint and pink markers). Map tiles keep the standard map, with an optional light `GoogleMap.style` JSON.

**Style guard test.** `test/theme/style_rules_test.dart`:
- Greps `lib/` for `FontWeight.bold`, `w500`–`w900`, `BoxShadow(`, `elevation: [1-9]`, `toUpperCase(`, `width: [2-9]` on borders, and any `Colors.black` background, and fails if it finds one. This turns the style's forbidden list into a CI check.
- Checks that the theme's animation durations are at least 200ms.
- Checks text contrast:
  - `#4a5568` on `#fafaf8`: about 7.4:1, passes.
  - `#7a8a9e` is only for secondary text at 14pt or larger: about 3.6:1, so the test asserts which tokens may be used for body text.
  - `#b0b8c4` is decoration only.
  - White on `#64b5f6` is about 2.3:1, which fails AA. Primary buttons therefore use text colour `#2f4a66` on sky blue (about 5:1), or white on a darker sky `#3d8fd1`. **This is the one place I'll depart from the token sheet, to meet the WCAG AA requirement in the same spec.**

Existing widget tests (`walk_setup_test`, `walk_history_card_test`, `auth_form_layout_test`) must keep passing. They check text and layout, not style.

---

## Verification

1. **Backend:**
   - `uv venv -p 3.11 && uv pip install -r requirements.txt -r requirements-dev.txt && ruff check . && pytest` all pass.
   - `docker build` succeeds (if the Docker daemon is available).
   - `python -m app.run` with a local or Atlas Mongo answers `/health` on port 8000.
   - With `ADMIN_PAGES` unset, `/walks` and GraphiQL return 404.
2. **App:** `flutter analyze` reports "No issues found!". `flutter test` passes, including the new contract, theme-guard and model tests.
3. **End to end (manual, needs your `.env` keys):**
   - Run the backend locally, then point the app at it with `GRAPHQL_ENDPOINT=http://<lan-ip>:8000/graphql flutter run --dart-define-from-file=.env`.
   - Sign in, generate a walk, start it, take a task photo (the photo counter now shows), collect a stop, finish, view the summary and history.
   - Check that a request with no token gets 401 and a request with another user's `userId` is rejected.
4. **Style check:** screenshots of each screen on a phone or emulator against the checklist (no bold, no shadows, hairline borders, underline inputs, one botanical per screen, 500ms transitions). Native and device runs are your step, because this machine has no Android SDK or Xcode.

## Commit order

One branch per repo, about one commit per bullet group, in this order:
1. Backend Phase 1, 2 and 3, each a separate commit.
2. App Phase 4.
3. App Phase 5.
4. App Phase 6, screen by screen.

Phase 1 and Phase 4 can be merged and deployed before the larger refactor and restyle.

---

## Changelog

One entry per phase as it lands.

### 2026-10-28: all phases implemented

Branches: `mambo_backend` `improve/stabilize`, `city_walk` `improve/stabilize-and-restyle`
(from `codex/002`, plus card 001's commit and the docs from `chore/stabilize-foundation`).

**Where the work differs from the plan**
- The backend GraphQL code lives in `app/api/`, not `app/graphql/`, so that it
  does not sit next to the `graphql` library name.
- Backend phases 1-3 landed as two commits (code + tests, deploy + docs).
  The schema split and the fixes touch the same lines, so splitting them would
  have meant writing the code twice.
- App phases 5 and 6 were done together screen by screen, so each screen was
  rewritten once.
- Two colours were adjusted for WCAG AA:
  - Text on sky-blue buttons is deep ink `#1F3A56`, because white is 2.3:1.
  - Small secondary text is `#6B7280`, the guide's body grey, because
    `#7A8A9E` is 3.4:1.
- Instead of the contract-file round trip described in Phase 4,
  `test/contract/operations.json` is exported by the app and copied to the
  backend as `tests/app_operations.json`. The backend test checks that the
  copy matches when both repositories sit side by side.

**Backend** (61 tests, ruff clean)
- Public schema unchanged except `verifyTaskWithGpt` latitude/longitude, which
  are now optional (diffed against `main`).
- Sign-in token verification; ownership checks on every walk and log operation.
- Admin pages behind `ADMIN_PAGES` plus a password.
- About 15 broken fields and mutations fixed (see the commit message), including
  task progress always null and duplicate log entries never detected.
- `schema.py` and `gpt_service.py` (3,300 lines) split into `app/api` and `app/llm`.
  About 900 lines of unused code and `map_generator/` removed.
- One port (8000), Python 3.11, gunicorn, timeouts on every external call, no
  secrets in logs. CI runs the tests before deploying.

**App** (145 tests, analyze clean)
- All 27 GraphQL documents in `GraphQLOperations`, with arguments sent as
  variables. A contract test is shared with the backend.
- The walk page was rebuilt on a unit-tested `WalkSession` (1,970 → about 700
  lines, no lint exemption). Card 009 is done.
- Japanese Fresh theme, tokens, botanical drawings and a paper background on
  every screen. `AppColors` and `AppTextStyles` removed.
  `test/theme/style_rules_test.dart` enforces the forbidden list and contrast.
- Walk summary and log review split into section widgets.

**Not verified here** (needs the maintainer)
- A device run on Android and iOS. Nothing native changed.
- A real end-to-end walk against the deployed backend.
- Deploying the backend:
  - Add `SUPABASE_JWT_SECRET` (and ideally `EC2_KNOWN_HOSTS`) to the repository secrets.
  - Install Python 3.11 on the server.
  - Switch `mambo.service` to gunicorn.
  - App builds that send no token stop working once this is deployed.
