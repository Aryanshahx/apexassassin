#!/usr/bin/env python3
"""Conservatively repair v0.6.1 levels for 20%-larger, correctly spaced cover.

The input is the version-3 level JSON.  Existing maps/guard counts/rewards stay;
interior wall sections are removed only when necessary to reconnect the larger
single-guard navigation clearance or make space for every original crate.
Crates retain their dimensions/types and move to safe, separated grid locations.
Guard starts are repositioned into clear, well-spaced areas; route points are repaired.
"""
import json, math, random, sys, collections, time
from pathlib import Path
CELL=32.0
BASE_GROW=3.0
SCALE=1.2
PLAYER_MARGIN=4.0
GUARD_MARGIN=24.0 # four units physical wall margin + 20 units guard clearance
ART_GAP=14.0

def geom(a):
 x,y,w,h=a[:4];cx=(x+w/2)*CELL;cy=(y+h/2)*CELL
 rw=(w*CELL+BASE_GROW*2)*SCALE;rh=(h*CELL+BASE_GROW*2)*SCALE
 return (cx-rw/2,cy-rh/2,cx+rw/2,cy+rh/2)
def too_close(a,b,gap):
 return not (a[2]+gap<=b[0] or b[2]+gap<=a[0] or a[3]+gap<=b[1] or b[3]+gap<=a[1])
