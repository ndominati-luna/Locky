#!/bin/sh
# Redraws the DMG artwork (background.tiff, VolumeIcon.icns) next to this script.
set -e
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
xcrun --sdk macosx swift "$here/draw_assets.swift" "$root/Apps/Mac/Resources/Assets.xcassets/LockyGlyph.imageset/LockyGlyph.pdf" "$work" "$root"
tiffutil -cathidpicheck "$work/background.png" "$work/background@2x.png" -out "$here/background.tiff"
iconutil -c icns "$work/VolumeIcon.iconset" -o "$here/VolumeIcon.icns"
