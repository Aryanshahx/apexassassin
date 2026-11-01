#!/usr/bin/env python3
"""Crop original Blender renders to their visible extents for collider alignment.

Run after render_v69_props.py. Floor tiles and overlays are deliberately left
unchanged. An extra transparent pixel protects antialiasing and anchors each
sprite's visible bounds to the 2D obstacle rectangle.
"""
from pathlib import Path
from PIL import Image

OUT=Path(__file__).resolve().parents[1]/'assets/environment/v69'
names='''crate_wood crate_wood_small crate_steel crate_green crate_ammo crate_tool crate_hazard crate_metal crate_camo cargo_box cargo_stack barrel_red barrel_blue barrel_yellow barrel_gray pallet pallet_boxes pallet_plastic sandbags tires fence pipe_v pipe_h container_blue_h container_blue_v container_red_h container_red_v wall_concrete_h wall_concrete_v wall_hazard_h wall_hazard_v wall_jersey_h wall_jersey_v vent grate manhole lamp plant bush storage_rack'''.split()
for name in names:
    path=OUT/(name+'.png');image=Image.open(path).convert('RGBA')
    a=image.getchannel('A');box=a.point(lambda x:255 if x>3 else 0).getbbox()
    if box is None:raise SystemExit(f'Empty rendered sprite: {name}')
    l,t,r,b=box;bounds=(max(l-2,0),max(t-2,0),min(r+2,image.width),min(b+2,image.height))
    cropped=image.crop(bounds);cropped.save(path,optimize=True)
    print(name,image.size,'->',cropped.size)
print('Finalized',len(names),'original sprites')
