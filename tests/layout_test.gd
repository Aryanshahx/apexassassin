extends SceneTree
## Validate all 100 enlarged level layouts, not just the currently visible map.
var checks := 0
var failures := 0
func _init() -> void:
	call_deferred("_run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)
func _run() -> void:
	var gs = root.get_node("GameState")
	var script = load("res://scripts/game/level.gd")
	var lv = script.new()
	check(is_equal_approx(lv.OBSTACLE_SCALE, 1.2), "all visible and collision cover is scaled 20%")
	check(lv.GRADE_FLOOR.r > 0.7 and lv.GRADE_FLOOR.g > 0.8 and lv.GRADE_WALL.r > 0.95, "brighter floor and colorful original container art")
	var guard_count := 0
	var crate_count := 0
	var shape_count := 0
	for number in range(1, 101):
		lv.wall_rects.clear()
		lv.crate_rects.clear()
		lv._load_level(number)
		lv._build_grid()
		lv._build_walkable_regions()
		var spawn: Vector2i = lv._to_cell(lv.player_pos)
		var player_region := int(lv.region_by_cell.get(spawn, -1))
		check(int(lv.data.width) == 29 and int(lv.data.height) == 46 and lv.data.get("partition_walls", []).size() == 4 and lv.data.get("gate_decor", []).size() == 2, "level %d is enlarged and has four green partitions and two open gates" % number)
		check(not lv._solid(lv.player_pos) and player_region >= 0, "level %d player spawn is clear" % number)
		check(lv.guard_walkable_regions.size() == 1, "level %d guard-clear floor is connected" % number)
		var geometry_ok: bool = lv.wall_rects.size() == lv.data.walls.size() and lv.crate_rects.size() == lv.data.crates.size()
		for pair in [[lv.data.walls, lv.wall_rects], [lv.data.crates, lv.crate_rects]]:
			for i in range(pair[0].size()):
				var item: Array = pair[0][i]
				var before := Rect2(lv.ORIGIN + Vector2(item[0], item[1]) * lv.CELL, Vector2(item[2], item[3]) * lv.CELL).grow(3.0)
				var actual: Rect2 = pair[1][i]
				if actual.get_center().distance_to(before.get_center()) > 0.001 or actual.size.distance_to(before.size * 1.2) > 0.001:
					geometry_ok = false
		check(geometry_ok, "level %d cover is exactly 20%% larger about the same centre" % number)
		var cover_clear := true
		for i in range(lv.crate_rects.size()):
			var expanded: Rect2 = lv.crate_rects[i].grow(13.99)
			for wall in lv.wall_rects:
				if expanded.intersects(wall):
					cover_clear = false
			for j in range(i):
				if expanded.intersects(lv.crate_rects[j]):
					cover_clear = false
		check(cover_clear, "level %d crates do not overlap walls or one another" % number)
		crate_count += lv.crate_rects.size()
		var spawn_safe := true
		var positions: Array[Vector2] = []
		for guard in lv.data.guards:
			var cell := Vector2i(int(guard.x), int(guard.y))
			var pos: Vector2 = lv._cell_center(cell.x, cell.y)
			if pos.distance_to(lv.player_pos) < 280.0 or lv._guard_solid(pos) or not lv.guard_region_by_cell.has(cell) or int(lv.region_by_cell.get(cell, -2)) != player_region:
				spawn_safe = false
			for prior in positions:
				if pos.distance_to(prior) < 160.0:
					spawn_safe = false
			positions.append(pos)
			guard_count += 1
		check(spawn_safe, "level %d guards spawn apart from cover and are reachable" % number)
		var shapes_ok: bool = lv.data.get("l_shapes", []).size() == 6
		var used := {}
		for shape in lv.data.get("l_shapes", []):
			if shape.arms.size() != 2 or not ["red", "blue", "olive"].has(String(shape.color)):
				shapes_ok = false
				continue
			var ai := int(shape.arms[0])
			var bi := int(shape.arms[1])
			if ai < 8 or bi < 8 or ai >= lv.data.walls.size() or bi >= lv.data.walls.size() or used.has(ai) or used.has(bi):
				shapes_ok = false
				continue
			used[ai] = true
			used[bi] = true
			var h: Array = lv.data.walls[ai]
			var v: Array = lv.data.walls[bi]
			if h[2] < 4 or h[3] != 1 or v[2] != 1 or v[3] < 3 or not lv.wall_rects[ai].intersects(lv.wall_rects[bi]):
				shapes_ok = false
			shape_count += 1
		check(shapes_ok and lv.data.guards.size() >= 4, "level %d has six genuinely joined long L covers and retains guards" % number)
		var accents_ok: bool = lv.data.crates.size() == 3
		for crate in lv.data.crates:
			if int(crate[2]) * int(crate[3]) < 4:
				accents_ok = false
		check(accents_ok, "level %d has three large crate clusters and no tiny scattered crates" % number)
	check(guard_count == 1064, "all original 1064 guard spawns retained")
	check(shape_count == 600, "600 long L-shaped cover groups across 100 enlarged levels")
	check(crate_count == 300, "three large crate clusters per map")
	lv.free()
	print("LAYOUT %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
