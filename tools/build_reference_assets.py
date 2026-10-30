#!/usr/bin/env python3
"""Rebuild screenshot-derived character and guard art.

Uses the two user-provided screenshots in art_source/reference. The 12 character
cutouts use original screenshot RGB with only an alpha mask; the playable cards
remove the screenshot's lock icon because all 12 choices are freely selectable.
The two guards likewise use RGB pixels from the gameplay reference. The input is
one still image per design, not original animation frames. Requires Pillow,
NumPy, and opencv-python. Outputs are shipped; running this is optional.
"""
from pathlib import Path
from hashlib import sha256
import json
import cv2
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT/'art_source/reference'
OUT = ROOT/'assets/reference'
(OUT/'characters').mkdir(parents=True, exist_ok=True)
(OUT/'cards').mkdir(parents=True, exist_ok=True)
(OUT/'guards').mkdir(parents=True, exist_ok=True)
meta = json.loads((SRC/'roster_metadata.json').read_text())
roster_bytes=(SRC/'roster_reference.jpg').read_bytes()
assert sha256(roster_bytes).hexdigest()==meta['source_sha256']
source = Image.open(SRC/'roster_reference.jpg').convert('RGB')
pixels=np.array(source)
assert source.size==(1278,1837)
tops=[[10,10],[325,317],[625,625],[932,932],[1239,1239],[1547,1547]]
columns=[45,645]
for item in meta['characters']:
    n=item['number']; row,col=divmod(n-1,2); x=columns[col]; y=tops[row][col]
    x1,y1,x2,y2=item['card_crop']
    card=pixels[y1:y2,x1:x2].copy()
    # Erase only the padlock on the screenshot card. These twelve are selectable
    # immediately, so displaying a lock would misrepresent game state.
    gray=cv2.cvtColor(card,cv2.COLOR_RGB2GRAY)
    count,_,stats,_=cv2.connectedComponentsWithStats((gray[20:115,440:540]<105).astype('uint8'))
    candidates=[]
    for px,py,pw,ph,area in stats[1:]:
        px+=440; py+=20
        if 455<=px<=490 and 34<=py<=48 and 40<=pw<=55 and 48<=ph<=64 and area>1200:
            candidates.append((int(px),int(py),int(pw),int(ph),int(area)))
    assert candidates, f'Lock not found in card {n}'
    px,py,pw,ph,_=max(candidates,key=lambda a:a[4])
    lockmask=np.zeros(card.shape[:2],np.uint8)
    lockmask[py-3:py+ph+3,px-3:px+pw+3]=255
    unlocked=cv2.inpaint(cv2.cvtColor(card,cv2.COLOR_RGB2BGR),lockmask,3,cv2.INPAINT_TELEA)
    Image.fromarray(cv2.cvtColor(unlocked,cv2.COLOR_BGR2RGB),'RGB').save(OUT/'cards'/f'{n:02d}.png',optimize=True)

    x1=x+120; y1=y+7; x2=x+445; y2=min(y+208,source.height)
    roi=pixels[y1:y2,x1:x2].copy(); h,w=roi.shape[:2]
    mask=np.zeros((h,w),np.uint8)
    cv2.grabCut(cv2.cvtColor(roi,cv2.COLOR_RGB2BGR),mask,(9,5,w-18,h-10),
                np.zeros((1,65),np.float64),np.zeros((1,65),np.float64),7,cv2.GC_INIT_WITH_RECT)
    mask=np.where((mask==cv2.GC_FGD)|(mask==cv2.GC_PR_FGD),255,0).astype('uint8')
    count,components,stats,_=cv2.connectedComponentsWithStats(mask)
    assert count>1
    largest=1+int(np.argmax(stats[1:,cv2.CC_STAT_AREA]))
    mask=np.where(components==largest,255,0).astype('uint8')
    alpha=cv2.GaussianBlur(mask,(3,3),0.45)
    sprite=Image.fromarray(np.dstack([roi,alpha]),'RGBA')
    bounds=sprite.getbbox(); assert bounds
    sprite=sprite.crop(bounds)
    assert list(sprite.size)==item['sprite_size'],(n,sprite.size,item['sprite_size'])
    sprite.save(OUT/'characters'/f'{n:02d}.png',optimize=True)

# Standard and elite reference guards, extracted from the user-supplied gameplay image.
assert sha256((SRC/'guard_reference.jpg').read_bytes()).hexdigest()==meta['guard_source_sha256']
guard_source=np.array(Image.open(SRC/'guard_reference.jpg').convert('RGB'))
for name,box in [('guard',(383,768,462,855)),('elite',(507,91,581,181))]:
    x1,y1,x2,y2=box; roi=guard_source[y1:y2,x1:x2].copy(); h,w=roi.shape[:2]
    mask=np.zeros((h,w),np.uint8)
    cv2.grabCut(cv2.cvtColor(roi,cv2.COLOR_RGB2BGR),mask,(4,4,w-8,h-8),
                np.zeros((1,65),np.float64),np.zeros((1,65),np.float64),8,cv2.GC_INIT_WITH_RECT)
    mask=np.where((mask==1)|(mask==3),255,0).astype('uint8')
    count,components,stats,_=cv2.connectedComponentsWithStats(mask)
    assert count>1
    largest=1+int(np.argmax(stats[1:,cv2.CC_STAT_AREA]))
    mask=np.where(components==largest,255,0).astype('uint8')
    alpha=cv2.GaussianBlur(mask,(3,3),0.45)
    sprite=Image.fromarray(np.dstack([roi,alpha]),'RGBA')
    bounds=sprite.getbbox(); assert bounds
    sprite.crop(bounds).save(OUT/'guards'/f'{name}.png',optimize=True)
print('Built 12 screenshot-derived player sprites, 12 selectable cards, and 2 screenshot-derived guard sprites.')
