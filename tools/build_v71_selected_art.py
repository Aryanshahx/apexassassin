#!/usr/bin/env python3
"""Build compact playable sprites from the user's selected AI art choices.

Requires Pillow and NumPy. Raw selected images are kept separately under
art_source/v71-selected for reproducibility and are not required at runtime.
The chosen rectangular wall/crate sprites had a baked checkerboard background;
only their actual image footprints are cropped, never the fake checkerboard.
All additional variants are deterministic derivatives/procedural drawings.
"""
from pathlib import Path
import argparse, hashlib, json, math
import numpy as np
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageOps

ROOT=Path(__file__).resolve().parents[1]
SRC=ROOT/'art_source/v71-selected'
DST=ROOT/'assets/environment/v71'
THEMES=('warehouse','factory','dockyard','military','night','desert','snow','rooftop')
RESAMPLE=Image.Resampling.LANCZOS

def save(im,name):
    DST.mkdir(parents=True,exist_ok=True)
    im.save(DST/name,optimize=True)

def source(n):
    p=SRC/('selected_'+n+'.png')
    if not p.is_file():raise FileNotFoundError(p)
    return Image.open(p).convert('RGB')

def dim_scale(im,colour,strength=0.35,bright=1.0):
    base=ImageEnhance.Brightness(im.convert('RGB')).enhance(bright)
    tint=Image.new('RGB',base.size,colour)
    return Image.blend(base,tint,strength)

def square_material():
    raw=source('floor')
    # Pick the interior of a tile in the approved texture, excluding the AI's
    # irregular joints; mirror it to guarantee exact repeatable outer edges.
    patch=raw.crop((1107,918,1179,980)).resize((128,128),RESAMPLE)
    tile=Image.new('RGB',(256,256))
    tile.paste(patch,(0,0));tile.paste(ImageOps.mirror(patch),(128,0))
    tile.paste(ImageOps.flip(patch),(0,128));tile.paste(ImageOps.flip(ImageOps.mirror(patch)),(128,128))
    d=ImageDraw.Draw(tile)
    for k in (0,128):
        d.line((k,0,k,255),fill=(54,52,53),width=2)
        d.line((0,k,255,k),fill=(54,52,53),width=2)
        d.line((k+2,0,k+2,255),fill=(96,93,92),width=1)
        d.line((0,k+2,255,k+2),fill=(96,93,92),width=1)
    # Match opposite edge texels so bilinear texture repeat has no seam.
    a=np.asarray(tile).copy()
    a[:,-1]=a[:,0]
    a[-1,:]=a[0,:]
    return Image.fromarray(a,'RGB')

def make_floor():
    base=square_material()
    styles={
      'warehouse':((92,90,87),0.03,1.0),
      'factory':((84,91,96),0.18,0.96),
      'dockyard':((74,102,111),0.26,1.0),
      'military':((90,103,75),0.30,1.03),
      'night':((41,62,88),0.38,0.86),
      'desert':((164,137,92),0.48,1.22),
      'snow':((202,216,224),0.57,1.30),
      'rooftop':((93,110,133),0.27,1.02),
    }
    for theme,(tint,strength,brightness) in styles.items():save(dim_scale(base,tint,strength,brightness),f'floor_{theme}.png')


def crop_chroma(im):
    rgb=np.asarray(im).astype(np.int16);r,g,b=rgb[:,:,0],rgb[:,:,1],rgb[:,:,2]
    magenta=(r>140)&(b>95)&((r-g)>45)&((b-g)>35)
    mask=Image.fromarray(np.where(magenta,0,255).astype(np.uint8),'L')
    # Clear tiny keying noise without expanding the visible footprint.
    mask=mask.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.MaxFilter(3))
    bbox=mask.getbbox()
    if not bbox:raise ValueError('No foreground in selected art')
    out=im.convert('RGBA');out.putalpha(mask);out=out.crop(bbox)
    # Restrict output texture size while retaining aspect and alpha.
    out.thumbnail((512,512),RESAMPLE)
    return out


def recolour_rgba(im,tint,strength):
    rgb=Image.blend(im.convert('RGB'),Image.new('RGB',im.size,tint),strength)
    rgb.putalpha(im.getchannel('A'));return rgb


def crate_recolour(im,dark,light,amount=0.72):
    grey=ImageOps.grayscale(im.convert('RGB'))
    color=ImageOps.colorize(grey,dark,light)
    return Image.blend(im.convert('RGB'),color,amount).convert('RGBA')


