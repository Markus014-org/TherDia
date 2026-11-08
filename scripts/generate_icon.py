#!/usr/bin/env python3
"""Create TherDia's orange 1024x1024 App Store icon without third-party packages."""
import math
import struct
import zlib
from pathlib import Path

SIZE = 1024
ORANGE = (243, 105, 20)
WHITE = (255, 255, 255)
canvas = bytearray(bytes(ORANGE) * (SIZE * SIZE))

def fill_pixel(x, y):
    if 0 <= x < SIZE and 0 <= y < SIZE:
        offset = (y * SIZE + x) * 3
        canvas[offset:offset + 3] = bytes(WHITE)

def line(a, b, width=28):
    ax, ay = a
    bx, by = b
    radius = width / 2
    minx = max(0, int(min(ax, bx) - radius - 1))
    maxx = min(SIZE, int(max(ax, bx) + radius + 2))
    miny = max(0, int(min(ay, by) - radius - 1))
    maxy = min(SIZE, int(max(ay, by) + radius + 2))
    dx, dy = bx - ax, by - ay
    length2 = dx * dx + dy * dy
    for y in range(miny, maxy):
        for x in range(minx, maxx):
            factor = max(0, min(1, ((x - ax) * dx + (y - ay) * dy) / length2)) if length2 else 0
            px, py = ax + factor * dx, ay + factor * dy
            if (x - px) ** 2 + (y - py) ** 2 <= radius ** 2:
                fill_pixel(x, y)

def path(points, width=28, close=False):
    for start, end in zip(points, points[1:]):
        line(start, end, width)
    if close:
        line(points[-1], points[0], width)

left = [(178,280),(260,240),(350,245),(486,310),(486,754),(390,700),(300,675),(178,702)]
right = [(538,310),(674,245),(764,240),(846,280),(846,702),(724,675),(634,700),(538,754)]
path(left, 28, True)
path(right, 28, True)
line((512,298),(512,753),28)
path([(260,500),(348,500),(394,418),(452,576),(502,474),(544,515),(610,425),(654,500),(758,500)], 28)

def chunk(typ, payload):
    return struct.pack('>I',len(payload)) + typ + payload + struct.pack('>I',zlib.crc32(typ+payload)&0xffffffff)

raw = b''.join(b'\x00' + canvas[y*SIZE*3:(y+1)*SIZE*3] for y in range(SIZE))
png = b'\x89PNG\r\n\x1a\n'
png += chunk(b'IHDR', struct.pack('>2I5B', SIZE, SIZE, 8, 2, 0, 0, 0))
png += chunk(b'IDAT', zlib.compress(raw, 9))
png += chunk(b'IEND', b'')
target = Path(__file__).resolve().parents[1] / 'TherDia/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png'
target.parent.mkdir(parents=True, exist_ok=True)
target.write_bytes(png)
print('Generated orange TherDia icon:', target)
