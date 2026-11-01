#!/usr/bin/env python3
"""Prepare in-game scenery from the user's flattened 1536x1024 reference.

The output is a practical recreation, not the original separate game assets.
Sprites and dock containers are isolated from the supplied sheet, and floors
are made repeatable from its swatches. Some tiny preview details are resized,
recoloured or reconstructed; the originals are not recoverable from the sheet.
Requires Pillow, NumPy and OpenCV. Does not touch save data or recordings.

Usage: python3 tools/build_v68_environment.py [reference.png]
"""
from pathlib import Path
import sys
import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

PROJECT = Path(__file__).resolve().parents[1]
SOURCE = Path(sys.argv[1]) if len(sys.argv) > 1 else PROJECT / 'art_source/environment/v68_reference_sheet.png'
OUT = PROJECT / 'assets/environment/v68'
OUT.mkdir(parents=True, exist_ok=True)
image = Image.open(SOURCE).convert('RGB')
if image.size != (1536, 1024):
    raise SystemExit(f'Expected the user-provided 1536x1024 sheet, got {image.size}')

# Carefully cropped individual objects, not a flattened game map. Bounding
# rectangles are only from the supplied sheet; the pixels are not AI generated.
# Thresholds only isolate the exterior silhouette; interior pixels stay intact.
SPECS = {
    'crate_wood': ((25, 461, 118, 575), 31),
    'crate_wood_small': ((137, 458, 217, 555), 31),
    'crate_green': ((245, 456, 336, 555), 30),
    'crate_steel': ((365, 446, 447, 555), 30),
    'barrel_red': ((470, 447, 540, 562), 30),
    'barrel_blue': ((550, 449, 621, 561), 30),
    'crate_hazard': ((627, 455, 707, 555), 31),
    'pallet': ((21, 584, 152, 672), 28),
    'tires': ((174, 569, 259, 673), 30),
    'sandbags': ((276, 566, 430, 675), 30),
    'crate_camo': ((441, 565, 570, 675), 28),
    'crate_metal': ((585, 575, 702, 673), 28),
    'wall_concrete': ((1127, 78, 1306, 145), 27),
    'wall_hazard': ((1134, 173, 1279, 255), 28),
    'wall_barrier': ((1134, 270, 1270, 340), 27),
    'fence': ((1300, 193, 1398, 319), 27),
    'vent': ((337, 741, 413, 819), 28),
    'grate': ((244, 747, 313, 815), 28),
    'manhole': ((430, 742, 509, 820), 28),
    'camera': ((607, 736, 676, 819), 28),
    'lamp': ((535, 741, 581, 762), 35),
    'plant': ((38, 740, 111, 820), 28),
    'bush': ((135, 740, 217, 820), 28),
}


