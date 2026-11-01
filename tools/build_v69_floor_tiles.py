#!/usr/bin/env python3
"""Create original, seamless 2-cell floor materials and shared light/shadow maps.

Procedural artwork only; the user's reference sheets are not sampled. The two
visible squares in each PNG correspond to two 32-unit gameplay cells, making
floor joints and authored obstacle positions share one grid.
"""
from pathlib import Path
import math
import cv2
import numpy as np
from PIL import Image,ImageDraw,ImageFilter

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/environment/v69';OUT.mkdir(parents=True,exist_ok=True)
N=256

def seamless_noise(rng,sigma):
    # Periodic filtering in the Fourier domain means the noise tiles naturally.
    a=rng.standard_normal((N,N));fy=np.fft.fftfreq(N)[:,None];fx=np.fft.fftfreq(N)[None,:]
    field=np.fft.ifft2(np.fft.fft2(a)*np.exp(-2*(math.pi**2)*sigma**2*(fx*fx+fy*fy))).real
    return (field-field.mean())/(field.std()+1e-9)

palettes={
 'warehouse':((70,76,80),1.00,0.0),
 'factory':((62,68,70),1.00,0.0),
 'dockyard':((60,74,83),1.00,0.0),
 'military':((74,78,67),.78,0.0),
 'night':((28,39,54),.72,0.0),
 'desert':((133,108,78),.26,.55),
 'snow':((169,182,191),.16,.35),
 'rooftop':((75,81,91),.90,0.0),
}
for idx,(name,(base,seam_strength,organic)) in enumerate(palettes.items()):
    rng=np.random.default_rng(690201+idx*229)
    fine=seamless_noise(rng,.7);medium=seamless_noise(rng,4.0);broad=seamless_noise(rng,17)
    # Soft multi-scale roughness; low amplitude avoids dirty repeating blotches.
    value=1.7*fine+2.5*medium+2.0*broad
    if organic:value+=organic*(3.2*seamless_noise(rng,2.2)+3.0*seamless_noise(rng,11))
    yy,xx=np.mgrid[0:N,0:N];tile_index=(xx//128)+2*(yy//128)
    tile_variants=np.array([0.5,-1.6,1.1,-.5]);value+=tile_variants[tile_index]
    data=np.empty((N,N,3),dtype=np.float32)
    for c in range(3):data[:,:,c]=base[c]+value
    # Narrow, parallel masonry joints. The first/last edges are identical.
    pos_x=np.minimum(xx%128,128-(xx%128));pos_y=np.minimum(yy%128,128-(yy%128))
    joints=np.minimum(pos_x,pos_y)
    data[joints<=1]-=20*seam_strength
    data[joints==2]-=11*seam_strength
    data[joints==3]+=4*seam_strength
    # Fine original dust marks; fade them close to borders so wrapping remains clean.
    for _ in range(22):
        x,y=rng.integers(7,249,2);length=int(rng.integers(2,9));strength=float(rng.uniform(-5,3))
        data[y,min(x,248):min(x+length,250)]+=strength
    data=np.clip(data,0,255).astype(np.uint8)
    data[:,-1]=data[:,0];data[-1,:]=data[0,:]
    tile=Image.fromarray(data,'RGB');tile.save(OUT/f'floor_{name}.png',optimize=True)
    assert np.array_equal(data[0],data[-1]) and np.array_equal(data[:,0],data[:,-1])
    print('created original aligned seamless floor',name)

# Small, contact-sized shadow: object masking hides the centre, leaving a
# restrained directional rim rather than the large floating black halo in v68.
mask=Image.new('L',(256,256));d=ImageDraw.Draw(mask)
d.rounded_rectangle((15,15,240,240),radius=25,fill=205)
mask=mask.filter(ImageFilter.GaussianBlur(10))
rgba=Image.new('RGBA',(256,256),(5,8,11,0));rgba.putalpha(mask)
rgba.save(OUT/'contact_shadow.png',optimize=True)

for name,colour in [('warm',(255,186,98)),('cool',(100,171,245))]:
    yy,xx=np.mgrid[:256,:256];r=np.sqrt(((xx-128)/128)**2+((yy-128)/128)**2)
    a=(np.maximum(0,1-r)**3.0*52).astype('uint8')
    a4=np.zeros((256,256,4),dtype='uint8');a4[:,:,:3]=colour;a4[:,:,3]=a
    Image.fromarray(a4,'RGBA').save(OUT/f'glow_{name}.png',optimize=True)

cap=Image.new('RGBA',(256,48),(0,0,0,0));d=ImageDraw.Draw(cap)
poly=[(0,7),(20,5),(42,8),(67,4),(86,6),(109,3),(134,6),(157,4),(180,7),(204,4),(230,6),(255,8),(255,23),(235,21),(214,26),(194,20),(173,25),(151,19),(129,24),(107,19),(84,24),(62,19),(41,23),(20,19),(0,22)]
d.polygon(poly,fill=(221,234,243,185));d.line(poly[:12],fill=(248,251,252,205),width=2)
cap.filter(ImageFilter.GaussianBlur(.7)).save(OUT/'snow_cap.png',optimize=True)
print('created cohesive contact shadow, restrained glows and snow accent')
