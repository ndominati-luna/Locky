"""Prints the files of a Sparkle feed that Sparkle may still download: the disk image and the deltas
of the newest version for each minimum macOS (one version as long as they all run on the same
macOS). The feed keeps every version for the history of the release notes, without their files.

    python3 -I Tools/Release/feed_files.py build/site/mac/appcast.xml
"""
import sys
import xml.etree.ElementTree as ET

SPARKLE = "{http://www.andymatuschak.org/xml-namespaces/sparkle}"

newest = {}
for item in ET.parse(sys.argv[1]).getroot().iter("item"):
    build = int(item.findtext(SPARKLE + "version", "0"))
    minimum = item.findtext(SPARKLE + "minimumSystemVersion", "")
    if minimum not in newest or build > newest[minimum][0]:
        newest[minimum] = (build, item)
names = {
    enclosure.get("url").rsplit("/", 1)[-1]
    for _, item in newest.values()
    for enclosure in item.iter("enclosure")
}
print("\n".join(sorted(names)))
