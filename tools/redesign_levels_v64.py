#!/usr/bin/env python3
"""Generate larger, navigable industrial maps from the v0.6.3 levels.

Original guard counts, level IDs and rewards are retained. Connected green
partitions, wide gates, large joined L containers and a few large crate clusters
replace small scattered cover. Every guard-clear cell remains connected.
"""
import json
import math
import random
import sys
from pathlib import Path
from repair_levels_v62 import Map, geom, too_close, contains, bits, CELL, GUARD_MARGIN, ART_GAP

WIDTH = 29
HEIGHT = 46


def redesign(level):
    n = int(level['id'])
    rng = random.Random(640000 + 193 * n)
    m = Map(WIDTH, HEIGHT)
    old_w, old_h = int(level['width']), int(level['height'])
    spawn = (WIDTH // 2, HEIGHT - 2)
    spawn_pos = ((spawn[0] + .5) * CELL, (spawn[1] + .5) * CELL)
    walls = [[0, 0, WIDTH, 1], [0, HEIGHT-1, WIDTH, 1],
             [0, 0, 1, HEIGHT], [WIDTH-1, 0, 1, HEIGHT]]
    physical = [geom(item) for item in walls]
    solid = 0
    for rect in physical:
        solid |= m.rect_mask(rect, GUARD_MARGIN)
    shapes, partitions, gates = [], [], []

    def acceptable(items):
        trial = solid
        rects = [geom(item) for item in items]
        if any(contains(rect, spawn_pos, 52.0) for rect in rects):
            return False
        if any(too_close(rect, other, ART_GAP) for rect in rects for other in physical):
            return False
        for rect in rects:
            trial |= m.rect_mask(rect, GUARD_MARGIN)
        free = m.all & ~trial
        seed = m.nearest(free, spawn)
        return m.connected(free, seed)

    def place(items):
        nonlocal solid
        for item in items:
            rect = geom(item)
            physical.append(rect)
            solid |= m.rect_mask(rect, GUARD_MARGIN)

    # Two interrupted green defensive walls with wide walkable gate openings.
    # Segments deliberately stop short of the outer walls for alternate routes.
    for y in (15, 30):
        candidates = [[3, y, 7, 1], [19, y, 7, 1]]
        for segment in candidates:
            if acceptable([segment]):
                partitions.append(len(walls))
                walls.append(segment)
                place([segment])
        gates.append([11, y, 7, 1])  # decoration only; never a blocker

    # Distribute six long joined L groups vertically, retaining earlier scope.
    bands = ((3, 8), (9, 14), (16, 21), (22, 28), (31, 36), (37, 42))
    for band, (lo, hi) in enumerate(bands):
        candidates = []
        for y in range(lo, hi + 1):
            for x in range(3, WIDTH - 4):
                for w in (4, 5, 6, 7):
                    for h in (4, 5, 6):
                        if x + w >= WIDTH - 2 or y + h >= HEIGHT - 2:
                            continue
                        for orientation in range(4):
                            candidates.append((x, y, w, h, orientation))
        rng.shuffle(candidates)
        for x, y, w, h, orientation in candidates:
            bottom, right = bool(orientation & 2), bool(orientation & 1)
            row = y + h - 1 if bottom else y
            column = x + w - 1 if right else x
            vertical_y = y if bottom else y + 1
            arms = [[x, row, w, 1], [column, vertical_y, 1, h - 1]]
            if not acceptable(arms):
                continue
            index = len(walls)
            walls.extend(arms)
            place(arms)
            # Warm reddish-brown covers like the supplied reference, while
            # retaining small color accents and the approved depot material.
            color = ('red', 'red', 'olive', 'red', 'red', 'blue')[(n + band) % 6]
            shapes.append({'arms': [index, index+1], 'color': color})
            break
        else:
            raise RuntimeError(f'Level {n}: cannot place long L cover in band {band}')

    # A few larger box stacks; no one-cell clutter.
    crates = []
    candidate_boxes = [(x, y, w, h) for y in range(3, HEIGHT-4)
                       for x in range(3, WIDTH-4) for w, h in ((2, 2), (3, 2), (2, 3))
                       if x+w < WIDTH-2 and y+h < HEIGHT-2]
    rng.shuffle(candidate_boxes)
    for x, y, w, h in candidate_boxes:
        item = [x, y, w, h, 'wood']
        if acceptable([item]):
            crates.append(item)
            place([item])
            if len(crates) == 3:
                break
    if len(crates) < 2:
        raise RuntimeError(f'Level {n}: not enough room for large crate accents')

    free = m.all & ~solid
    seed = m.nearest(free, spawn)
    assert m.connected(free, seed)
    options = [m.point(i) for i in bits(free)]
    def openness(point):
        x, y = point
        return sum(0 <= x+dx < WIDTH and 0 <= y+dy < HEIGHT and bool(free & m.bit((x+dx,y+dy)))
                   for dx, dy in ((1,0),(-1,0),(0,1),(0,-1)))
    placed, guards = [], []
    for old in level['guards']:
        old_pos = (round(old['x'] * (WIDTH-1)/(old_w-1)), round(old['y'] * (HEIGHT-1)/(old_h-1)))
        choices = sorted(options, key=lambda p: (openness(p) < 3,
                         (p[0]-old_pos[0])**2 + (p[1]-old_pos[1])**2, abs(p[1]-old_pos[1]), p[1], p[0]))
        pick = None
        for gap in (176, 160, 144, 128, 112):
            pick = next((p for p in choices if math.dist(p, spawn)*CELL >= 300 and
                         all(math.dist(p, q)*CELL >= gap for q in placed)), None)
            if pick is not None:
                break
        if pick is None:
            raise RuntimeError(f'Level {n}: no spaced guard start')
        placed.append(pick)
        guard = dict(old)
        guard['x'], guard['y'] = pick
        route = [list(pick)]
        for target in old['route'][1:]:
            scaled = (round(target[0]*(WIDTH-1)/(old_w-1)), round(target[1]*(HEIGHT-1)/(old_h-1)))
            q = min(options, key=lambda p: ((p[0]-scaled[0])**2 + (p[1]-scaled[1])**2,p[1],p[0]))
            route.append(list(q))
        guard['route'] = route
        guards.append(guard)
    result = dict(level)
    result.update(width=WIDTH, height=HEIGHT, spawn=list(spawn), walls=walls, crates=crates,
                  guards=guards, l_shapes=shapes, partition_walls=partitions, gate_decor=gates)
    return result


def main():
    if len(sys.argv) != 3:
        raise SystemExit('Usage: python3 tools/redesign_levels_v64.py v063_levels.json v064_levels.json')
    data = json.loads(Path(sys.argv[1]).read_text())
    if data.get('layout_revision') != '0.6.3':
        raise SystemExit('Input must be original v0.6.3 levels, not already-redesigned maps.')
    data['levels'] = [redesign(level) for level in data['levels']]
    data['layout_revision'] = '0.6.4'
    Path(sys.argv[2]).write_text(json.dumps(data, separators=(',', ':'))+'\n')
    print('Generated',len(data['levels']),'larger levels with',sum(len(x['guards']) for x in data['levels']),
          'guards,',sum(len(x['l_shapes']) for x in data['levels']),'L groups,',
          sum(len(x['partition_walls']) for x in data['levels']),'green wall segments and',
          sum(len(x['crates']) for x in data['levels']),'large crates.')

if __name__ == '__main__':
    main()
