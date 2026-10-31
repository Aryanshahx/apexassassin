#!/usr/bin/env python3
"""Separate screenshot-derived guard stills into reconstructed 2-D rig layers.

These are *not* original animation frames. A short weapon polygon and two boot
patches are separated so the game can create a gentle gait and a raised-weapon
pose. Source PNGs are retained intact. Requires Pillow, NumPy and OpenCV.
"""
from pathlib import Path
import cv2
import numpy as np
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parents[1]
SRC=ROOT/'assets/reference/guards'
OUT=SRC/'parts'
SPECS={
 'guard':dict(gun=[(7,9),(35,10),(43,14),(42,21),(35,21),(8,17)], upper=(23,0,44,17), upper_cut=(23,0,44,12), lower=(8,44,43,71), lower_cut=(0,52,59,71)),
 'elite':dict(gun=[(0,0),(10,2),(43,17),(43,25),(37,27),(2,10)], gun_only=[(0,0),(22,0),(20,4),(15,8),(10,12),(3,15),(0,13)], upper=(22,0,44,18), upper_cut=(22,0,44,12), lower=(8,50,42,74), lower_cut=(0,58,58,74)),
}

def build(name,spec):
 im=Image.open(SRC/f'{name}.png').convert('RGBA');w,h=im.size;arr=np.array(im)
 gm=Image.new('L',im.size);ImageDraw.Draw(gm).polygon(spec['gun'],fill=255)
 gun=np.array(gm)>0
 # Inpaint just the cropped gun in the underlying pose. Its source pixels are
 # drawn back as an independently rotatable layer; the visible result stays
 # close to the original reference pose when it is lowered.
 mask=(gun & (arr[:,:,3]>4)).astype(np.uint8)*255
 filled=cv2.inpaint(cv2.cvtColor(arr[:,:,:3],cv2.COLOR_RGB2BGR),mask,3,cv2.INPAINT_TELEA)
 base=arr.copy();base[:,:,:3]=cv2.cvtColor(filled,cv2.COLOR_BGR2RGB)
 # The elite rifle extends beyond the silhouette. Once separated, that
 # gun-only region is transparent rather than an inpainted floating nub.
 if 'gun_only' in spec:
  outside=Image.new('L',im.size);ImageDraw.Draw(outside).polygon(spec['gun_only'],fill=255)
  base[np.asarray(outside)>0,3]=0
 def masked(region):
  m=Image.new('L',im.size);ImageDraw.Draw(m).rectangle(region,fill=255)
  pixels=arr.copy();pixels[:,:,3]=np.where(np.asarray(m)>0,arr[:,:,3],0);pixels[pixels[:,:,3]==0,:3]=0
  return Image.fromarray(pixels,'RGBA')
 for name2,box in [('foot_front',spec['upper']),('foot_back',spec['lower'])]:
  masked(box).save(OUT/f'{name}_{name2}.png',optimize=True)
 for box in (spec['upper_cut'],spec['lower_cut']):
  x1,y1,x2,y2=box;base[y1:y2,x1:x2,3]=0
 base[base[:,:,3]==0,:3]=0
 Image.fromarray(base,'RGBA').save(OUT/f'{name}_body.png',optimize=True)
 gun_pixels=arr.copy();gun_pixels[:,:,3]=np.where(gun,arr[:,:,3],0);gun_pixels[gun_pixels[:,:,3]==0,:3]=0
 Image.fromarray(gun_pixels,'RGBA').save(OUT/f'{name}_weapon.png',optimize=True)
 print(name,im.size,'body, front/back feet, weapon')

if __name__=='__main__':
 OUT.mkdir(parents=True,exist_ok=True)
 for name,spec in SPECS.items():build(name,spec)
