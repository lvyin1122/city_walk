# 027: Password reset with an e-mail code

- **Status:** draft
- **Priority:** P1
- **Owner:** Codex
- **Base branch:** improve/stabilize-and-restyle
- **Branch:** codex/027-password-reset
- **Waiting for:** the maintainer's Supabase setup: custom SMTP, and the
  "Reset password" e-mail template containing `{{ .Token }}` (the 6-digit
  code) instead of only a link

## Goal

A user who forgot their password can set a new one inside the app with a code
sent by e-mail. No deep links are needed.

## Background

- `lib/features/auth/sign_in_page.dart` has no "forgot password" entry; a
  locked-out user can only create a new account and loses their walks.
- Supabase supports: `resetPasswordForEmail(email)` (sends the recovery
  e-mail), `verifyOTP(type: OtpType.recovery, email:, token:)` (signs the user
  in), then `updateUser(UserAttributes(password: ...))`.
- Auth screens use `AuthScaffold`, `AuthSubmitButton`, `AuthFooter`
  (`lib/features/auth/auth_form_layout.dart`) and map errors with
  `auth_error_messages.dart`; `AuthService` wraps Supabase
  (`lib/services/auth_service.dart`).
- After a successful sign-in the pages call
  `Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false)`.

## Files or directories involved

- `lib/services/auth_service.dart`
- `lib/features/auth/reset_password_page.dart` (new)
- `lib/features/auth/sign_in_page.dart`
- `lib/features/auth/auth_error_messages.dart`
- `test/features/auth/reset_password_page_test.dart` (new)
- `test/features/auth/auth_error_messages_test.dart`

## Implementation requirements

1. `AuthService`: `sendPasswordResetCode(email)`,
   `verifyPasswordResetCode(email, code)`, `setNewPassword(password)`, each
   with a 20-second timeout.
2. `ResetPasswordPage` (two steps, `AuthScaffold` title `重设密码`):
   - step 1: field `邮箱`, button `发送验证码`; on success the SnackBar
     `验证码已发送，请查看邮箱`;
   - step 2: fields `验证码` (digits, 6) and `新密码（至少 6 位）`, button
     `设置新密码`; a `TextButton` `重新发送` enabled 60 s after sending; a
     password shorter than 6 characters shows `密码至少需要 6 位` (the
     sign-up page's message) and sends nothing;
   - success: SnackBar `密码已更新` and navigate to `/` like sign-in;
   - the page takes `AuthService` as a constructor parameter for tests.
3. `sign_in_page.dart`: a `TextButton` `忘记密码？` under the password field
   that opens the page with the typed e-mail prefilled.
4. `auth_error_messages.dart`: `resetErrorMessage(AuthException)`: expired or
   invalid code → `验证码不正确或已过期`; rate limit → `操作太频繁了，请稍后再试`;
   otherwise `操作失败，请稍后重试`.

## Restrictions

- Change only the files above. No UI text other than the strings above.
- Never log the e-mail, the code or the password.

## Tests to add or update

`reset_password_page_test.dart` with a fake `AuthService`: step 1 → step 2
after sending; the code field accepts 6 digits; a too-short password shows
`密码至少需要 6 位`; success calls the fake in order. Error-message tests for
the three cases.

## Acceptance criteria

- Device check against the production Supabase project: a reset with a real
  inbox works end to end.

## Commands that must pass

```sh
flutter pub get
flutter analyze   # "No issues found!"
flutter test      # all pass
```

## Information Codex must report after completion

The report format in `AGENTS.md`.
