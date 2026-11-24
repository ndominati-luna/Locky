#!/usr/bin/env python3
"""Takes the Magic Keyboards out of this macOS, for the desk in front of the Macs of the iPhone.

macOS draws them from above, in the colours of the iMac, for its Bluetooth settings
(CoreBluetoothUI): the Magic Keyboard with Touch ID (A282) and the one with the numeric keypad too
(A284). The app lays them down on the desk with the camera of the picture of the Mac
(DeskAccessories.swift). Run it on a Mac:

    python3 -I Tools/MacCatalog/make_keyboards.py

It writes Keyboard-<kind>-<colour>.imageset into Apps/iOS/Resources/DeskAccessories.xcassets, each
cropped to the keyboard itself (no shadow), so that the picture is the keyboard seen from above,
edge to edge.
"""
import json
import pathlib
import subprocess
import tempfile

from PIL import Image

RESOURCES = pathlib.Path("/System/Library/PrivateFrameworks/CoreBluetoothUI.framework/Versions/A/Resources")
KINDS = {"Compact": "A282", "Numpad": "A284"}
COLOURS = ["Silver", "Blue", "Green", "Pink", "Purple", "Yellow", "Orange"]
WIDTH = 720

root = pathlib.Path(__file__).resolve().parents[2]
catalog = root / "Apps/iOS/Resources/DeskAccessories.xcassets"
catalog.mkdir(parents=True, exist_ok=True)
(catalog / "Contents.json").write_text(json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2) + "\n")

with tempfile.TemporaryDirectory() as work:
    for kind, model in KINDS.items():
        for colour in COLOURS:
            iconset = pathlib.Path(work) / f"{model}_{colour}.iconset"
            subprocess.run(["iconutil", "-c", "iconset", str(RESOURCES / f"{model}_{colour}.icns"), "-o", str(iconset)], check=True)
            artwork = Image.open(iconset / "icon_512x512@2x.png").convert("RGBA")
            # The keyboard, without the soft shadow macOS puts under it.
            box = artwork.getchannel("A").point(lambda value: 255 if value > 64 else 0).getbbox()
            keyboard = artwork.crop(box)
            # Sharp enough for the widest keyboard the iPhone shows, at 3x.
            keyboard = keyboard.resize((WIDTH, round(keyboard.height * WIDTH / keyboard.width)), Image.LANCZOS)
            name = f"Keyboard-{kind}-{colour}"
            destination = catalog / f"{name}.imageset"
            destination.mkdir(exist_ok=True)
            keyboard.save(destination / f"{name}.png", optimize=True)
            (destination / "Contents.json").write_text(json.dumps({
                "images": [{"filename": f"{name}.png", "idiom": "universal"}],
                "info": {"author": "xcode", "version": 1}
            }, indent=2) + "\n")
            print(f"{name}.png: {keyboard.size[0]} x {keyboard.size[1]} px")
