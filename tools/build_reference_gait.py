#!/usr/bin/env python3
"""Separate the one visible boot in each supplied screenshot pose.

The source art contains no walk frames. These are cut-out layers for a gentle
pivoted approximation, not original animation. Keeps the original stills intact.
Requires Pillow.
"""
from pathlib import Path
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
SRC=ROOT/'assets/reference/characters'
OUT=ROOT/'assets/reference/characters/parts'

def build(index):
    im=Image.open(SRC/f'{index:02}.png').convert('RGBA')
    w,h=im.size
    cut=round(w*0.82)
    # A small overlap keeps the ankle attached while the single visible boot
    # swings. There is no duplicated second boot or distortion of the torso.
    overlap=6
    foot=im.copy()
    alpha=foot.getchannel('A')
    alpha.paste(0,(0,0,cut,h))
    foot.putalpha(alpha)
    body=im.copy()
    alpha=body.getchannel('A')
    alpha.paste(0,(min(w,cut+overlap),0,w,h))
    body.putalpha(alpha)
    for name,img in [('body',body),('boot',foot)]:
        img.save(OUT/f'{index:02}_{name}.png',optimize=True)

if __name__=='__main__':
    OUT.mkdir(parents=True,exist_ok=True)
    for index in range(1,13):build(index)
    print('Built screenshot-derived body and single-visible-boot layers for 12 reference characters.')
