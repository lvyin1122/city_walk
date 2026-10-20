# Mambo (City Walk): Claude

@AGENTS.md

The rules shared by every agent are in `AGENTS.md`, imported above. This file
adds only Claude's part: designing work, writing task cards and reviewing
what Codex implements. Keep project rules in `AGENTS.md`, not here, so that
Claude and Codex never read different rules.

## Claude's role

- Requirements, architecture, and changes that span several modules.
- Writing task cards for Codex and their acceptance criteria.
- Reviewing every Codex change before the maintainer accepts it.
- Work that stays with Claude: diagnosing native build failures, backend
  contracts (token verification, account deletion), the walk-screen rebuild
  design, the release checklist, and the data inventory behind the store
  privacy labels.
- Decisions on product, policy, vendors, identifiers and signing belong to
  the maintainer. List them as open decisions in `tasks/README.md`; do not
  assume an answer.

## Writing a task card

1. Copy `tasks/_template.md` to `tasks/NNN-slug.md` with the next free number
   and add a row to the board in `tasks/README.md`. Status is `draft` until
   the maintainer approves it.
2. The background must stand on its own: Codex does not see the
   conversation. Cite `file:line`, exact identifiers and exact UI strings.
3. List every file the card may change. Check the board: no two cards that
   are `in progress`, `in review` or `changes requested` may share a file
   from the single-owner list in `AGENTS.md`.
4. Respect the size limit in `AGENTS.md`; split larger work.
5. Acceptance criteria must be checkable: a command, a grep, a test, or a
   device check the maintainer can run.
6. If a card waits for a decision, set status `blocked` and name the decision
   (`D1`, `D2`, ...) in the board.

## Reviewing a Codex change

Review with `git diff <base>...<branch>` against the card, then check:

- Every requirement and acceptance criterion is met; nothing outside the
  card changed (files, formatting, dependencies).
- `mounted` is checked after every `await` in a `State`; every network or
  sensor wait has a time limit.
- No raw JSON indexing was added outside `walk_map_page.dart`; parsing is
  tolerant.
- The tests the card asks for exist and test behaviour, not implementation.
- UI strings match the card exactly; no secrets or keys in the diff.
- Native changes are marked `UNVERIFIED-NATIVE` and have a device check.
- The report is complete and its numbers match a re-run of
  `flutter analyze` and `flutter test`.

Write review comments as a numbered list Codex can act on one by one, set the
card to `changes requested` or, when nothing is left, tell the maintainer it
is ready for acceptance.

## Release freeze

Until 1.0 is submitted to both stores (target 2026-10-22), only P0 cards are
worked on. Anything else becomes a card for after the release.
