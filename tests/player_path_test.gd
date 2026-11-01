extends SceneTree
## Follow actual highlighted paths, including off-centre starts and tight corners.
var checks := 0
var failures := 0
func _init() -> void:
	call_deferred("_run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)
func follow(lv: Node2D, destination: Vector2) -> bool:
	lv._path_to(destination)
	if lv.player_path.is_empty():
		return lv.player_pos.distance_to(destination) < 1.0
	var end: Vector2 = lv.player_path[lv.player_path.size()-1]
	var before: Vector2 = lv.player_pos
	for waypoint in lv.player_path:
		if not lv._los(before, waypoint):
			return false
		before = waypoint
	for frame in range(500):
		before = lv.player_pos
		var old_route: PackedVector2Array = lv.player_path.duplicate()
		lv._move_player(1.0/30.0)
		# A single frame may cross a waypoint and turn. Validate both real
		# subsegments, not the fictitious straight chord across the corner.
		var corner: Vector2 = before
		var removed: int = old_route.size() - lv.player_path.size()
		for i in range(removed):
			if not lv._los(corner, old_route[i]):
				return false
			corner = old_route[i]
		if lv._solid(lv.player_pos) or not lv._los(corner, lv.player_pos):
			return false
		if lv.player_path.is_empty():
			return lv.player_pos.distance_to(end) < 0.05
		if lv.player_pos.distance_squared_to(before) < 0.00001:
			return false
	return false
func _run() -> void:
	var gs = root.get_node("GameState")
	gs.sound_enabled = false
	gs.selected_assassin = "ronin"
	gs.upgrades = {"speed": 0, "health": 0, "damage": 0}
	gs.start_level(1)
	await process_frame
	await process_frame
	var lv = current_scene
	lv.set_physics_process(false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 630456
	var routes := 0
	for n in range(1,101):
		lv.wall_rects.clear()
		lv.crate_rects.clear()
		lv._load_level(n)
		lv._build_grid()
		lv._build_walkable_regions()
		var spawn_cell: Vector2i = lv._to_cell(lv.player_pos)
		var cells: Array = lv.walkable_regions[int(lv.region_by_cell[spawn_cell])]
		var all_ok := true
		for sample in range(12):
			var a: Vector2i = cells[rng.randi_range(0,cells.size()-1)]
			var b: Vector2i = cells[rng.randi_range(0,cells.size()-1)]
			var start: Vector2 = lv._cell_center(a.x,a.y) + Vector2(rng.randf_range(-15.5,15.5),rng.randf_range(-15.5,15.5))
			var goal: Vector2 = lv._cell_center(b.x,b.y) + Vector2(rng.randf_range(-15.5,15.5),rng.randf_range(-15.5,15.5))
			if lv._solid(start): start = lv._cell_center(a.x,a.y)
			if lv._solid(goal): goal = lv._cell_center(b.x,b.y)
			lv.player_pos = start
			if not follow(lv, goal):
				all_ok = false
				print("ROUTE FAILURE level=",n," start=",start," goal=",goal," stopped=",lv.player_pos)
			routes += 1
		check(all_ok, "level %d follows highlighted off-centre paths without stopping or crossing cover" % n)
	# A wall cuts across one grid cell: its centre is solid even though the
	# start and destination are open. The player must route around the corner.
	lv.data = {"width": 8, "height": 8}
	lv.blocking_rects.clear()
	lv.blocking_rects.append(Rect2(Vector2(132, 244), Vector2(8, 16)))
	lv.guard_blocking_rects.clear()
	lv.guard_blocking_rects.append(lv.blocking_rects[0])
	lv._build_grid()
	lv._build_walkable_regions()
	lv.player_pos = Vector2(128,252)
	var goal := Vector2(144,252)
	check(not lv._solid(lv.player_pos) and not lv._solid(goal) and lv._to_cell(lv.player_pos) == lv._to_cell(goal) and lv.grid.is_point_solid(lv._to_cell(goal)), "synthetic split cell reproduces an open start with a blocked grid centre")
	check(follow(lv,goal) and lv.player_pos.distance_to(goal) < 0.05, "same-cell split around a corner is actually traversable")
	# Reproduce a real sub-cell pocket from an earlier dense level: no grid
	# centre is visible from its start, so escape around a cover corner first.
	lv.data = {"width": 29, "height": 46}
	lv.blocking_rects.clear()
	lv.blocking_rects.append(Rect2(454.8, 929.2, 514.4, 53.6))
	lv.blocking_rects.append(Rect2(576.4, 1114.8, 207.2, 130.4))
	lv.blocking_rects.append(Rect2(451.6, 990.0, 168.8, 92.0))
	lv.blocking_rects.append(Rect2(643.6, 990.0, 168.8, 92.0))
	lv.guard_blocking_rects = lv.blocking_rects.duplicate()
	lv._build_grid()
	lv._build_walkable_regions()
	lv.player_pos = Vector2(631.6959, 1069.838)
	var pocket_target := Vector2(781.4766, 813.1845)
	check(lv._visible_player_anchors(lv.player_pos).is_empty(), "dense pocket reproduces no direct grid anchor")
	check(follow(lv, pocket_target) and lv.player_pos.distance_to(pocket_target) < 0.1, "off-centre pocket is escaped around a cover corner")
	print("PLAYER PATH %d checks, %d failures; %d routes followed" % [checks, failures, routes])
	quit(1 if failures else 0)
