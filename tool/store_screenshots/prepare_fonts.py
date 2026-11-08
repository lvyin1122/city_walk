"""Make static Noto Sans CJK SC fonts for the store screenshot renderer.

The renderer needs the app's light weights (w200, w300, w400) as separate
static fonts. This cuts them from a Noto Sans CJK variable collection and
writes them to tool/store_screenshots/fonts/ (git-ignored).

    pip install fonttools
    python3 tool/store_screenshots/prepare_fonts.py [path/to/NotoSansCJK-VF.ttc]

Default source: Fedora's google-noto-sans-cjk-vf-fonts package. On macOS,
download NotoSansCJK-VF.ttc (OFL) from github.com/notofonts/noto-cjk.
"""

import sys
from pathlib import Path

from fontTools.ttLib import TTCollection
from fontTools.varLib.instancer import instantiateVariableFont

DEFAULT_SOURCE = "/usr/share/fonts/google-noto-sans-cjk-vf-fonts/NotoSansCJK-VF.ttc"
FACE = "Noto Sans CJK SC"
WEIGHTS = {"ExtraLight": 200, "Light": 300, "Regular": 400}
OUT = Path(__file__).resolve().parent / "fonts"


def main() -> None:
    source = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_SOURCE
    OUT.mkdir(exist_ok=True)
    for style, weight in WEIGHTS.items():
        # Reload per weight: instancing changes the font in place.
        collection = TTCollection(source)
        face = next(f for f in collection.fonts if f["name"].getDebugName(1) == FACE)
        static = instantiateVariableFont(face, {"wght": weight}, updateFontNames=False)
        static["OS/2"].usWeightClass = weight
        target = OUT / f"NotoSansSC-{style}.otf"
        static.save(target)
        print(f"{target.name}: {target.stat().st_size // 1024} KB")


if __name__ == "__main__":
    main()
