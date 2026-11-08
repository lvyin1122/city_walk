# 033: Share a finished walk as a card

- **Status:** draft
- **Priority:** P2
- **Owner:** Codex
- **Base branch:** improve/stabilize-and-restyle
- **Branch:** codex/033-share-card
- **Waiting for:** nothing (better after 030 so the card's texts are localized)

## Goal

After a walk, one tap produces a good-looking image of it (route map, a few
photos, the numbers, the title and the Mambo name) and opens the system share
sheet. This is the app's first growth loop.

## Background

- The summary (`lib/features/walk/walk_summary.dart`) shows stats, a map, the
  story and photos, but nothing can be shared. The product analysis names a
  shareable result as the missing end of the core loop
  (`docs/product-ux-marketing-analysis.md`, 4.3 and 6.7).
- `share_plus` and `gal` are already dependencies; the free-record result page
  already shares an image with `SharePlus.instance.share(...)`
  (`lib/features/home/log/log_review_result_page.dart:332`).
- `GoogleMapController.takeSnapshot()` returns PNG bytes of the visible map
  (the summary keeps the controller in `_mapController`).
- Off-screen widgets can be rendered to an image with a `RepaintBoundary` and
  `toImage(pixelRatio: 3)`.

## Files or directories involved

- `lib/features/walk/widgets/share_card.dart` (new)
- `lib/features/walk/walk_summary.dart`
- `test/features/walk/share_card_test.dart` (new)

## Implementation requirements

1. `ShareCard` widget (1080 × 1350 logical pixels at pixel ratio 1, built for
   rendering, not for the screen): `PaperBackground`, the walk title, the date,
   the map snapshot (or a botanical drawing when there is none), up to three
   photos (surprises first, then task photos), the four numbers of
   `WalkStatsCard`, and the line `Mambo 漫步 · 慢慢走，留意那些被忽略的细节`.
2. `Future<Uint8List> renderShareCard(...)` renders it off-screen to PNG.
3. On the summary page, an `OutlinedButton.icon(Icons.ios_share, '分享这次漫步')`
   below the stats: take the snapshot, load the photos (10 s timeout each,
   skip failures), render, write to a temporary file and share it with the text
   `我刚用 Mambo 走完「{title}」`. While working, the button shows
   `正在生成…` and is disabled; a failure shows `分享失败，请重试`.

## Restrictions

- No new dependency. No user name, e-mail, address or coordinates on the card
  besides the map image.
- No UI text other than the strings above.

## Tests to add or update

`share_card_test.dart`: the card renders with 0, 1 and 3 photos and without a
map without exceptions; `renderShareCard` returns PNG bytes.

## Acceptance criteria

- Device check: sharing to the photo library and to a messaging app produces
  a crisp image.

## Commands that must pass

```sh
flutter pub get
flutter analyze   # "No issues found!"
flutter test      # all pass
```

## Information Codex must report after completion

The report format in `AGENTS.md`.
