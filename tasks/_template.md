# NNN: <title>

- **Status:** draft
- **Priority:** P0 / P1 / P2
- **Owner:** Codex
- **Base branch:** chore/stabilize-foundation
- **Branch:** codex/NNN-slug
- **Waiting for:** <decisions or cards, or "nothing">

## Goal

<One or two sentences: what is true when this card is done.>

## Background

<Why this is needed, with file:line references. Codex does not see the
conversation, so this section must be enough on its own.>

## Files or directories involved

<Every file the card may change. Nothing else may change.>

## Implementation requirements

1. <Exact, checkable steps. Exact identifiers and UI strings.>

## Restrictions

- <What must not be done.>

## Tests to add or update

- <Test file and the cases it covers.>

## Acceptance criteria

- <Commands, greps, tests or device checks that prove the goal.>

## Commands that must pass

```sh
flutter pub get
flutter analyze   # "No issues found!"
flutter test      # all pass
```

## Information Codex must report after completion

The report format in `AGENTS.md`, plus:

- <anything specific to this card>
