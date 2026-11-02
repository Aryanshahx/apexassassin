#!/usr/bin/env python3
"""Restore the previous per-level enemy minimum without moving v0.7.1 guards.

Usage: python3 tools/restore_v72_enemies.py /path/to/v071/levels.json output.json
The installed source-map v069 catalog has the same per-level counts as v070.
Supplemental guards use existing clearance, routes, patrol and combat AI.
"""
from pathlib import Path
import json,math,sys
from repair_levels_v62 import Map,geom,GUARD_MARGIN,PLAYER_MARGIN,bits,CELL

ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT/'data/source_maps/v70/v069-level-catalog.json'

def main():
 if len(sys.argv)!=3:raise SystemExit(__doc__)
 prior=json.loads(BASE.read_text())['levels']
 data=json.loads(Path(sys.argv[1]).read_text())
 if not str(data.get('layout_revision','')).startswith('0.7.1-'):
  raise SystemExit('Input must be the untouched v0.7.1 catalog')
 added=0
 for old,lv in zip(prior,data['levels']):
  assert old['id']==lv['id']
  m=Map(lv['width'],lv['height']);guard_occ=0;player_occ=0
  for item in lv['walls']+lv['crates']:
   rectangle=geom(item)
   guard_occ|=m.rect_mask(rectangle,GUARD_MARGIN)
   player_occ|=m.rect_mask(rectangle,PLAYER_MARGIN)
  guard_free=m.all&~guard_occ
  player_free=m.all&~player_occ
  spawn=tuple(lv['spawn'])
  reachable=m.flood(player_free,m.bit(spawn))
  options=[m.point(i) for i in bits(guard_free & reachable)]
  original=list(lv['guards']);chosen=[(g['x'],g['y']) for g in original]
  target=max(len(original),len(old['guards']))
  while len(chosen)<target:
   valid=[q for q in options if math.dist(q,spawn)*CELL>=320 and
          all(math.dist(q,p)*CELL>=160 for p in chosen)]
   if not valid:raise RuntimeError(f'No safe supplementary slot: level {lv["id"]}')
   # Further from the starting position first, then distribute from neighbors.
   def score(q):
    return (min(math.dist(q,spawn)*CELL,700),
            min(math.dist(q,p)*CELL for p in chosen),-q[1],-q[0])
   q=max(valid,key=score)
   adjacent=[]
   for dx,dy in ((1,0),(-1,0),(0,1),(0,-1)):
    p=(q[0]+dx,q[1]+dy)
    if 0<=p[0]<m.w and 0<=p[1]<m.h and guard_free&m.bit(p) and reachable&m.bit(p):adjacent.append(p)
   next_point=max(adjacent,key=lambda p:math.dist(p,spawn)) if adjacent else q
   face=round(math.degrees(math.atan2(q[1]-spawn[1],q[0]-spawn[0])))%360
   lv['guards'].append({'x':q[0],'y':q[1],'route':[list(q),list(next_point)],
                       'face':face,'elite':False,'source_kind':'v72_supplement'})
   chosen.append(q);added+=1
  # New guards can queue too long in two narrow-gate pursuit scenarios.
  # Move only those supplemental (not supplied source) guards to safe cells.
  adjustments={28:(6,(23,28)),76:(11,(5,15))}
  if lv['id'] in adjustments:
   index,candidate=adjustments[lv['id']]
   assert lv['guards'][index]['source_kind']=='v72_supplement'
   assert candidate in options and math.dist(candidate,spawn)*CELL>=320
   assert all(math.dist(candidate,p)*CELL>=160 for i,p in enumerate(chosen) if i!=index)
   chosen[index]=candidate
   guard=lv['guards'][index];guard['x'],guard['y']=candidate
   adjacent=[]
   for dx,dy in ((1,0),(-1,0),(0,1),(0,-1)):
    q=(candidate[0]+dx,candidate[1]+dy)
    if 0<=q[0]<m.w and 0<=q[1]<m.h and guard_free&m.bit(q) and reachable&m.bit(q):adjacent.append(q)
   guard['route']=[list(candidate),list(max(adjacent,key=lambda q:math.dist(q,spawn)) if adjacent else candidate)]
   guard['face']=round(math.degrees(math.atan2(candidate[1]-spawn[1],candidate[0]-spawn[0])))%360
   guard['source_adjustment']='traffic safety'
  # With the denser patrol roster, an existing guard can now approach the
  # unchanged level-75 start within three seconds. Move only the unspecified
  # player entry point, never the supplied guard hints or cover geometry.
  if lv['id']==75:
   candidate=(17,46)
   assert candidate in options and all(math.dist(candidate,p)*CELL>=320 for p in chosen)
   lv['spawn']=list(candidate)
   lv['v72_player_start_adjusted']='idle-start safety'
  lv['v72_minimum_from_previous']=len(old['guards'])
  lv['v72_supplement_count']=target-len(original)
 data['layout_revision']='0.7.2-source-priority-restored-enemies'
 Path(sys.argv[2]).write_text(json.dumps(data,separators=(',',':'))+'\n')
 print('Restored',added,'guards; total',sum(len(x['guards']) for x in data['levels']))
if __name__=='__main__':main()
