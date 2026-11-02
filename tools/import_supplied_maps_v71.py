#!/usr/bin/env python3
"""Adapt supplied Hunter Files map grids with source-priority guard placement.

Layout geometry preserves the supplied solid/open cell pattern and flips; exact
original runtime transforms, doors, traps and AI behavior are unavailable.
All 611 supplied guards and nine supplied bosses are used where records exist.
The ten special levels without any source roster use the existing project's
roster as a fallback. A guard may move to the nearest safe cell; the player
start is selected near the source entrance without overlapping guards.

Usage: python3 tools/import_supplied_maps_v71.py v069-levels.json output.json
"""
from pathlib import Path
from collections import Counter
import copy, json, math, random, sys
import import_supplied_maps_v70 as v70
from repair_levels_v62 import Map, geom, CELL, GUARD_MARGIN, bits

ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'data/source_maps/v70'
THEMES=('warehouse','factory','dockyard','military','night','desert','snow','rooftop')
OFFSET=0.5
TILE=2
GUARD_GAP=160.0
SPAWN_GAP=416.0
# Validated with actual 3-second patrol and pursuit simulations. The source
# does not specify a player start. Level 95 is the one
# exceptional crowded map: no >=320-unit player start passed; one supplied guard
# is moved to a nearby clear cell so the level remains playable and fair.
SAFE_START_ADJUSTMENTS={2:(4,21),35:(11,45),89:(23,61),91:(19,3),95:(17,44)}
GUARD_SAFETY_ADJUSTMENTS={95:{6:(21,34)}}
# A half-cell offset puts a 32-unit gameplay-cell centre at the centre of
# each 64-unit source cell. Full-sized adjacent source obstacles can touch
# without closing narrow valid passages for the existing guard body.
v70.OFFSET=OFFSET
v70.INSET=0.0


def source_target(hint,width,height,fx,fy):
    x=round(float(hint['coordX'])/100.0);y=round(float(hint['coordY'])/100.0)
    if fx:x=width-1-x
    if fy:y=height-1-y
    return (1+TILE*x,1+TILE*y)


def line_clear(a,b,rectangles):
    # Existing line-of-sight uses the physical rectangles grown by 4 units.
    # Segment/rectangle clipping lets the spawn selector prefer initial cover
    # without moving the source-priority guard placements.
    ax=(a[0]+0.5)*CELL;ay=(a[1]+0.5)*CELL
    dx=(b[0]-a[0])*CELL;dy=(b[1]-a[1])*CELL
    for x0,y0,x1,y1 in rectangles:
        enter=0.0;leave=1.0
        for start,delta,lo,hi in ((ax,dx,x0-4,x1+4),(ay,dy,y0-4,y1+4)):
            if abs(delta)<1e-9:
                if start<lo or start>=hi:
                    enter=2.0;break
            else:
                t0=(lo-start)/delta;t1=(hi-start)/delta
                enter=max(enter,min(t0,t1));leave=min(leave,max(t0,t1))
                if enter>leave:break
        if enter<=leave and leave>=0.0 and enter<=1.0:return False
    return True


def face_hint(hint,fx,fy):
    # The integer-to-angle convention is an approximation. The original
    # direction enum implementation is not available in the supplied source.
    angle=(int(hint.get('dir',0))*90)%360
    if fx:angle=(180-angle)%360
    if fy:angle=(-angle)%360
    return angle


def prop(theme,wide,rng):
    stock={
       'warehouse':('crate_wood','crate_tan','crate_steel'),
       'factory':('crate_steel','crate_blue','crate_red'),
       'dockyard':('crate_blue','crate_red','crate_steel'),
       'military':('crate_green','crate_tan','crate_steel'),
       'night':('crate_blue','crate_steel','crate_green'),
       'desert':('crate_tan','crate_wood','crate_green'),
       'snow':('crate_blue','crate_steel','crate_green'),
       'rooftop':('crate_steel','crate_blue','crate_red'),
    }
    options=list(stock[theme])
    if wide:options += ['sandbags','barrel_pallet']
    return rng.choice(options)


