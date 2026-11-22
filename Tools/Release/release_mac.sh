#!/bin/sh
# Builds a new version of Locky for Mac, ready to put on https://locky.lunabee.studio:
#
#   build/site/locky-mac-install.dmg   the download for new users (always the latest version)
#   build/site/mac/appcast.xml         the Sparkle feed (SUFeedURL of the app)
#   build/site/mac/Locky-<version>.dmg the update Sparkle downloads, and its deltas
#
# Archive, Developer ID signature, notarization of the app and of the disk image, then the Sparkle
# feed signed with the EdDSA key of the keychain. Put build/site on the site afterwards with
# upload_mac.sh. Keep build/site/mac between releases: the feed, which keeps every version (the
# apps read the history of the release notes in it), and only the files of the latest version, from
# which the next one makes its delta (a Mac further behind downloads the whole disk image).
#
# Before the first release (see README):
#   - a "Developer ID Application" certificate of LUNABEE STUDIO (VH79XGK7M2) in the keychain;
#   - a notarytool profile: xcrun notarytool store-credentials Locky --apple-id <id> --team-id VH79XGK7M2
#   - the Sparkle key (generate_keys) whose public half is SUPublicEDKey in Apps/Mac/Info.plist.
# Before each release: raise MARKETING_VERSION and CURRENT_PROJECT_VERSION of the LockyMac target,
# and write the release notes in Tools/Release/ReleaseNotes/<version>.md (optional).
set -e
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
team="VH79XGK7M2"
notary=${NOTARY_PROFILE:-Locky}
site_url="https://locky.lunabee.studio"
build="$root/build/mac"
site="$root/build/site"
packages="$root/build/packages"

fail() {
    echo "error: $*" >&2
    exit 1
}

# MARK: Checks

identity=$(security find-identity -v -p codesigning | awk -v team="($team)" '/Developer ID Application/ && index($0, team) {print $2; exit}')
[ -n "$identity" ] || fail "no Developer ID Application certificate of team $team in the keychain."
xcrun notarytool history --keychain-profile "$notary" >/dev/null 2>&1 \
    || fail "no notarytool profile \"$notary\": xcrun notarytool store-credentials $notary --apple-id <Apple ID> --team-id $team"

settings=$(xcodebuild -project "$root/Locky.xcodeproj" -scheme LockyMac -configuration Release -showBuildSettings 2>/dev/null)
version=$(echo "$settings" | awk -F' = ' '/^ *MARKETING_VERSION = / {print $2; exit}')
build_number=$(echo "$settings" | awk -F' = ' '/^ *CURRENT_PROJECT_VERSION = / {print $2; exit}')
[ -n "$version" ] && [ -n "$build_number" ] || fail "cannot read the version of LockyMac."
[ -e "$site/mac/Locky-$version.dmg" ] && fail "Locky $version is already in $site/mac: raise MARKETING_VERSION and CURRENT_PROJECT_VERSION."
echo "Locky $version ($build_number)"

# MARK: Build

rm -rf "$build"
mkdir -p "$build" "$site/mac"
xcodebuild archive -project "$root/Locky.xcodeproj" -scheme LockyMac -configuration Release \
    -destination 'generic/platform=macOS' -archivePath "$build/Locky.xcarchive" \
    -clonedSourcePackagesDirPath "$packages" -allowProvisioningUpdates -quiet
xcodebuild -exportArchive -archivePath "$build/Locky.xcarchive" -exportOptionsPlist "$here/ExportOptions.plist" \
    -exportPath "$build/export" -allowProvisioningUpdates -quiet
app="$build/export/Locky.app"

sparkle="$packages/artifacts/sparkle/Sparkle/bin"
public_key=$("$sparkle/generate_keys" -p 2>/dev/null) || fail "no Sparkle key in the keychain: run $sparkle/generate_keys"
[ "$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "$app/Contents/Info.plist")" = "$public_key" ] \
    || fail "SUPublicEDKey of Apps/Mac/Info.plist is not the public key of the keychain ($public_key)."

# MARK: Notarization

echo "Notarizing the app…"
ditto -c -k --keepParent "$app" "$build/Locky.zip"
xcrun notarytool submit "$build/Locky.zip" --keychain-profile "$notary" --wait
xcrun stapler staple "$app"

dmg="$build/Locky-$version.dmg"
"$here/make_dmg.sh" "$app" "$dmg" "$identity"
echo "Notarizing the disk image…"
xcrun notarytool submit "$dmg" --keychain-profile "$notary" --wait
xcrun stapler staple "$dmg"
spctl --assess --type open --context context:primary-signature --verbose "$dmg"

# MARK: Site

# The feed of the site, when this Mac has not made the previous release.
[ -e "$site/mac/appcast.xml" ] || curl -fsSL "$site_url/mac/appcast.xml" -o "$site/mac/appcast.xml" 2>/dev/null || rm -f "$site/mac/appcast.xml"
cp "$dmg" "$site/mac/"
[ -e "$here/ReleaseNotes/$version.md" ] && cp "$here/ReleaseNotes/$version.md" "$site/mac/Locky-$version.md"
"$sparkle/generate_appcast" --download-url-prefix "$site_url/mac/" --link "$site_url" --embed-release-notes \
    --maximum-versions 0 "$site/mac"
# Only the files of the new version stay (the feed keeps the former versions for their notes).
latest=$(python3 -I "$here/feed_files.py" "$site/mac/appcast.xml")
for file in "$site/mac"/*; do
    name=$(basename "$file")
    [ "$name" = "appcast.xml" ] && continue
    echo "$latest" | grep -qxF "$name" || rm -rf "$file"
done
cp "$dmg" "$site/locky-mac-install.dmg"

echo
echo "Ready in $site: put it on $site_url with Tools/Release/upload_mac.sh."
