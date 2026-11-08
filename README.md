# Mambo 漫步

**A city-walk app for iPhone and Android.** Flutter package name: `mambo`.

Pick a few interests and how long you have. Mambo generates a walk around the
street you're standing on, gives you small photo tasks along the way and writes
the story of your walk when you finish.

<p align="center">
  <img src="docs/images/feature-graphic.png" width="720" alt="Mambo 漫步: 给不想做功课的旅人，一场此刻生成的城市漫步" />
</p>

<p align="center">
  <img src="docs/images/screenshot-01-setup.png" width="240" alt="Pick interests and a duration" />
  <img src="docs/images/screenshot-05-summary.png" width="240" alt="The summary of a finished walk with its story" />
  <img src="docs/images/screenshot-06-history.png" width="240" alt="Every finished walk in the history tab" />
</p>

The UI is Simplified Chinese, hard-coded; localisation is planned (cards
028-032). The walks are written for Hong Kong. The images above are the README
previews of the store screenshots (see [Store screenshots](#store-screenshots)).

## How a walk works

1. **Setup.** Choose keywords (street culture, food, landmarks, nature, ...)
   and a duration of 10-120 minutes, then tap **生成路线**. Custom keywords can
   be separated with commas or 、. Before the first walk, the app asks for
   consent to send location and photos to the AI services.
2. **Preview.** The generated walk appears on Google Maps with every stop
   selected. Drop the ones that are wrong for this afternoon before you start.
3. **Walk.** Live location; a stop counts as reached within about 35 m. Photo
   tasks are checked by AI, and **这里让我惊喜** marks a spot you want to
   keep. Each stop opens walking directions in the maps app. A generated place
   or task can be reported.
4. **Summary.** Stops, tasks, time, distance, the path you walked, an AI-written
   story (kept on the device once written) and your photos. The story can be
   reported too.

Leaving a walk pauses it, and closing the app mid-walk does not lose it: Home
shows an in-progress card to resume or give up.

Bottom navigation: **我的** (profile, sign-out, account deletion) · **漫步** ·
**历史**.

A free-form record flow (photos through the day, an evening review, a
scrapbook cover) exists but is switched off for 1.0 with `ENABLE_FREE_RECORD`.

An old build whose version is below the backend's `minimumVersion` is asked to
update before it starts.

## Prerequisites

- [Flutter](https://docs.flutter.dev/get-started/install) **3.47.6** (Dart
  3.13). CI pins this version.
- Xcode (iOS 15+) on macOS, or Android Studio / an Android device or emulator.
- Google Maps keys with the Maps SDK for Android and iOS enabled.
- The publishable (anon) key of the production Supabase project.

The backend is [`mambo_backend`](https://github.com/lvyin1122/mambo_backend):
GraphQL at `https://54.248.65.240/graphql`, Supabase for sign-in, Cloudinary
for photos. The app needs none of their secrets.

## Setup

```bash
git clone https://github.com/lvyin1122/city_walk.git
cd city_walk
flutter pub get
```

### 1. Build-time configuration

```bash
cp .env.example .env
```

`.env.example` already holds the production endpoint and Supabase URL. Paste
the anon key into `SUPABASE_ANON_KEY` (Supabase Dashboard → Project Settings →
API keys; never the `service_role` key). If your `.env` is older, delete its
`IMGBB_API_KEY`, `GOOGLE_MAPS_API_KEY` and `CLOUDINARY_*` lines: they are no
longer used.

`.env` is git-ignored, and `.env.example` is the only env file in the
repository. The values are passed to the build with `--dart-define-from-file`
and compiled into the app, so anyone who has the app can read them. Put only
values there that are safe to publish.

### 2. Google Maps keys

The keys live in two git-ignored files. Copy the examples and fill them in:

| Platform | Copy | To |
| --- | --- | --- |
| Android | `android/secrets.properties.example` | `android/secrets.properties` |
| iOS | `ios/Flutter/Secrets.example.xcconfig` | `ios/Flutter/Secrets.xcconfig` |

Restrict each key to this app's package name or bundle identifier in the Google
Cloud console (iOS: `app.mambo`). The files are not in git, so every new clone
needs them. Without a key, Android shows a blank map and iOS crashes when the
first map opens (`GMSServices checkServicePreconditions`); an iOS debug build
stops at launch with a message that names the missing file.

### 3. Run

```bash
flutter run --dart-define-from-file=.env
```

Without `--dart-define-from-file` the app starts on a screen listing the
missing configuration.

On iOS, run `pod install` in `ios/` after cloning or after changing
dependencies. `ios/Podfile.lock` is not in the repository yet: generate it on
macOS and commit it.

```bash
flutter analyze   # "No issues found!"
flutter test
```

On a Linux machine behind a proxy, `flutter test` needs localhost to bypass it:
`NO_PROXY=127.0.0.1,localhost,::1 no_proxy=127.0.0.1,localhost,::1 flutter test`.

## Backend contract

Every GraphQL document the app sends is in
`lib/services/graphql_operations.dart` and is exported to
`test/contract/operations.json` (31 operations). The backend keeps a copy and
validates it against its schema. After changing an operation:

```bash
UPDATE_CONTRACT=1 flutter test test/contract
cp test/contract/operations.json ../mambo_backend/tests/app_operations.json
```

The full integration guide (auth, errors, quotas, data model, call order) is
`mambo_backend/docs/client-api-integration.md`.

- Every request carries the signed-in user's Supabase access token as
  `Authorization: Bearer ...`. The backend verifies it; after an HTTP 401 the
  app refreshes the session once and retries. Build with
  `--dart-define=API_SEND_AUTH_HEADER=false` only against a local backend
  started with `AUTH_DISABLED=1`.
- Photos are uploaded straight to Cloudinary with a signature the backend
  issues (`createUploadSignature`). There is no upload preset to configure in
  the app.
- Requests that wait for an AI model time out after 240 s; everything else
  after 30 s.

## Permissions

- **Location, while using the app.** Plans the walk and records the route.
  While a walk is being recorded, recording continues with the screen locked
  (iOS background mode, Android foreground service).
- **Camera.** Photos for tasks and surprise spots.
- **Photo library.** Picks photos and saves the ones you take.

iOS: `ios/Runner/Info.plist`. Android: `android/app/src/main/AndroidManifest.xml`.

## Store screenshots

`tool/store_screenshots/` renders framed screenshots with captions in 简体中文
and English for the App Store (1320×2868), Google Play (1080×1920 and the
1024×500 feature graphic) and social media (4:5, 3:4, 9:16):

```bash
python3 tool/store_screenshots/prepare_fonts.py   # once; needs fonttools
tool/store_screenshots/capture_ios.sh             # macOS: map screens from the simulator
flutter test tool/store_screenshots               # writes build/store/
```

The setup, summary and history screens are rendered from the app's widgets
with demo data. The map screens (preview, walk, photo check) come from the iOS
simulator. See `tool/store_screenshots/README.md`.

## Project layout

```
lib/
  main.dart               start-up checks, update prompt, auth wrapper
  app/                    env.dart (build config), links, app version, error reporting
  core/
    api/                  ApiClient (token, refresh, timeouts, errors), ApiException
    geo/                  GeoPoint, distance, walking time, route order
    map/                  GeoPoint <-> LatLng, camera fitting, directions links
    media/                photo picking, image compression
    format/               durations, distances, dates
  features/
    auth/                 sign in, sign up
    account/              account deletion
    consent/              consent before sending data to AI
    report/               report a generated place, task or story
    home/                 home, setup form, history, profile, tutorial, free record
    walk/                 domain models, repository, session, preview, live map, summary
  services/               GraphQL operations and service, records, auth, Cloudinary
  theme/                  tokens.dart and app_theme.dart (the Japanese Fresh style)
  widgets/                botanical drawings, paper background, cards
test/                     unit and widget tests, mirroring lib/; test/contract/
tool/store_screenshots/   store and marketing screenshots
tasks/                    task cards and the board (tasks/README.md)
docs/                     product, UX, marketing and technical reviews (Traditional Chinese)
```

`AGENTS.md` holds the conventions and how work is organised; `CLAUDE.md`
imports it.

## CI and secrets

- `.github/workflows/ci.yml` runs on pushes to `main` and on pull requests. It
  fails if a secret file is tracked, then runs analyze, the tests and an
  Android debug build (with `.env.example`, compile check only).
- `.github/workflows/dart.yml` builds an unsigned iOS IPA on demand. It needs
  the `APP_ENV` and `MAPS_API_KEY_IOS` repository secrets, which are not set
  yet.
- Never commit `.env`, `android/secrets.properties`, `android/key.properties`,
  `ios/Flutter/Secrets.xcconfig` or a keystore. They are git-ignored, CI
  rejects them, and a local pre-commit hook (`.git/hooks/pre-commit`, not
  versioned) blocks them on the maintainer's machine.

## Stack

Flutter · Dart · Google Maps · Supabase Auth · GraphQL · Cloudinary ·
shared_preferences · audioplayers

## Notes

- iOS ships as MamboWalk with the bundle identifier `app.mambo`, the app in
  App Store Connect. The Android application ID `com.example.mambo` is still a
  placeholder (decision D3 in `tasks/README.md`); choose the real one before
  the first Play upload, because it cannot change afterwards.
- 1.0 targets iPhone only on iOS (card 011).
- Only iOS and Android are supported; the web and desktop folders were
  removed.
