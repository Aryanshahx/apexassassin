#!/usr/bin/env python3
"""Extract 12 stills from the user's RGB concept sheets; no original motion frames exist.

Requires Pillow, NumPy and OpenCV; run with the original three supplied PNGs in
art_source/v72-user.  Small manually defined opaque hand/weapon silhouettes
repair dark foreground that the statistical cutout would otherwise discard.
"""
from pathlib import Path
import cv2
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'art_source/v72-user'
OUT = ROOT / 'assets/actors/v72'
ROWS = (
    ('IMG_20261101_183418.png', 'players',
     ('commando','agent','mercenary','swat','hunter','elite'),
     ((18,80,210,316),(215,80,414,316),(412,80,603,316),
      (601,80,783,316),(779,80,966,316),(959,80,1142,316))),
    ('IMG_20261101_183440.png', 'enemies',
     ('guard','soldier','heavy','sniper','officer','shield'),
     ((39,23,187,161),(193,23,344,161),(347,23,501,161),
      (501,23,654,161),(655,23,808,161),(812,23,940,161))),
)
# Coordinates refer to their respective still crops, not invented character art.
FIX = {
    ('players','hunter'): [(56,140),(102,138),(111,153),(116,177),(109,188),
                           (110,197),(112,217),(106,222),(98,218),(87,190),
                           (73,191),(61,184),(52,168)],
    ('enemies','guard'): [(41,79),(104,79),(110,93),(105,105),(96,109),
                          (103,121),(101,130),(95,128),(80,112),(70,116),
                          (59,115),(48,110),(38,100)],
    ('enemies','soldier'): [(42,80),(105,80),(108,94),(103,105),(94,109),
                            (98,122),(96,131),(90,129),(78,114),(68,117),
                            (58,115),(48,110),(39,99)],
}

def extract(sheet, box, group, name):
    x0,y0,x1,y1 = box
    rgb = np.array(sheet.crop(box).convert('RGB'))
    h,w = rgb.shape[:2]
    mask = np.zeros((h,w),np.uint8)
    bg = np.zeros((1,65),np.float64)
    fg = np.zeros((1,65),np.float64)
    cv2.grabCut(rgb,mask,(2,2,w-4,h-4),bg,fg,7,cv2.GC_INIT_WITH_RECT)
    alpha = np.where((mask==cv2.GC_FGD)|(mask==cv2.GC_PR_FGD),255,0).astype(np.uint8)
    # Keep major connected parts, including small detached highlights on guns;
    # tiny isolated background/heading flecks are removed.
    n, labels, stats, _ = cv2.connectedComponentsWithStats(alpha,8)
    largest = int(np.max(stats[1:,cv2.CC_STAT_AREA])) if n > 1 else 0
    clean = np.zeros_like(alpha)
    for i in range(1,n):
        if int(stats[i,cv2.CC_STAT_AREA]) >= max(18,int(largest*0.003)):
            clean[labels==i] = 255
    silhouette = Image.fromarray(clean,'L')
    if (group,name) in FIX:
        ImageDraw.Draw(silhouette).polygon(FIX[group,name],fill=255)
    # The top of some enemy crops includes pixels from the baked title; their
    # silhouettes start well below it. Never ship those background letters.
    if group == 'enemies':
        ImageDraw.Draw(silhouette).rectangle((0,0,w,7),fill=0)
    rgba = Image.fromarray(rgb,'RGB').convert('RGBA')
    rgba.putalpha(silhouette)
    bounds = rgba.getbbox()
    if not bounds:
        raise RuntimeError('Empty segmentation: '+group+'/'+name)
    rgba = rgba.crop(bounds)
    path = OUT/group/(name+'.png')
    path.parent.mkdir(parents=True,exist_ok=True)
    rgba.save(path,optimize=True)
    return path

def main():
    for filename,group,names,boxes in ROWS:
        sheet=Image.open(SOURCE/filename)
        for name,box in zip(names,boxes):
            print(extract(sheet,box,group,name))
    key = Image.open(SOURCE/'KeyIconB.png').convert('RGBA')
    key_path=ROOT/'assets/ui/v72/key.png'
    key_path.parent.mkdir(parents=True,exist_ok=True)
    key.save(key_path,optimize=True)
    print(key_path)

if __name__=='__main__':
    main()
