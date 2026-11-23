"""Prints the files of a Sparkle feed that Sparkle may still download: the disk image and the deltas
of the newest version, and of an older one only if it runs on an older macOS than every newer
version (one version as long as the newest runs wherever the others did). The feed keeps every
version for the history of the release notes, without their files.

    python3 -I Tools/Release/feed_files.py build/site/mac/appcast.xml
"""
import sys
import xml.etree.ElementTree as ET

SPARKLE = "{http://www.andymatuschak.org/xml-namespaces/sparkle}"


def macos(version):
    """"26.0" as (26, 0), for comparisons; no minimum as the oldest macOS."""
    return tuple(int(part) for part in version.split(".") if part.isdigit()) or (0,)


versions = sorted(
    (
        (int(item.findtext(SPARKLE + "version", "0")), macos(item.findtext(SPARKLE + "minimumSystemVersion", "")), item)
        for item in ET.parse(sys.argv[1]).getroot().iter("item")
    ),
    key=lambda version: version[0],
    reverse=True,
)
kept = []
lowest = None
for _, minimum, item in versions:
    # Useful only for the Macs the newer versions leave behind.
    if lowest is None or minimum < lowest:
        kept.append(item)
        lowest = minimum
names = {enclosure.get("url").rsplit("/", 1)[-1] for item in kept for enclosure in item.iter("enclosure")}
print("\n".join(sorted(names)))