def generate(old,cfg,src):
    number=int(old['id']);assert number==int(cfg['baseLevel'])
    sw=len(src[0]);sh=len(src);fx=bool(cfg.get('flipX'));fy=bool(cfg.get('flipY'))
    grid=[list(reversed(row)) if fx else row[:] for row in src]
    if fy:grid.reverse()
    width=2+TILE*sw;height=2+TILE*sh
    theme=THEMES[(number-1)%8];rng=random.Random(710027+number*719)
    # The outer frame is outside the user-supplied source cells; all interior
    # cover rectangles exactly fill their source cells rather than shrinking.
    walls=[[0,0,width,1],[0,height-1,width,1],[0,0,1,height],[width-1,0,1,height]]
    for r in v70.grouped(grid,'wall'):walls.append(v70.source_rect(*r))
    wall_kinds={str(i):'wall' for i in range(len(walls))}
    for r in v70.grouped(grid,'gate'):
        wall_kinds[str(len(walls))]='gate';walls.append(v70.source_rect(*r))
    crates=[]
    for x,y,w,h in v70.grouped(grid,'box',2,1):
        crates.append(v70.source_rect(x,y,w,h)+[prop(theme,w>1,rng)])
    m=Map(width,height);blocked=0
    for r in walls+crates:blocked |= m.rect_mask(geom(r),GUARD_MARGIN)
    free=m.all&~blocked
    if not free or not m.connected(free,free&-free):raise RuntimeError(f'Level {number} guard-clear map disconnected')
    options=[m.point(i) for i in bits(free)]
    entrances=[(x,y) for y,row in enumerate(grid) for x,v in enumerate(row) if v=='EE']
    if len(entrances)!=1:raise RuntimeError(f'Level {number} has {len(entrances)} entrances')
    ex,ey=entrances[0];desired=(1+TILE*ex,1+TILE*max(1,ey-1))
    hints=[('guard',h) for h in cfg.get('guards',[]) if 'coordX' in h and 'coordY' in h]
    hints += [('boss',h) for h in cfg.get('bosses',[]) if 'coordX' in h and 'coordY' in h]
    chosen=[];guards=[];errors=[]
    if hints:
        # Source roster wins. Project each hint to the nearest reachable,
        # body-clear cell while respecting the existing 160-unit spacing.
        for i,(kind,hint) in enumerate(hints):
            target=source_target(hint,sw,sh,fx,fy)
            valid=[q for q in options if all(math.dist(q,p)*CELL>=GUARD_GAP for p in chosen)]
            if not valid:raise RuntimeError(f'No source guard slot at level {number}, index {i}')
            point=min(valid,key=lambda q:((q[0]-target[0])**2+(q[1]-target[1])**2,abs(q[1]-target[1]),q[1],q[0]))
            chosen.append(point);errors.append(round(math.dist(point,target)*CELL,2))
            oldguard=old['guards'][i] if i<len(old['guards']) else {'elite':False}
            guard=copy.deepcopy(oldguard)
            guard.update({'x':point[0],'y':point[1],'face':face_hint(hint,fx,fy),
                          'elite':True if kind=='boss' else bool(oldguard.get('elite',False)),
                          'source_kind':kind,'source_type':str(hint.get('type','')),
                          'source_coord':[hint['coordX'],hint['coordY']],
                          'source_dir':int(hint.get('dir',0))})
            guards.append(guard)
        for index,point in GUARD_SAFETY_ADJUSTMENTS.get(number,{}).items():
            if point not in options or any(math.dist(point,p)*CELL<GUARD_GAP for i,p in enumerate(chosen) if i!=index):
                raise RuntimeError(f'Invalid safety guard adjustment at level {number}, index {index}')
            chosen[index]=point
            guards[index]['x'],guards[index]['y']=point
            guards[index]['source_adjustment']='idle-start safety'
            errors[index]=round(math.dist(point,source_target(hints[index][1],sw,sh,fx,fy))*CELL,2)
        distances={q:min(math.dist(q,p)*CELL for p in chosen) for q in options}
        # Dense supplied rosters can make a fixed 416-unit separation
        # impossible; keep their guards and use the farthest safe position.
        target_gap=min(SPAWN_GAP,max(distances.values())-0.001)
        valid=[q for q in options if distances[q]>=target_gap]
        if target_gap<320 or not valid:raise RuntimeError(f'No adequately separated player spawn near source guards at level {number}')
        valid.sort(key=lambda q:((q[0]-desired[0])**2+(q[1]-desired[1])**2,-q[1],q[0]))
        rectangles=[geom(r) for r in walls+crates]
        # Prefer the closest entrance-adjacent point shielded from any guard
        # within 520 units; this changes the unspecified player start, not the
        # explicitly selected source guard locations. If none exists, retain
        # the nearest point satisfying the available 320–416-unit clearance.
        spawn=next((q for q in valid if all(math.dist(q,p)*CELL>=520 or not line_clear(q,p,rectangles) for p in chosen)),valid[0])
        if number in SAFE_START_ADJUSTMENTS:
            candidate=SAFE_START_ADJUSTMENTS[number]
            if candidate not in options or distances[candidate]<320:
                raise RuntimeError(f'Invalid safety player adjustment at level {number}')
            spawn=candidate
        roster='source'
    else:
        # These ten levelType=2 records have no source guards or bosses.
        # Keep the previous playable roster rather than silently creating an
        # empty/unwinnable level; it is explicitly marked as a fallback.
        spawn=min(options,key=lambda q:((q[0]-desired[0])**2+(q[1]-desired[1])**2,-q[1],q[0]))
        for oldguard in old['guards']:
            valid=[q for q in options if math.dist(q,spawn)*CELL>=560 and all(math.dist(q,p)*CELL>=GUARD_GAP for p in chosen)]
            if not valid:valid=[q for q in options if math.dist(q,spawn)*CELL>=SPAWN_GAP and all(math.dist(q,p)*CELL>=GUARD_GAP for p in chosen)]
            if not valid:raise RuntimeError(f'No fallback guard slot at level {number}')
            q=max(valid,key=lambda p:(min((p[0]-z[0])**2+(p[1]-z[1])**2 for z in chosen) if chosen else (p[0]-spawn[0])**2+(p[1]-spawn[1])**2,
                                      (p[0]-spawn[0])**2+(p[1]-spawn[1])**2,-p[1],-p[0]))
            chosen.append(q);guard=copy.deepcopy(oldguard);guard['x'],guard['y']=q;guard['source_kind']='fallback';guards.append(guard)
        roster='fallback'
    # Existing patrol AI consumes short connected route endpoints.
    for i,(point,guard) in enumerate(zip(chosen,guards)):
        neighbors=[]
        for dx,dy in ((1,0),(-1,0),(0,1),(0,-1)):
            q=(point[0]+dx,point[1]+dy)
            if 0<=q[0]<width and 0<=q[1]<height and (free&m.bit(q)):neighbors.append(q)
        neighbor=neighbors[(number+i)%len(neighbors)] if neighbors else point
        guard['route']=[list(point),list(neighbor)]
    out=copy.deepcopy(old)
    out.update({'width':width,'height':height,'walls':walls,'crates':crates,
                'spawn':list(spawn),'guards':guards,'theme':theme,
                'source_map_id':cfg['mapId'],'source_base_level':number,
                'source_flip_x':fx,'source_flip_y':fy,'source_grid_size':[sw,sh],
                'source_tile_cells':TILE,'source_tile_offset':OFFSET,
                'source_guard_roster':roster,'use_authored_guard_starts':True,
                'source_guard_hints_used':len(errors),'source_guard_hint_errors':errors,
                'wall_kinds':wall_kinds,
                'source_grass':[[x,y] for y,row in enumerate(grid) for x,v in enumerate(row) if v=='::'],
                'source_door_count':len(cfg.get('doors',[])),'source_chest_count':len(cfg.get('chests',[])),
                'source_trap_count':len(cfg.get('laserTraps',[]))+len(cfg.get('freezeTraps',[])),
                'scenery_details':[],'scenery_lights':[],'l_shapes':[],
                'partition_walls':list(range(4,len(walls))),'gate_decor':[],
                'area_breaks':[],'room_floor':[]})
    out.pop('helipad',None)
    return out


