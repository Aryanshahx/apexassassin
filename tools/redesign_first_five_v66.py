#!/usr/bin/env python3
"""Approximate the visible first-five Hunter Assassin walkthrough layouts.

Reference: https://www.youtube.com/watch?v=EFnL3VUJ9fk (2020).
Individual stills corroborate parts of levels 1, 3, 4 and 5; the walkthrough
pans, and not every edge is visible. These are *not* exact copies. Distances
are adapted to Apex Assassin's existing enlarged, guard-clear cover. This
script changes only levels 1–5 and leaves levels 6–100 exactly as loaded.
"""
from pathlib import Path
import json

PATH = Path(__file__).resolve().parents[1] / 'data/levels/levels.json'
W, H = 20, 34
BORDER = [[0,0,W,1], [0,H-1,W,1], [0,0,1,H], [W-1,0,1,H]]

# Walls and wood rectangles are in 32-unit cells. Each reference-style level
# has two guards, as visible in the first-five walkthrough's 0/2 HUD.
LAYOUTS = [
    # Level 1: two large central square islands and a middle cross-wall.
    dict(walls=[[8,4,4,4], [1,16,10,2], [18,16,1,2], [8,25,4,4]],
         crates=[[6,4,2,2], [12,5,1,2], [6,24,2,2], [12,26,2,2],
                 [2,12,1,2], [16,13,1,2], [2,29,2,1], [16,29,2,1]],
         spawn=[10,31], guards=[(14,20,270), (5,10,90)]),
    # Level 2: long left-of-centre vertical wall, lower L and staggered blocks.
    dict(walls=[[6,6,1,10], [6,21,1,6], [3,26,4,1]],
         crates=[[10,4,1,1], [15,4,1,1], [10,9,1,1], [15,9,1,1],
                 [10,14,1,1], [15,14,1,1], [10,19,1,1], [15,19,1,1],
                 [10,24,1,1], [15,24,1,1], [7,10,2,3], [16,14,2,2],
                 [2,23,1,1], [12,28,2,2]],
         spawn=[10,31], guards=[(3,15,0), (14,21,270)]),
    # Level 3: left L-shaped enclosure, small posts and a square lower island.
    dict(walls=[[4,6,1,2], [4,12,1,11], [4,22,5,1], [16,22,3,1], [8,27,4,4]],
         crates=[[8,5,1,1], [14,5,2,2], [8,11,1,1], [14,11,2,1],
                 [8,17,1,1], [14,17,1,1], [1,18,2,2], [16,19,2,1],
                 [2,27,2,2], [15,27,2,1]],
         spawn=[15,31], guards=[(12,16,270), (12,8,90)]),
    # Level 4: paired long L walls forming a central lane and lower square blocks.
    dict(walls=[[4,5,1,9], [4,12,3,1], [14,5,1,6], [12,9,3,1],
                [14,15,1,8], [14,22,2,1], [3,25,3,3], [10,25,3,3], [16,25,2,3]],
         crates=[[6,4,2,2], [6,19,1,1], [15,24,2,1]],
         spawn=[10,31], guards=[(10,18,270), (10,6,90)]),
    # Level 5: alternating U-shaped left maze, with a separate right crate field.
    dict(walls=[[7,5,1,5], [4,9,4,1], [4,6,1,3],
                [7,14,1,5], [4,18,4,1], [4,15,1,3],
                [7,23,1,5], [4,27,4,1], [4,24,1,3]],
         crates=[[11,3,1,1], [15,3,1,1], [11,8,1,1], [15,8,1,1],
                 [11,14,1,1], [15,14,1,1], [11,20,1,1], [15,20,1,1],
                 [11,27,1,1], [15,27,2,2], [2,24,2,1]],
         spawn=[10,31], guards=[(13,17,0), (13,8,90)]),
]


def main():
    catalog = json.loads(PATH.read_text())
    if len(catalog['levels']) != 100:
        raise SystemExit('Expected the existing 100-level catalog')
    for index, plan in enumerate(LAYOUTS):
        old = catalog['levels'][index]
        if old['id'] != index + 1:
            raise SystemExit('Unexpected level order')
        authored = []
        for x, y, facing in plan['guards']:
            authored.append({'x': x, 'y': y, 'route': [[x,y], [x,y+1]],
                             'face': facing, 'elite': False})
        catalog['levels'][index] = {
            'id': old['id'], 'name': old['name'], 'width': W, 'height': H,
            'walls': BORDER + plan['walls'],
            'crates': [r + ['wood'] for r in plan['crates']],
            'spawn': plan['spawn'], 'guards': authored,
            'reward_cash': old['reward_cash'],
            'walkthrough_reference': '2020-first-five-approximate',
        }
    PATH.write_text(json.dumps(catalog, separators=(',', ':')) + '\n')
    print('Rebuilt first five approximate walkthrough maps; levels 6–100 unchanged.')

if __name__ == '__main__':
    main()
