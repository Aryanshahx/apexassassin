#!/usr/bin/env python3
"""Independent supplied-grid, source roster, generated-art and metadata checks."""
from pathlib import Path
from collections import Counter
import hashlib, json, math, re
ROOT=Path(__file__).resolve().parents[1]
S=ROOT/'data/source_maps/v70'

def verify_manifest():
    checked=0
    for line in (S/'source-manifest.sha256').read_text().splitlines():
        digest,name=line.split('  ',1);p=ROOT/name
        assert p.is_file() and hashlib.sha256(p.read_bytes()).hexdigest()==digest,name
        checked+=1
    assert checked==217
    return checked

def grids():
    out={};key=None
    for line in (S/'RemoteMaps.txt').read_text().splitlines():
        line=line.strip()
        if re.fullmatch(r'ID[A-Z]+\d+',line):key=line;out[key]=[]
        elif key and ',' in line:out[key].append([x for x in line.split(',') if x])
    return out

def rect(item):
    x,y,w,h=map(float,item[:4]);cx=(x+w/2)*32;cy=(y+h/2)*32
    width=(w*32+6)*1.2;height=(h*32+6)*1.2
    return (cx-width/2,cy-height/2,cx+width/2,cy+height/2)
def contains(r,x,y):return r[0]<=x<r[2] and r[1]<=y<r[3]

def main():
    checked=verify_manifest();src=grids()
    cfg=json.loads((S/'recovered_remote_config.json').read_text())['remoteMaps']
    old=json.loads((S/'v069-level-catalog.json').read_text())['levels']
    actual=json.loads((ROOT/'data/levels/levels.json').read_text())['levels']
    assert len(src)==45 and len(cfg)==len(old)==len(actual)==100
    sampled=0;guards=0;source_rosters=0;fallback=0;errs=[];pairs=set()
    for previous,config,lv in zip(old,cfg,actual):
        assert previous['id']==config['baseLevel']==lv['id']
        assert previous['name']==lv['name'] and previous['reward_cash']==lv['reward_cash']
        assert previous['theme']==lv['theme'] and previous['theme_name']==lv['theme_name']
        assert lv['source_map_id']==config['mapId']
        assert lv['source_flip_x']==bool(config.get('flipX')) and lv['source_flip_y']==bool(config.get('flipY'))
        assert lv['source_tile_offset']==0.5 and lv['source_tile_cells']==2
        assert lv['source_door_count']==len(config.get('doors',[]))
        assert lv['source_chest_count']==len(config.get('chests',[]))
        assert lv['source_trap_count']==len(config.get('laserTraps',[]))+len(config.get('freezeTraps',[]))
        hints=[('guard',x) for x in config.get('guards',[])]+[('boss',x) for x in config.get('bosses',[])]
        if hints:
            source_rosters+=1;assert lv['source_guard_roster']=='source' and len(lv['guards'])==max(len(hints),len(previous['guards']))
            assert len(lv['source_guard_hint_errors'])==len(hints)
            for i,(guard,(kind,hint)) in enumerate(zip(lv['guards'],hints)):
                assert guard['source_kind']==kind and guard['source_type']==hint['type']
                assert guard['source_coord']==[hint['coordX'],hint['coordY']] and guard['source_dir']==hint['dir']
                hx=round(float(hint['coordX'])/100);hy=round(float(hint['coordY'])/100)
                if config.get('flipX'):hx=len(src[config['mapId']][0])-1-hx
                if config.get('flipY'):hy=len(src[config['mapId']])-1-hy
                expected_error=math.dist((guard['x'],guard['y']),(1+2*hx,1+2*hy))*32
                assert abs(lv['source_guard_hint_errors'][i]-expected_error)<0.011,(lv['id'],i,'source displacement')
                assert guard.get('source_adjustment')==('idle-start safety' if lv['id']==95 and i==6 else None)
        else:
            fallback+=1;assert lv['source_guard_roster']=='fallback' and len(lv['guards'])==len(previous['guards'])
            assert all(x['source_kind']=='fallback' for x in lv['guards'])
        assert lv['v72_minimum_from_previous']==len(previous['guards'])
        prefix=len(hints) if hints else len(previous['guards'])
        assert len(lv['guards'])==max(prefix,len(previous['guards']))
        assert lv['v72_supplement_count']==len(lv['guards'])-prefix
        assert all(x['source_kind']=='v72_supplement' for x in lv['guards'][prefix:])
        guards+=len(lv['guards']);errs.extend(lv['source_guard_hint_errors'])
        raw=src[config['mapId']];grid=[list(reversed(row)) if config.get('flipX') else row[:] for row in raw]
        if config.get('flipY'):grid.reverse()
        assert lv['source_grid_size']==[len(grid[0]),len(grid)]
        assert lv['width']==2+2*len(grid[0]) and lv['height']==2+2*len(grid)
        pairs.add((config['mapId'],bool(config.get('flipX')),bool(config.get('flipY'))))
        walls=[rect(r) for r in lv['walls']];boxes=[rect(r) for r in lv['crates']]
        for y,row in enumerate(grid):
            for x,tile in enumerate(row):
                # Sample nine points inside EVERY source tile, close to both
                # edges. This detects v70-style shrunken obstacles, not merely
                # whether the centre cell is occupied.
                for dy in (0.1,0.5,0.9):
                    for dx in (0.1,0.5,0.9):
                        px=(0.5+2*x+2*dx)*32;py=(0.5+2*y+2*dy)*32
                        wall=any(contains(r,px,py) for r in walls)
                        box=any(contains(r,px,py) for r in boxes)
                        assert wall==(tile in ('XX','NN','EE')),(lv['id'],x,y,tile,'wall',dx,dy)
                        assert box==(tile=='BB'),(lv['id'],x,y,tile,'box',dx,dy)
                        sampled+=1
    assert source_rosters==90 and fallback==10 and guards==1066 and len(errs)==620 and len(pairs)==64
    assets=list((ROOT/'assets/environment/v71').glob('*.png'));assert len(assets)>=25
    print(f'V72 SOURCE INTEGRITY {checked} supplied files verified; {sampled} source-tile samples matched solid/box geometry; {source_rosters} source-priority rosters, {fallback} fallback rosters; {guards} guards; 100 IDs/rewards preserved; {len(pairs)} map/flip pairs; {len(errs)} source hints, mean displacement {sum(errs)/len(errs):.2f} units')
if __name__=='__main__':main()
