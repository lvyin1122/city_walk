# 020: Signed photo uploads

- **Status:** in review (approved and implemented in the maintainer-authorized P0 batch 2026-10-30; CI/device acceptance pending)
- **Priority:** P0 (must be in 1.0: the unsigned preset can only be turned off
  once no installed build uses it)
- **Owner:** Codex
- **Base branch:** improve/stabilize-and-restyle
- **Branch:** codex/020-signed-photo-uploads
- **Waiting for:** backend card B10 merged (contract); not at the same time as
  another card that changes `graphql_operations.dart` (007, 018, 021, 026)

## Goal

Photos are uploaded with a short-lived signature that the backend issues to a
signed-in user, into that user's folder. The app no longer contains a
Cloudinary upload preset that anyone could use.

## Background

- `lib/services/cloudinary_service.dart:15-73` posts to
  `https://api.cloudinary.com/v1_1/${Env.cloudinaryCloudName}/image/upload`
  with `upload_preset = Env.cloudinaryUploadPreset` (unsigned). Both values
  are compiled into the app (`lib/app/env.dart:18-23`, required in `missing`).
- Backend card B10 adds (use this exact document):

  ```graphql
  mutation CreateUploadSignature {
    createUploadSignature { cloudName apiKey timestamp signature folder uploadPreset }
  }
  ```

  A signed upload sends the form fields `file`, `api_key`, `timestamp`,
  `signature`, `folder` and `upload_preset` (exactly the signed values).
- `uploadImage` already has a timeout covering send and response and returns
  null on any failure (card 002); callers show
  `照片上传失败，请检查网络后重试`. Tests use `MockClient`
  (`test/services/cloudinary_service_test.dart`).

## Files or directories involved

- `lib/services/cloudinary_service.dart`
- `lib/services/graphql_operations.dart`, `test/contract/operations.json`
- `lib/services/graphql_service.dart`
- `lib/app/env.dart`
- `.env.example`
- `README.md` (the configuration list only)
- `test/services/cloudinary_service_test.dart`

## Implementation requirements

1. `GraphQLOperations.createUploadSignature` = the document above, added to
   `all`; regenerate `operations.json`.
2. In `graphql_service.dart`, define
   `typedef UploadSignature = ({String cloudName, String apiKey, int timestamp, String signature, String folder, String uploadPreset});`
   and `GraphQLService.createUploadSignature()` returning it; a missing field
   throws `ApiResponseFormatException`.
3. `CloudinaryService.uploadImage(File imageFile, {http.Client? client, Duration timeout = const Duration(seconds: 60), Future<UploadSignature> Function()? signatureSource})`:
   get the signature first (default source:
   `GraphQLService().createUploadSignature`), then post the six fields to
   `https://api.cloudinary.com/v1_1/<cloudName>/image/upload`.
   Getting the signature counts towards the same timeout. Any failure returns
   null and logs the reason with `debugPrint` (no URL, no signature).
4. `env.dart`: remove `cloudinaryCloudName`, `cloudinaryUploadPreset` and
   their `missing` entries. `.env.example` and `README.md`: remove the two
   variables.

## Restrictions

- Change only the files above. Callers of `uploadImage` keep working without
  changes.
- No new dependency.

## Tests to add or update

`cloudinary_service_test.dart`, with a fake `signatureSource` and
`MockClient`:

- the request goes to the `cloudName` from the signature and carries exactly
  `api_key`, `timestamp`, `signature`, `folder`, `upload_preset` and the file;
  no other upload preset appears;
- a `signatureSource` that throws `ApiNetworkException` → null, no HTTP call;
- the existing 200 / 400 / never-responding cases still behave as before.

## Acceptance criteria

- `grep -rn -i "upload_preset\|UPLOAD_PRESET" lib .env.example` shows only
  the field built from the signature in `cloudinary_service.dart`.
- Device check (maintainer, against a backend with B10): a task photo uploads
  and the stored URL contains `/mambo/u/`.

## Commands that must pass

```sh
flutter pub get
flutter analyze   # "No issues found!"
flutter test      # all pass
```

## Information Codex must report after completion

The report format in `AGENTS.md`. Maintainer: contract sync on the backend;
keep the unsigned preset until this build is the minimum version (card 021).