def main():
    if len(sys.argv)!=3:raise SystemExit(__doc__)
    doc=json.loads(Path(sys.argv[1]).read_text());old=doc['levels']
    grids=v70.read_grids(SOURCE/'RemoteMaps.txt')
    config=json.loads((SOURCE/'recovered_remote_config.json').read_text())['remoteMaps']
    if len(old)!=100 or len(config)!=100 or len(grids)!=45:raise RuntimeError('Unexpected catalog/source size')
    levels=[generate(a,b,grids[b['mapId']]) for a,b in zip(old,config)]
    doc['levels']=levels;doc['layout_revision']='0.7.1-source-priority-selected-art'
    Path(sys.argv[2]).write_text(json.dumps(doc,separators=(',',':'))+'\n')
    errs=[e for level in levels for e in level['source_guard_hint_errors']]
    print('Adapted',len(levels),'levels from',len(grids),'source grids; no source solid cells removed or shrunk')
    print('Source roster',sum(1 for l in levels if l['source_guard_roster']=='source'),'levels; fallback roster',sum(1 for l in levels if l['source_guard_roster']=='fallback'),'levels')
    print('Total guards',sum(len(l['guards']) for l in levels),'; source hints',len(errs),'exact',sum(e<0.1 for e in errs),'within 64 units',sum(e<=64 for e in errs),'mean displacement',round(sum(errs)/len(errs),2))
    print('Themes:',dict(Counter(l['theme'] for l in levels)))

if __name__=='__main__':main()
