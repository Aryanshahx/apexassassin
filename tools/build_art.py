#!/usr/bin/env python3
"""Build original Apex Assassin vector art + keyed character portraits.

Requires: pip install pillow cairosvg
The generated PNGs are committed, so end users do NOT need these dependencies.
"""
from __future__ import annotations
import math
from pathlib import Path
import cairosvg
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "assets"
SRC = ROOT / "art_source"
RAW = ROOT.parent / "raw"
SRC.mkdir(parents=True, exist_ok=True)

PAL = {
    "ronin": dict(cloth="#23262e", dark="#12141a", trim="#c9973f", scarf="#b3272d", mask="#e8e2d2", eye="#ffbf3f", skin="#c98d62"),
    "nova": dict(cloth="#1f3d46", dark="#101c22", trim="#d7a54a", scarf="#e06a1f", mask="#f1ead8", eye="#ffc23f", skin="#d9a074"),
    "guard": dict(cloth="#e07a1f", dark="#5c2d0c", trim="#2b2f38", scarf="#7a4213", mask="#2b2f38", eye="#ffe08a", skin="#c98d62"),
    "elite": dict(cloth="#b3272d", dark="#3d0f12", trim="#d7a54a", scarf="#5c1518", mask="#2b2f38", eye="#ff6a3f", skin="#c98d62"),
}

def svg(w, h, body):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{body}</svg>'

def render(name, text, scale=3):
    p = SRC / f"{name}.svg"
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(text)
    out = ART / f"{name}.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    cairosvg.svg2png(bytestring=text.encode(), write_to=str(out), scale=scale)

def character_parts(kind):
    c = PAL[kind]
    is_guard = kind in ("guard", "elite")
    # torso / shoulders, facing up (-Y)
    torso = svg(64, 64, f'''
    <path d="M18 24 Q32 16 46 24 L48 46 Q32 54 16 46 Z" fill="{c['cloth']}" stroke="{c['dark']}" stroke-width="3"/>
    <path d="M22 26 Q32 22 42 26 L40 44 Q32 48 24 44 Z" fill="{c['dark']}" opacity="0.35"/>
    <path d="M20 28 L44 40" stroke="{c['trim']}" stroke-width="3" opacity="0.8"/>
    <rect x="27" y="36" width="10" height="7" rx="2" fill="{c['trim']}"/>
    ''')
    head = svg(64, 64, f'''
    <path d="M32 10 C18 10 14 24 16 34 C20 42 44 42 48 34 C50 24 46 10 32 10 Z" fill="{c['cloth']}" stroke="{c['dark']}" stroke-width="3"/>
    <path d="M22 26 Q32 20 42 26 L40 36 Q32 40 24 36 Z" fill="{c['mask']}"/>
    <path d="M24 27 L29 27 M35 27 L40 27" stroke="{c['eye']}" stroke-width="3" stroke-linecap="round"/>
    <path d="M32 12 L32 22" stroke="{c['trim']}" stroke-width="2" opacity="0.7"/>
    ''')
    if is_guard:
        head = svg(64, 64, f'''
        <circle cx="32" cy="28" r="17" fill="{c['cloth']}" stroke="{c['dark']}" stroke-width="3"/>
        <path d="M16 28 Q32 18 48 28 L48 24 Q32 12 16 24 Z" fill="{c['dark']}" opacity="0.5"/>
        <rect x="22" y="26" width="20" height="7" rx="3" fill="{c['mask']}"/>
        <circle cx="27" cy="29" r="2" fill="{c['eye']}"/><circle cx="37" cy="29" r="2" fill="{c['eye']}"/>
        <rect x="29" y="12" width="6" height="8" rx="2" fill="{c['trim']}"/>
        ''')
    arm = svg(32, 48, f'''
    <rect x="9" y="4" width="14" height="30" rx="7" fill="{c['cloth']}" stroke="{c['dark']}" stroke-width="3"/>
    <rect x="10" y="24" width="12" height="8" rx="3" fill="{c['trim']}"/>
    <circle cx="16" cy="37" r="6" fill="{c['skin']}" stroke="{c['dark']}" stroke-width="2"/>
    ''')
    leg = svg(32, 48, f'''
    <rect x="9" y="2" width="14" height="30" rx="7" fill="{c['dark']}"/>
    <rect x="8" y="28" width="16" height="14" rx="5" fill="{c['cloth']}" stroke="{c['dark']}" stroke-width="2"/>
    ''')
    scarf = svg(48, 64, f'''
    <path d="M20 4 Q30 18 22 34 Q16 48 26 60 L34 56 Q28 44 34 30 Q40 14 30 4 Z" fill="{c['scarf']}" stroke="{c['dark']}" stroke-width="2"/>
    ''')
    blade = svg(32, 64, f'''
    <rect x="13" y="38" width="6" height="18" rx="2" fill="{c['dark']}"/>
    <rect x="8" y="34" width="16" height="6" rx="2" fill="{c['trim']}"/>
    <path d="M16 2 Q24 18 20 34 L12 34 Q8 18 16 2 Z" fill="#dfe7ee" stroke="#5a6570" stroke-width="2"/>
    <path d="M16 6 L16 30" stroke="#ffffff" stroke-width="2" opacity="0.8"/>
    ''')
    rifle = svg(32, 72, f'''
    <rect x="12" y="4" width="8" height="44" rx="2" fill="#20242c" stroke="#0d0f13" stroke-width="2"/>
    <rect x="10" y="30" width="12" height="18" rx="3" fill="{c['trim']}"/>
    <rect x="14" y="0" width="4" height="10" fill="#0d0f13"/>
    <rect x="8" y="48" width="16" height="10" rx="3" fill="#3a2417"/>
    ''')
    base = f"characters/{kind}"
    render(f"{base}/torso", torso)
    render(f"{base}/head", head)
    render(f"{base}/arm", arm)
    render(f"{base}/leg", leg)
    render(f"{base}/scarf", scarf)
    render(f"{base}/blade", blade)
    render(f"{base}/rifle", rifle)

