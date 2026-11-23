#!/usr/bin/env python3
"""Cuts the foot of the Pro Stand out of the Pro Display XDR of this macOS, for ProDisplayXDR.

The panel and the arm are drawn by the app (sharp at any size, and the panel pivots); only the
aluminium foot comes from the artwork of Apple, with its shadow on the desk. Run it on a Mac:

    python3 -I Tools/MacCatalog/make_xdr.py

It reads com.apple.pro-display-xdr.icns from CoreTypes and writes XdrFoot.imageset into
Apps/SharedBrand/StoryAssets.xcassets. The measures of the artwork (1024 px) it relies on are
in ProDisplayXDR.swift: panel 1000 x 572 px from y 261, arm 248 px wide down to y 922.
"""
import json
import pathlib
import subprocess
import sys
import tempfile

from PIL import Image

ICNS = "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/com.apple.pro-display-xdr.icns"
FOOT_TOP = 922  # where the straight arm bends into the foot

root = pathlib.Path(__file__).resolve().parents[2]
destination = root / "Apps/SharedBrand/StoryAssets.xcassets/XdrFoot.imageset"

with tempfile.TemporaryDirectory() as work:
    iconset = pathlib.Path(work) / "xdr.iconset"
    subprocess.run(["iconutil", "-c", "iconset", ICNS, "-o", str(iconset)], check=True)
    artwork = Image.open(iconset / "icon_512x512@2x.png").convert("RGBA")

if artwork.size != (1024, 1024):
    sys.exit(f"unexpected artwork size {artwork.size}")
below = artwork.crop((0, FOOT_TOP, 1024, 1024))
left, top, right, bottom = below.getbbox()
# Centred on the arm (x 388...635), so that the app can centre the foot under the panel.
centre = (388 + 636) / 2
half = max(centre - left, right - centre)
foot = artwork.crop((round(centre - half), FOOT_TOP, round(centre + half), FOOT_TOP + bottom))

destination.mkdir(parents=True, exist_ok=True)
foot.save(destination / "XdrFoot.png")
(destination / "Contents.json").write_text(json.dumps({
    "images": [{"filename": "XdrFoot.png", "idiom": "universal"}],
    "info": {"author": "xcode", "version": 1}
}, indent=2) + "\n")
print(f"XdrFoot.png: {foot.size[0]} x {foot.size[1]} px (artwork x {round(centre - half)}, y {FOOT_TOP})")
