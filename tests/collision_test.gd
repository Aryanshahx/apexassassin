extends SceneTree
## Deterministic head-on and crossing guard traffic: no overlapping or vibrating.
var checks := 0
var failures := 0
func _init() -> void:
	call_deferred("_run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)
func _open_origin(lv: Node2D) -> Vector2:
	for y in range(2, int(lv.data.height) - 6):
		for x in range(2, int(lv.data.width) - 6):
			var ok := true
			for dy in range(6):
				for dx in range(6):
					if lv.grid.is_point_solid(Vector2i(x + dx, y + dy)):
						ok = false
			if ok:
				return lv._cell_center(x + 1, y + 2)
	return Vector2.ZERO
func _reset_guard(g: Dictionary, point: Vector2) -> void:
	g.pos = point
	g.path.clear()
	g.pi = 0
	g.blocked_t = 0.0
	g.avoid_time = 0.0
	g.avoid_direction = Vector2.ZERO
	g.avoid_side = 1.0
func _run() -> void:
	var gs = root.get_node("GameState")
	gs.sound_enabled = false
	gs.start_level(1)
	await process_frame
	await process_frame
	var lv = current_scene
	lv.set_physics_process(false)
	var origin := _open_origin(lv)
	check(origin != Vector2.ZERO, "found open floor for collision tests")
	var a: Dictionary = lv.guards[0]
	var b: Dictionary = lv.guards[1]
	var c: Dictionary = lv.guards[2]
	var d: Dictionary = lv.guards[3]
	lv.guards.clear()
	lv.guards.append(a)
	lv.guards.append(b)
	for scenario in [0, 1]:
		_reset_guard(a, origin)
		_reset_guard(b, origin + Vector2(120, 0) if scenario == 0 else origin + Vector2(64, -64))
		var end_a: Vector2 = origin + Vector2(120, 0)
		var end_b: Vector2 = origin if scenario == 0 else origin + Vector2(64, 64)
		var last_a := Vector2.ZERO
		var last_b := Vector2.ZERO
		var flips_a := 0
		var flips_b := 0
		var min_gap := INF
		var wall_violation := false
		for frame in range(600):
			var before_a: Vector2 = a.pos
			var before_b: Vector2 = b.pos
			lv._seek(a, end_a, 1.0 / 60.0, 58.0)
			lv._seek(b, end_b, 1.0 / 60.0, 58.0)
			var va: Vector2 = a.pos - before_a
			var vb: Vector2 = b.pos - before_b
			if va.length() > 0.1 and last_a.length() > 0.1 and va.normalized().dot(last_a.normalized()) < -0.5:
				flips_a += 1
			if vb.length() > 0.1 and last_b.length() > 0.1 and vb.normalized().dot(last_b.normalized()) < -0.5:
				flips_b += 1
			if va.length() > 0.1: last_a = va
			if vb.length() > 0.1: last_b = vb
			min_gap = minf(min_gap, a.pos.distance_to(b.pos))
			for wall in lv.guard_blocking_rects:
				if wall.has_point(a.pos) or wall.has_point(b.pos): wall_violation = true
		var label := "head-on" if scenario == 0 else "crossing"
		check(min_gap >= lv.GUARD_GAP - 0.06, label + " guards do not overlap")
		check(not wall_violation, label + " guards maintain wall clearance")
		check(a.pos.distance_to(end_a) < 1.0 and b.pos.distance_to(end_b) < 1.0, label + " guards get around each other and reach their goals")
		check(flips_a < 5 and flips_b < 5, label + " guards do not vibrate back and forth")
		print("TRAFFIC ",label," min_gap=", snappedf(min_gap, 0.01)," reversals=", flips_a,"/", flips_b)
	# Four alerted guards converge on the same last-known player position.
	# They must not overlap or remain stuck endlessly in INVESTIGATE.
	lv.guards.append(c)
	lv.guards.append(d)
	var center := origin + Vector2(32, 16)
	var offsets := [Vector2(-65,0), Vector2(65,0), Vector2(0,-65), Vector2(0,65)]
	lv.player_pos = Vector2(-10000, -10000)
	for i in range(4):
		_reset_guard(lv.guards[i], center + offsets[i])
		lv.guards[i].state = lv.GState.INVESTIGATE
		lv.guards[i].last_seen = center
		lv.guards[i].sees_player = false
	var crowd_gap := INF
	var reached_search := false
	for frame in range(360):
		lv._update_guards(1.0 / 60.0)
		for i in range(4):
			if lv.guards[i].state == lv.GState.SEARCH: reached_search = true
			for j in range(i): crowd_gap = minf(crowd_gap, lv.guards[i].pos.distance_to(lv.guards[j].pos))
	check(crowd_gap >= lv.GUARD_GAP - 0.06, "four investigating guards avoid crowd overlap")
	check(reached_search, "blocked investigating guards search instead of jittering forever")
	print("CROWD min_gap=", snappedf(crowd_gap, 0.01), " reached_search=", reached_search)
	print("COLLISION %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
