# 012: API client: language header and limit messages

- **Status:** in review (approved and implemented in the maintainer-authorized P0 batch 2026-10-30; CI/device acceptance pending)
- **Priority:** P0
- **Owner:** Codex
- **Base branch:** improve/stabilize-and-restyle
- **Branch:** codex/012-api-language-and-limits
- **Waiting for:** nothing (pairs with backend cards B05 and B07)

## Goal

Every backend request tells the server the app's language, and when the server
refuses a request because of a usage limit the user reads a clear Chinese
sentence instead of "服务处理请求时出错".

## Background

- `lib/core/api/api_client.dart`, `execute` (line ~56-108), builds the headers
  at line ~62 (`Content-Type` and, when signed in, `Authorization`). The
  backend (card B07) reads the language from an `X-App-Language` header and
  uses it for walk titles, stop names, tasks and stories. The UI is Simplified
  Chinese until localisation (card 028), so the value is `zh-Hans` for now.
- The backend (card B05) limits AI operations per user and answers with a
  GraphQL error whose `extensions.code` is `RATE_LIMITED` (too many in a
  minute) or `QUOTA_EXCEEDED` (daily limit). Card B11 adds `NOT_AVAILABLE`
  for retired operations. Today only `UNAUTHENTICATED` is recognised
  (`_isUnauthenticated`, line ~131-140); everything else becomes
  `ApiGraphQLException` with a generic message.
- `lib/core/api/api_exception.dart` defines the sealed `ApiException`
  hierarchy; `toString()` returns `userMessage`, which pages show, e.g.
  `'生成步行路线失败：${e.userMessage}'` (`home_page.dart:341`).

## Files or directories involved

- `lib/core/api/api_client.dart`
- `lib/core/api/api_exception.dart`
- `test/core/api/api_client_test.dart`

## Implementation requirements

1. `api_client.dart`:
   - `typedef LanguageTagProvider = String Function();`
   - constructor parameter `this.languageTag = defaultLanguageTag`, where
     `static String defaultLanguageTag() => 'zh-Hans';`
   - every request carries `X-App-Language: <languageTag()>`.
   - after decoding, read the `extensions.code` of every error: if any is
     `RATE_LIMITED` throw `ApiRateLimitException(<joined messages>, daily: false)`;
     if any is `QUOTA_EXCEEDED` throw `ApiRateLimitException(..., daily: true)`.
     Keep the existing order: the `UNAUTHENTICATED` check comes first.
2. `api_exception.dart`: `final class ApiRateLimitException extends ApiException`
   with `final bool daily;` and
   `userMessage`: `daily ? '今天的次数已经用完了，明天再来吧' : '操作太频繁了，请稍等一分钟再试'`.
3. If any `switch` over `ApiException` in `lib/` stops compiling, stop and
   report (do not change other files).

## Restrictions

- Change only the files above. No UI text other than the two strings above.
- Do not change timeouts or the 401 handling.

## Tests to add or update

`test/core/api/api_client_test.dart` (uses `MockClient`):

- every request has `X-App-Language: zh-Hans`; a client built with
  `languageTag: () => 'en'` sends `en`;
- an error with `extensions.code` `RATE_LIMITED` → `ApiRateLimitException`,
  `daily == false`, `userMessage` as above;
- `QUOTA_EXCEEDED` → `daily == true`;
- `UNAUTHENTICATED` still → `ApiHttpException` with status 401.

## Acceptance criteria

- `grep -n "X-App-Language" lib/core/api/api_client.dart` prints one line.

## Commands that must pass

```sh
flutter pub get
flutter analyze   # "No issues found!"
flutter test      # all pass
```

## Information Codex must report after completion

The report format in `AGENTS.md`.
