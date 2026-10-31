#!/usr/bin/env python3
"""Generate the blue faceted diamond UI icons without changing saved currency."""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]


def diamond(size):
    scale = size * 4
    im = Image.new('RGBA', (scale, scale), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    def pts(values):
        return [(round(x * scale / 100), round(y * scale / 100)) for x, y in values]
    def poly(values, color):
        d.polygon(pts(values), fill=color)
    def line(values, color, width):
        d.line(pts(values), fill=color, width=max(1, round(width * scale / 100)), joint='curve')
    # A small dark outline/shadow keeps the light facets legible on bright UI.
    poly([(4, 34), (24, 11), (76, 11), (96, 34), (50, 93)], '#073950')
    poly([(9, 33), (26, 14), (74, 14), (91, 33), (50, 87)], '#45d9fc')
    poly([(9, 33), (26, 14), (34, 33)], '#b2f6ff')
    poly([(26, 14), (41, 14), (34, 33)], '#68e7ff')
    poly([(41, 14), (59, 14), (66, 33), (34, 33)], '#e8ffff')
    poly([(59, 14), (74, 14), (66, 33)], '#91f1ff')
    poly([(74, 14), (91, 33), (66, 33)], '#48bfe8')
    poly([(9, 33), (34, 33), (50, 87)], '#34a9db')
    poly([(34, 33), (66, 33), (50, 87)], '#83edff')
    poly([(66, 33), (91, 33), (50, 87)], '#1781b3')
    line([(9, 33), (26, 14), (74, 14), (91, 33), (50, 87), (9, 33)], '#baf7ff', 1.6)
    line([(10, 33), (90, 33)], '#e6ffff', 1.4)
    line([(26, 14), (34, 33), (50, 86), (66, 33), (74, 14)], '#d7fbff', 1.0)
    line([(24, 19), (32, 18)], '#ffffff', 3.0)
    return im.resize((size, size), Image.Resampling.LANCZOS)


def build():
    dest = ROOT / 'assets' / 'ui'
    dest.mkdir(parents=True, exist_ok=True)
    diamond(64).save(dest / 'gem.png')
    diamond(96).save(dest / 'gem_drop.png')


if __name__ == '__main__':
    build()
    print('Built blue diamond icons')
