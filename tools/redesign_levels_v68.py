#!/usr/bin/env python3
"""Generate 100 new, navigable environments based on the supplied asset sheet.

Level IDs, guard counts, guard attributes and rewards are retained. Geometry,
visual themes and object placement are new. Guard-clear floor connectivity,
expanded collision boxes and authored spawn safety are validated for every
accepted placement. Theme and placement are deterministic for each level.

Usage: python3 tools/redesign_levels_v68.py v067_levels.json v068_levels.json
"""
from pathlib import Path
import json
import math
import random
import sys
from collections import Counter

from repair_levels_v62 import Map, geom, too_close, contains, bits, CELL, GUARD_MARGIN, ART_GAP

WIDTH, HEIGHT = 29, 46
THEMES = ('warehouse', 'factory', 'dockyard', 'military', 'night', 'desert', 'snow', 'rooftop')
NAMES = {'warehouse': 'Warehouse', 'factory': 'Factory', 'dockyard': 'Dockyard',
         'military': 'Military Base', 'night': 'Night Ops', 'desert': 'Desert Base',
         'snow': 'Snow Base', 'rooftop': 'Urban Rooftop'}
# kind, width, height. Clusters are one physical obstacle with multiple visible
# crates, avoiding gaps between the sprites and their solid rectangle.
PLANS = {
    'warehouse': [('wood_cluster',4,2), ('wood_cluster',2,4), ('crate_green',2,2), ('crate_steel',2,2), ('barrel_red',2,3), ('pallet',3,2)],
    'factory': [('crate_metal',4,2), ('crate_steel',2,2), ('barrel_blue',2,3), ('barrel_red',2,3), ('crate_hazard',2,2), ('pipe_v',2,6), ('fence',2,3)],
    'dockyard': [('container_blue_v',2,6), ('container_red_h',6,2), ('wood_cluster',4,2), ('crate_hazard',2,2)],
    'military': [('sandbags',4,2), ('crate_camo',3,2), ('crate_green',2,2), ('wood_cluster',2,4), ('barrel_red',2,3)],
    'night': [('wood_cluster',4,2), ('crate_steel',2,2), ('barrel_blue',2,3), ('crate_green',2,2), ('crate_hazard',2,2)],
    'desert': [('sandbags',4,2), ('wood_cluster',2,4), ('crate_wood',2,2), ('crate_camo',3,2), ('tires',2,2)],
    'snow': [('crate_steel',2,2), ('crate_metal',4,2), ('wood_cluster',4,2), ('barrel_blue',2,3), ('sandbags',4,2)],
    'rooftop': [('crate_metal',4,2), ('vent',2,2), ('crate_steel',2,2), ('wall_hazard',4,2), ('crate_hazard',2,2)],
}
ZONES = ((2, 15), (16, 28), (29, 43))


