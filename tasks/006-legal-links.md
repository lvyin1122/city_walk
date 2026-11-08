# 006: Privacy policy and terms links

- **Status:** blocked (approved in principle 2026-10-30; maintainer retains store deployment, identifiers/signing and legal URLs)
- **Priority:** P0
- **Owner:** Codex
- **Base branch:** improve/stabilize-and-restyle (updated 2026-10-29: the newest code is there)
- **Branch:** codex/006-legal-links
- **Waiting for:** D8 (the URLs), card 016 (`url_launcher` and `AppLinks`),
  card 017 (`AiConsent`). Revised 2026-10-29: `url_launcher` and
  `AppLinks.open` now come from card 016, and the profile gets a row to
  withdraw the AI consent of card 017.

## Goal

The privacy policy and terms can be opened from the profile page and from
the sign-up page, as both stores require.

## Background

`lib/features/home/user_profile.dart` has two rows in its `ListView`:
`'关于'` and `'退出登录'`. There is no privacy policy or terms link anywhere in
the app. Card 016 added `url_launcher` and `lib/app/links.dart` with
`AppLinks.open(Uri)` (returns false instead of throwing). Card 017 added
`AiConsent.revoke()` (`lib/features/consent/ai_consent.dart`); GDPR expects
consent to be as easy to withdraw as to give. The URLs come from D8 in
`tasks/README.md`.

## Files or directories involved

- `lib/app/links.dart`
- `lib/features/home/user_profile.dart`
- `lib/features/auth/sign_up_page.dart`
- `test/app/links_test.dart` (new)

## Implementation requirements

1. (Done by card 016: `url_launcher` is a dependency.)
2. `lib/app/links.dart`: add to the existing `AppLinks` the `static final Uri`
   fields `privacyPolicy`, `terms`, `support` and `accountDeletion`, holding
   the D8 URLs.
3. `user_profile.dart`: between `'关于'` and `'退出登录'`, add two `ListTile`s
   in the same style, `'隐私政策'` and `'用户协议'`, each followed by the same
   `Divider`. When `AppLinks.open` returns false, show a `SnackBar` with
   `'无法打开链接'` (check `mounted` / `context.mounted` first).
4. `sign_up_page.dart`: below the `'注册'` button, add the line
   `'注册即表示你同意《用户协议》和《隐私政策》'`, where `《用户协议》` and
   `《隐私政策》` are tappable and open the matching links (a `Text.rich`
   with `TapGestureRecognizer`s that are disposed in `dispose`, or two
   `TextButton`s in a `Wrap`).
5. `user_profile.dart`: after `'用户协议'`, a `ListTile` `'撤回 AI 数据授权'`
   (same style, followed by the same `Divider`). It opens a dialog: title
   `'撤回授权？'`, content
   `'撤回后，生成路线前会再次征求你的同意。已经生成的内容不受影响。'`, buttons
   `'取消'` and `'撤回'`. `'撤回'` calls `AiConsent.revoke()` and shows the
   SnackBar `'已撤回授权'` (check `context.mounted` first).

## Restrictions

- Change only the files above. No other profile changes (account deletion
  is card 007).
- No UI text other than the strings above.

## Tests to add or update

`test/app/links_test.dart`: every `AppLinks` URI is absolute and uses
`https`.

## Acceptance criteria

- Both links open in the browser from the profile and from sign-up, on a
  device.
- After `'撤回'`, tapping `生成路线` shows the AI consent dialog again.
- `git diff --stat` shows no change to `pubspec.yaml` or `pubspec.lock`.

## Commands that must pass

```sh
flutter pub get
flutter analyze   # "No issues found!"
flutter test      # all pass
```

## Information Codex must report after completion

The report format in `AGENTS.md`.
