# 017: Ask before sending personal data to AI services

- **Status:** in review (approved and implemented in the maintainer-authorized P0 batch 2026-10-30; CI/device acceptance pending)
- **Priority:** P0 (App Store blocker)
- **Owner:** Codex
- **Base branch:** improve/stabilize-and-restyle
- **Branch:** codex/017-ai-data-consent
- **Waiting for:** D13 only for the provider names in the text (the text below
  names both providers in use today; drop "和 OpenAI"/"and OpenAI" if D13 removes
  OpenAI before this card starts)

## Goal

Before the app first sends a user's location, keywords, photos or notes to a
third-party AI service, the user sees what is sent, to whom and why, and
explicitly agrees. Without agreement no AI feature starts.

## Background

- Since 2025-11-13, App Review guideline 5.1.2(i) requires apps to disclose
  where personal data is shared with third parties, **including third-party
  AI**, and to obtain explicit permission before doing so. A line in the
  privacy policy is not enough; apps have been rejected for this.
- Mambo sends to Alibaba Cloud (Qwen) and OpenAI: the user's position and
  reverse-geocoded address and the keywords (walk generation), task photos
  (photo checks), walk data (story), and in the free record flow the photos and
  notes (questions, scrapbook images).
- Entry points that start AI work: `_generateWalk` in
  `lib/features/home/home_page.dart:297-352` and `_startFreeRecord`
  (line ~127-131). Everything else (tasks, checks, stories) happens inside a
  walk that was generated after one of these.
- First launch: `_showTutorialOnFirstLaunch` (line ~52-57) pushes the
  tutorial without waiting for it.
- Card 006 adds a profile row to withdraw consent, using `AiConsent.revoke()`
  from this card.

## Files or directories involved

- `lib/features/consent/ai_consent.dart` (new)
- `lib/features/home/home_page.dart`
- `test/features/consent/ai_consent_test.dart` (new)

## Implementation requirements

1. `lib/features/consent/ai_consent.dart`:
   - `abstract final class AiConsent` with `static Future<bool> isGranted()`,
     `grant()`, `revoke()`, stored in `SharedPreferences` under
     `ai_consent_v1` (a new key name when the text changes materially).
   - `class AiConsentDialog extends StatelessWidget`: an `AlertDialog`,
     title `AI 服务与你的数据`, scrollable content (it must fit a small phone
     at large text size) with, in this order:
     - `为了生成路线、拍摄任务和漫步故事，Mambo 会把以下内容发送给第三方 AI 服务处理：`
     - `• 你的大致位置和附近的地址`
     - `• 你选择或输入的关键词`
     - `• 你拍摄的任务照片和写下的文字`
     - `这些服务是阿里云通义千问（Qwen）和 OpenAI，只用于为你生成内容。Mambo 不会出售你的数据。详情见隐私政策。`
     - in `bodySmall`: `Mambo sends your approximate location and nearby address, the keywords you choose, and the task photos and notes you add to third-party AI services (Alibaba Cloud Qwen and OpenAI) to plan walks, create photo tasks and write walk stories. They are used only to generate content for you.`
     Actions: `TextButton` `不同意` (pops `false`) and `FilledButton`
     `同意并继续` (pops `true`). Not dismissible by tapping outside.
   - `Future<bool> ensureAiConsent(BuildContext context)`: true at once when
     granted; otherwise shows the dialog; on `true` calls `grant()` and
     returns true; otherwise false. Check `context.mounted` after every await.
2. `home_page.dart`:
   - `_openTutorial` returns the `Future` of the push;
     `_showTutorialOnFirstLaunch` awaits it, then (if mounted) calls
     `ensureAiConsent(context)` and ignores the result.
   - `_generateWalk`: before setting `_isLoading`, if
     `!await ensureAiConsent(context)`, show `需要你的同意才能生成路线` and
     return.
   - `_startFreeRecord` becomes `async`: if `!await ensureAiConsent(context)`,
     show `需要你的同意才能开始记录` and return.

## Restrictions

- Change only the files above. Do not change the tutorial itself.
- No new dependency. No UI text other than the strings above.

## Tests to add or update

`test/features/consent/ai_consent_test.dart`
(`SharedPreferences.setMockInitialValues({})`):

- `ensureAiConsent` shows the dialog when not granted; tapping `同意并继续`
  returns true and stores the flag; the next call shows no dialog;
- tapping `不同意` returns false and stores nothing;
- `revoke()` makes the dialog appear again;
- the dialog at 360 × 640 logical pixels with `TextScaler.linear(1.3)` renders
  without an exception and both buttons can be tapped (scroll if needed).

## Acceptance criteria

- On a fresh install (device check): the dialog appears right after the
  tutorial, and again on tapping `生成路线` if it was declined; no request to
  `generateWalkWithGpt` is sent before agreement (check the debug log).
- `grep -rn "ai_consent_v1" lib` prints one line.

## Commands that must pass

```sh
flutter pub get
flutter analyze   # "No issues found!"
flutter test      # all pass
```

## Information Codex must report after completion

The report format in `AGENTS.md`.

Maintainer: mention the consent screen in the App Review notes ("AI data
consent is shown after the tutorial and before the first walk is generated")
and list both providers in the privacy policy.