def generate(level, attempt=0):
    number = int(level['id'])
    theme = THEMES[(number - 1) % len(THEMES)]
    rng = random.Random(6800329 + number * 701 + attempt * 104729)
    m = Map(WIDTH, HEIGHT)
    # Leave the player visibly above the bottom edge and close to useful cover.
    spawn = (14, 42)
    spawn_pos = ((spawn[0] + 0.5) * CELL, (spawn[1] + 0.5) * CELL)
    walls = [[0,0,WIDTH,1], [0,HEIGHT-1,WIDTH,1], [0,0,1,HEIGHT], [WIDTH-1,0,1,HEIGHT]]
    crates = []
    wall_kinds = {}
    physical = [geom(item) for item in walls]
    solid = 0
    for rect in physical:
        solid |= m.rect_mask(rect, GUARD_MARGIN)
    # Military sample has a genuinely clear helipad, not a decal hidden under
    # crates. It is decorative and completely walkable.
    reserve = (9*CELL, 17*CELL, 20*CELL, 28*CELL) if theme == 'military' else None

    def acceptable(item):
        rect = geom(item)
        if contains(rect, spawn_pos, 52.0):
            return False
        if reserve is not None and too_close(rect, reserve, 12.0):
            return False
        if any(too_close(rect, other, ART_GAP) for other in physical):
            return False
        trial = solid | m.rect_mask(rect, GUARD_MARGIN)
        free = m.all & ~trial
        return m.connected(free, m.nearest(free, spawn))

    def put(item, wall_kind=None):
        nonlocal solid
        physical.append(geom(item))
        solid |= m.rect_mask(geom(item), GUARD_MARGIN)
        if wall_kind is None:
            crates.append(item)
        else:
            wall_kinds[str(len(walls))] = wall_kind
            walls.append(item[:4])

    def find_place(kind, w, h, zone):
        low, high = zone
        if high-h < low:
            return False
        spots = [(x,y) for y in range(low, high-h+1) for x in range(2, WIDTH-2-w+1)]
        rng.shuffle(spots)
        # Keep a lively mix of props in the initially visible center, instead
        # of hiding most of the reference detail against the side walls.
        if rng.random() < 0.68:
            spots.sort(key=lambda p: 0 if 7 <= p[0] and p[0] + w <= 22 else 1)
        for x, y in spots:
            item = [x,y,w,h,kind]
            if acceptable(item):
                put(item)
                return True
        return False

    # A low cover cluster shields the initial player position from long direct
    # sightlines while leaving broad routes around both sides.
    starter_kind = {'warehouse':'wood_cluster', 'factory':'crate_metal', 'dockyard':'container_blue_h',
                    'military':'sandbags', 'night':'wood_cluster', 'desert':'sandbags',
                    'snow':'crate_metal', 'rooftop':'wall_hazard'}[theme]
    starter_width = 6 if theme == 'dockyard' else 4
    starter = [14 - starter_width // 2, 38, starter_width, 2, starter_kind]
    if not acceptable(starter):
        raise RuntimeError(f'Level {number}: invalid starter cover')
    put(starter)

    # Place each environment's identifying objects in each of the three
    # traversal regions; repeatable RNG makes 100 distinct arrangements.
    for zone_index, zone in enumerate(ZONES):
        order = list(PLANS[theme])
        rng.shuffle(order)
        # The initial warehouse camera always contains wood, steel, green and
        # a red barrel, as in the user's main reference.
        required = 4 if theme == 'dockyard' else 5
        placed = 0
        for kind, w, h in order:
            if find_place(kind, w, h, zone):
                placed += 1
        if placed < required - (1 if theme == 'military' and zone_index == 1 else 0):
            if attempt < 40:
                return generate(level, attempt+1)
            raise RuntimeError(f'Level {number}: cannot fit {theme} reference props safely in zone {zone_index}')

    # Short real concrete barricades with broad lanes; do not add walls to the
    # center of the helipad. They use the matching sheet-derived wall sprites.
    for j in range(2 if theme not in ('warehouse', 'military') else 1):
        kind = 'wall_hazard' if theme in ('factory','rooftop') and j == 0 else 'wall_concrete'
        shapes = [(4,1), (1,4), (5,1)]
        rng.shuffle(shapes)
        candidates = []
        for w,h in shapes:
            for y in range(4, 41-h):
                for x in range(2, WIDTH-2-w+1):
                    candidates.append([x,y,w,h,kind])
        rng.shuffle(candidates)
        for candidate in candidates:
            if acceptable(candidate):
                put(candidate, kind)
                break

    free = m.all & ~solid
    assert m.connected(free, m.nearest(free, spawn))
    options = [m.point(i) for i in bits(free)]

    def openness(p):
        x,y=p
        return sum(0 <= x+dx < WIDTH and 0 <= y+dy < HEIGHT and bool(free & m.bit((x+dx,y+dy)))
                   for dx,dy in ((1,0),(-1,0),(0,1),(0,-1)))

    # Keep each original guard and elite flag but repair authored routes to the
    # new clearance grid. Runtime distribution still spreads them further.
    placed, guards = [], []
    old_w, old_h = int(level['width']), int(level['height'])
    for old in level['guards']:
        intended = (round(old['x']*(WIDTH-1)/(old_w-1)), round(old['y']*(HEIGHT-1)/(old_h-1)))
        choices = sorted(options, key=lambda p: (openness(p)<3, (p[0]-intended[0])**2+(p[1]-intended[1])**2,
                                                  abs(p[1]-intended[1]), p[1], p[0]))
        chosen = next((p for p in choices if math.dist(p,spawn)*CELL >= 288 and
                       all(math.dist(p,q)*CELL >= 160 for q in placed)), None)
        if chosen is None:
            if attempt < 40:
                return generate(level, attempt+1)
            raise RuntimeError(f'Level {number}: no safe positions for all guards')
        placed.append(chosen)
        guard = dict(old)
        guard['x'], guard['y'] = chosen
        guard['route'] = [list(chosen)]
        for target in old.get('route', [])[1:]:
            pick = min(options, key=lambda p: ((p[0]-target[0])**2+(p[1]-target[1])**2,p[1],p[0]))
            guard['route'].append(list(pick))
        guards.append(guard)

    # Embedded lights and floor details are art only; they never add collision.
    details = []
    choices = [p for p in options if 3 <= p[0] <= WIDTH-4 and 3 <= p[1] <= HEIGHT-4 and
               math.dist(p,spawn) >= 3 and not (reserve is not None and contains(reserve,((p[0]+.5)*CELL,(p[1]+.5)*CELL),0))]
    rng.shuffle(choices)
    detail_types = ['grate', 'manhole', 'vent']
    if theme in ('military', 'desert'):
        detail_types += ['plant', 'bush']
    elif theme in ('warehouse', 'factory'):
        detail_types += ['camera']
    for kind in detail_types:
        pick = next((p for p in choices if all(math.dist(p,(d['x'],d['y'])) >= 5 for d in details)), None)
        if pick:
            details.append({'kind': kind, 'x': pick[0], 'y': pick[1]})
    # Visible warm pools on the inner floor, inspired by the reference's
    # warehouse lamps; their positions are visual only, never collision.
    lights = [[8,5], [20,15], [8,30], [20,40]]
    result = dict(level)
    result.update(width=WIDTH, height=HEIGHT, spawn=list(spawn), walls=walls, crates=crates,
                  guards=guards, theme=theme, theme_name=NAMES[theme], wall_kinds=wall_kinds,
                  l_shapes=[], partition_walls=list(map(int,wall_kinds)), gate_decor=[],
                  area_breaks=[], room_floor=[], scenery_details=details, scenery_lights=lights)
    if theme == 'military':
        result['helipad'] = [14.5, 22.5, 5.0]
    else:
        result.pop('helipad', None)
    return result


def main():
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    source, target = map(Path, sys.argv[1:])
    document = json.loads(source.read_text())
    old = document['levels']
    if len(old) != 100:
        raise SystemExit('Expected the existing 100-level catalog.')
    new = [generate(level) for level in old]
    assert [x['id'] for x in new] == [x['id'] for x in old]
    assert [len(x['guards']) for x in new] == [len(x['guards']) for x in old]
    assert [x['reward_cash'] for x in new] == [x['reward_cash'] for x in old]
    assert len({json.dumps([x['walls'],x['crates']],sort_keys=True) for x in new}) == len(new)
    document['levels'] = new
    document['layout_revision'] = '0.6.8-reference-sheet'
    target.write_text(json.dumps(document,separators=(',',':')) + '\n')
    print('Generated',len(new),'unique playable reference-inspired environments')
    print('Themes:', dict(Counter(x['theme'] for x in new)))
    print('Guards:',sum(len(x['guards']) for x in new),'props:',sum(len(x['crates']) for x in new),
          'inner walls:',sum(len(x['walls'])-4 for x in new))
    print('IDs, enemy counts, elite flags and rewards retained from the existing catalog.')


if __name__ == '__main__':
    main()
