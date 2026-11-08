# 018: Report a problem with a generated place, task or story

- **Status:** in review (approved and implemented in the maintainer-authorized P0 batch 2026-10-30; CI/device acceptance pending)
- **Priority:** P0 (Google Play blocker)
- **Owner:** Codex
- **Base branch:** improve/stabilize-and-restyle
- **Branch:** codex/018-report-a-problem
- **Waiting for:** nothing to build it; backend card B02 must be deployed for
  the report to reach the server (contract sync afterwards, see the backend
  board)

## Goal

From inside the app, a user can report a generated story, task or place as
offensive, wrong, closed or unsafe, without leaving the app. Google Play's
AI-generated content policy requires in-app reporting for apps that generate
content with AI; it is also the trust signal the product needs ("this place
does not exist").

## Background

- There is no way to flag AI output. Stories, tasks, photo verdicts and stop
  names/descriptions are all generated.
- Backend card B02 adds this mutation (use this exact document):

  ```graphql
  mutation ReportContent($kind: String!, $walkId: String, $stopIndex: Int, $detail: String) {
    reportContent(kind: $kind, walkId: $walkId, stopIndex: $stopIndex, detail: $detail) { success }
  }
  ```

  `kind`: `place`, `task`, `story`, `photo_check` or `other`. `stopIndex` is
  the stop's position in the walk (`WalkStop.index`). `detail` ≤ 1,000
  characters.
- All documents live in `GraphQLOperations` (`lib/services/graphql_operations.dart`),
  are listed in its `all` map and exported to `test/contract/operations.json`
  (`UPDATE_CONTRACT=1 flutter test test/contract`).
- The story is shown by `WalkStoryCard` (`lib/features/walk/widgets/summary_sections.dart:62-124`)
  on the summary page (`lib/features/walk/walk_summary.dart:209`). Card 015
  adds the place and task entry points on the walk screen using this card's
  dialog.
- Use `ChoiceChip`s for the reasons (radio groups' old API is deprecated and
  would fail `flutter analyze`).

## Files or directories involved

- `lib/features/report/report_dialog.dart` (new)
- `lib/features/report/report_repository.dart` (new)
- `lib/services/graphql_operations.dart`, `test/contract/operations.json`
- `lib/services/graphql_service.dart`
- `lib/features/walk/widgets/summary_sections.dart` (`WalkStoryCard` only)
- `lib/features/walk/walk_summary.dart` (one argument)
- `test/features/report/report_dialog_test.dart` (new)
- `test/services/graphql_service_test.dart`

## Implementation requirements

1. `GraphQLOperations.reportContent` = the document above; add
   `'reportContent'` to `all`; regenerate `operations.json`.
2. `GraphQLService.reportContent({required String kind, String? walkId, int? stopIndex, String? detail})`
   with variables (omit null ones), returning `success == true`.
3. `report_repository.dart`: `enum ReportKind { place, task, story }` with a
   `wireName` (`place`, `task`, `story`); `class ReportRepository` taking a
   `GraphQLService` (default `GraphQLService()`), method
   `Future<void> send({required ReportKind kind, required String walkId, int? stopIndex, String? detail})`
   that throws `ApiResponseFormatException('reportContent returned false')`
   when `success` is false.
4. `report_dialog.dart`:
   `Future<void> showReportDialog(BuildContext context, {required ReportKind kind, required String walkId, int? stopIndex, ReportRepository? repository})`.
   - Title by kind: `报告这个地点` / `报告这个任务` / `报告这个故事`.
   - Reasons as single-select `ChoiceChip`s: `内容不当或令人不适`,
     `地点不存在、已关闭或不安全` (only for `place`), `和实际情况不符`, `其他`.
   - `TextField` labelled `补充说明（可选）`, `maxLength: 500`.
   - Actions `取消` and `提交`; `提交` is disabled until a reason is chosen and
     while sending (show a small progress indicator in it).
   - `detail` sent = the reason, plus a line break and the note when the note
     is not empty.
   - Success: close the dialog and show the SnackBar `已收到，谢谢你的反馈`.
     `ApiException`: keep the dialog open and show `e.userMessage` under the
     text field in `FreshColors.error`.
5. `WalkStoryCard`: optional `VoidCallback? onReport`; when set and a story is
   shown (not loading, not failed), a `TextButton.icon` with
   `Icons.flag_outlined` and `报告这个故事` below the text.
   `walk_summary.dart` passes
   `onReport: () => showReportDialog(context, kind: ReportKind.story, walkId: widget.walkId)`.

## Restrictions

- Change only the files above. Do not touch the walk page (card 015 adds the
  other entry points).
- No new dependency. No UI text other than the strings above.

## Tests to add or update

- `report_dialog_test.dart` with a fake repository: `提交` is disabled until
  a reason is picked; the place-only reason appears only for `place`; a
  successful send closes the dialog, shows the SnackBar and passes the
  expected `kind`, `walkId`, `stopIndex` and `detail`; a thrown
  `ApiNetworkException` keeps the dialog open and shows its `userMessage`.
- `graphql_service_test.dart`: `reportContent` sends the document from
  `GraphQLOperations` and omits null variables.
- `test/contract` passes with the regenerated `operations.json`.

## Acceptance criteria

- `grep -n "reportContent" lib/services/graphql_operations.dart` shows the
  document and the `all` entry.
- After B02 is deployed (maintainer): a report from a device appears in the
  `content_reports` collection.

## Commands that must pass

```sh
flutter pub get
flutter analyze   # "No issues found!"
flutter test      # all pass
```

## Information Codex must report after completion

The report format in `AGENTS.md`, plus the new `operations.json` entry.
Maintainer: run the contract sync on the backend after merging.