def environment():
    floor = svg(64, 64, '''
    <rect width="64" height="64" fill="#b9b2a4"/>
    <rect width="64" height="64" fill="url(#n)" opacity="0.18"/>
    <path d="M0 0H64M0 32H64M0 64H64M0 0V64M32 0V64M64 0V64" stroke="#8f887a" stroke-width="1" opacity="0.35"/>
    <circle cx="12" cy="18" r="1.5" fill="#8f887a" opacity="0.4"/><circle cx="48" cy="44" r="1" fill="#8f887a" opacity="0.4"/>
    <defs><filter id="n"><feTurbulence baseFrequency="0.9" numOctaves="2"/></filter></defs>
    ''')
    # CairoSVG doesn't do feTurbulence reliably; keep simple tile.
    floor = svg(64, 64, '''
    <rect width="64" height="64" fill="#b9b2a4"/>
    <path d="M0 0H64M0 32H64M0 64H64M0 0V64M32 0V64M64 0V64" stroke="#8f887a" stroke-width="1" opacity="0.35"/>
    <circle cx="12" cy="18" r="1.5" fill="#8f887a" opacity="0.35"/><circle cx="48" cy="44" r="1" fill="#8f887a" opacity="0.35"/>
    <path d="M4 8 L14 6 M40 52 L54 50" stroke="#a29a8b" stroke-width="1" opacity="0.5"/>
    ''')
    render("level/floor_tile", floor, 2)
    wall = svg(64, 64, '''
    <rect width="64" height="64" fill="#3a2417"/>
    <rect x="3" y="3" width="58" height="58" fill="#8a5a33"/>
    <rect x="3" y="3" width="58" height="5" fill="#a8703f"/>
    <circle cx="10" cy="12" r="2.5" fill="#5c3a20"/><circle cx="54" cy="12" r="2.5" fill="#5c3a20"/>
    <circle cx="10" cy="52" r="2.5" fill="#5c3a20"/><circle cx="54" cy="52" r="2.5" fill="#5c3a20"/>
    ''')
    render("level/wall_tile", wall, 2)
    for name, base, dark, strap in [("blue", "#1f6fb2", "#0d3a63", "#ffd23f"), ("olive", "#5a6b32", "#2e3a18", "#8a9a5b"), ("gray", "#59616b", "#2b3038", "#9aa0a8")]:
        crate = svg(96, 96, f'''
        <rect x="4" y="6" width="88" height="86" rx="6" fill="#000" opacity="0.3"/>
        <rect x="4" y="2" width="88" height="86" rx="6" fill="{dark}"/>
        <rect x="9" y="7" width="78" height="76" rx="4" fill="{base}"/>
        <path d="M14 12 L82 78 M82 12 L14 78" stroke="{dark}" stroke-width="5" opacity="0.7"/>
        <rect x="9" y="7" width="78" height="8" fill="{strap}" opacity="0.35"/>
        <rect x="9" y="75" width="78" height="8" fill="{dark}" opacity="0.6"/>
        <circle cx="14" cy="12" r="3" fill="{dark}"/><circle cx="82" cy="12" r="3" fill="{dark}"/>
        <circle cx="14" cy="78" r="3" fill="{dark}"/><circle cx="82" cy="78" r="3" fill="{dark}"/>
        <path d="M70 7 h12 l-12 12 h12" stroke="{strap}" stroke-width="3" fill="none" opacity="0.9"/>
        ''')
        render(f"level/crate_{name}", crate, 2)
    slash = svg(96, 96, '''
    <path d="M12 70 Q48 4 88 30 Q58 22 30 76 Z" fill="#ffffff" opacity="0.9"/>
    <path d="M18 72 Q50 18 84 34" stroke="#bff7ff" stroke-width="4" fill="none" opacity="0.8"/>
    ''')
    render("fx/slash", slash, 2)
    spark = svg(32, 32, '''<circle cx="16" cy="16" r="6" fill="#fff6c9"/><circle cx="16" cy="16" r="11" fill="#ffd23f" opacity="0.35"/>''')
    render("fx/spark", spark, 2)
    # Preserve the current blue-diamond currency whenever art is regenerated.
    from build_diamond_v63 import build as build_diamond
    build_diamond()

def key_portrait(src: Path, out: Path):
    im = Image.open(src).convert("RGBA")
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if r > 150 and b > 150 and g < 140 and (r - g) > 60 and (b - g) > 60:
                px[x, y] = (r, g, b, 0)
            elif r > 120 and b > 120 and g < 160 and (r - g) > 35 and (b - g) > 35:
                # soft edge despill
                alpha = max(0, 255 - int(((r - g) + (b - g)) * 1.6))
                px[x, y] = (min(r, g + 40), g, min(b, g + 40), alpha)
    bbox = im.getbbox()
    if bbox:
        im = im.crop(bbox)
    im.thumbnail((640, 640), Image.LANCZOS)
    out.parent.mkdir(parents=True, exist_ok=True)
    im.save(out)

def main():
    for k in PAL:
        character_parts(k)
    environment()
    for name in ("ronin", "nova"):
        src = RAW / f"{name}_card.png"
        if src.exists():
            key_portrait(src, ART / "home" / f"card_{name}.png")
    print("Original art built ->", ART)

if __name__ == "__main__":
    main()
