extends SceneTree
## Enemies crossing the same narrow doorway, with wall/body-clearance checks.
var checks := 0
var failures := 0
func _init() -> void:
	call_deferred("_run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)
func _simulate(lv: Node2D, actors: Array, starts: Array, goals: Array, label: String) -> void:
	lv.guards.clear()
	for i in range(actors.size()):
		var g: Dictionary = actors[i]
		lv.guards.append(g)
		g.pos = starts[i]
		g.alive = true
		g.path.clear()
		g.pi = 0
		g.blocked_t = 0.0
		g.avoid_time = 0.0
		g.avoid_direction = Vector2.ZERO
		g.avoid_side = 1.0
		g.travel_dir = Vector2.ZERO
		g.traffic_wait = false
		g.traffic_stall = 0.0
		g.yield_partner = -1
		g.yield_forward = Vector2.ZERO
		g.yield_side = Vector2.ZERO
		g.yield_left = 0.0
	var reached := []
	var previous := []
	var flips := []
	for i in range(actors.size()):
		reached.append(false)
		previous.append(Vector2.ZERO)
		flips.append(0)
	var min_gap := INF
	var hit_wall := false
	for frame in range(3600):
		for i in range(actors.size()):
			var g: Dictionary = actors[i]
			var before: Vector2 = g.pos
			lv._seek(g, goals[i], 1.0 / 60.0, 58.0)
			var motion: Vector2 = g.pos - before
			if motion.length() > 0.1 and previous[i].length() > 0.1 and motion.normalized().dot(previous[i].normalized()) < -0.5:
				flips[i] += 1
			if motion.length() > 0.1:
				previous[i] = motion
			if g.pos.distance_to(goals[i]) < 2.0:
				reached[i] = true
			if lv._guard_solid(g.pos):
				hit_wall = true
		for i in range(actors.size()):
			for j in range(i):
				min_gap = minf(min_gap, actors[i].pos.distance_to(actors[j].pos))
		if reached.all(func(v): return v):
			break
	check(reached.all(func(v): return v), label + " all guards pass through the gate")
	check(min_gap >= lv.GUARD_GAP - 0.06, label + " guards remain separated")
	check(not hit_wall, label + " guards never enter the doorway walls")
	check(flips.all(func(v): return v <= 6), label + " avoids rapid left/right oscillation")
	print("GATE ", label, " reached=", reached, " gap=", snappedf(min_gap, 0.01), " reversals=", flips)
func _run() -> void:
	var gs = root.get_node("GameState")
	gs.sound_enabled = false
	gs.start_level(6)
	await process_frame
	await process_frame
	var lv = current_scene
	lv.set_physics_process(false)
	var actors: Array = lv.guards.duplicate()
	# Synthetic two-room map: the gap between expanded walls allows only one
	# guard body at a time, so the test cannot pass by walking around the wall.
	lv.data.width = 21
	lv.data.height = 20
	var o: Vector2 = lv.ORIGIN
	var x: float = o.x + 10 * lv.CELL
	var top: float = o.y + 8 * lv.CELL
	var bottom: float = o.y + 11 * lv.CELL
	lv.blocking_rects.clear()
	lv.blocking_rects.append(Rect2(x, o.y - 1000, 32, top - o.y + 1000))
	lv.blocking_rects.append(Rect2(x, bottom, 32, 1000))
	lv.guard_blocking_rects.clear()
	for r in lv.blocking_rects:
		lv.guard_blocking_rects.append(r.grow(24.0))
	lv._build_grid()
	lv._build_walkable_regions()
	var left: Vector2 = lv._cell_center(4, 9)
	var right: Vector2 = lv._cell_center(16, 9)
	_simulate(lv, actors.slice(0, 2), [lv._cell_center(5, 9), lv._cell_center(2, 9)], [right, right + Vector2(0, 96)], "same direction")
	_simulate(lv, actors.slice(0, 2), [left, right], [right, left], "opposite directions")
	_simulate(lv, actors.slice(0, 2), [right, left], [left, right], "opposite, reversed priority")
	_simulate(lv, actors.slice(0, 4), [left, right, lv._cell_center(1, 9), lv._cell_center(19, 9)], [right, left, lv._cell_center(18, 12), lv._cell_center(2, 12)], "four-guard traffic")
	print("GATE TEST %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
