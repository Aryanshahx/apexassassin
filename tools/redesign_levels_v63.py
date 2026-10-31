#!/usr/bin/env python3
"""Replace small scattered obstacles with long, navigable L-shaped cover.

Input levels are the deterministic v0.6.2 layouts. Player spawn, rewards,
level IDs and all guards are preserved. Each L is made of two touching
container rectangles with a shared colour; no changes to actor scales.
"""
import json, math, random, sys
from pathlib import Path
from repair_levels_v62 import Map, geom, too_close, contains, bits, CELL, GUARD_MARGIN, PLAYER_MARGIN, ART_GAP


def redesign(lv):
    m = Map(lv['width'], lv['height'])
    rng = random.Random(630000 + int(lv['id']) * 17)
    spawn = tuple(lv['spawn'])
    spawn_pos = ((spawn[0] + .5) * CELL, (spawn[1] + .5) * CELL)
    walls = [list(x) for x in lv['walls'][:4]]
    physical = [geom(x) for x in walls]
    solid = 0
    for r in physical:
        solid |= m.rect_mask(r, GUARD_MARGIN)
    shapes = []

    def try_piece(items):
        nonlocal solid
        rects = [geom(item) for item in items]
        if any(contains(rect, spawn_pos, 44.0) for rect in rects):
            return False
        if any(too_close(rect, other, ART_GAP) for rect in rects for other in physical):
            return False
        trial = solid
        for rect in rects:
            trial |= m.rect_mask(rect, GUARD_MARGIN)
        free = m.all & ~trial
        seed = m.nearest(free, spawn)
        if not m.connected(free, seed):
            return False
        return True

    def add_piece(items):
        nonlocal solid
        for item in items:
            r = geom(item)
            physical.append(r)
            solid |= m.rect_mask(r, GUARD_MARGIN)

    # Four long Ls per map: distribute them up the map instead of clustering.
    for band, (lo, hi) in enumerate(((2, 7), (9, 14), (16, 21), (23, 27))):
        candidates = []
        for y in range(lo, hi + 1):
            for x in range(2, m.w - 3):
                for w in (4, 5, 6):
                    for h in (4, 5, 6):
                        if x + w >= m.w - 1 or y + h >= m.h - 1:
                            continue
                        for orientation in range(4):
                            candidates.append((x, y, w, h, orientation))
        rng.shuffle(candidates)
        placed = False
        for x, y, w, h, orientation in candidates:
            bottom = bool(orientation & 2)
            right = bool(orientation & 1)
            row = y + h - 1 if bottom else y
            column = x + w - 1 if right else x
            vertical_y = y if bottom else y + 1
            horizontal = [x, row, w, 1]
            vertical = [column, vertical_y, 1, h - 1]
            if not try_piece([horizontal, vertical]):
                continue
            first = len(walls)
            walls.extend([horizontal, vertical])
            add_piece([horizontal, vertical])
            shapes.append({'arms': [first, first + 1], 'color': ('blue', 'red', 'olive')[(lv['id'] + band) % 3]})
            placed = True
            break
        if not placed:
            raise RuntimeError(f"Level {lv['id']}: no safe long L in band {band}")

    # Retain at most two long structural pieces, never small fragments.
    long_walls = [list(a) for a in lv['walls'][4:] if max(a[2], a[3]) >= 5]
    rng.shuffle(long_walls)
    extra = 0
    for item in long_walls:
        if try_piece([item]):
            walls.append(item)
            add_piece([item])
            extra += 1
            if extra == 2:
                break

    # Keep at most two large existing crates as accents, not scattered tiny ones.
    candidates = [list(c) for c in lv['crates'] if c[2] * c[3] >= 4]
    rng.shuffle(candidates)
    candidates.sort(key=lambda c: -c[2] * c[3])
    crates = []
    for item in candidates:
        if try_piece([item]):
            crates.append(item)
            add_piece([item])
            if len(crates) == 2:
                break

    free = m.all & ~solid
    seed = m.nearest(free, spawn)
    assert m.connected(free, seed)
    options = [m.point(i) for i in bits(free)]
    positions, guards = [], []
    def openness(q):
        return sum(0 <= q[0] + dx < m.w and 0 <= q[1] + dy < m.h and bool(free & m.bit((q[0]+dx,q[1]+dy))) for dx,dy in ((1,0),(-1,0),(0,1),(0,-1)))
    for old in lv['guards']:
        pos = (old['x'], old['y'])
        ordered = sorted(options, key=lambda q: (openness(q) < 3, (q[0]-pos[0])**2 + (q[1]-pos[1])**2, abs(q[1]-pos[1]), q[1], q[0]))
        pick = None
        for gap in (128,112,96,80,70):
            pick = next((q for q in ordered if math.dist(q,spawn)*CELL >= 280 and all(math.dist(q,o)*CELL >= gap for o in positions)), None)
            if pick is not None:
                break
        if pick is None:
            raise RuntimeError(f"Level {lv['id']}: no safe guard start")
        positions.append(pick)
        g = dict(old)
        g['x'], g['y'] = pick
        route = [list(pick)]
        for target in old['route'][1:]:
            q = min(options, key=lambda z: ((z[0]-target[0])**2 + (z[1]-target[1])**2, z[1], z[0]))
            route.append(list(q))
        g['route'] = route
        guards.append(g)
    out = dict(lv)
    out['walls'], out['crates'], out['guards'], out['l_shapes'] = walls, crates, guards, shapes
    return out


def main():
    if len(sys.argv) != 3:
        raise SystemExit('Usage: python3 tools/redesign_levels_v63.py v062_levels.json v063_levels.json')
    data = json.loads(Path(sys.argv[1]).read_text())
    if data.get('layout_revision') != '0.6.2':
        raise SystemExit('Input must be original v0.6.2 repaired levels, not already redesigned maps.')
    data['levels'] = [redesign(lv) for lv in data['levels']]
    data['layout_revision'] = '0.6.3'
    Path(sys.argv[2]).write_text(json.dumps(data, separators=(',', ':')) + '\n')
    print('Redesigned', len(data['levels']), 'levels:', sum(len(x['l_shapes']) for x in data['levels']), 'L shapes,', sum(len(x['crates']) for x in data['levels']), 'accent crates,', sum(len(x['guards']) for x in data['levels']), 'guards.')


if __name__ == '__main__':
    main()
