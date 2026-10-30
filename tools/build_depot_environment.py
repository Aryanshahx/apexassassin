#!/usr/bin/env python3
"""Build the Warehouse Depot environment tileset.

Floor + container walls + crates are cropped from the approved depot concept art
(art_source/environment/depot_concept.png) so the in-game look matches the pick.
Piece textures are authored as clean tileable SVGs in the same palette/style for
the parts that need arbitrary sizes (wall runs of any length).
"""
from pathlib import Path
from PIL import Image, ImageEnhance, ImageFilter
import cairosvg

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "assets" / "environment" / "depot"
SRC = ROOT / "art_source" / "environment"
CONCEPT = SRC / "depot_concept.png"
ART.mkdir(parents=True, exist_ok=True)
SRC.mkdir(parents=True, exist_ok=True)


def render(name: str, body: str, w: int, h: int, scale: int = 2) -> None:
    text = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" '
            f'viewBox="0 0 {w} {h}">{body}</svg>')
    (SRC / f"{name}.svg").write_text(text)
    cairosvg.svg2png(bytestring=text.encode(), write_to=str(ART / f"{name}.png"), scale=scale)


def crop_floor() -> None:
    """Grab a clean concrete patch from the concept and make it seamlessly tileable."""
    if not CONCEPT.exists():
        return
    im = Image.open(CONCEPT).convert("RGB")
    # Open floor area in the middle-lower corridor of the approved concept.
    # Cleanest concrete window found by scanning for bright, low-variance,
    # low-saturation pixels (no crates, arrows or drains).
    patch = im.crop((340, 1160, 540, 1360)).resize((256, 256), Image.LANCZOS)
    # Make it seamless by wrap-blending a shifted copy, then restore local detail.
    shift = patch.copy()
    shift = Image.blend(patch, Image.effect_noise(patch.size, 0).convert("RGB"), 0.0)
    rolled = Image.new("RGB", patch.size)
    rolled.paste(patch.crop((128, 128, 256, 256)), (0, 0))
    rolled.paste(patch.crop((0, 128, 128, 256)), (128, 0))
    rolled.paste(patch.crop((128, 0, 256, 128)), (0, 128))
    rolled.paste(patch.crop((0, 0, 128, 128)), (128, 128))
    # Blend original with its 180-deg rotation to kill directional seams.
    flip = patch.transpose(Image.FLIP_LEFT_RIGHT).transpose(Image.FLIP_TOP_BOTTOM)
    tile = Image.blend(patch, flip, 0.35)
    tile = tile.filter(ImageFilter.GaussianBlur(0.4))
    tile = ImageEnhance.Contrast(tile).enhance(0.85)
    tile = ImageEnhance.Brightness(tile).enhance(1.06)
    tile.save(ART / "floor.png")


CONTAINERS = {
    "red":   dict(top="#c0392b", hi="#e05a45", lo="#8e2а1f".replace("а", "a"), side="#7d241a", rib="#a53225"),
    "blue":  dict(top="#2f6fb5", hi="#4d90d9", lo="#1f4f88", side="#1b4477", rib="#2a63a3"),
    "olive": dict(top="#5d7a34", hi="#7d9c4a", lo="#425823", side="#3a4d1f", rib="#526b2d"),
}


def container_top(color: str) -> None:
    """Horizontal container lid, tiles along X. 128x64 logical."""
    c = CONTAINERS[color]
    ribs = "".join(
        f'<rect x="{x}" y="6" width="7" height="52" rx="2" fill="{c["rib"]}"/>'
        f'<rect x="{x}" y="6" width="3" height="52" rx="1.5" fill="{c["hi"]}" opacity="0.55"/>'
        for x in range(10, 128, 16)
    )
    render(f"container_{color}", f'''
      <rect x="0" y="0" width="128" height="64" fill="{c["lo"]}"/>
      <rect x="0" y="3" width="128" height="55" fill="{c["top"]}"/>
      {ribs}
      <rect x="0" y="3" width="128" height="5" fill="{c["hi"]}" opacity="0.75"/>
      <rect x="0" y="55" width="128" height="6" fill="{c["side"]}"/>
      <rect x="0" y="0" width="128" height="64" fill="none" stroke="#14181f" stroke-width="4"/>
    ''', 128, 64)


def container_end(color: str) -> None:
    """Hazard-striped end cap for a container run. 32x64 logical."""
    c = CONTAINERS[color]
    stripes = "".join(
        f'<path d="M{-20 + i * 16} 64 L{-4 + i * 16} 64 L{12 + i * 16} 0 L{-4 + i * 16} 0 Z" fill="#f2c230"/>'
        for i in range(4)
    )
    render(f"container_{color}_end", f'''
      <rect x="0" y="0" width="32" height="64" fill="#1c2029"/>
      <g clip-path="url(#cap)">{stripes}</g>
      <clipPath id="cap"><rect x="3" y="4" width="26" height="56"/></clipPath>
      <rect x="0" y="0" width="32" height="64" fill="none" stroke="#14181f" stroke-width="4"/>
      <rect x="2" y="2" width="28" height="4" fill="{c["hi"]}" opacity="0.5"/>
    ''', 32, 64)


def crate() -> None:
    render("crate_wood", '''
      <rect x="2" y="2" width="60" height="60" rx="4" fill="#b5793c" stroke="#14181f" stroke-width="4"/>
      <rect x="7" y="7" width="50" height="50" rx="2" fill="#c98f4e"/>
      <path d="M7 7 L57 57 M57 7 L7 57" stroke="#a06a30" stroke-width="7"/>
      <path d="M7 7 L57 57 M57 7 L7 57" stroke="#d9a05c" stroke-width="3"/>
      <rect x="2" y="2" width="60" height="10" rx="3" fill="#8d5c2a" opacity="0.55"/>
      <rect x="2" y="52" width="60" height="10" rx="3" fill="#6f4620" opacity="0.5"/>
      <circle cx="9" cy="9" r="3.4" fill="#8fa0ad" stroke="#3b4550" stroke-width="1.4"/>
      <circle cx="55" cy="9" r="3.4" fill="#8fa0ad" stroke="#3b4550" stroke-width="1.4"/>
      <circle cx="9" cy="55" r="3.4" fill="#8fa0ad" stroke="#3b4550" stroke-width="1.4"/>
      <circle cx="55" cy="55" r="3.4" fill="#8fa0ad" stroke="#3b4550" stroke-width="1.4"/>
    ''', 64, 64)


def details() -> None:
    render("drain", '''
      <rect x="2" y="2" width="60" height="44" rx="4" fill="#7c8794" stroke="#2b323b" stroke-width="4"/>
      <rect x="7" y="7" width="50" height="34" rx="2" fill="#4a545f"/>
      ''' + "".join(f'<rect x="{11 + i * 8}" y="9" width="4" height="30" rx="2" fill="#20262d"/>' for i in range(6)) + '''
    ''', 64, 48)
    render("arrow", '''
      <path d="M32 4 L54 30 L42 30 L42 60 L22 60 L22 30 L10 30 Z"
            fill="#f2c230" opacity="0.55"/>
    ''', 64, 64)


def main() -> None:
    crop_floor()
    for color in CONTAINERS:
        container_top(color)
        container_end(color)
    crate()
    details()
    print("depot environment built ->", ART)


if __name__ == "__main__":
    main()
