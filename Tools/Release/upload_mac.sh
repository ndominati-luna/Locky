#!/bin/sh
# Puts build/site (made by release_mac.sh) on https://locky.lunabee.studio by SFTP: the disk image
# and the deltas of the latest version when missing on the site (or of another size), then the
# feed, then locky-mac-install.dmg. Removes every other file from the mac folder of the site, so
# that it keeps nothing useless. The rest of the site is left untouched.
#
# The feed keeps every version, for the history of the release notes that the apps read in it, but
# Sparkle only downloads the latest one a Mac can run: the site only holds the files of the newest
# version for each minimum macOS (one version as long as they all run on the same macOS), like
# build/site/mac after release_mac.sh.
#
#   Tools/Release/upload_mac.sh [--dry-run]
#
# The destination is not in the repository (public): LOCKY_SITE_SFTP=<user>@<host>, and
# LOCKY_SITE_ROOT, the web root on the account (locky by default), in the environment or in
# Tools/Release/site.local, which git ignores.
set -e
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
site="$root/build/site"
[ -e "$here/site.local" ] && . "$here/site.local"
dest=${LOCKY_SITE_SFTP:?"set LOCKY_SITE_SFTP=<user>@<host>, in the environment or in Tools/Release/site.local"}
web=${LOCKY_SITE_ROOT:-locky}
dry_run=0
[ "$1" = "--dry-run" ] && dry_run=1

fail() {
    echo "error: $*" >&2
    exit 1
}

[ -e "$site/mac/appcast.xml" ] && [ -e "$site/locky-mac-install.dmg" ] || fail "nothing to upload in $site: run release_mac.sh first."

# Files Sparkle may download: those of the newest version for each minimum macOS of the feed.
named=$(python3 -I "$here/feed_files.py" "$site/mac/appcast.xml")
[ -n "$named" ] || fail "the feed names no file."
for file in $named; do
    [ -e "$site/mac/$file" ] || fail "the feed names $file, missing in $site/mac."
done

# Files of the mac folder of the site, with their size.
remote=$(printf 'ls -l %s/mac\n' "$web" | sftp -q -b - "$dest" | awk '/^-/ {n = $NF; sub(/.*\//, "", n); print n, $5}')

remote_size() {
    echo "$remote" | awk -v name="$1" '$1 == name {print $2}'
}

batch=$(mktemp)
trap 'rm -f "$batch"' EXIT
echo "cd $web/mac" >> "$batch"
for file in $named; do
    size=$(stat -f %z "$site/mac/$file")
    if [ "$(remote_size "$file")" != "$size" ]; then
        echo "upload  mac/$file"
        echo "put \"$site/mac/$file\"" >> "$batch"
    fi
done
# The feed once what it names is there, then the download for new users.
echo "upload  mac/appcast.xml"
echo "put \"$site/mac/appcast.xml\"" >> "$batch"
echo "upload  locky-mac-install.dmg"
echo "put \"$site/locky-mac-install.dmg\" ../locky-mac-install.dmg" >> "$batch"
for file in $(echo "$remote" | awk '{print $1}'); do
    [ "$file" = "appcast.xml" ] && continue
    echo "$named" | grep -qxF "$file" && continue
    echo "remove  mac/$file"
    echo "rm \"$file\"" >> "$batch"
done

if [ "$dry_run" = 1 ]; then
    echo "(dry run: nothing sent)"
    exit 0
fi
sftp -q -b "$batch" "$dest" >/dev/null
echo "Done: https://locky.lunabee.studio/mac/appcast.xml"
