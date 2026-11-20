#!/bin/sh
# Builds the Locky disk image: the app and a link to Applications on the Locky background, with the
# Locky volume icon. Finder lays out the window, so the first run asks to let the terminal control
# Finder (System Settings > Privacy & Security > Automation).
#
# Usage: make_dmg.sh <Locky.app> <output.dmg> [signing identity]
set -e
app=$1
output=$2
identity=$3
here=$(cd "$(dirname "$0")" && pwd)
volume="Locky"

[ -d "$app" ] || { echo "No app at $app" >&2; exit 1; }
work=$(mktemp -d)
mount=""
# Cleanup that cannot fail: set -e applies to the trap too.
trap 'if [ -n "$mount" ]; then hdiutil detach "$mount" -quiet -force 2>/dev/null || true; fi; rm -rf "$work"' EXIT

# Contents of the volume.
mkdir -p "$work/content/.background"
ditto "$app" "$work/content/Locky.app"
ln -s /Applications "$work/content/Applications"
cp "$here/DMG/background.tiff" "$work/content/.background/background.tiff"

# A writable image first, for Finder to store the layout of the window.
for existing in /Volumes/"$volume"*; do
    [ -d "$existing" ] && hdiutil detach "$existing" -quiet -force 2>/dev/null || true
done
hdiutil create -quiet -volname "$volume" -srcfolder "$work/content" -fs HFS+ -format UDRW -ov "$work/rw.dmg"
mount=$(hdiutil attach "$work/rw.dmg" -readwrite -noverify -noautoopen 2>/dev/null | awk -F'\t' '/\/Volumes\// {print $NF}')

osascript <<EOF
tell application "Finder"
    tell disk "$volume"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {200, 120, 860, 548}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 128
        set text size of viewOptions to 13
        set background picture of viewOptions to file ".background:background.tiff"
        -- Hidden items out of the way, for those who show hidden files.
        repeat with hiddenItem in {".background", ".fseventsd", ".DS_Store"}
            try
                set position of item hiddenItem of container window to {330, 640}
            end try
        end repeat
        set position of item "Locky.app" of container window to {165, 200}
        set position of item "Applications" of container window to {495, 200}
        close
        open
        update without registering applications
        delay 2
        close
    end tell
end tell
EOF

# The volume icon: an icon file at the root and the custom icon flag on the volume (after the
# layout: Finder drops the icon file while it lays out the window).
cp "$here/DMG/VolumeIcon.icns" "$mount/.VolumeIcon.icns"
SetFile -c icnC "$mount/.VolumeIcon.icns"
SetFile -a C "$mount"

# Hide the background folder and volume icon from the window, then freeze the image.
SetFile -a V "$mount/.background" "$mount/.VolumeIcon.icns"
rm -rf "$mount/.fseventsd"
chmod -Rf go-w "$mount" || true
sync
hdiutil detach "$mount" -quiet
mount=""
rm -f "$output"
hdiutil convert -quiet "$work/rw.dmg" -format ULFO -o "$output"

if [ -n "$identity" ]; then
    codesign --force --sign "$identity" --timestamp "$output"
fi
echo "$output"
