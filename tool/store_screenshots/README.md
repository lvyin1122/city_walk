# Store and marketing screenshots

Renders framed screenshots, each with a caption, in Simplified Chinese and
English, for the App Store, Google Play and social media. Output goes to
`build/store/` (git-ignored):

```
build/store/<zh-Hans|en>/<target>/NN-name.png
```

| Target | Size | Use |
| --- | --- | --- |
| `appstore` | 1320×2868 | App Store, iPhone 6.9″ (the required size; the app is iPhone-only) |
| `play` | 1080×1920 | Google Play phone screenshots |
| `play-feature` | 1024×500 | Google Play feature graphic |
| `social-4x5` | 1080×1350 | Instagram feed |
| `social-3x4` | 1242×1660 | 小红书 |
| `social-9x16` | 1080×1920 | Stories, TikTok cover |
| `readme` | 540×1173 | Previews for the repository README |

## Slots

| # | Screen | Source |
| --- | --- | --- |
| 01 | Walk setup | rendered from `WalkSetup` with demo data |
| 02 | Walk preview on the map | device capture |
| 03 | Walk screen with a task | device capture |
| 04 | Accepted task photo | device capture |
| 05 | Walk summary | rendered (stats and story, map left out) |
| 06 | History | rendered from `WalkHistoryCard` |

A capture in `raw/NN-*.png` always replaces the rendered screen for that slot.
Slots 02-04 are skipped until they have a capture: Google Maps is a native
view and cannot be rendered in a test. Captions are in `captions.dart`, demo
data in `demo_data.dart`.

## Steps

1. **Fonts (once).** Light-weight Simplified Chinese fonts for the renderer.
   This takes a few minutes:

   ```sh
   pip install fonttools
   python3 tool/store_screenshots/prepare_fonts.py [path/to/NotoSansCJK-VF.ttc]
   ```

   The default source is Fedora's `google-noto-sans-cjk-vf-fonts` package; on
   macOS, download `NotoSansCJK-VF.ttc` from github.com/notofonts/noto-cjk.
   Emoji come from Noto Color Emoji; pass another path with
   `--dart-define=STORE_EMOJI_FONT=...`.

2. **Device captures (macOS).** Sign in with a dedicated test account (the
   same one can be the App Review demo account), then run:

   ```sh
   tool/store_screenshots/capture_ios.sh          # slots 02-04
   tool/store_screenshots/capture_ios.sh 05       # optional: the full summary
   ```

3. **Your photos (optional).** Put up to six of your own street photos in
   `photos/`. They fill 心动瞬间 on the rendered summary.

4. **Render.**

   ```sh
   flutter test tool/store_screenshots
   ```

   It runs only when named; plain `flutter test` and CI skip it. On the
   maintainer's Linux machine, prefix it with the `NO_PROXY` variables from
   `AGENTS.md`.

`fonts/`, `raw/` and `photos/` are git-ignored. Only the README previews in
`docs/images/` are committed.
