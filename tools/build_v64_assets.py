#!/usr/bin/env python3
"""Build v0.6.4 floor, key and individual head layers reproducibly.

The new original concepts live in art_source; the existing reference art is
unchanged. Requires Pillow, NumPy and OpenCV only when regenerating assets.
"""
from pathlib import Path
import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'assets'
REF = ASSETS / 'reference'


def save(image, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, optimize=True)


def floor():
    image = Image.open(ROOT/'art_source/environment/v64_floor_concept.webp').convert('RGB').resize((512,512), Image.Resampling.LANCZOS)
    a = np.asarray(image, dtype=np.float32).copy()
    # Feather the opposite borders into one another to suppress tile seams.
    for i in range(48):
        factor = (1.0 - i/48.0)**2
        mean = (a[:,i,:] + a[:,-i-1,:]) * .5
        a[:,i,:] = a[:,i,:]*(1-factor) + mean*factor
        a[:,-i-1,:] = a[:,-i-1,:]*(1-factor) + mean*factor
    for i in range(48):
        factor = (1.0 - i/48.0)**2
        mean = (a[i,:,:] + a[-i-1,:,:]) * .5
        a[i,:,:] = a[i,:,:]*(1-factor) + mean*factor
        a[-i-1,:,:] = a[-i-1,:,:]*(1-factor) + mean*factor
    save(Image.fromarray(np.uint8(np.clip(a,0,255)), 'RGB'), ASSETS/'environment/v64/herringbone.png')


def secret_character():
    image = Image.open(ROOT/'art_source/characters/vault_phantom_topdown.webp').convert('RGB')
    rgb = np.asarray(image, dtype=np.float32)
    # Remove the intentionally flat magenta backdrop, including its antialias.
    strength = np.minimum(rgb[:,:,0], rgb[:,:,2]) - rgb[:,:,1]
    alpha = np.clip((130.0-strength)/100.0,0,1)
    # Remove magenta spill from dark antialiased edge pixels without altering
    # the blue/teal/gold materials inside the silhouette.
    spill = (strength > 7) & (rgb[:,:,1] < 70) & (np.abs(rgb[:,:,0]-rgb[:,:,2]) < 45)
    rgb[:,:,0] = np.where(spill, np.minimum(rgb[:,:,0], rgb[:,:,1] + 7), rgb[:,:,0])
    rgb[:,:,2] = np.where(spill, np.minimum(rgb[:,:,2], rgb[:,:,1] + 7), rgb[:,:,2])
    rgba = np.dstack((rgb,alpha*255)).astype(np.uint8)
    result = Image.fromarray(rgba,'RGBA')
    bbox = result.getbbox()
    if not bbox:
        raise RuntimeError('No secret-character pixels detected')
    result = result.crop(bbox)
    canvas = Image.new('RGBA',(result.width+48,result.height+48),(0,0,0,0))
    canvas.alpha_composite(result,(24,24))
    canvas.thumbnail((248,156),Image.Resampling.LANCZOS)
    final = Image.new('RGBA',(248,156),(0,0,0,0))
    final.alpha_composite(canvas,((248-canvas.width)//2,(156-canvas.height)//2))
    save(final, REF/'characters/vault_phantom.png')
    return final


def split_head(image, center, radius, body_path, head_path):
    image = image.convert('RGBA')
    w,h = image.size
    # Supersampled ellipse softly follows the original visible head. An
    # inpainted underlay supports slight head movement without a double image.
    scale = 4
    stencil = Image.new('L',(w*scale,h*scale),0)
    d = ImageDraw.Draw(stencil)
    cx,cy = center;rx,ry = radius
    d.ellipse(((cx-rx)*scale,(cy-ry)*scale,(cx+rx)*scale,(cy+ry)*scale),fill=255)
    stencil = stencil.resize((w,h),Image.Resampling.LANCZOS).filter(ImageFilter.GaussianBlur(.55))
    mask = np.asarray(stencil,dtype=np.float32)/255.0
    rgba = np.asarray(image,dtype=np.uint8)
    support = (np.asarray(stencil)>128).astype(np.uint8)*255
    # Inpaint RGB only; keep the original silhouette alpha of the body.
    fill = cv2.inpaint(np.ascontiguousarray(rgba[:,:,:3]),support,3,cv2.INPAINT_TELEA)
    under = rgba.copy()
    under[:,:,:3] = np.clip(rgba[:,:,:3]*(1-mask[:,:,None]) + fill*mask[:,:,None],0,255).astype(np.uint8)
    head = rgba.copy()
    head[:,:,3] = np.clip(rgba[:,:,3]*mask,0,255).astype(np.uint8)
    save(Image.fromarray(under,'RGBA'),body_path)
    save(Image.fromarray(head,'RGBA'),head_path)


def heads(secret):
    for index in range(1,13):
        src = Image.open(REF/f'characters/parts/{index:02d}_body.png').convert('RGBA')
        w,h = src.size
        center=(w*.66,h*.42);radius=(w*.16,h*.22)
        split_head(src,center,radius,REF/f'characters/parts/v64_{index:02d}_body.png',REF/f'characters/parts/v64_{index:02d}_head.png')
    for name in ('guard','elite'):
        src=Image.open(REF/f'guards/parts/{name}_body.png').convert('RGBA')
        w,h=src.size
        center=(w*.44,h*.57);radius=(w*.21,h*.21)
        split_head(src,center,radius,REF/f'guards/parts/v64_{name}_body.png',REF/f'guards/parts/v64_{name}_head.png')
    w,h=secret.size
    split_head(secret,(w*.66,h*.42),(w*.16,h*.22),REF/'characters/parts/v64_vault_body.png',REF/'characters/parts/v64_vault_head.png')


def key_icon():
    im=Image.new('RGBA',(256,256),(0,0,0,0));d=ImageDraw.Draw(im)
    # Slight shadow, heavy dark outline, gold shaft and a hollow bow.
    d.line([(92,106),(190,204)],fill=(30,20,4,180),width=34)
    d.line([(90,100),(188,198)],fill=(54,35,7,255),width=30)
    d.line([(90,100),(188,198)],fill=(244,174,30,255),width=22)
    d.line([(88,95),(180,187)],fill=(255,222,99,255),width=7)
    d.polygon([(159,168),(192,164),(204,176),(184,188),(206,190),(215,203),(190,216),(170,196)],fill=(70,44,5,255))
    d.polygon([(162,170),(190,170),(198,176),(180,189),(202,193),(208,201),(191,210),(169,193)],fill=(247,177,32,255))
    d.ellipse((34,30,120,116),fill=(57,36,7,255));d.ellipse((40,36,114,110),fill=(255,193,47,255))
    d.ellipse((53,49,101,97),fill=(97,61,7,255));d.ellipse((60,56,94,90),fill=(0,0,0,0))
    d.arc((44,40,111,107),190,285,fill=(255,239,160,255),width=5)
    save(im.resize((96,96),Image.Resampling.LANCZOS),ASSETS/'ui/v64_key.png')


def main():
    floor(); secret=secret_character(); heads(secret); key_icon()
    print('Built v0.6.4 tile, original secret character, independent head layers and gold key.')

if __name__=='__main__':main()
