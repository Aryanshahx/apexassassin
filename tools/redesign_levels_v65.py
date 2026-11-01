#!/usr/bin/env python3
"""Rebuild the 100 warehouses with denser, screenshot-inspired crate clusters.

Keeping original level IDs, guard counts and rewards, two green partitions have
wide, navigable gates. Large contiguous L-shaped clusters and box stacks replace
sparse, thin container lines. Every guard-clear floor cell remains connected.
"""
from pathlib import Path
import json
import math
import random
import sys
from repair_levels_v62 import Map, geom, too_close, contains, bits, CELL, GUARD_MARGIN, ART_GAP

WIDTH, HEIGHT = 29, 46
# The supplied screenshot's traced lower warehouse has ~43.5% covered area.
# Measure actual expanded rectangles in the 15x32-cell initial camera view.
REFERENCE_COVERAGE_MIN = 0.415
REFERENCE_COVERAGE_MAX = 0.455


def viewport_coverage(items):
    clip = (7*CELL, 13*CELL, 22*CELL, 45*CELL)
    rects = []
    for item in items:
        x0,y0,x1,y1 = geom(item)
        x0,y0,x1,y1 = max(x0,clip[0]),max(y0,clip[1]),min(x1,clip[2]),min(y1,clip[3])
        if x1>x0 and y1>y0:
            rects.append((x0,y0,x1,y1))
    xs = sorted({x for rect in rects for x in (rect[0],rect[2])})
    area = 0.0
    for left,right in zip(xs,xs[1:]):
        spans = sorted((y0,y1) for x0,y0,x1,y1 in rects if x0<right and x1>left)
        length = 0.0
        end = -1.0
        for y0,y1 in spans:
            if y1 <= end:
                continue
            length += y1-max(y0,end)
            end = y1
        area += (right-left)*length
    return area / ((clip[2]-clip[0])*(clip[3]-clip[1]))


