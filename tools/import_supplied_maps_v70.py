#!/usr/bin/env python3
"""Adapt the user's supplied map grids and placement configuration to Godot.

The 100 source configurations reference 45 source grids (some repeated with
flips). The supplied binary contains compiled machine code, not runnable Godot
source; this adapter reimplements only a conservative data mapping, and keeps
this project's existing mechanics, level IDs, rewards and guard identities.

XX/NN/EE are treated as solid wall cells, BB as solid cover, __ as floor and
:: as cosmetic grass. Tile meanings are cross-checked against the static parser
and MapData predicates in the user-supplied library. Door/trap/chest config is
retained in the supplied source JSON but not silently turned into new mechanics.

Usage: python3 tools/import_supplied_maps_v70.py v069-levels.json output.json
Run from the project root. The unchanged v069 file may come from the update
backup. Guard starts are pulled toward supplied coordinates where safe, with
additional guards retained and starts separated for the existing AI.
"""
from pathlib import Path
from collections import Counter
import copy, hashlib, json, math, random, re, sys

from repair_levels_v62 import Map, geom, CELL, GUARD_MARGIN, bits

ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'data/source_maps/v70'
ART=ROOT/'assets/environment/v70'
THEMES=('warehouse','factory','dockyard','military','night','desert','snow','rooftop')
TILE=2
OFFSET=1
INSET=20.0  # desired visible/physical inset per source tile rectangle
# Leave at least three idle seconds before any full-speed patrol can reach
# flashlight range, without changing combat or adding artificial invulnerability.
SPAWN_GAP=560.0
GUARD_GAP=160.0


def read_grids(path):
    result={};key=None
    for raw in path.read_text().splitlines():
        line=raw.strip()
        if re.fullmatch(r'ID[A-Z]+\d+',line):
            if line in result:raise ValueError('Duplicate source map '+line)
            key=line;result[key]=[]
        elif key and ',' in line:
            cells=[x for x in line.split(',') if x]
            if not all(x in ('XX','NN','EE','BB','__','::') for x in cells):
                raise ValueError(f'Unknown source tile in {key}: {cells}')
            result[key].append(cells)
    for key,rows in result.items():
        if not rows or not rows[0] or any(len(row)!=len(rows[0]) for row in rows):
            raise ValueError('Bad source grid '+key)
    return result


def source_rect(x,y,w,h):
    # Invert the existing physical +20% obstacle calculation. Rectangles
    # are drawn at their actual enlarged sizes, so appearance and collision
    # agree while one-source-tile corridors keep guard-body clearance.
    cx=(OFFSET+TILE*(x+w/2))*CELL;cy=(OFFSET+TILE*(y+h/2))*CELL
    actualw=TILE*w*CELL-INSET;actualh=TILE*h*CELL-INSET
    raww=(actualw/1.2-6)/CELL;rawh=(actualh/1.2-6)/CELL
    return [round(cx/CELL-raww/2,7),round(cy/CELL-rawh/2,7),round(raww,7),round(rawh,7)]


def grouped(grid,group,maxwidth=999,maxheight=999):
    h=len(grid);w=len(grid[0]);used=set();out=[]
    def matches(s):
        return s in ('XX','NN') if group=='wall' else s=='BB' if group=='box' else s=='EE'
    for y in range(h):
        for x in range(w):
            if (x,y) in used or not matches(grid[y][x]):continue
            gw=0
            while x+gw<w and gw<maxwidth and (x+gw,y) not in used and matches(grid[y][x+gw]):gw+=1
            gh=1
            while y+gh<h and gh<maxheight and all((x+i,y+gh) not in used and matches(grid[y+gh][x+i]) for i in range(gw)):
                gh+=1
            for yy in range(y,y+gh):
                for xx in range(x,x+gw):used.add((xx,yy))
            out.append((x,y,gw,gh))
    return out


