#!/usr/bin/env python3
"""Reconstruct a clean backdrop from the selected warehouse UI concept.

Labels, character art and controls in the concept are removed. Godot supplies
real dynamic controls. Requires Pillow, NumPy and OpenCV.
"""
from pathlib import Path
from PIL import Image
import numpy as np,cv2
ROOT = Path(__file__).resolve().parents[1]
im=Image.open(ROOT/'art_source/selector/concept.webp').convert('RGB').resize((720,1282),Image.Resampling.LANCZOS)
a=np.array(im); m=np.zeros(a.shape[:2],np.uint8)
# Only small isolated marks in the header need inpainting.
for x1,y1,x2,y2 in [(14,15,166,84),(624,12,701,96),(76,99,643,171)]:m[y1:y2,x1:x2]=255
b=cv2.inpaint(a,m,5,cv2.INPAINT_TELEA)
# Extend the clean upper corrugated back wall behind the original demo figure.
# Feather the pasted patch into the existing warehouse shelving.
patch=cv2.resize(a[180:291,130:505],(375,175),interpolation=cv2.INTER_LINEAR)
y1,y2,x1,x2=290,465,130,505
feather=np.ones((175,375),np.float32)
for k in range(10):
 t=(k+1)/10; feather[:,k]*=t;feather[:,-1-k]*=t
for k in range(12):feather[k,:]*=(k+1)/12
b[y1:y2,x1:x2]=(patch*feather[:,:,None]+b[y1:y2,x1:x2]*(1-feather[:,:,None])).astype(np.uint8)
# Replace foreground demo art/buttons/carousel with a continuous real floor
# sample from the untouched lower part of the selected concept.
base=a[808:920,:,:]
floor=cv2.resize(base,(720,817),interpolation=cv2.INTER_LINEAR).astype(np.float32)
y,x=np.mgrid[0:817,0:720]
spot=np.exp(-((x-360)/390)**2-((y-100)/290)**2) * np.maximum(0,1-y/720)
floor += spot[:,:,None]*np.array([8,14,17],np.float32)
floor=np.clip(floor,0,255).astype('uint8')
# Replace the complete sample foreground; no demo character pixels remain.
b[465:]=floor
# Slight overall dim lets the real dynamic UI remain legible.
b=(b.astype(np.float32)*0.91).clip(0,255).astype('uint8')
Image.fromarray(b).save(ROOT/'assets/ui/selector/warehouse.jpg',quality=90,optimize=True)
