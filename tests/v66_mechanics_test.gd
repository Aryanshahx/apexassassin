extends SceneTree
## Regression for the reported stationary-guard bug and shortest-corner routes.
## Use an isolated XDG_DATA_HOME. All geometry and actors are from the game.
var checks := 0
var failures := 0

func _init() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)

func reset_guard(g: Dictionary, pos: Vector2, state: int) -> void:
	g.pos = pos
	g.rig.position = pos
	g.rig.visible = true
	g.alive = true
	g.hp = 1
	g.state = state
	g.face = 0.0
	g.speed = 58.0
	g.vision = 250.0
	g.shoot = 0.0
	g.wait = 999.0
	g.sees_player = false
	g.alert_repath = 0.0
	g.chase_left = 0.0
	g.blocked_t = 0.0
	g.avoid_time = 0.0
	g.avoid_direction = Vector2.ZERO
	g.traffic_stall = 0.0
	g.traffic_wait = false
	g.yield_partner = -1
	g.yield_side = Vector2.ZERO
	g.yield_left = 0.0
	g.path.clear()
	g.pi = 0

func route_length(start: Vector2, route: PackedVector2Array) -> float:
	var length := 0.0
	var p := start
	for point in route:
		length += p.distance_to(point)
		p = point
	return length

func _run() -> void:
	var gs = root.get_node("GameState")
	gs.sound_enabled = false
	gs.haptics_enabled = false
	gs.selected_assassin = "ronin"
	gs.selected_knife = "standard"
	gs.upgrades = {"speed": 0, "health": 0, "damage": 0}
	gs.start_level(6)
	await process_frame
	await process_frame
	var lv = current_scene
	lv.set_physics_process(false)
	var source: Dictionary = lv.guards[0]
	var witness: Dictionary = lv.guards[1]
	var origin: Vector2 = load("res://tests/v65_test_fixtures.gd").open_arena(lv)
	lv.guards.clear()
	lv.guards.append(source)

	# Reproduces the actual regression: 96 units was inside the old 128-unit
	# stop radius, so a visible guard only aimed and waited instead of chasing.
	reset_guard(source, origin, lv.GState.PATROL)
	lv.player_pos = origin + Vector2(96, 0)
	var before: Vector2 = source.pos
	for frame in range(30):
		lv._update_guards(1.0 / 60.0)
	check(source.state == lv.GState.ALERT and source.pos.distance_to(before) > 45.0, "visible guard actually advances from 96 units, instead of freezing at the old 128-unit stop distance")
	check(source.pos.distance_to(lv.player_pos) < 50.0, "pursuit closes to the player rather than standing off")

	# A distant same-area witness should run too, without a personal cone hit.
	load("res://tests/v65_test_fixtures.gd").open_arena(lv)
	lv.guards.append(witness)
	reset_guard(source, origin, lv.GState.PATROL)
	reset_guard(witness, origin + Vector2(0, 360), lv.GState.PATROL)
	witness.face = PI
	lv.player_pos = origin + Vector2(230, 0)
	var witness_initial: Vector2 = witness.pos
	check(not lv._can_see(witness.pos, witness.face, lv.player_pos, witness.vision), "witness begins beyond its cone and range")
	for frame in range(120):
		lv._update_guards(1.0 / 60.0)
	check(witness.state == lv.GState.ALERT and witness.pos.distance_to(witness_initial) > 100.0, "same-area witness actively chases after the spotter raises the alarm")
	check(witness.pos.distance_to(lv.player_pos) < witness_initial.distance_to(lv.player_pos) - 80.0, "distant witness makes real progress toward the player")

	# Once two guards have approach lanes, an arrived guard must not orbit
	# endlessly around an otherwise stationary target.
	load("res://tests/v65_test_fixtures.gd").open_arena(lv)
	lv.player_pos = origin + Vector2(200, 0)
	reset_guard(source, lv.player_pos + Vector2(45, 0), lv.GState.ALERT)
	reset_guard(witness, lv.player_pos + Vector2(-200, 0), lv.GState.ALERT)
	source.chase_live = true
	witness.chase_live = true
	witness.speed = 0.0
	for frame in range(60):
		lv._update_guards(1.0 / 60.0)
	var settled: Vector2 = source.pos
	for frame in range(120):
		lv._update_guards(1.0 / 60.0)
	check(source.pos.distance_to(settled) < 0.5 and source.pos.distance_to(lv.player_pos) <= 41.0, "arrived guard does not orbit a stationary target")

	# A moving hidden target must be pursued around a wall, not fired through it.
	lv.guards.clear()
	lv.guards.append(source)
	load("res://tests/v65_test_fixtures.gd").open_arena(lv)
	var wall := Rect2(origin + Vector2(110, -90), Vector2(24, 180))
	lv.blocking_rects.append(wall)
	lv.guard_blocking_rects.append(wall.grow(lv.GUARD_WALL_MARGIN))
	lv._build_grid()
	lv._build_walkable_regions()
	reset_guard(source, origin, lv.GState.ALERT)
	lv.player_pos = origin + Vector2(240, 0)
	lv.bullets.clear()
	var hidden_shots := 0
	var collisions := 0
	var travel := 0.0
	for frame in range(240):
		# Move the target laterally without leaving the map.
		lv.player_pos = origin + Vector2(240, 24.0 * sin(float(frame) * 0.025))
		var last: Vector2 = source.pos
		var hidden: bool = not lv._los(last, lv.player_pos)
		var old_shots: int = lv.bullets.size()
		lv._update_guards(1.0 / 60.0)
		if hidden and lv.bullets.size() > old_shots:
			hidden_shots += 1
		if not lv._guard_line_clear(last, source.pos):
			collisions += 1
		travel += last.distance_to(source.pos)
	check(hidden_shots == 0 and collisions == 0, "hidden moving player cannot be shot through cover and guard never crosses it")
	check(travel > 100.0 and source.pos.distance_to(lv.player_pos) < 220.0, "guard walks around a real wall toward a moving hidden player")
	check(source.last_seen.distance_to(lv.player_pos) < 0.01, "alarm continues tracking the moving player's live position")

	# Independent analytical shortest path: straight across one rectangle is
	# blocked, and either symmetric route must touch two convex corners.
	lv.guards.clear()
	lv.data = {"width": 29, "height": 46}
	lv.blocking_rects.clear()
	lv.guard_blocking_rects.clear()
	var box := Rect2(origin + Vector2(100, -40), Vector2(100, 80))
	lv.blocking_rects.append(box)
	lv.guard_blocking_rects.append(box)
	lv._build_grid()
	lv._build_walkable_regions()
	lv.player_pos = origin + Vector2(20, 0)
	var target := origin + Vector2(280, 0)
	lv._path_to(target)
	var expected := 100.0 + 2.0 * sqrt(80.0 * 80.0 + 40.0 * 40.0)
	var actual := route_length(lv.player_pos, lv.player_path)
	var legal: bool = not lv.player_path.is_empty()
	var point: Vector2 = lv.player_pos
	for next in lv.player_path:
		legal = legal and lv._los(point, next)
		point = next
	check(legal and point.distance_to(target) < 0.01, "corner route contains only collision-free segments and reaches the actual destination")
	check(actual >= expected - 0.01 and actual <= expected + 4.0, "single-obstacle path matches independent Euclidean optimum within the sub-pixel clearance allowance")
	var stalled := false
	for frame in range(300):
		var old: Vector2 = lv.player_pos
		lv._move_player(1.0 / 60.0)
		if not lv.player_path.is_empty() and lv.player_pos.distance_to(old) < 0.0001:
			stalled = true
		if lv.player_path.is_empty():
			break
	check(not stalled and lv.player_pos.distance_to(target) < 0.1, "real movement follows the shortest-corner path without getting stuck")
	lv.player_pos = origin + Vector2(20, -100)
	var direct := origin + Vector2(260, -100)
	lv._path_to(direct)
	check(lv.player_path.size() == 1 and lv.player_path[0].distance_to(direct) < 0.01, "an unobstructed destination is one genuinely straight segment")

	# A moving enemy tap is replanned and the normal attack still lands.
	load("res://tests/v65_test_fixtures.gd").open_arena(lv)
	lv.guards.clear()
	lv.guards.append(source)
	reset_guard(source, origin + Vector2(220, 0), lv.GState.PATROL)
	source.diamond_carrier = false
	lv.player_pos = origin
	lv.player_path.clear()
	lv.hunt_target = 0
	lv.repath = 0.0
	lv.attack_cd = 0.0
	lv.kills = 0
	var hunt_wall_violation := false
	for frame in range(180):
		if source.alive:
			source.pos += Vector2(0, 0.35)
			lv.repath = maxf(0.0, lv.repath - 1.0 / 60.0)
			lv._update_hunt()
			var old: Vector2 = lv.player_pos
			lv._move_player(1.0 / 60.0)
			if not lv._los(old, lv.player_pos):
				hunt_wall_violation = true
			lv.attack_cd = maxf(0.0, lv.attack_cd - 1.0 / 60.0)
			lv._auto_attack()
		else:
			break
	check(not hunt_wall_violation and not source.alive and lv.kills == 1, "moving-enemy hunt replans and completes the normal melee attack")

	# Exercise actual initial map positions, not only an empty synthetic arena.
	for number in range(1, 6):
		gs.start_level(number)
		await process_frame
		await process_frame
		lv = current_scene
		lv.set_physics_process(false)
		var starts: Array[Vector2] = []
		var distances: Array[float] = []
		var paths: Array[float] = []
		var cover_hits := 0
		for g in lv.guards:
			reset_guard(g, g.pos, lv.GState.ALERT)
			starts.append(g.pos)
			distances.append(g.pos.distance_to(lv.player_pos))
			paths.append(0.0)
		for frame in range(360):
			var old: Array[Vector2] = []
			for g in lv.guards:
				old.append(g.pos)
			lv._update_guards(1.0 / 60.0)
			for i in range(lv.guards.size()):
				var g: Dictionary = lv.guards[i]
				paths[i] += old[i].distance_to(g.pos)
				if not lv._guard_line_clear(old[i], g.pos):
					cover_hits += 1
		var all_move := true
		for i in range(lv.guards.size()):
			if paths[i] < 100.0 or lv.guards[i].pos.distance_to(lv.player_pos) > distances[i] - 60.0:
				all_move = false
		check(cover_hits == 0, "level %d pursuing guards never cross cover" % number)
		check(all_move, "level %d both real guards make sustained pursuit progress" % number)
		print("CHASE level=", number, " travel=", paths, " initial=", distances, " final=", [lv.guards[0].pos.distance_to(lv.player_pos), lv.guards[1].pos.distance_to(lv.player_pos)])
	print("V66 MECHANICS %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
