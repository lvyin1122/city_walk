# 002: Time limits on waits that can hang

- **Status:** draft
- **Priority:** P0
- **Owner:** Codex
- **Base branch:** chore/stabilize-foundation
- **Branch:** codex/002-bound-hanging-waits
- **Waiting for:** approval

## Goal

No spinner lasts forever. Getting the position, uploading a photo and
downloading the scrapbook image each fail within a known time with a readable
message.

## Background

Backend calls already time out through `ApiClient`. Three other waits do not:

- `lib/features/home/home_page.dart:324`, `await location.getLocation()` in
  `_currentPosition()`. Indoors the plugin can wait indefinitely, and the
  "生成路线" spinner never stops. (`quick_start_map_page.dart` already uses
  `.timeout(...)` at lines 63 and 189; follow the same pattern.)
- `lib/services/cloudinary_service.dart:28`, `await request.send()` and the
  response read after it have no time limit.
- `lib/features/home/log/log_review_result_page.dart:392`,
  `await http.get(...)` for the scrapbook image has no time limit.

Cloudinary and downloading an image by URL are third-party calls, so plain
`http` is allowed there (see `AGENTS.md`), but always with a timeout.

## Files or directories involved

- `lib/features/home/home_page.dart`
- `lib/services/cloudinary_service.dart`
- `lib/features/home/log/log_review_result_page.dart`
- `test/services/cloudinary_service_test.dart` (new)

## Implementation requirements

1. `home_page.dart`, `_currentPosition()`: add
   `.timeout(const Duration(seconds: 15))` to `location.getLocation()`. On a
   `TimeoutException`, call
   `_showMessage('暂时无法获取你的位置，请到开阔处再试一次。', isError: true)`
   and return null.
2. `CloudinaryService.uploadImage(File imageFile, {http.Client? client,
   Duration timeout = const Duration(seconds: 60)})`:
   - Send the request with `client.send(request)` when a client is given;
     otherwise create an `http.Client` and close it when done (also after a
     failure). Never close a client that was passed in.
   - The timeout covers both sending the request and reading the response.
   - On a timeout return null, as for any other failure, and `debugPrint`
     the reason.
3. `log_review_result_page.dart:392`: add
   `.timeout(const Duration(seconds: 30))` to `http.get`. On a timeout,
   `_fetchImageBytes` returns null, so the existing failure path handles it.
4. Check `mounted` after every new `await` before using `context` or calling
   `setState`.

## Restrictions

- Change only the four files above. Do not touch `walk_map_page.dart`
  (card 001 owns it).
- Public signatures change only by the optional parameters in requirement 2.
- No new dependencies. No UI text other than the string in requirement 1.

## Tests to add or update

`test/services/cloudinary_service_test.dart`, using `MockClient` from
`package:http/testing.dart` and a small file in a temporary directory:

- a 200 response with `{"secure_url": "https://example.com/a.jpg"}` returns
  that URL;
- a 400 response returns null;
- a client that never responds
  (`MockClient((_) => Completer<http.Response>().future)`) returns null
  within a short test timeout (for example 100 ms).

## Acceptance criteria

- `grep -rn "getLocation()" lib` shows a `.timeout(` on every call.
- The three upload outcomes are covered by tests.
- `git diff --stat chore/stabilize-foundation` lists only the four files.

## Commands that must pass

```sh
flutter pub get
flutter analyze   # "No issues found!"
flutter test      # all pass
```

## Information Codex must report after completion

The report format in `AGENTS.md`, plus a list of every wait that got a time
limit, with its file:line and the limit.
