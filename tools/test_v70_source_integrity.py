#!/usr/bin/env python3
"""Independent catalog, supplied-asset and source-tile integrity checks."""
from pathlib import Path
import collections, hashlib, json, math, re, sys
ROOT=Path(__file__).resolve().parents[1]
S=ROOT/'data/source_maps/v70'

def verify_manifest():
    checked=0
    for line in (S/'source-manifest.sha256').read_text().splitlines():
        digest,name=line.split('  ',1)
        p=ROOT/name
        assert p.is_file(),name
        assert hashlib.sha256(p.read_bytes()).hexdigest()==digest,name
        checked+=1
    assert checked==217,checked
    return checked

def grids():
    maps={};key=None
    for line in (S/'RemoteMaps.txt').read_text().splitlines():
        line=line.strip()
        if re.fullmatch(r'ID[A-Z]+\d+',line):
            key=line;maps[key]=[]
        elif key and ',' in line:
            maps[key].append([x for x in line.split(',') if x])
    return maps

def inside(a,x,y,margin=4):
    cx=(float(a[0])+float(a[2])/2)*32;cy=(float(a[1])+float(a[3])/2)*32
    w=(float(a[2])*32+6)*1.2;h=(float(a[3])*32+6)*1.2
    return cx-w/2-margin<=x<cx+w/2+margin and cy-h/2-margin<=y<cy+h/2+margin

def main():
    files=verify_manifest()
    old=json.loads((S/'v069-level-catalog.json').read_text())['levels']
    config=json.loads((S/'recovered_remote_config.json').read_text())['remoteMaps']
    actual=json.loads((ROOT/'data/levels/levels.json').read_text())['levels']
    maps=grids()
    assert len(old)==len(config)==len(actual)==100 and len(maps)==45
    tile_checks=0;guards=0;errors=[];pairs=set();themes=collections.Counter()
    for prev,src,lv in zip(old,config,actual):
        assert prev['id']==src['baseLevel']==lv['id']
        assert prev['name']==lv['name'] and prev['reward_cash']==lv['reward_cash']
        assert prev['theme']==lv['theme'] and prev['theme_name']==lv['theme_name']
        assert len(prev['guards'])==len(lv['guards'])
        for a,b in zip(prev['guards'],lv['guards']):
            assert {k:v for k,v in a.items() if k not in ('x','y','route')} == {k:v for k,v in b.items() if k not in ('x','y','route')}
            guards+=1
        assert lv['source_map_id']==src['mapId']
        assert lv['source_flip_x']==bool(src.get('flipX')) and lv['source_flip_y']==bool(src.get('flipY'))
        assert lv['source_door_count']==len(src.get('doors',[]))
        assert lv['source_chest_count']==len(src.get('chests',[]))
        assert lv['source_trap_count']==len(src.get('laserTraps',[]))+len(src.get('freezeTraps',[]))
        assert lv['source_guard_hints_used']==len(lv['source_guard_hint_errors'])
        errors += lv['source_guard_hint_errors']
        pairs.add((src['mapId'],bool(src.get('flipX')),bool(src.get('flipY'))));themes[lv['theme']]+=1
        raw=maps[src['mapId']];grid=[list(reversed(r)) if src.get('flipX') else r[:] for r in raw]
        if src.get('flipY'):grid.reverse()
        assert lv['source_grid_size']==[len(grid[0]),len(grid)]
        assert lv['width']==2+2*len(grid[0]) and lv['height']==2+2*len(grid)
        grass=[]
        for y,row in enumerate(grid):
            for x,t in enumerate(row):
                # Centre of one supplied 64-unit cell. Physical blocker geometry
                # is independently calculated from saved level rectangles.
                px=(2+2*x)*32;py=(2+2*y)*32
                wall=any(inside(a,px,py) for a in lv['walls'])
                box=any(inside(a,px,py) for a in lv['crates'])
                assert wall==(t in ('XX','NN','EE')), (lv['id'],x,y,t,'wall',wall)
                assert box==(t=='BB'), (lv['id'],x,y,t,'box',box)
                if t=='::':grass.append([x,y])
                tile_checks+=1
        assert lv['source_grass']==grass
    assert guards==1064 and len(pairs)==64 and len(themes)==8
    print(f'SOURCE INTEGRITY {files} supplied files matched SHA-256; {tile_checks} source cells matched collision roles; 100 IDs/rewards and {guards} guard non-position attributes retained; {len(pairs)} source map/flip pairs; {len(errors)} guard hints, mean displacement {sum(errors)/len(errors):.2f} units')

if __name__=='__main__':main()