def choose_prop(theme,wide,rng):
    categories={
        'warehouse': ('brownBoxTheme','brownBoxTheme'),
        'factory': ('blueBoxTheme','blueBoxTheme'),
        'dockyard': ('containerBoxTheme','containerBoxTheme'),
        'military': ('greenBoxTheme','containerBoxTheme'),
        'night': ('blueBoxTheme','blueBoxTheme'),
        'desert': ('brownBoxTheme','brownBoxTheme'),
        'snow': ('hospitalBoxTheme','blueBoxTheme'),
        'rooftop': ('scifiBoxTheme','blueBoxTheme'),
    }
    big,small=categories[theme];folder=big if wide else small
    pattern='boxBig*.png' if wide else 'boxLittle*.png'
    choices=sorted((ART/folder).glob(pattern))
    if not choices:raise RuntimeError('Missing supplied prop images '+folder+'/'+pattern)
    return rng.choice(choices).relative_to(ART).as_posix()


def coordinate_cell(point,width,height,flip_x,flip_y):
    x=round(float(point['coordX'])/100.0);y=round(float(point['coordY'])/100.0)
    if flip_x:x=width-1-x
    if flip_y:y=height-1-y
    return (OFFSET+TILE*x,OFFSET+TILE*y)


def generate(old,cfg,src):
    number=int(old['id']);assert number==int(cfg['baseLevel'])
    sw=len(src[0]);sh=len(src);flip_x=bool(cfg.get('flipX'));flip_y=bool(cfg.get('flipY'))
    grid=[list(reversed(row)) if flip_x else row[:] for row in src]
    if flip_y:grid.reverse()
    width=OFFSET*2+TILE*sw;height=OFFSET*2+TILE*sh
    theme=THEMES[(number-1)%len(THEMES)];rng=random.Random(700026 + number*719)
    walls=[[0,0,width,1],[0,height-1,width,1],[0,0,1,height],[width-1,0,1,height]]
    for rect in grouped(grid,'wall'):walls.append(source_rect(*rect))
    wall_kinds={str(i):'source_wall' for i in range(len(walls))}
    for rect in grouped(grid,'gate'):
        wall_kinds[str(len(walls))]='source_gate';walls.append(source_rect(*rect))
    crates=[]
    for x,y,w,h in grouped(grid,'box',2,1):
        crates.append(source_rect(x,y,w,h)+[choose_prop(theme,w>1,rng)])
    m=Map(width,height);blocked=0
    for rect in walls+crates:blocked |= m.rect_mask(geom(rect),GUARD_MARGIN)
    free=m.all & ~blocked
    if not free:raise RuntimeError(f'Level {number} has no guard-clear area')
    # Every supplied map should remain connected without removing source cells.
    seed=free & -free
    if not m.connected(free,seed):raise RuntimeError(f'Level {number} disconnected after physical conversion')
    options=[m.point(i) for i in bits(free)]
    entrances=[(x,y) for y,row in enumerate(grid) for x,v in enumerate(row) if v=='EE']
    if len(entrances)!=1:raise RuntimeError(f'Level {number} expected one source entrance, got {len(entrances)}')
    ex,ey=entrances[0]
    intended=(OFFSET+TILE*ex,OFFSET+TILE*max(1,ey-1))
    spawn=min(options,key=lambda q:((q[0]-intended[0])**2+(q[1]-intended[1])**2,-q[1],q[0]))
    hints=[h for h in cfg.get('guards',[]) if 'coordX' in h and 'coordY' in h]
    hints += [h for h in cfg.get('bosses',[]) if 'coordX' in h and 'coordY' in h]
    chosen=[];guards=[];hint_errors=[]
    for i,oldguard in enumerate(old['guards']):
        # Preserve counts, elite flags, face and all other non-position fields.
        valid=[q for q in options if math.dist(q,spawn)*CELL>=SPAWN_GAP and all(math.dist(q,z)*CELL>=GUARD_GAP for z in chosen)]
        if not valid:raise RuntimeError(f'No safe guard slot for level {number}, guard {i}')
        if i<len(hints):
            target=coordinate_cell(hints[i],sw,sh,flip_x,flip_y)
            q=min(valid,key=lambda p:((p[0]-target[0])**2+(p[1]-target[1])**2,abs(p[1]-target[1]),p[1],p[0]))
            hint_errors.append(round(math.dist(q,target)*CELL,2))
        elif chosen:
            q=max(valid,key=lambda p:(min((p[0]-z[0])**2+(p[1]-z[1])**2 for z in chosen),
                                      (p[0]-spawn[0])**2+(p[1]-spawn[1])**2,-p[1],-p[0]))
        else:
            q=max(valid,key=lambda p:((p[0]-spawn[0])**2+(p[1]-spawn[1])**2,-p[1],-p[0]))
        chosen.append(q);g=copy.deepcopy(oldguard);g['x'],g['y']=q
        # A short clear authored patrol endpoint; the existing roaming/chase
        # algorithms continue to handle movement and traffic during play.
        neighbors=[]
        for dx,dy in ((1,0),(-1,0),(0,1),(0,-1)):
            r=(q[0]+dx,q[1]+dy)
            if 0<=r[0]<width and 0<=r[1]<height and (free & m.bit(r)):neighbors.append(r)
        neighbor=neighbors[(number+i)%len(neighbors)] if neighbors else q
        g['route']=[list(q),list(neighbor)];guards.append(g)
    out=copy.deepcopy(old)
    out.update({'width':width,'height':height,'walls':walls,'crates':crates,
                'spawn':list(spawn),'guards':guards,'theme':theme,
                'source_map_id':cfg['mapId'],'source_base_level':number,
                'source_flip_x':flip_x,'source_flip_y':flip_y,
                'source_grid_size':[sw,sh],'source_tile_cells':TILE,
                'use_authored_guard_starts':True,'source_guard_hints_used':len(hint_errors),
                'source_guard_hint_errors':hint_errors,'wall_kinds':wall_kinds,
                'source_grass':[[x,y] for y,row in enumerate(grid) for x,v in enumerate(row) if v=='::'],
                'source_door_count':len(cfg.get('doors',[])),
                'source_chest_count':len(cfg.get('chests',[])),
                'source_trap_count':len(cfg.get('laserTraps',[]))+len(cfg.get('freezeTraps',[])),
                'scenery_details':[],'scenery_lights':[],
                'l_shapes':[],'partition_walls':list(range(4,len(walls))),
                'gate_decor':[],'area_breaks':[],'room_floor':[]})
    out.pop('helipad',None)
    return out


