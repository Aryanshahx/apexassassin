#!/usr/bin/env python3
"""Generate 100 validated industrial stealth levels for Apex Assassin."""
import json, random
from repair_levels_v62 import repair
from redesign_levels_v63 import redesign
from redesign_levels_v64 import redesign as enlarge_v64
from collections import deque
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
W, H = 21, 34
CRATE_TYPES = ["blue", "blue", "olive", "gray"]
SPAWN = (10, H - 2)


def neighbors(c):
    x, y = c
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        yield (x + dx, y + dy)


def reachable(blocked, start=SPAWN):
    if start in blocked:
        return set()
    seen = {start}
    q = deque([start])
    while q:
        c = q.popleft()
        for n in neighbors(c):
            if 0 <= n[0] < W and 0 <= n[1] < H and n not in blocked and n not in seen:
                seen.add(n)
                q.append(n)
    return seen


def all_free_connected(blocked):
    free = {(x, y) for x in range(W) for y in range(H) if (x, y) not in blocked}
    if not free:
        return False
    return len(reachable(blocked, next(iter(free)))) == len(free)


def build(level: int):
    rng = random.Random(9000 + level)
    walls = [[0, 0, W, 1], [0, H - 1, W, 1], [0, 0, 1, H], [W - 1, 0, 1, H]]
    for x in (6, 14):
        gaps = set()
        for _ in range(4):
            gy = rng.randint(2, H - 5)
            for g in range(gy, gy + rng.randint(2, 3)):
                gaps.add(g)
        y = 1
        while y < H - 1:
            if y in gaps:
                y += 1
                continue
            y0 = y
            while y < H - 1 and y not in gaps:
                y += 1
            walls.append([x, y0, 1, y - y0])
    cross_rows = [9, 18, 27] if level > 12 else [12, 24]
    for y in cross_rows:
        gaps = set()
        for _ in range(3):
            gx = rng.randint(1, W - 4)
            for g in range(gx, gx + rng.randint(2, 3)):
                gaps.add(g)
        x = 1
        while x < W - 1:
            if x in gaps:
                x += 1
                continue
            x0 = x
            while x < W - 1 and x not in gaps:
                x += 1
            if x - x0 >= 2:
                walls.append([x0, y, x - x0, 1])

    def wall_block(seg):
        b = set()
        for x, y, w, h in seg:
            for xx in range(x, x + w):
                for yy in range(y, y + h):
                    b.add((xx, yy))
        b.discard(SPAWN)
        return b

    blocked = wall_block(walls)
    # Repair wall layouts that seal off pockets by opening whole segments.
    while not all_free_connected(blocked) and len(walls) > 4:
        idx = rng.randrange(4, len(walls))
        walls.pop(idx)
        blocked = wall_block(walls)
    assert all_free_connected(blocked), f"walls disconnect level {level}"

    crates = []
    attempts = 0
    target_crates = 10 + min(12, level // 6)
    while len(crates) < target_crates and attempts < 600:
        attempts += 1
        w = rng.choice([1, 1, 2, 2, 3])
        h = rng.choice([1, 1, 2, 2, 3])
        x = rng.randint(1, W - 1 - w)
        y = rng.randint(2, H - 3 - h)
        cells = [(xx, yy) for xx in range(x, x + w) for yy in range(y, y + h)]
        if any(c in blocked for c in cells):
            continue
        if any(abs(c[0] - SPAWN[0]) + abs(c[1] - SPAWN[1]) < 3 for c in cells):
            continue
        trial = blocked | set(cells)
        if not all_free_connected(trial):
            continue
        crates.append([x, y, w, h, rng.choice(CRATE_TYPES)])
        blocked = trial

    reach = reachable(blocked)
    free = [c for c in reach if c != SPAWN and c[1] < H - 3]
    rng.shuffle(free)
    guard_count = min(12, 4 + level // 4)
    guards = []
    # Two passes: prefer spacing, then relax to guarantee the target count.
    for min_dist in (3, 2, 1):
        for c in free:
            if len(guards) >= guard_count:
                break
            if abs(c[0] - SPAWN[0]) + abs(c[1] - SPAWN[1]) < 8:
                continue
            if any(abs(c[0] - g["x"]) + abs(c[1] - g["y"]) < min_dist for g in guards):
                continue
            targets = [t for t in free if 2 <= abs(t[0] - c[0]) + abs(t[1] - c[1]) <= 6]
            route = [list(c)]
            if targets:
                route.append(list(rng.choice(targets)))
            guards.append({
                "x": c[0], "y": c[1], "route": route,
                "face": rng.choice([0, 90, 180, 270]),
                "elite": level > 20 and len(guards) == 0,
            })
        if len(guards) >= guard_count:
            break
    assert len(guards) >= 4, f"level {level} only {len(guards)} guards"
    assert len(reachable(blocked)) == W * H - len(blocked), f"level {level} disconnected"

    return {
        "id": level, "name": "Level %d" % level,
        "width": W, "height": H,
        "walls": walls, "crates": crates,
        "spawn": list(SPAWN), "guards": guards,
        "reward_cash": 50 + level * 5,
    }


def main():
    # Build and repair the original seeded maps, then transform them into the
    # larger v0.6.4 warehouse with six joined L groups and clear passages.
    levels = [enlarge_v64(redesign(repair(build(i))[0])) for i in range(1, 101)]
    out = ROOT / "data" / "levels" / "levels.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps({"schema": 3, "levels": levels, "layout_revision": "0.6.4"}, separators=(",", ":")) + "\n")
    total_guards = sum(len(l["guards"]) for l in levels)
    print("Generated %d levels (%d guards total) -> %s" % (len(levels), total_guards, out))
    for i in (1, 4, 20, 50, 100):
        l = levels[i - 1]
        print("  Level %3d: %2d guards, %2d crates, %2d wall segments" % (i, len(l["guards"]), len(l["crates"]), len(l["walls"])))


if __name__ == "__main__":
    main()
