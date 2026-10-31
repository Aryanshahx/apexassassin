extends SceneTree
## Behavioral regression: steering, highlighted paths, guard aim and LOS.
## Always run with isolated XDG_DATA_HOME: start_level writes a save.
var checks := 0
var failures := 0

func _init() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", message)

func _sampled_ray(lv: Node2D, origin: Vector2, direction: Vector2, distance: float, steps: int) -> float:
	for i in range(1, steps + 1):
		if lv._solid(origin + direction * (distance * float(i) / float(steps))):
			return distance * float(i - 1) / float(steps)
	return distance

# Find the same straight-lane scenario in the larger redesigned map instead
# of assuming an old level-1 cell remains walkable after walls were moved.
func _find_clear_lane(lv: Node2D) -> Dictionary:
	for y in range(9, int(lv.data.height) - 5):
		for x in range(3, int(lv.data.width) - 4):
			var start: Vector2 = lv._cell_center(x, y) + Vector2(0, -8)
			var goal: Vector2 = lv._cell_center(x, y - 4)
			var drag: Vector2 = lv._cell_center(x + 1, y - 4)
			if lv._guard_solid(start) or lv._guard_solid(goal) or lv._guard_solid(drag):
				continue
			if not lv._guard_line_clear(start, goal) or not lv._guard_line_clear(goal, drag) or not lv._guard_line_clear(start, start + Vector2(0, 100)):
				continue
			var crowded := false
			for guard in lv.guards:
				if start.distance_to(guard.pos) < 180.0 or goal.distance_to(guard.pos) < 140.0:
					crowded = true
					break
			if not crowded:
				return {"start": start, "goal": goal, "drag": drag}
	return {}

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
	var lane := _find_clear_lane(lv)
	check(not lane.is_empty(), "the redesigned map has an open straight test lane")
	if lane.is_empty():
		quit(1)
		return
	var start: Vector2 = lane.start
	var goal: Vector2 = lane.goal
	var drag_goal: Vector2 = lane.drag
	var direction := (goal - start).normalized()
	lv.player_pos = start
	var backwards := 0
	var initial_projection := 0.0
	for frame in range(90):
		if frame % 7 == 0:
			lv._path_to(goal)
			if frame == 0 and lv.player_path.size() > 0:
				initial_projection = (lv.player_path[0] - lv.player_pos).dot(direction)
		var before: Vector2 = lv.player_pos
		lv._move_player(1.0 / 60.0)
		if (lv.player_pos - before).dot(direction) < -0.1:
			backwards += 1
	check(initial_projection > 0, "first route waypoint is forward, not the old current-cell centre")
	check(backwards == 0, "repeated drag/hunt replans never force backward walking")
	check(lv.player_pos.distance_to(goal) < 1.0, "replanned walk reaches the selected destination")

	# Guard seek replans must likewise not return to the centre behind them.
	var guard: Dictionary = lv.guards[0]
	guard.pos = start
	guard.path.clear()
	backwards = 0
	for frame in range(180):
		if frame % 7 == 0:
			guard.path.clear()
		var before: Vector2 = guard.pos
		lv._seek(guard, goal, 1.0 / 60.0, 58.0)
		if (guard.pos - before).dot(direction) < -0.1:
			backwards += 1
	check(backwards == 0, "guard replanning does not reverse toward current-cell centre")
	check(guard.pos.distance_to(goal) < 1.0, "guard seek reaches its target")

	# Guard weapon aim follows real visibility and eases back when sight is lost.
	guard.pos = start
	guard.face = -PI / 2
	guard.state = lv.GState.PATROL
	guard.wait = 100.0
	guard.alert = 0.0
	guard.shoot = 100.0
	guard.path.clear()
	lv.player_pos = start + Vector2(5, -40)
	lv._update_guards(0.1)
	check(guard.rig.guard_aim_target == 1.0, "guard raises gun when player is visible")
	guard.rig._process(0.4)
	check(guard.rig.guard_aim_amount > 0.99 and absf(guard.rig.guard_gun.rotation) > 0.8, "gun visibly raises towards player")
	var expected_offset: float = angle_difference(guard.face, (lv.player_pos - guard.pos).angle())
	check(absf(guard.rig.guard_aim_offset - expected_offset) < 0.1, "weapon tracks player's direction relative to the guard")
	lv.bullets.clear()
	lv._fire(guard)
	check(lv.bullets.size() == 1 and lv.bullets[0].vel.normalized().dot((lv.player_pos - guard.pos).normalized()) > 0.999, "shot follows player-facing gun direction")
	lv.player_pos = start + Vector2(0, 100)
	lv._update_guards(0.1)
	check(guard.rig.guard_aim_target == 0.0, "guard lowers gun after losing sight")
	guard.rig._process(0.4)
	check(is_zero_approx(guard.rig.guard_aim_amount), "gun eases back to patrol pose")

	# Touch shows the actual remaining path and its end arrow, never a tap ring.
	lv.player_pos = start
	lv.guards.clear()
	lv.effects.clear()
	lv.player_path.clear()
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = lv.to_global(goal)
	lv._unhandled_input(touch)
	check(lv.dragging and lv.player_path.size() > 0, "touch press starts normal path")
	var drawn: PackedVector2Array = lv._route_visual_points()
	check(drawn.size() >= 2 and drawn[0].distance_to(lv.player_pos) < 0.01 and drawn[drawn.size() - 1].distance_to(goal) < 0.1, "highlight follows real path from player to touched destination")
	check(lv.effects.is_empty(), "touch produces no separate pulsing destination marker")
	var arrow: PackedVector2Array = lv._route_arrow_points()
	check(arrow.size() == 3 and arrow[0].distance_to(drawn[drawn.size() - 1]) < 0.01, "arrowhead points to the end of the real highlighted path")
	var arrow_forward: Vector2 = (arrow[0] - (arrow[1] + arrow[2]) * 0.5).normalized()
	check(arrow_forward.dot((drawn[drawn.size() - 1] - drawn[drawn.size() - 2]).normalized()) > 0.99, "arrowhead follows the final path segment")
	var path_before: PackedVector2Array = lv.player_path.duplicate()
	var drag := InputEventScreenDrag.new()
	drag.position = lv.to_global(drag_goal)
	lv._unhandled_input(drag)
	check(lv.player_path == path_before and lv.drag_target.distance_to(drag_goal) < 0.1 and lv.drag_dirty, "drag target updates immediately and marks a new route")
	lv.drag_repath = 0.0
	lv._physics_process(1.0 / 60.0)
	check(not lv.drag_dirty and lv._route_visual_points()[lv._route_visual_points().size() - 1].distance_to(drag_goal) < 0.1, "next physics tick responds to finger movement")
	path_before = lv.player_path.duplicate()
	var emulated := InputEventMouseButton.new()
	emulated.device = InputEvent.DEVICE_ID_EMULATION
	emulated.button_index = MOUSE_BUTTON_LEFT
	emulated.pressed = true
	emulated.position = lv.to_global(goal)
	lv._unhandled_input(emulated)
	check(lv.effects.is_empty() and lv.player_path == path_before, "emulated mouse does not duplicate a touch")
	touch.pressed = false
	touch.position = drag.position
	lv._unhandled_input(touch)
	check(not lv.dragging, "touch release ends dragging")
	# The camera can follow the player during a tap. A stationary finger-up
	# must not turn into a different world destination after the camera moves.
	lv.player_pos = start
	touch.pressed = true
	touch.position = lv.to_global(goal)
	lv._unhandled_input(touch)
	var original_destination: Vector2 = lv.player_path[lv.player_path.size() - 1]
	var original_transform: Vector2 = lv.position
	lv.position += Vector2(25, 35)
	touch.pressed = false
	lv._unhandled_input(touch)
	check(lv.player_path.size() > 0 and lv.player_path[lv.player_path.size() - 1].distance_to(original_destination) < 0.01, "camera motion cannot shift a stationary tap destination on release")
	lv.position = original_transform
	lv.player_pos = start
	lv._path_to(goal)
	var before_move: Vector2 = lv.player_pos
	lv._move_player(0.1)
	drawn = lv._route_visual_points()
	check(lv.player_pos.distance_to(before_move) > 1.0 and drawn.size() >= 2 and drawn[0].distance_to(lv.player_pos) < 0.01, "highlight starts at the moving player and shortens")
	lv.player_path.clear()
	check(lv._route_visual_points().is_empty() and lv._route_arrow_points().is_empty(), "path and arrow disappear when route is complete")

	# A tiny final AStar fragment must not make the arrow shrink/flicker or
	# point 90 degrees away from the highlighted route at a grid boundary.
	lv.player_pos = Vector2(0, 0)
	lv.player_path = PackedVector2Array([Vector2(80, 0), Vector2(80.1, 0.2)])
	var tiny_arrow: PackedVector2Array = lv._route_arrow_points()
	var tiny_base: Vector2 = (tiny_arrow[1] + tiny_arrow[2]) * 0.5
	var tiny_dir: Vector2 = (tiny_arrow[0] - tiny_base).normalized()
	check(tiny_arrow[0].distance_to(Vector2(80.1, 0.2)) < 0.01, "arrow tip is exactly the actual path endpoint")
	check(tiny_arrow[0].distance_to(tiny_base) > 9.0, "tiny end fragment does not collapse arrow size")
	check(tiny_dir.dot(Vector2.RIGHT) > 0.99, "tiny end fragment does not rotate the arrow away from the overall path")
	lv.player_pos = Vector2(30, 0)
	var moved_arrow: PackedVector2Array = lv._route_arrow_points()
	var moved_dir: Vector2 = (moved_arrow[0] - (moved_arrow[1] + moved_arrow[2]) * 0.5).normalized()
	check(tiny_dir.dot(moved_dir) > 0.999 and tiny_arrow[0].distance_to(moved_arrow[0]) < 0.01, "arrow remains stable while the player advances")
	lv.player_path.clear()

	# A touch on cover/outside the arena uses the nearest reachable floor, not a
	# straight line or stale marker through the obstacle.
	lv.player_pos = start
	var blocked: Vector2 = lv.crate_rects[0].get_center()
	lv._path_to(blocked)
	drawn = lv._route_visual_points()
	check(drawn.size() >= 2 and not lv._solid(drawn[drawn.size() - 1]), "touch on cover routes to reachable floor")
	check(drawn.is_empty() or drawn[drawn.size() - 1].distance_to(blocked) > 1.0, "cover itself is never highlighted as a reachable destination")
	lv._path_to(Vector2(-500, -500))
	drawn = lv._route_visual_points()
	check(drawn.size() >= 2 and lv.grid.is_in_boundsv(lv._to_cell(drawn[drawn.size() - 1])), "outside touch clamps to reachable arena")

	# Tapping an enemy also immediately shows its route, without a red tap ring.
	guard.pos = goal
	guard.alive = true
	lv.guards.append(guard)
	lv.player_pos = start
	lv.effects.clear()
	touch.pressed = true
	touch.position = lv.to_global(goal)
	lv._unhandled_input(touch)
	check(lv.hunt_target == 0 and lv._route_visual_points().size() >= 2, "enemy tap shows chase path immediately")
	check(lv.effects.is_empty(), "enemy tap does not add a destination marker")
	lv.guards.clear()

	# Obstacle point tests remain exactly the same as growing existing cover by 4.
	var rng := RandomNumberGenerator.new()
	rng.seed = 516
	for i in range(300):
		var p := Vector2(rng.randf_range(-20, 760), rng.randf_range(-20, 1400))
		var expected := false
		for r in lv.wall_rects:
			if r.grow(4).has_point(p):
				expected = true
		for r in lv.crate_rects:
			if r.grow(4).has_point(p):
				expected = true
		check(lv._solid(p) == expected, "blocking-rectangle cache matches enlarged cover")

	# Compare the exact ray intersections with dense 0.5-unit sampling across
	# six levels, different origins and non-axis-aligned directions.
	var ray_checks := 0
	for number in [1, 3, 17, 40, 70, 100]:
		lv.wall_rects.clear()
		lv.crate_rects.clear()
		lv._load_level(number)
		var origins: Array[Vector2] = [lv.player_pos]
		for n in range(mini(2, lv.data.guards.size())):
			var g = lv.data.guards[n]
			origins.append(lv._cell_center(int(g.x), int(g.y)))
		for origin in origins:
			if lv._solid(origin):
				continue
			for i in range(16):
				var angle := TAU * (float(i) + 0.37) / 16.0
				var dir := Vector2.from_angle(angle)
				var actual: float = lv._raycast_distance(origin, dir, 250.0)
				var sampled := _sampled_ray(lv, origin, dir, 250.0, 500)
				var matches_sample := absf(actual - sampled) <= 0.55
				if actual + 0.55 < sampled:
					# A ray can clip a corner for <0.5 units and escape between
					# samples. Verify the exact intersection on both sides instead.
					matches_sample = lv._solid(origin + dir * (actual + 0.01)) and (actual <= 0.01 or not lv._solid(origin + dir * (actual - 0.01)))
				check(matches_sample, "analytic vision ray matches dense sampling or a verified corner graze")
				ray_checks += 1
	check(ray_checks >= 250, "multiple guards and levels exercise analytic rays")

	# A non-gating benchmark shows the work avoided versus the old 64 samples.
	var sample_origin: Vector2 = lv.player_pos
	var start_us := Time.get_ticks_usec()
	var checksum := 0.0
	for repeat in range(20):
		for i in range(40):
			checksum += _sampled_ray(lv, sample_origin, Vector2.from_angle(TAU * i / 40.0), 250.0, 64)
	var sampled_us := Time.get_ticks_usec() - start_us
	start_us = Time.get_ticks_usec()
	for repeat in range(20):
		for i in range(40):
			checksum += lv._raycast_distance(sample_origin, Vector2.from_angle(TAU * i / 40.0), 250.0)
	var exact_us := Time.get_ticks_usec() - start_us
	print("RAY BENCH sampled=", sampled_us, "us exact=", exact_us, "us (checksum ", snappedf(checksum, 0.1), ")")
	print("MOVEMENT %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
