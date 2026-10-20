# 006: Privacy policy and terms links

- **Status:** blocked
- **Priority:** P0
- **Owner:** Codex
- **Base branch:** chore/stabilize-foundation
- **Branch:** codex/006-legal-links
- **Waiting for:** D8 (the URLs)

## Goal

The privacy policy and terms can be opened from the profile page and from
the sign-up page, as both stores require.

## Background

`lib/features/home/user_profile.dart` has two rows in its `ListView`:
`'关于'` and `'退出登录'`. There is no privacy policy or terms link anywhere in
the app. `url_launcher` 6.3.3 is already in `pubspec.lock` as a transitive
dependency of `supabase_flutter`, so adding it directly should not change
the resolved version. The URLs come from D8 in `tasks/README.md`.

## Files or directories involved

- `pubspec.yaml`, `pubspec.lock`
- `lib/app/links.dart` (new)
- `lib/features/home/user_profile.dart`
- `lib/features/auth/sign_up_page.dart`
- `test/app/links_test.dart` (new)

## Implementation requirements

1. Add `url_launcher` with `flutter pub add url_launcher`.
2. `lib/app/links.dart`: `abstract final class AppLinks` with
   `static final Uri` fields `privacyPolicy`, `terms`, `support` and
   `accountDeletion`, holding the D8 URLs, and
   `static Future<bool> open(Uri uri)` that calls
   `launchUrl(uri, mode: LaunchMode.externalApplication)` and returns false
   instead of throwing.
3. `user_profile.dart`: between `'关于'` and `'退出登录'`, add two `ListTile`s
   in the same style, `'隐私政策'` and `'用户协议'`, each followed by the same
   `Divider`. When `AppLinks.open` returns false, show a `SnackBar` with
   `'无法打开链接'` (check `mounted` / `context.mounted` first).
4. `sign_up_page.dart`: below the `'注册'` button, add the line
   `'注册即表示你同意《用户协议》和《隐私政策》'`, where `《用户协议》` and
   `《隐私政策》` are tappable and open the matching links (a `Text.rich`
   with `TapGestureRecognizer`s that are disposed in `dispose`, or two
   `TextButton`s in a `Wrap`).

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
- `url_launcher` resolves to the same version as before in `pubspec.lock`,
  or the report explains the change.

## Commands that must pass

```sh
flutter pub get
flutter analyze   # "No issues found!"
flutter test      # all pass
```

## Information Codex must report after completion

The report format in `AGENTS.md`, plus the `url_launcher` constraint added
to `pubspec.yaml` and a summary of the `pubspec.lock` diff.
