# 034: Move the free-record code into its own feature folder

- **Status:** draft
- **Priority:** P2
- **Owner:** Codex
- **Base branch:** improve/stabilize-and-restyle (after 019 is merged)
- **Branch:** codex/034-move-free-record
- **Waiting for:** card 019; run before 031 if both are planned

## Goal

The secondary free-record flow lives in one folder, `lib/features/log/`, so
it is visibly separate from the walk product and can later be merged into it
or deleted in one step.

## Background

The flow is spread over three places: `lib/features/walk/quick_start_map_page.dart`,
`lib/features/home/log/` (pages and `widgets/`), and
`lib/services/log_service.dart` plus `lib/services/scrapbook_quota_service.dart`.
Card 019 hides it behind `Env.enableFreeRecord`.

## Files or directories involved

- move `lib/features/walk/quick_start_map_page.dart` → `lib/features/log/quick_start_map_page.dart`
- move `lib/features/home/log/` → `lib/features/log/` (keep the `widgets/` subfolder)
- move `lib/services/log_service.dart` → `lib/features/log/data/log_service.dart`
- move `lib/services/scrapbook_quota_service.dart` → `lib/features/log/data/scrapbook_quota_service.dart`
- every import that points to them (`home_page.dart`, `history_tab.dart`, the
  moved files themselves) and the matching tests under `test/`
- `AGENTS.md` and `README.md`: the layout sections only

## Implementation requirements

1. Move with `git mv` so history follows; fix imports; no code change inside
   the files beyond imports.
2. Add `lib/features/log/README.md` (three lines): what the flow is, that it is
   behind `ENABLE_FREE_RECORD`, and that it uses the `log*` backend operations.

## Restrictions

- Pure move: `git diff -M --stat` must show renames with only import lines
  changed. Mechanical change: approved exception to the six-file limit.

## Tests to add or update

Move the tests to mirror the new paths; all pass unchanged.

## Acceptance criteria

- `grep -rn "features/home/log\|services/log_service\|services/scrapbook_quota" lib test`
  prints nothing.

## Commands that must pass

```sh
flutter pub get
flutter analyze   # "No issues found!"
flutter test      # all pass
```

## Information Codex must report after completion

The report format in `AGENTS.md`, plus `git diff -M --stat`.