def extract(name, rect, threshold):
    crop = np.array(image.crop(rect))
    # A dark panel surrounds each asset. Keep the largest external shape, then
    # fill it; this avoids punching holes in tyres, mesh, metal and dark faces.
    v = crop.max(axis=2)
    binary = ((v > threshold) * 255).astype(np.uint8)
    binary = cv2.morphologyEx(binary, cv2.MORPH_CLOSE, np.ones((3, 3), np.uint8), iterations=1)
    contours, _ = cv2.findContours(binary, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    if not contours:
        raise RuntimeError(f'No foreground found for {name}')
    contour = max(contours, key=cv2.contourArea)
    mask = np.zeros(v.shape, dtype=np.uint8)
    cv2.drawContours(mask, [contour], -1, 255, thickness=-1)
    # Subpixel antialiasing without a halo of opaque background pixels.
    mask = cv2.GaussianBlur(mask, (3, 3), 0.42)
    rgba = Image.fromarray(np.dstack((crop, mask)), 'RGBA')
    box = rgba.getchannel('A').getbbox()
    if not box or (box[2]-box[0]) < 15 or (box[3]-box[1]) < 12:
        raise RuntimeError(f'Implausibly small silhouette for {name}: {box}')
    rgba = rgba.crop(box)
    # Pixel-based art stays true to the reference while being usable at a
    # moderate range of game scales.
    longest = max(rgba.size)
    factor = min(3.0, max(1.0, 256.0 / longest))
    rgba = rgba.resize((round(rgba.width * factor), round(rgba.height * factor)), Image.Resampling.LANCZOS)
    rgba.save(OUT / f'{name}.png', optimize=True)
    print('extracted', name, rgba.size, 'from', rect)


for name, (rect, threshold) in SPECS.items():
    extract(name, rect, threshold)

# One industrial pipe is isolated from the small factory reference; its exact
# outline is hand-masked because the background there is another floor tile,
# not the dark blank panel used for individual icons.
pipe = image.crop((969, 430, 986, 500)).convert('RGBA')
pipe_mask = Image.new('L', pipe.size, 0)
ImageDraw.Draw(pipe_mask).polygon([(2,0),(15,0),(16,49),(15,58),(12,66),(9,69),(5,67),(2,62),(1,55),(1,5)], fill=255)
pipe_mask = pipe_mask.filter(ImageFilter.GaussianBlur(0.45))
pipe.putalpha(pipe_mask)
pipe = pipe.resize((92, 280), Image.Resampling.LANCZOS)
pipe.save(OUT / 'pipe_v.png', optimize=True)
pipe.transpose(Image.Transpose.ROTATE_90).save(OUT / 'pipe_h.png', optimize=True)


def mirrored_surface(crop, brightness=1.0):
    patch = image.crop(crop).resize((128, 128), Image.Resampling.LANCZOS)
    patch = ImageEnhance.Brightness(patch).enhance(brightness)
    result = Image.new('RGB', (256, 256))
    result.paste(patch, (0, 0))
    result.paste(patch.transpose(Image.Transpose.FLIP_LEFT_RIGHT), (128, 0))
    result.paste(patch.transpose(Image.Transpose.FLIP_TOP_BOTTOM), (0, 128))
    result.paste(patch.transpose(Image.Transpose.ROTATE_180), (128, 128))
    return result


def tint(source, colour, amount):
    overlay = Image.new('RGB', source.size, colour)
    return Image.blend(source, overlay, amount)


def grid_tile(surface, strength=74, accent=(24, 27, 31)):
    # Reference examples have fine square joints. Two softly lit joints in
    # each 256-pixel pattern make the reference's small tile scale.
    rgba = surface.convert('RGBA')
    line = Image.new('RGBA', rgba.size)
    d = ImageDraw.Draw(line)
    for x in (0, 128, 255):
        d.line((x, 0, x, 255), fill=(*accent, strength), width=2)
        if x < 254:
            d.line((x+2, 0, x+2, 255), fill=(220, 214, 207, 16), width=1)
    for y in (0, 128, 255):
        d.line((0, y, 255, y), fill=(*accent, strength), width=2)
        if y < 254:
            d.line((0, y+2, 255, y+2), fill=(220, 214, 207, 16), width=1)
    rgba = Image.alpha_composite(rgba, line).convert('RGB')
    a = np.array(rgba)
    # Exact wrap boundaries prevent hairline seams on the tiled floor.
    a[:, -1] = a[:, 0]
    a[-1, :] = a[0, :]
    return Image.fromarray(a)


gray = mirrored_surface((692, 88, 766, 176), 1.17)
desert = mirrored_surface((906, 208, 980, 296), 1.10)
FLOORS = {
    'warehouse': grid_tile(gray),
    'factory': grid_tile(tint(gray, (75, 78, 78), 0.12), 79),
    'dockyard': grid_tile(tint(gray, (70, 91, 115), 0.22), 75),
    'military': grid_tile(tint(gray, (87, 92, 74), 0.20), 68),
    'night': grid_tile(tint(gray, (8, 35, 66), 0.68), 93, (2, 11, 23)),
    'desert': grid_tile(tint(desert, (195, 153, 95), 0.15), 36, (92, 66, 39)),
    'snow': grid_tile(tint(gray, (215, 229, 242), 0.75), 29, (81, 105, 129)),
    'rooftop': grid_tile(tint(gray, (88, 95, 110), 0.33), 84),
}
for name, floor in FLOORS.items():
    floor.save(OUT / f'floor_{name}.png', optimize=True)
    a = np.array(floor)
    assert np.array_equal(a[0], a[-1]) and np.array_equal(a[:, 0], a[:, -1])
    print('created seamless floor', name, floor.size)

# The sheet contains a small dockyard preview, not separate large container
# sprites. Isolate its actual blue/red horizontal and blue vertical surfaces;
# derive the vertical red variant by applying the reference red hue to the blue
# crop. Resize and add edge accents. No prior project art is used for these.
container_crops = {
    'blue_h': (1164, 429, 1233, 470),
    'red_h': (1240, 429, 1314, 470),
    'blue_v': (1265, 528, 1300, 620),
}
containers = {name: image.crop(rect) for name, rect in container_crops.items()}
blue_hsv = cv2.cvtColor(np.array(containers['blue_v']), cv2.COLOR_RGB2HSV)
red_hsv = cv2.cvtColor(np.array(containers['red_h']), cv2.COLOR_RGB2HSV)
blue_hsv[:, :, 0] = np.uint8(np.median(red_hsv[:, :, 0]))
blue_hsv[:, :, 1] = np.clip(blue_hsv[:, :, 1].astype('float32') * 1.2, 0, 255).astype('uint8')
containers['red_v'] = Image.fromarray(cv2.cvtColor(blue_hsv, cv2.COLOR_HSV2RGB))
for name, body in containers.items():
    size = (384, 128) if name.endswith('_h') else (128, 384)
    body = body.resize(size, Image.Resampling.LANCZOS)
    body = body.filter(ImageFilter.UnsharpMask(radius=1.4, percent=90, threshold=2))
    d = ImageDraw.Draw(body, 'RGBA')
    d.rectangle((0, 0, size[0] - 1, size[1] - 1), outline=(8, 13, 21, 150), width=3)
    d.line((4, 3, size[0] - 5, 3), fill=(220, 224, 218, 75), width=2)
    d.line((4, size[1] - 4, size[0] - 5, size[1] - 4), fill=(5, 8, 13, 100), width=3)
    body.save(OUT / f'container_{name}.png', optimize=True)

# Lamps are purely decorative and use a gentle premultiplied-looking radial
# alpha field. The guard flashlight remains a separate, unchanged game object.
for name, colour in [('warm', (255, 177, 76)), ('cool', (100, 177, 255))]:
    size = 256
    yy, xx = np.mgrid[:size, :size]
    r = np.sqrt(((xx-size/2)/(size/2))**2 + ((yy-size/2)/(size/2))**2)
    alpha = (np.maximum(0, 1-r)**2.4 * 88).astype('uint8')
    rgba = np.zeros((size, size, 4), dtype='uint8')
    rgba[:, :, :3] = colour
    rgba[:, :, 3] = alpha
    Image.fromarray(rgba, 'RGBA').save(OUT / f'glow_{name}.png', optimize=True)

print(f'Created {len(list(OUT.glob("*.png")))} environment textures in {OUT}')

# Contact shadows and the snow cap are decorative overlays and are never used
# for physical collision or stealth calculations.
size = 256
yy, xx = np.mgrid[:size, :size]
r = np.sqrt(((xx-size/2)/(size/2))**2 + ((yy-size/2)/(size/2))**2)
rgba = np.zeros((size,size,4), dtype='uint8')
rgba[:,:,3] = (np.maximum(0,1-r)**1.6 * 220).astype('uint8')
Image.fromarray(rgba,'RGBA').save(OUT/'shadow_soft.png', optimize=True)
cap = Image.new('RGBA',(256,80),(0,0,0,0))
cd = ImageDraw.Draw(cap)
poly=[(0,7),(16,5),(32,7),(48,3),(65,4),(82,1),(101,4),(122,2),(142,5),(161,3),(183,5),(203,2),(223,5),(239,4),(255,7),(255,35),(242,33),(231,40),(218,32),(201,37),(184,29),(167,34),(147,27),(125,32),(110,25),(91,30),(70,24),(52,29),(35,23),(19,29),(0,24)]
cd.polygon(poly,fill=(224,239,250,205))
cd.line(poly[:14],fill=(250,252,255,240),width=3)
cap = cap.filter(ImageFilter.GaussianBlur(0.6))
cap.save(OUT/'snow_cap.png', optimize=True)
print('Created contact shadow and snow overlay')