def redesign(level, attempt=0):
    number = int(level['id'])
    rng = random.Random(650001 + number * 277 + attempt * 100003)
    m = Map(WIDTH, HEIGHT)
    old_w, old_h = int(level['width']), int(level['height'])
    spawn = (WIDTH // 2, HEIGHT - 2)
    spawn_pos = ((spawn[0] + .5) * CELL, (spawn[1] + .5) * CELL)
    walls = [[0, 0, WIDTH, 1], [0, HEIGHT-1, WIDTH, 1],
             [0, 0, 1, HEIGHT], [WIDTH-1, 0, 1, HEIGHT],
             [1, 17, 17, 1], [25, 17, 3, 1],
             [1, 25, 7, 1], [15, 25, 13, 1],
             [4, 18, 2, 2], [13, 18, 2, 2],
             [3, 23, 2, 2], [17, 23, 2, 2]]
    partitions = [4, 5, 6, 7, 8, 9, 10, 11]
    gates = [[18, 17, 7, 1], [8, 25, 7, 1]]
    physical = [geom(item) for item in walls]
    solid = 0
    for rect in physical:
        solid |= m.rect_mask(rect, GUARD_MARGIN)
    free = m.all & ~solid
    seed = m.nearest(free, spawn)
    if not m.connected(free, seed):
        raise RuntimeError(f'Level {number}: fixed green gates are disconnected')

    def acceptable(items):
        rects = [geom(item) for item in items]
        if any(contains(rect, spawn_pos, 52.0) for rect in rects):
            return False
        if any(too_close(rect, other, ART_GAP) for rect in rects for other in physical):
            return False
        trial = solid
        for rect in rects:
            trial |= m.rect_mask(rect, GUARD_MARGIN)
        avail = m.all & ~trial
        return m.connected(avail, m.nearest(avail, spawn))

    def place(items):
        nonlocal solid
        for item in items:
            rect = geom(item)
            physical.append(rect)
            solid |= m.rect_mask(rect, GUARD_MARGIN)

    shapes = []
    # Large contiguous crates, not scattered small single-cell obstacles.
    # Each L has two thick overlapping arms and is drawn as a multi-crate stack.
    for lo, hi in ((2, 15), (27, 43)):
        for _group in range(3):
            found = False
            candidates = []
            for _attempt in range(1600):
                w = rng.randint(5, 8)
                h = rng.randint(5, 7)
                thick = rng.choice((3, 3, 4))
                x = rng.randint(2, WIDTH-2-w)
                y = rng.randint(lo, hi-h+1)
                orientation = rng.randrange(4)
                candidates.append((x,y,w,h,thick,orientation))
            for x, y, w, h, thick, orientation in candidates:
                bottom, right = bool(orientation & 2), bool(orientation & 1)
                row = y + h - thick if bottom else y
                column = x + w - thick if right else x
                vert_y = y if bottom else y + thick
                arms = [[x, row, w, thick], [column, vert_y, thick, h-thick]]
                if not acceptable(arms):
                    continue
                index = len(walls)
                walls.extend(arms)
                place(arms)
                shapes.append({'arms': [index, index + 1], 'color': 'red'})
                found = True
                break
            if not found:
                if attempt < 30:
                    return redesign(level, attempt + 1)
                raise RuntimeError(f'Level {number}: unable to place six large L clusters')

    crates = []
    candidates = [(x, y, w, h) for y in range(2, HEIGHT-4)
                  for x in range(2, WIDTH-4) for w, h in ((3, 2), (2, 3), (3, 3), (4, 2))
                  if x+w < WIDTH-2 and y+h < HEIGHT-2]
    rng.shuffle(candidates)
    # Give the initial camera view the same busy, clustered feel as the
    # reference; the stable shuffle still varies each level.
    candidates.sort(key=lambda c: 0 if 7 <= c[0] and c[0] + c[2] <= 22 and 13 <= c[1] and c[1] + c[3] <= 44 else 1)
    for x,y,w,h in candidates:
        item = [x,y,w,h,'wood']
        if acceptable([item]):
            crates.append(item)
            place([item])
            if len(crates) >= 16:
                break
    if len(crates) < 6:
        if attempt < 30:
            return redesign(level, attempt + 1)
        raise RuntimeError(f'Level {number}: cannot fit at least six large crate stacks')

    # Retry deterministically until the initial-view obstacle density is close
    # to the user's reference, while maintaining guard-clear connectivity.
    density = viewport_coverage(walls[4:] + crates)
    if not (REFERENCE_COVERAGE_MIN <= density <= REFERENCE_COVERAGE_MAX):
        if attempt < 80:
            return redesign(level, attempt + 1)
        raise RuntimeError(f'Level {number}: cannot match reference density: {density:.3f}')
    free = m.all & ~solid
    assert m.connected(free, m.nearest(free, spawn))
    options = [m.point(i) for i in bits(free)]
    def openness(point):
        x, y = point
        return sum(0 <= x+dx < WIDTH and 0 <= y+dy < HEIGHT and bool(free & m.bit((x+dx,y+dy)))
                   for dx,dy in ((1,0),(-1,0),(0,1),(0,-1)))
    placed, guards = [], []
    for old in level['guards']:
        scaled = (round(old['x']*(WIDTH-1)/(old_w-1)), round(old['y']*(HEIGHT-1)/(old_h-1)))
        choices = sorted(options, key=lambda p: (openness(p)<3,
                         (p[0]-scaled[0])**2 + (p[1]-scaled[1])**2,
                         abs(p[1]-scaled[1]), p[1], p[0]))
        pick = None
        for gap in (176, 160, 144, 128):
            pick = next((p for p in choices if math.dist(p, spawn)*CELL >= 300 and
                         all(math.dist(p,q)*CELL >= gap for q in placed)), None)
            if pick is not None:
                break
        if pick is None:
            if attempt < 30:
                return redesign(level, attempt + 1)
            raise RuntimeError(f'Level {number}: no spaced guard starts')
        placed.append(pick)
        guard = dict(old)
        guard['x'], guard['y'] = pick
        route = [list(pick)]
        for target in old.get('route', [])[1:]:
            q = min(options, key=lambda p: ((p[0]-target[0])**2+(p[1]-target[1])**2,p[1],p[0]))
            route.append(list(q))
        guard['route'] = route
        guards.append(guard)
    result = dict(level)
    result.update(width=WIDTH, height=HEIGHT, spawn=list(spawn), walls=walls, crates=crates,
                  guards=guards, l_shapes=shapes, partition_walls=partitions,
                  gate_decor=gates, area_breaks=[17,25], room_floor=[18,25])
    return result


def main():
    if len(sys.argv) != 3:
        raise SystemExit('Usage: python3 tools/redesign_levels_v65.py v064_levels.json v065_levels.json')
    data = json.loads(Path(sys.argv[1]).read_text())
    if data.get('layout_revision') != '0.6.4':
        raise SystemExit('Input must be original v0.6.4 levels.')
    # Level 17 uses the second deterministic seed: the first layout was
    # connected but produced a long guard-patrol bottleneck in live tests.
    data['levels'] = [redesign(level, 2 if int(level['id']) == 17 else 0) for level in data['levels']]
    data['layout_revision'] = '0.6.5'
    Path(sys.argv[2]).write_text(json.dumps(data,separators=(',',':'))+'\n')
    print('Generated', len(data['levels']), 'denser maps;',
          sum(len(l['guards']) for l in data['levels']), 'guards;',
          sum(len(l['l_shapes']) for l in data['levels']), 'large L clusters;',
          sum(len(l['crates']) for l in data['levels']), 'large crate stacks.')


if __name__ == '__main__':
    main()
