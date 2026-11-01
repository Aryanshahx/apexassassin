extends RefCounted
## Synthetic open arena for isolated behavior tests. Dense production maps are
## independently tested for real routing, connectivity and guard traffic.
static func open_arena(lv: Node2D) -> Vector2:
	lv.blocking_rects.clear()
	lv.guard_blocking_rects.clear()
	lv._build_grid()
	lv._build_walkable_regions()
	return lv._cell_center(6, 8)