def contains(r,p,margin):return r[0]-margin <= p[0] < r[2]+margin and r[1]-margin <= p[1] < r[3]+margin
class Map:
 def __init__(self,w,h):
  self.w=w;self.h=h;self.all=(1<<(w*h))-1
  self.left=sum(1<<(y*w) for y in range(h));self.right=self.left<<(w-1)
 def bit(self,p):return 1<<(p[1]*self.w+p[0])
 def point(self,i):return (i%self.w,i//self.w)
 def rect_mask(self,r,margin):
  x0=max(0,math.ceil((r[0]-margin-CELL/2)/CELL));x1=min(self.w-1,math.ceil((r[2]+margin-CELL/2)/CELL)-1)
  y0=max(0,math.ceil((r[1]-margin-CELL/2)/CELL));y1=min(self.h-1,math.ceil((r[3]+margin-CELL/2)/CELL)-1)
  if x1<x0 or y1<y0:return 0
  row=((1<<(x1-x0+1))-1)<<x0;out=0
  for y in range(y0,y1+1):out|=row<<(y*self.w)
  return out
 def flood(self,free,seed):
  seen=free&seed
  while 1:
   new=(seen | (seen<<self.w) | (seen>>self.w) | ((seen&~self.left)>>1) | ((seen&~self.right)<<1))&free&self.all
   if new==seen:return seen
   seen=new
 def nearest(self,free,cell):
  if not free:return 0
  if free & self.bit(cell):return self.bit(cell)
  best=None
  for i in bits(free):
   x,y=self.point(i);q=((x-cell[0])**2+(y-cell[1])**2,abs(y-cell[1]),y,x)
   if best is None or q<best[0]:best=(q,1<<i)
  return best[1]
 def connected(self,free,seed):
  return bool(free) and self.flood(free,seed)==free

def bits(value):
 while value:
  bit=value&-value;yield bit.bit_length()-1;value^=bit

def repair(lv, attempt=0, extra_wall_trial=False):
 M=Map(lv['width'],lv['height']);spawn=tuple(lv['spawn']);sp=( (spawn[0]+.5)*CELL,(spawn[1]+.5)*CELL )
 oldwalls=lv['walls'];walls=list(oldwalls);removed=[]
 def mask_walls(wlist,margin):
  occ=0
  for a in wlist:occ|=M.rect_mask(geom(a),margin)
  return M.all&~occ
 # First remove any interior wall that physically covers the original player spawn.
 for a in list(walls[4:]):
  if contains(geom(a),sp,PLAYER_MARGIN+8):walls.remove(a);removed.append(a)
 # Open physical guard passages. Retain the four boundary walls, and repeatedly
 # remove the one interior section which maximizes the connected region.
 while 1:
  free=mask_walls(walls,GUARD_MARGIN);seed=M.nearest(free,spawn);reach=M.flood(free,seed)
  if free==reach:break
  options=[]
  for i in range(4,len(walls)):
   newer=walls[:i]+walls[i+1:];f=mask_walls(newer,GUARD_MARGIN);s=M.nearest(f,spawn);v=M.flood(f,s);vcount=v.bit_count();dis=f.bit_count()-vcount
   if vcount>reach.bit_count() or dis<(free.bit_count()-reach.bit_count()):
    a=walls[i];area=a[2]*a[3]
    options.append(((vcount-dis*1.25,-area,-i),i))
  if not options:
   raise RuntimeError('Could not repair wall connectivity for level '+str(lv['id']))
  i=max(options)[1];removed.append(walls.pop(i))
 # Repair crate placement without changing dimensions or colors. Largest first.
 wallrects=[geom(a) for a in walls]
 physical=list(wallrects);occ_guard=M.all^mask_walls(walls,GUARD_MARGIN);occ_player=M.all^mask_walls(walls,PLAYER_MARGIN)
 crates=[];missed=[]
 oldcrates=list(enumerate(lv['crates']))
 if attempt:
  random.Random(620000 + lv['id'] * 100 + attempt).shuffle(oldcrates)
 oldcrates.sort(key=lambda z:-z[1][2]*z[1][3])
 for oldidx,c in oldcrates:
  ox,oy,w,h,typ=c
  # Locality first, deterministic tie-break. Keep original crate if already safe.
  candidates=[(x,y) for y in range(1,M.h-1-h+1) for x in range(1,M.w-1-w+1)]
  if attempt:
   seed = 6200000 + lv['id'] * 1000 + oldidx * 17 + attempt
   rng = random.Random(seed)
   # Small deterministic placement jitter explores other nearby valid spaces.
   costs = {q:rng.uniform(-4.0,4.0) for q in candidates}
   candidates.sort(key=lambda q:((q[0]-ox)**2+(q[1]-oy)**2+costs[q],q[1],q[0]))
  else:
   candidates.sort(key=lambda q:((q[0]-ox)**2+(q[1]-oy)**2,abs(q[1]-oy),q[1],q[0]))
  found=None
  for x,y in candidates:
   raw=[x,y,w,h,typ];r=geom(raw)
   if any(too_close(r,b,ART_GAP) for b in physical):continue
   if contains(r,sp,44):continue
   gm=M.rect_mask(r,GUARD_MARGIN);free=M.all&~(occ_guard|gm);seed=M.nearest(free,spawn)
   if not M.connected(free,seed):continue
   pm=M.rect_mask(r,PLAYER_MARGIN);pfree=M.all&~(occ_player|pm);s=M.bit(spawn)
   if not (pfree&s):continue
   # Player can reach the guard-accessible space from their actual spawn.
   if not (M.flood(pfree,s)&seed):continue
   found=(raw,r,gm,pm);break
  if found:
   raw,r,gm,pm=found;crates.append((oldidx,raw));physical.append(r);occ_guard|=gm;occ_player|=pm
  else:missed.append(c)
 crates=[raw for _,raw in sorted(crates)]
 free=M.all&~occ_guard;seed=M.nearest(free,spawn);assert M.connected(free,seed)
 pfree=M.all&~occ_player;assert pfree&M.bit(spawn) and M.flood(pfree,M.bit(spawn))&seed
 # Reposition guard starts only if expanded cover or another guard is too close.
 guard_cells=[];guards=[];old_guards=lv['guards'];options=[M.point(i) for i in bits(free)]
 for gd in old_guards:
  old=(gd['x'],gd['y'])
  def openness(q):
   return sum(0 <= q[0]+dx < M.w and 0 <= q[1]+dy < M.h and bool(free & M.bit((q[0]+dx,q[1]+dy))) for dx,dy in ((1,0),(-1,0),(0,1),(0,-1)))
  # Prefer a small open intersection instead of spawning two actors inside
  # one narrow gate. More space makes their first routes visibly smoother.
  cand=sorted(options,key=lambda q:(openness(q)<3,(q[0]-old[0])**2+(q[1]-old[1])**2,abs(q[1]-old[1]),q[1],q[0]))
  p=None
  for gap in (128, 112, 96, 80, 70):
   p=next((q for q in cand if all(math.dist(q,other)*CELL >= gap for other in guard_cells) and math.dist(q,spawn)*CELL>=280),None)
   if p is not None:break
  if p is None:raise RuntimeError('No safe guard start in level '+str(lv['id']))
  guard_cells.append(p);g=dict(gd);g['x'],g['y']=p
  newroute=[list(p)]
  for target in gd['route'][1:]:
   q=min(options,key=lambda z:((z[0]-target[0])**2+(z[1]-target[1])**2,z[1],z[0]));newroute.append(list(q))
  g['route']=newroute;guards.append(g)
 out=dict(lv);out['walls']=walls;out['crates']=crates;out['guards']=guards
 stats={'walls_removed':len(removed),'wall_original':len(oldwalls)-4,'crate_orig':len(oldcrates),'crate_remaining':len(crates), 'crate_moves':sum(c not in lv['crates'] for c in crates), 'guard_moves':sum((a['x'],a['y'])!=(b['x'],b['y']) for a,b in zip(old_guards,guards))}
 if missed and attempt < 9:
  alternative, altstats = repair(lv, attempt + 1, extra_wall_trial)
  if altstats['crate_remaining'] > stats['crate_remaining']:
   if altstats['crate_remaining'] == len(lv['crates']) or attempt != 0:
    return alternative, altstats
   out,stats = alternative,altstats
 if stats['crate_remaining'] < len(lv['crates']) and attempt == 0 and not extra_wall_trial:
  # If no placement fits after retries, sacrifice one small interior wall
  # instead of deleting a crate or closing a doorway.
  for candidate in sorted(walls[4:], key=lambda w:(w[2]*w[3],w[1],w[0])):
   reduced=dict(lv); reduced['walls']=walls.copy(); reduced['walls'].remove(candidate)
   alt, altstats=repair(reduced,0,True)
   if altstats['crate_remaining'] == len(lv['crates']):
    altstats['walls_removed']=len(oldwalls)-len(alt['walls'])
    altstats['wall_original']=len(oldwalls)-4
    return alt,altstats
 return out,stats

def main():
 if len(sys.argv) != 3:
  raise SystemExit('Usage: python3 tools/repair_levels_v62.py original_levels.json repaired_levels.json')
 inp=Path(sys.argv[1]);out=Path(sys.argv[2]);data=json.loads(inp.read_text());stats=[];levels=[]
 if data.get('layout_revision') == '0.6.2':
  raise SystemExit('This input is already repaired for v0.6.2; regenerate from the original layouts instead.')
 for lv in data['levels']:
  repaired,st=repair(lv);levels.append(repaired);stats.append(st)
  if lv['id']%10==0:print('processed',lv['id'],flush=True)
 data['levels']=levels;data['layout_revision']='0.6.2';out.write_text(json.dumps(data,separators=(',',':'))+'\n')
 print('wrote',out)
 for k in stats[0]:print(k,'total',sum(s[k] for s in stats),'avg',sum(s[k] for s in stats)/len(stats),'range',(min(s[k] for s in stats),max(s[k] for s in stats)))
 print('worst crate levels',[(i+1,s['crate_orig'],s['crate_remaining']) for i,s in enumerate(stats) if s['crate_remaining']<6])
 print('level 1',stats[0])
if __name__=='__main__':main()
