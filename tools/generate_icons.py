#!/usr/bin/env python3
"""Generate dit.'s code-native launcher artwork without third-party packages.

Run `python3 tools/generate_icons.py` to regenerate icons, or add `--check`
to verify only these generated assets and their launcher wiring.
"""
import argparse
import json
import math
from pathlib import Path
import struct
import zlib
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
RES = 'android/app/src/main/res'
CORAL = (231, 120, 96)
MARK = 'M42,54 A8,8 0,1 1,26,54 A8,8 0,1 1,42,54 Z M57,46 L74,46 A8,8 0,0 1,74,62 L57,62 A8,8 0,0 1,57,46 Z'


def chunk(kind, data):
    return struct.pack('!I', len(data)) + kind + data + struct.pack('!I', zlib.crc32(kind + data))


def png(size, rounded):
    """Render circle/capsule distance fields with antialiasing at native size."""
    scale = size / 108
    pixels = bytearray()
    for row in range(size):
        pixels.append(0)  # PNG filter: none
        y = (row + .5) / scale
        for col in range(size):
            x = (col + .5) / scale
            dot = math.hypot(x - 34, y - 54) - 8
            dash = math.hypot(x - max(57, min(74, x)), y - 54) - 8
            white = max(0, min(1, .5 - min(dot, dash) * scale))
            alpha = 1
            if rounded:
                qx, qy = abs(x - 54) - 30, abs(y - 54) - 30
                distance = math.hypot(max(qx, 0), max(qy, 0)) + min(max(qx, qy), 0) - 24
                alpha = max(0, min(1, .5 - distance * scale))
            pixels.extend(round(c + (255 - c) * white) for c in CORAL)
            pixels.append(round(alpha * 255))
    header = struct.pack('!IIBBBBB', size, size, 8, 6, 0, 0, 0)
    return b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', header) + chunk(b'IDAT', zlib.compress(pixels, 9)) + chunk(b'IEND', b'')


def outputs():
    files = {}
    for density, size in [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)]:
        files[f'{RES}/mipmap-{density}/ic_launcher.png'] = png(size, True)
    for size in [192, 512]:
        files[f'web/icons/Icon-{size}.png'] = png(size, True)
        files[f'web/icons/Icon-maskable-{size}.png'] = png(size, False)
    files['web/favicon.png'] = png(32, True)
    files['assets/branding/app-icon.svg'] = f'''<svg xmlns="http://www.w3.org/2000/svg" width="108" height="108" viewBox="0 0 108 108" role="img" aria-label="dit. Morse dot and dash">
  <rect width="108" height="108" rx="24" fill="#E77860"/>
  <path fill="#FFFFFF" d="{MARK}"/>
</svg>
'''.encode()
    files[f'{RES}/drawable/ic_launcher_foreground.xml'] = f'''<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp" android:height="108dp"
    android:viewportWidth="108" android:viewportHeight="108">
    <path android:fillColor="#FFFFFFFF" android:pathData="{MARK}" />
</vector>
'''.encode()
    files[f'{RES}/values/ic_launcher_colors.xml'] = b'''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#E77860</color>
</resources>
'''
    for version in [26, 33]:
        mono = '\n    <monochrome android:drawable="@drawable/ic_launcher_foreground" />' if version == 33 else ''
        files[f'{RES}/mipmap-anydpi-v{version}/ic_launcher.xml'] = f'''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@drawable/ic_launcher_foreground" />{mono}
</adaptive-icon>
'''.encode()
    return files


def verify_wiring():
    namespace = '{http://schemas.android.com/apk/res/android}'
    app = ET.parse(ROOT / 'android/app/src/main/AndroidManifest.xml').getroot().find('application')
    assert app.get(namespace + 'icon') == '@mipmap/ic_launcher'
    assert app.get(namespace + 'roundIcon') == '@mipmap/ic_launcher'
    manifest = json.loads((ROOT / 'web/manifest.json').read_text())
    assert manifest['name'] == 'dit. — Learn Morse code'
    assert manifest['short_name'] == 'dit.'
    for entry in manifest['icons']:
        path = ROOT / 'web' / entry['src']
        data = path.read_bytes()
        width, height = struct.unpack('!II', data[16:24])
        assert entry['sizes'] == f'{width}x{height}'
    for version in [26, 33]:
        adaptive = ET.parse(ROOT / f'{RES}/mipmap-anydpi-v{version}/ic_launcher.xml').getroot()
        assert adaptive.tag == 'adaptive-icon'
        assert adaptive.find('foreground').get(namespace + 'drawable') == '@drawable/ic_launcher_foreground'
        if version == 33:
            assert adaptive.find('monochrome') is not None
    # The entire mark lies within Android's centered 66dp safe circle.
    assert math.hypot(74 - 54, 0) + 8 < 33
    assert math.hypot(34 - 54, 0) + 8 < 33


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    files = outputs()
    for name, content in files.items():
        target = ROOT / name
        if args.check:
            assert target.exists() and target.read_bytes() == content, f'Icon out of date: {name}'
        else:
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(content)
    verify_wiring()
    print(f'{"Verified" if args.check else "Generated and verified"} {len(files)} icon assets; Android legacy/adaptive/themed and web references valid.')
