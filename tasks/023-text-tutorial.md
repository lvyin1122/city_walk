# 023: A Chinese text tutorial and an 8 MB smaller app

- **Status:** draft
- **Priority:** P1
- **Owner:** Codex
- **Base branch:** improve/stabilize-and-restyle
- **Branch:** codex/023-text-tutorial
- **Waiting for:** nothing (not at the same time as another card that changes
  `pubspec.yaml`)

## Goal

The first-launch tutorial speaks the app's language and matches its style, and
the app no longer bundles 8.4 MB of English screenshots.

## Background

- `lib/features/home/tutorial_slides.dart:41-58` shows
  `assets/images/Tutorial_EN_0{1,2,3}.png`: English screenshots of an older
  design, each 2386 × 5117 pixels and 2-3.3 MB (8.4 MB together). Decoding one
  takes about 49 MB of memory, risky on low-end Android phones, and the rest of
  the app is Simplified Chinese.
- `pubspec.yaml` lists the three PNGs under `flutter: assets:`. `README.md`
  shows the same files as screenshots; they stay in the repository for it.
- `Botanical` drawings (`lib/widgets/botanical.dart`: `sprig`, `ginkgo`,
  `blossom`, `bamboo`) and `PaperBackground` are the app's visual language.

## Files or directories involved

- `lib/features/home/tutorial_slides.dart`
- `pubspec.yaml` (remove three asset lines)
- `test/features/home/tutorial_slides_test.dart` (new)

## Implementation requirements

1. Replace the image pages with three text pages on `PaperBackground`, each a
   `Botanical` (size 96, off-centre like the splash screen), a title
   (`headlineMedium`) and a body (`bodyLarge`):
   1. `BotanicalKind.sprig` — `在熟悉的城市里，慢慢走` —
      `告诉 Mambo 你有多少时间、想看什么，它会在你附近规划一条步行路线。`
   2. `BotanicalKind.ginkgo` — `边走边发现` —
      `按顺序走到每一站，完成小小的拍摄任务；遇到让你心动的角落，就把它记下来。`
   3. `BotanicalKind.blossom` — `留下这次漫步` —
      `走完后，你会得到这次的路线、照片和一段属于你的故事。`
   Keep `跳过`, `下一步`, `开始使用`, the dots and `onFinish` as they are.
2. `pubspec.yaml`: remove the three `Tutorial_EN_0x.png` lines only.

## Restrictions

- Do not delete the PNG files (README uses them). No new dependency. No UI
  text other than the strings above.

## Tests to add or update

`tutorial_slides_test.dart`: page 1 shows its title; `下一步` twice reaches
page 3 and `开始使用`; `跳过` pops (or calls `onFinish`); at 360 × 640 with
`TextScaler.linear(1.3)` no page overflows.

## Acceptance criteria

- `grep -n "Tutorial_EN" lib pubspec.yaml -r` prints nothing.
- The release APK is about 8 MB smaller (maintainer, from CI or a local build).

## Commands that must pass

```sh
flutter pub get
flutter analyze   # "No issues found!"
flutter test      # all pass
```

## Information Codex must report after completion

The report format in `AGENTS.md`.
