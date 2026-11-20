#!/bin/sh
# Regenerates the Macs embedded in the iPhone and Watch apps from the CoreTypes of this macOS:
# product images with a transparent screen (1024 px for the iPhone, 384 px for the Watch) and
# the table type/model → image of LockyKit. Run it on the latest macOS when Apple ships new Macs.
set -e
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
xcrun --sdk macosx swiftc -O "$here/main.swift" "$here/ScreenLocator.swift" -o "$work/render"
"$work/render" "$work/large" 1024
"$work/render" "$work/small" 384
python3 "$here/write_catalog.py" "$work/large" "$work/small" "$root"
