# 007: Account deletion

- **Status:** in review (approved and implemented in the maintainer-authorized P0 batch 2026-10-30; CI/device acceptance pending)
- **Priority:** P0
- **Owner:** Codex
- **Base branch:** improve/stabilize-and-restyle (updated 2026-10-29: the newest code is there)
- **Branch:** codex/007-account-deletion
- **Waiting for:** backend card B02 merged (contract below, filled
  2026-10-29; present in the local backend); not at the same time as card 006
  (`user_profile.dart`) or another card changing `graphql_operations.dart`.
  Batch sequencing update 2026-10-30: 006 is postponed to the maintainer for
  legal URLs and store deployment; implement deletion independently, then
  preserve its profile row when 006 is implemented.

## Goal

A signed-in user can permanently delete their account and its data from the
profile page. App Store guideline 5.1.1(v) and Google Play both require this
for apps that let people create accounts.

## Background

There is no account deletion anywhere in the app. Deleting a Supabase user
needs a service-role key, which must never be in the client, so the backend
does the deletion (B-02 in `tasks/README.md`) and the app calls it through
`ApiClient`.

Local data to remove after a successful deletion (SharedPreferences):

- `walk_summary_<walkId>` (`lib/features/walk/data/walk_summary_cache.dart`)
- `scrapbook_gen_date`, `scrapbook_gen_count`
  (`lib/services/scrapbook_quota_service.dart`)
- `ai_consent_v1` (card 017) and any `track_queue_<walkId>` (card 026, if
  merged)

Keep `tutorial_seen` and `walk_info_seen`; they belong to the device, not the
account. The Supabase session is removed by signing out.

Signing out today (`user_profile.dart`, `_confirmSignOut`) calls
`_authService.signOut()` and then
`Navigator.pushAndRemoveUntil(... SplashScreen() ..., (route) => false)`.
Deletion ends the same way.

## Backend contract

Defined by backend card B02 (`mambo_backend/tasks/B02-account-deletion-and-reports.md`).
Use exactly this document:

```graphql
mutation DeleteAccount {
  deleteAccount { success message }
}
```

- No arguments: the user comes from the access token.
- `success: true`: the user's walks, routes, records, surprise spots and
  uploaded photos are deleted and the Supabase account is gone. A second call
  for an account that no longer exists also returns `success: true`.
- When the server cannot delete accounts (not configured) it answers with a
  GraphQL error and deletes nothing: `ApiGraphQLException` in the app.
- Without a valid session: `UNAUTHENTICATED` → `ApiHttpException(401)`.
- The call may take several seconds (photos are deleted one batch at a time):
  use a 60-second timeout.

## Files or directories involved

- `lib/services/graphql_operations.dart` (the document above, in `all`) and
  `test/contract/operations.json` (regenerated with
  `UPDATE_CONTRACT=1 flutter test test/contract`)
- `lib/services/graphql_service.dart` (one new method)
- `lib/features/account/account_repository.dart` (new)
- `lib/features/account/delete_account_dialog.dart` (new)
- `lib/features/home/user_profile.dart`
- `test/features/account/account_repository_test.dart` (new)
- `test/features/account/delete_account_dialog_test.dart` (new)

## Implementation requirements

1. `GraphQLOperations.deleteAccount` = the document above, added to `all`;
   regenerate `operations.json`. `GraphQLService.deleteAccount()` runs it with
   a 60-second timeout and returns normally only when `success` is true
   (otherwise throws `ApiResponseFormatException`).
2. `AccountRepository.deleteAccount()`: calls the mutation; on success
   removes the SharedPreferences keys listed above (every key that starts
   with `walk_summary_` or `track_queue_`, the two quota keys and
   `ai_consent_v1`) and signs out. Errors are
   rethrown as `ApiException`. Take the service and the sign-out function as
   constructor parameters so the repository can be tested.
3. `DeleteAccountDialog`, two steps:
   - Step 1: title `'删除账号'`, text
     `'删除后，你的漫步记录、照片和轨迹都会被永久删除，无法恢复。'`, buttons
     `'取消'` and `'继续'`.
   - Step 2: text `'请输入「删除」确认'`, a `TextField`, and a `'永久删除'`
     button that is enabled only when the trimmed input equals `'删除'`.
     While the request runs, show a progress indicator and disable the
     buttons. On failure, show the `ApiException.userMessage` in the dialog
     and enable the buttons again.
   - The dialog takes the delete action as a parameter, so it can be pumped
     in a test without Supabase.
4. `user_profile.dart`: after `'退出登录'`, add a `Divider` and a `ListTile`
   `'删除账号'` with a red icon and red text that opens the dialog. After a
   successful deletion, navigate exactly as sign-out does.

## Restrictions

- Never call Supabase admin APIs from the client.
- Change only the files above.
- No UI text other than the strings above.

## Tests to add or update

- `account_repository_test.dart`, with a fake service and fake sign-out:
  success removes the listed keys, keeps `tutorial_seen` and
  `walk_info_seen`, and signs out; a failure rethrows `ApiException` and
  changes nothing locally. Use `SharedPreferences.setMockInitialValues`.
- `delete_account_dialog_test.dart`: `'永久删除'` is disabled until `删除` is
  typed; a failing action shows the error and re-enables the buttons.

## Acceptance criteria

- On a device with a test account, deletion signs out and the account can no
  longer sign in.
- The backend owner confirms the account's walks, tracks and photos are
  gone.

## Commands that must pass

```sh
flutter pub get
flutter analyze   # "No issues found!"
flutter test      # all pass
```

## Information Codex must report after completion

The report format in `AGENTS.md`, plus the request and response observed
against a staging backend, if one was available.