def make_props():
    crate=source('cover_crate').crop((255,220,770,733)).resize((512,512),RESAMPLE).convert('RGBA')
    save(crate,'crate_wood.png')
    variants={
      'crate_green.png':('#161e15','#a6b777'),
      'crate_blue.png':('#142434','#9abbd2'),
      'crate_tan.png':('#302016','#dfbe86'),
      'crate_red.png':('#301c1b','#d4856d'),
      'crate_steel.png':('#151e27','#a2b2bf'),
    }
    for name,(dark,light) in variants.items():
        img=crate_recolour(crate,dark,light)
        if name=='crate_steel.png':
            d=ImageDraw.Draw(img)
            for x,y in [(31,31),(480,31),(31,480),(480,480)]:
                d.ellipse((x-8,y-8,x+8,y+8),fill='#606e79',outline='#11191e',width=3)
                d.line((x-4,y,x+4,y),fill='#c5d2d7',width=2)
        save(img,name)
    # Only solid wall pixels are used, excluding the selected image's baked
    # checkerboard. A vertical version is an exact 90-degree rotation.
    wall=source('wall').crop((36,342,1228,510)).resize((1024,144),RESAMPLE).convert('RGBA')
    save(wall,'wall_h.png');save(wall.transpose(Image.Transpose.ROTATE_90),'wall_v.png')
    barrel=crop_chroma(source('barrel'))
    save(barrel,'barrel_red.png')
    for name,color,amount in [('barrel_blue.png',(55,115,170),0.68),('barrel_yellow.png',(214,171,40),0.60),('barrel_gray.png',(123,128,132),0.78)]:
        save(recolour_rgba(barrel,color,amount),name)
    bags=crop_chroma(source('sandbag_cover'));save(bags,'sandbags.png')
    # Additional category-matched details are new procedural sprites. They are
    # cosmetic unless placed on a matching blocking rectangle.
    pallet=Image.new('RGBA',(512,256),(0,0,0,0));d=ImageDraw.Draw(pallet)
    d.rounded_rectangle((10,14,502,242),radius=12,fill='#5b381f',outline='#271b12',width=9)
    for y in (30,90,150,210):
        d.rounded_rectangle((24,y,488,y+32),radius=3,fill='#b5824d',outline='#3b2616',width=5)
        for x in (42,470):d.ellipse((x-4,y+13,x+4,y+21),fill='#3a2b1d')
    save(pallet,'pallet.png')
    # For small round barrels, the visible pallet base fills the blocking box
    # so the cover's rectangular collision does not have invisible corners.
    stack=pallet.copy();barr=barrel.copy();barr.thumbnail((165,205),RESAMPLE)
    for x in (72,205,338):stack.alpha_composite(barr,(x,25))
    save(stack,'barrel_pallet.png')
    tire=Image.new('RGBA',(256,256),(0,0,0,0));d=ImageDraw.Draw(tire)
    for shrink in (4,12,20):d.ellipse((shrink,shrink,255-shrink,255-shrink),fill='#191d20',outline='#343a3d',width=7)
    d.ellipse((84,84,172,172),fill='#090d10',outline='#565b5d',width=6)
    save(tire,'tire.png')
    grate=Image.new('RGBA',(256,256),(0,0,0,0));d=ImageDraw.Draw(grate)
    d.rounded_rectangle((7,7,249,249),radius=6,fill='#353c40',outline='#111619',width=8)
    for x in range(35,230,30):d.line((x,25,x,231),fill='#89959a',width=7)
    save(grate,'floor_grate.png')
    # Selected hazard tile: extract an actual stripe band as a floor decal.
    hazard=source('hazard_tile')
    bw,bh=hazard.size
    band=hazard.crop((0,int(bh*0.407),int(bw*0.64),int(bh*0.50))).resize((512,72),RESAMPLE)
    save(band.convert('RGBA'),'hazard_mark_h.png')
    save(band.convert('RGBA').transpose(Image.Transpose.ROTATE_90),'hazard_mark_v.png')
    lamp=Image.new('RGBA',(256,96),(0,0,0,0));d=ImageDraw.Draw(lamp)
    d.rounded_rectangle((8,15,248,82),radius=25,fill='#47494a',outline='#202629',width=9)
    d.rounded_rectangle((27,30,229,67),radius=12,fill='#e6cf95',outline='#afa274',width=3)
    save(lamp,'lamp.png')
    # Original radial warm light; this is a floor-only visual, not a blocker.
    size=256; yy,xx=np.mgrid[0:size,0:size]; rr=np.sqrt((xx-(size-1)/2)**2+(yy-(size-1)/2)**2)/(size/2)
    alpha=np.clip((1.0-rr)**2*55,0,55).astype(np.uint8)
    rgba=np.zeros((size,size,4),dtype=np.uint8);rgba[:,:,0]=255;rgba[:,:,1]=197;rgba[:,:,2]=116;rgba[:,:,3]=alpha
    save(Image.fromarray(rgba,'RGBA'),'glow_warm.png')


def main():
    global SRC,DST
    parser=argparse.ArgumentParser();parser.add_argument('--source',default=str(SRC));parser.add_argument('--output',default=str(DST));args=parser.parse_args()
    SRC=Path(args.source);DST=Path(args.output);DST.mkdir(parents=True,exist_ok=True)
    make_floor();make_props()
    files=sorted(DST.glob('*.png'))
    print('Built',len(files),'compact textures from the selected art categories:',sum(p.stat().st_size for p in files),'bytes')
    print('SHA-256:',hashlib.sha256(b''.join(p.name.encode()+p.read_bytes() for p in files)).hexdigest())
if __name__=='__main__':main()
