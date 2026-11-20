#!/usr/bin/env python3
"""Writes the asset catalogs of the iPhone and Watch apps and the table of LockyKit from the
images the Swift tool rendered (see generate.sh)."""
import glob
import json
import os
import shutil
import sys

large, small, root = sys.argv[1], sys.argv[2], sys.argv[3]

for src, dst in [(large, 'Apps/iOS/Resources/MacCatalog.xcassets'), (small, 'Apps/Watch/Resources/MacCatalog.xcassets')]:
    dst = os.path.join(root, dst)
    if os.path.exists(dst):
        shutil.rmtree(dst)
    os.makedirs(dst)
    json.dump({"info": {"author": "xcode", "version": 1}}, open(dst + '/Contents.json', 'w'), indent=2)
    count = 0
    for f in sorted(glob.glob(src + '/*.png')):
        name = os.path.basename(f)[:-4]
        imageset = dst + '/' + name + '.imageset'
        os.makedirs(imageset)
        shutil.copy(f, imageset + '/' + name + '.png')
        json.dump({"images": [{"filename": name + '.png', "idiom": "universal"}], "info": {"author": "xcode", "version": 1}},
                  open(imageset + '/Contents.json', 'w'), indent=2)
        count += 1
    print(dst, count, 'images')

entries = json.load(open(large + '/manifest.json'))
types = []
models = {}
for entry in sorted(entries, key=lambda e: e['id']):
    screen = entry.get('screen')
    screen = 'nil' if not screen else '.init(x: %.4f, y: %.4f, width: %.4f, height: %.4f)' % tuple(screen)
    types.append('        "%s": .init(asset: "%s", screen: %s)' % (entry['id'], entry['asset'], screen))
    for code in entry['codes']:
        if '@' in code:
            continue
        # A bare model identifier goes to the type without a color.
        if code not in models or len(entry['id']) < len(models[code]):
            models[code] = entry['id']

source = '''import Foundation

// Generated from the CoreTypes of macOS by Tools/MacCatalog/generate.sh: do not edit by hand.

extension MacCatalog {
    /// Type of a Mac for macOS (model and color) → its image in the asset catalog of the app.
    static let types: [String: Entry] = [
%s
    ]

    /// Model identifier → type of the Mac (default color), when the Mac did not send its type.
    static let models: [String: String] = [
%s
    ]
}
''' % (',\n'.join(types), ',\n'.join('        "%s": "%s"' % (k, models[k]) for k in sorted(models)))
open(os.path.join(root, 'Packages/LockyKit/Sources/LockyKit/Model/MacCatalog+Data.swift'), 'w').write(source)
print(len(types), 'types,', len(models), 'models')
