#!/usr/bin/env python3
"""Refine the 100 existing layouts with original 2.5D themed prop variants.

Run after the v0.6.9 authored-layout generator. This pass deliberately retains
every obstacle footprint, spawn, guard, route and reward from its input. It
changes visible prop kinds and moves floor lights off cover. The preceding
layout pass preserves level IDs, guard attributes/counts and rewards but may
reposition guards and obstacles for the newly designed maps.

Usage: python3 tools/refine_v69_scenery.py v069_geometry.json v069_levels.json
"""
from pathlib import Path
from collections import Counter
import json,random,sys
from repair_levels_v62 import CELL,geom,contains

VARIANTS={
 'warehouse':{
    'crate_green':['crate_green','crate_ammo','cargo_box'],
    'crate_steel':['crate_steel','crate_tool','cargo_stack'],
    'pallet':['pallet','pallet_boxes','pallet_plastic','storage_rack'],
    'barrel_red':['barrel_red','barrel_red','barrel_gray'],
 },
 'factory':{
    'crate_steel':['crate_steel','crate_tool','crate_steel'],
    'crate_hazard':['crate_hazard','crate_tool','crate_hazard'],
    'crate_metal':['crate_metal','storage_rack','crate_metal'],
    'barrel_blue':['barrel_blue','barrel_yellow','barrel_gray'],
    'barrel_red':['barrel_red','barrel_yellow','barrel_red'],
 },
 'dockyard':{
    'crate_hazard':['crate_hazard','cargo_box','cargo_stack'],
 },
 'military':{
    'crate_green':['crate_green','crate_ammo','crate_ammo'],
    'barrel_red':['barrel_red','barrel_gray','barrel_blue'],
 },
 'night':{
    'crate_green':['crate_green','crate_ammo','crate_tool'],
    'crate_steel':['crate_steel','crate_hazard','crate_tool'],
    'crate_hazard':['crate_hazard','crate_ammo','crate_tool'],
    'barrel_blue':['barrel_blue','barrel_gray','barrel_blue'],
 },
 'desert':{
    'crate_wood':['crate_wood','cargo_box','cargo_stack'],
 },
 'snow':{
    'crate_steel':['crate_steel','crate_green','crate_ammo'],
    'barrel_blue':['barrel_blue','barrel_gray','barrel_blue'],
 },
 'rooftop':{
    'crate_steel':['crate_steel','crate_tool','crate_ammo'],
    'crate_hazard':['crate_hazard','crate_tool','crate_hazard'],
 },
}

def clear_light(level,xy,prior):
    x,y=xy
    if not (2<=x<int(level['width'])-2 and 2<=y<int(level['height'])-2):return False
    p=((x+.5)*CELL,(y+.5)*CELL)
    if any(contains(geom(item),p,22.0) for item in level['walls']+level['crates']):return False
    if any((x-a)**2+(y-b)**2<16 for a,b in prior):return False
    if level.get('helipad'):
        hx,hy,rad=level['helipad']
        if abs(x+.5-hx)<=rad and abs(y+.5-hy)<=rad:return False
    return True

def main(source,target):
    doc=json.loads(source.read_text());before=json.loads(source.read_text())
    if len(doc['levels'])!=100 or doc.get('layout_revision') not in ('0.6.8-reference-sheet', '0.6.9-authored-layouts'):
        raise SystemExit('Expected the complete v0.6.8 or v0.6.9 authored 100-level catalog.')
    for level in doc['levels']:
        rng=random.Random(6900329+int(level['id'])*7919);theme=level['theme']
        for i,item in enumerate(level['crates']):
            # The starter cover remains identifiable and geometrically unchanged.
            if i==0:continue
            choices=VARIANTS.get(theme,{}).get(item[4]) if len(item)>=5 else None
            if choices:item[4]=rng.choice(choices)
        for detail in level.get('scenery_details',[]):
            if detail.get('kind')=='camera':detail['kind']='grate'
        prior=[];lights=[]
        for old in level.get('scenery_lights',[]):
            x,y=map(int,old)
            candidates=[(x+dx,y+dy) for dx in range(-5,6) for dy in range(-5,6)]
            candidates.sort(key=lambda p:((p[0]-x)**2+(p[1]-y)**2,p[1],p[0]))
            point=next((p for p in candidates if clear_light(level,p,prior)),None)
            if point is not None:lights.append(list(point));prior.append(point)
        level['scenery_lights']=lights
        if theme=='desert':
            for key in level.get('wall_kinds',{}):
                if int(key)%2:level['wall_kinds'][key]='wall_jersey'
    doc['layout_revision']='0.6.9-original-2.5d'
    # Validate semantic and physical invariants before writing.
    for a,b in zip(before['levels'],doc['levels']):
        assert a['id']==b['id'] and a['reward_cash']==b['reward_cash']
        assert a['spawn']==b['spawn'] and a['guards']==b['guards']
        assert a['walls']==b['walls'] and [r[:4] for r in a['crates']]==[r[:4] for r in b['crates']]
    target.write_text(json.dumps(doc,separators=(',',':'))+'\n')
    counts=Counter(p[4] for l in doc['levels'] for p in l['crates'])
    print('Refined 100 levels: preserved all obstacle rectangles, guards, routes, IDs and rewards.')
    print('Cohesive original prop distribution:',dict(sorted(counts.items())))
    print('Floor lamps:',sum(len(l.get('scenery_lights',[])) for l in doc['levels']))

if __name__=='__main__':
    if len(sys.argv)!=3:raise SystemExit(__doc__)
    main(Path(sys.argv[1]),Path(sys.argv[2]))
