#!/usr/bin/env python3
"""Build warehouse texture pieces from the user-supplied reference screenshot.

The screenshot remains unchanged in art_source. This optional rebuild needs
Pillow, NumPy and OpenCV; they are not required for playing the shipped game.
"""
from pathlib import Path
import cv2
import numpy as np
from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'art_source/environment/v65_user_warehouse_reference.jpg'
OUT = ROOT / 'assets/environment/v65'


def save(image, name):
    OUT.mkdir(parents=True, exist_ok=True)
    image.save(OUT / name, optimize=True)


def mirrored_tile(image):
    # Reflections join edge-to-edge without a distracting rectangular seam.
    image = image.convert('RGB')
    w,h = image.size
    canvas = Image.new('RGB',(w*2,h*2))
    canvas.paste(image,(0,0))
    canvas.paste(ImageOps.mirror(image),(w,0))
    canvas.paste(ImageOps.flip(image),(0,h))
    canvas.paste(ImageOps.flip(ImageOps.mirror(image)),(w,h))
    return canvas


def main():
    original = Image.open(SOURCE).convert('RGB')
    if original.size != (640,1400):
        raise SystemExit('Expected the user-provided 640x1400 warehouse reference')
    # An otherwise clear area of the reference floor contains a thin orange
    # movement arrow. Remove only the arrow, leaving the surrounding floor.
    floor = np.array(original.crop((120,610,326,741)))
    hsv = cv2.cvtColor(floor, cv2.COLOR_RGB2HSV)
    mask = (((hsv[:,:,0] < 26) & (hsv[:,:,1] > 125) & (hsv[:,:,2] > 135)).astype('uint8') * 255)
    # Include the dark outline of the orange arrow as well as its bright core.
    cv2.fillPoly(mask,[np.array([[106,0],[125,0],[167,130],[146,130]],dtype=np.int32)],255)
    mask = cv2.dilate(mask,np.ones((5,5),np.uint8),iterations=1)
    floor = cv2.inpaint(floor,mask,5,cv2.INPAINT_TELEA)
    floor = floor[:,:195]  # keep the neighbouring crate shadow out of the tile
    save(mirrored_tile(Image.fromarray(floor)), 'reference_floor_blue.png')
    # A clean gray herringbone patch, with blue overlaid in the renderer.
    save(mirrored_tile(original.crop((402,1055,462,1158))), 'reference_floor.png')
    # Separate gray brick interior used between the two green partitions.
    save(mirrored_tile(original.crop((150,285,235,355))), 'reference_room_floor.png')
    # Screenshot crops used as live textures rather than a flattened whole
    # screenshot: actors, paths, gates and collisions are independent nodes.
    crops = {
        'green_wall.png': (112,175,457,237),
        'green_panel.png': (40,241,111,322),
        'gate.png': (181,464,258,535),
        'red_container.png': (257,100,399,172),
        'orange_hazard.png': (397,605,471,675),
        'brown_crate.png': (470,676,544,750),
        'strapped_stack.png': (468,886,618,1037),
        'orange_crate.png': (329,1167,398,1238),
        'red_vertical.png': (256,240,334,402),
    }
    for name,box in crops.items():
        save(original.crop(box),name)
    green=original.crop(crops['green_wall.png'])
    save(green.rotate(90,expand=True),'green_wall_vertical.png')
    print('Built',len(crops)+4,'warehouse floor, wall, gate and crate textures from the supplied reference.')


if __name__ == '__main__':
    main()