def main():
    if len(sys.argv)!=3:raise SystemExit(__doc__)
    original=json.loads(Path(sys.argv[1]).read_text());old=original['levels']
    grids=read_grids(SOURCE/'RemoteMaps.txt')
    config=json.loads((SOURCE/'recovered_remote_config.json').read_text())['remoteMaps']
    if len(old)!=100 or len(config)!=100 or len(grids)!=45:raise RuntimeError('Unexpected source or existing catalog size')
    levels=[generate(a,b,grids[b['mapId']]) for a,b in zip(old,config)]
    doc=dict(original);doc['levels']=levels;doc['layout_revision']='0.7.0-user-supplied-grids'
    Path(sys.argv[2]).write_text(json.dumps(doc,separators=(',',':'))+'\n')
    print('Adapted 100 configured levels from',len(grids),'supplied source grids')
    print('Retained',sum(len(l['guards']) for l in levels),'existing guards and all level IDs/rewards')
    print('Original guard hints used:',sum(l['source_guard_hints_used'] for l in levels))
    errs=[e for l in levels for e in l['source_guard_hint_errors']]
    print('Hint displacement: mean',round(sum(errs)/max(len(errs),1),2),'world units; within one source tile',sum(e<=64 for e in errs),'/',len(errs))
    print('Collision rectangles: walls',sum(len(l['walls']) for l in levels),'props',sum(len(l['crates']) for l in levels))
    print('Themes:',dict(Counter(l['theme'] for l in levels)))

if __name__=='__main__':main()
