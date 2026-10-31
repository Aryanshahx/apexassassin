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
	for number in range(1, 101):
		lv.wall_rects.clear()
		lv.crate_rects.clear()
		lv._load_level(number)
		lv._build_grid()
		lv._build_walkable_regions()
		var spawn: Vector2i = lv._to_cell(lv.player_pos)
		var player_region := int(lv.region_by_cell.get(spawn, -1))
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
				if pos.distance_to(prior) < 96.0:
					spawn_safe = false
			positions.append(pos)
			guard_count += 1
		check(spawn_safe, "level %d guards spawn apart from cover and are reachable" % number)
		check(lv.data.crates.size() >= 10 and lv.data.guards.size() >= 4, "level %d retains its obstacles and guards" % number)
	check(guard_count == 1064, "all original 1064 guard spawns retained")
	check(crate_count == 1744, "all original 1744 crates retained")
	lv.free()
	print("LAYOUT %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
