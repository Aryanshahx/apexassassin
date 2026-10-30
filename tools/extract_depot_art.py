#!/usr/bin/env python3
"""Cut the APPROVED depot concept art into game-ready sprites.

Nothing here is redrawn: every container lid, hazard cap, corner casting, crate
and drain is the actual pixels of art_source/environment/depot_concept.png.
Containers become 9-slice strips (fixed hazard caps + tileable ribbed middle)
plus a separate depth face so walls of any length keep the original shading.
"""
from pathlib import Path
from PIL import Image, ImageEnhance
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "art_source" / "environment" / "depot_concept.png"
OUT = ROOT / "assets" / "environment" / "depot"
OUT.mkdir(parents=True, exist_ok=True)

im = Image.open(SRC).convert("RGB")

# Measured from the concept: (x0, y0, x1, y1) of the lid, cap heights, depth face.
CONTAINERS = {
    "red":   dict(lid=(406, 433, 497, 791), cap_top=21, cap_bot=22, depth=(406, 791, 497, 819)),
    "blue":  dict(lid=(737, 474, 828, 772), cap_top=21, cap_bot=22, depth=(737, 772, 828, 809)),
    "olive": dict(lid=(487,  58, 579, 311), cap_top=21, cap_bot=22, depth=(487, 311, 579, 349)),
}


# Clean side-face strips measured off the horizontal containers in the concept.
DEPTH_H = {
    "red":   (582, 484, 728, 508),
    "blue":  (90, 323, 260, 348),
    "olive": (100, 834, 308, 866),
}


def save(img: Image.Image, name: str) -> None:
    img.save(OUT / f"{name}.png")


def build_containers() -> None:
    for color, c in CONTAINERS.items():
        lid = im.crop(c["lid"])
        w, h = lid.size
        ct, cb = c["cap_top"], c["cap_bot"]
        # Fixed caps and a tileable middle, all original pixels.
        save(lid.crop((0, 0, w, ct)), f"c_{color}_cap_a")
        save(lid.crop((0, h - cb, w, h)), f"c_{color}_cap_b")
        mid = lid.crop((0, ct, w, h - cb))
        # Blend the seam row so the middle repeats without a visible band.
        m = np.asarray(mid).astype(float)
        band = 6
        if m.shape[0] > band * 3:
            ramp = np.linspace(1, 0, band)[:, None, None]
            m[:band] = m[:band] * ramp + m[-band:][::-1] * (1 - ramp)
        save(Image.fromarray(m.clip(0, 255).astype("uint8")), f"c_{color}_mid")
        save(im.crop(c["depth"]), f"c_{color}_depth")
        # Side face for horizontal runs: real vertical corrugation, mirrored to tile.
        dh = im.crop(DEPTH_H[color])
        dw, dhh = dh.size
        strip = Image.new("RGB", (dw * 2, dhh))
        strip.paste(dh, (0, 0))
        strip.paste(dh.transpose(Image.FLIP_LEFT_RIGHT), (dw, 0))
        save(strip, f"c_{color}_depth_h")
        # Rotated set for horizontal runs (caps become left/right).
        save(lid.crop((0, 0, w, ct)).rotate(-90, expand=True), f"c_{color}_cap_l")
        save(lid.crop((0, h - cb, w, h)).rotate(-90, expand=True), f"c_{color}_cap_r")
        save(Image.fromarray(m.clip(0, 255).astype("uint8")).rotate(-90, expand=True), f"c_{color}_mid_h")


def build_crate() -> None:
    crate = im.crop((272, 328, 355, 416))
    save(crate, "crate_real")
    w, h = crate.size
    save(crate.crop((0, 0, w, int(h * 0.76))), "crate_real_top")
    save(crate.crop((0, int(h * 0.76), w, h)), "crate_real_depth")


def build_props() -> None:
    save(im.crop((734, 217, 791, 273)), "drain_real")
    # Yellow arrow: key the concrete out so it can lie on any floor.
    ar = im.crop((862, 676, 928, 726)).convert("RGBA")
    a = np.asarray(ar).astype(int)
    R, G, B = a[:, :, 0], a[:, :, 1], a[:, :, 2]
    keep = (R > 165) & (G > 140) & (R > B + 55)
    alpha = np.where(keep, 210, 0).astype("uint8")
    out = np.dstack([a[:, :, :3].astype("uint8"), alpha])
    save(Image.fromarray(out, "RGBA"), "arrow_real")


def build_floor() -> None:
    # Verified-clean hex concrete window (no crates, arrows or drains).
    patch = im.crop((400, 1168, 528, 1296))
    # 2x2 mirror tiling: seamless with zero ghosting, keeps the hex detail crisp.
    w, h = patch.size
    tile = Image.new("RGB", (w * 2, h * 2))
    tile.paste(patch, (0, 0))
    tile.paste(patch.transpose(Image.FLIP_LEFT_RIGHT), (w, 0))
    tile.paste(patch.transpose(Image.FLIP_TOP_BOTTOM), (0, h))
    tile.paste(patch.transpose(Image.FLIP_LEFT_RIGHT).transpose(Image.FLIP_TOP_BOTTOM), (w, h))
    tile = ImageEnhance.Contrast(tile).enhance(0.97)
    save(tile, "floor_real")


def main() -> None:
    build_containers()
    build_crate()
    build_props()
    build_floor()
    print("extracted real depot art ->", OUT)
    for f in sorted(OUT.glob("*_real.png")) + sorted(OUT.glob("c_red_*.png")):
        print("  ", f.name, Image.open(f).size)


if __name__ == "__main__":
    main()
