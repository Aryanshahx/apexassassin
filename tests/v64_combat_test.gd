extends SceneTree
## New pursuit/sight-loss behavior, progressive enemy types, heads and blood.
## Run with an isolated XDG_DATA_HOME.
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
	return load("res://tests/v65_test_fixtures.gd").open_arena(lv)

func _reset(g: Dictionary, pos: Vector2, state: int) -> void:
	g.pos = pos
	g.rig.position = pos
	g.face = 0.0
	g.state = state
	g.alive = true
	g.path.clear()
	g.pi = 0
	g.blocked_t = 0.0
	g.avoid_time = 0.0
	g.avoid_direction = Vector2.ZERO
	g.traffic_wait = false
	g.traffic_stall = 0.0
	g.yield_partner = -1
	g.yield_side = Vector2.ZERO
	g.yield_left = 0.0
	g.sees_player = false
	g.shoot = 0.0
	g.chase_left = 8.0
	g.route_goal = Vector2(INF, INF)
	g.progress_anchor = pos
	g.stuck_time = 0.0
	g.recover_left = 0.0

func _run() -> void:
	var gs = root.get_node("GameState")
	gs.sound_enabled = false
	gs.haptics_enabled = false
	gs.selected_assassin = "ronin"
	gs.upgrades = {"speed": 0, "health": 0, "damage": 0}
	check(is_equal_approx(gs.player_speed(), 190.0 * 1.20), "player base speed is 20% faster than v0.6.3")
	gs.upgrades.speed = 2
	gs.selected_assassin = "ref11"
	check(is_equal_approx(gs.player_speed(), (190.0 * 1.35 + 28.0) * 1.20), "20% speed increase includes the existing character bonus and upgrades")
	gs.selected_assassin = "ronin"
	gs.upgrades.speed = 0

	# Each head is a separate animated image for players, the secret and guards.
	var rig_script = load("res://scripts/game/reference_rig.gd")
	var ids: Array[String] = []
	for i in range(1, 13):
		ids.append("ref%02d" % i)
	ids.append("vault_phantom")
	for id in ids:
		var rig = rig_script.new()
		rig.setup(id, "player")
		root.add_child(rig)
		check(rig.head != null and rig.head.get_parent() == rig.art and rig.head.get_node("HeadArtwork").texture != null, id + " has a real separate head layer")
		var old_rotation: float = rig.head.rotation
		rig.set_moving(true)
		rig._process(0.23)
		check(absf(rig.head.rotation - old_rotation) > 0.005 and rig.head.position.distance_to(rig.head_rest) > 0.01, id + " head animates independently while running")
		root.remove_child(rig)
		rig.free()
	for type in ["guard", "elite"]:
		var rig = rig_script.new()
		rig.setup(type, "guard")
		root.add_child(rig)
		check(rig.head != null and rig.head.get_node("HeadArtwork").texture.resource_path.contains("v64_"), type + " guard has a separate head layer")
		rig.set_moving(true)
		rig._process(0.23)
		check(absf(rig.head.rotation) > 0.005, type + " guard head moves")
		root.remove_child(rig)
		rig.free()

	var type_at := {1: "guard", 7: "guard", 8: "ranger", 24: "ranger", 25: "breacher", 49: "breacher", 50: "captain", 100: "captain"}
	var hp_at := {1: 1, 7: 1, 8: 2, 24: 2, 25: 3, 49: 4, 50: 5, 100: 6}
	var last_damage := 0.0
	for number in [1, 7, 8, 24, 25, 49, 50, 100]:
		gs.start_level(number)
		await process_frame
		await process_frame
		var lv = current_scene
		lv.set_physics_process(false)
		var first: Dictionary = lv.guards[0]
		check(first.variant == type_at[number] and first.hp == hp_at[number], "level %d unlocks the right stronger archetype and armor" % number)
		check(float(first.shot_damage) >= last_damage, "level %d enemy damage does not regress" % number)
		last_damage = float(first.shot_damage)
		check(is_equal_approx(lv.ALERT_SPEED_MULTIPLIER, 1.8 * 1.15), "level %d alerted speed is 15%% above v0.6.3" % number)
	check(last_damage > 250.0, "late-game captain is substantially stronger")

	gs.start_level(1)
	await process_frame
	await process_frame
	var lv = current_scene
	lv.set_physics_process(false)
	var actors: Array = lv.guards.duplicate()
	var g: Dictionary = actors[0]
	lv.guards.clear()
	lv.guards.append(g)
	var origin := _open_origin(lv)
	check(origin != Vector2.ZERO, "found a clear synthetic lane for sight-loss testing")
	if origin == Vector2.ZERO:
		quit(1)
		return
	_reset(g, origin, lv.GState.PATROL)
	g.speed = 58.0
	g.vision = 250.0
	g.wait = 0.0
	lv.player_pos = origin + Vector2(160, 0)
	lv.bullets.clear()
	lv._update_guards(0.05)
	check(g.state == lv.GState.ALERT and g.sees_player and lv.bullets.is_empty(), "visible contact starts pursuit before the short firing delay")
	check(g.pos.distance_to(origin) >= 58.0 * 2.07 * 0.05 - 0.2 and g.rig.guard_aim_target == 1.0, "visible guard actually advances at increased chase speed with its gun raised")
	var known: Vector2 = g.last_seen
	check(known.distance_to(lv.player_pos) < 0.01 and g.chase_left >= 7.0, "sighting records last-known position and individual pursuit time")

	# Insert genuine LOS-blocking cover. v0.6.6 deliberately pursues the live
	# player after alarm, but must never aim or shoot through the wall.
	var wall := Rect2(origin + Vector2(75, -60), Vector2(16, 120))
	lv.blocking_rects.append(wall)
	lv.guard_blocking_rects.append(wall.grow(lv.GUARD_WALL_MARGIN))
	g.speed = 0.0
	g.shoot = 0.0
	lv.bullets.clear()
	var stayed_alert := true
	var tracked_hidden := false
	var raised_hidden := false
	for frame in range(20):
		lv.player_pos = origin + Vector2(155, 25 if frame % 2 == 0 else -25)
		lv._update_guards(0.02)
		stayed_alert = stayed_alert and g.state == lv.GState.ALERT
		tracked_hidden = tracked_hidden or g.last_seen.distance_to(known) > 0.01
		raised_hidden = raised_hidden or g.rig.guard_aim_target != 0.0
	check(not lv._los(g.pos, lv.player_pos), "test player is really hidden behind cover")
	check(stayed_alert and g.chase_left > 6.0, "guard keeps pursuing briefly instead of instantly giving up")
	check(tracked_hidden, "the alarm follows the live position behind cover")
	check(not raised_hidden and lv.bullets.is_empty(), "guard stops aiming and firing as soon as sight is lost")
	g.rig._process(0.4)
	check(is_zero_approx(g.rig.guard_aim_amount) and is_zero_approx(g.rig.guard_gun.rotation), "gun visibly lowers after sight loss")
	lv.blocking_rects.remove_at(lv.blocking_rects.size() - 1)
	lv.guard_blocking_rects.remove_at(lv.guard_blocking_rects.size() - 1)
	g.speed = 58.0
	g.path.clear()
	g.pi = 0
	lv.player_pos = origin + Vector2(0, 500)
	var previous_distance: float = g.pos.distance_to(lv.player_pos)
	for frame in range(60):
		lv._update_guards(1.0 / 60.0)
	check(g.pos.distance_to(lv.player_pos) < previous_distance - 50.0, "out-of-range guard physically pursues the live player")
	check(lv.bullets.is_empty() and g.rig.guard_aim_target == 0.0, "pursuit never fires at an unseen player")

	# No new sighting or gunfire: chase expires into search, then patrol.
	var other: Dictionary = actors[1]
	lv.guards.append(other)
	_reset(g, origin, lv.GState.ALERT)
	_reset(other, origin + Vector2(160, 0), lv.GState.ALERT)
	g.speed = 0.0
	other.speed = 0.0
	lv.player_pos = origin + Vector2(0, 500)
	lv.bullets.clear()
	for frame in range(200):
		lv._update_guards(0.05)
	check(g.state != lv.GState.ALERT and other.state != lv.GState.ALERT, "both guards leave active pursuit after ten seconds without a sightline")
	check(g.last_seen.distance_to(lv.player_pos) < 0.01 and other.last_seen.distance_to(lv.player_pos) < 0.01, "both remembered the moving target while pursuit lasted")
	check(lv.bullets.is_empty(), "out-of-range pursuers do not shoot")
	for frame in range(70):
		lv._update_guards(0.05)
	check(g.state == lv.GState.PATROL and other.state == lv.GState.PATROL, "both guards return to patrol after their finite search")

	# Multiple pursuers approach a shared target from different sides.
	_reset(g, origin, lv.GState.ALERT)
	_reset(other, origin + Vector2(160, 0), lv.GState.ALERT)
	g.speed = 58.0
	other.speed = 58.0
	var shared := origin + Vector2(80, 120)
	lv.player_pos = shared
	g.last_seen = shared
	other.last_seen = shared
	g.chase_left = lv._chase_duration(g)
	other.chase_left = lv._chase_duration(other)
	var goal_a: Vector2 = lv._pursuit_goal(g, shared)
	var goal_b: Vector2 = lv._pursuit_goal(other, shared)
	check(goal_a.distance_to(goal_b) > 20.0 and goal_a.distance_to(shared) <= 40.1 and goal_b.distance_to(shared) <= 40.1, "nearby pursuers take distinct close approach lanes")
	var min_gap := INF
	var travel_a := 0.0
	var travel_b := 0.0
	for frame in range(180):
		var a: Vector2 = g.pos
		var b: Vector2 = other.pos
		lv._update_guards(1.0 / 60.0)
		travel_a += g.pos.distance_to(a)
		travel_b += other.pos.distance_to(b)
		min_gap = minf(min_gap, g.pos.distance_to(other.pos))
	check(min_gap >= lv.GUARD_GAP - 0.06, "pursuing guards stay physically separated")
	check(travel_a > 15.0 and travel_b > 15.0, "both pursuing guards make progress instead of clustering motionless")

	# Real kill leaves level-permanent blood with twelve drops.
	lv.guards.clear()
	lv.guards.append(g)
	g.alive = true
	var kill_point: Vector2 = g.pos
	var cash_before: int = gs.cash
	lv._kill_guard(0)
	check(lv.blood_splats.size() == 1 and lv.blood_splats[0].pos.distance_to(kill_point) < 0.01 and lv.blood_splats[0].drops.size() == 12, "actual kill creates a blood splatter at the guard")
	check(gs.cash > cash_before, "blood effect does not remove existing kill money")
	lv._kill_guard(0)
	check(lv.blood_splats.size() == 1, "repeat kill cannot duplicate blood or loot")
	lv._update_effects(1000.0)
	check(lv.blood_splats.size() == 1 and not lv.blood_splats[0].has("t"), "blood remains unchanged even after a long time")
	check(not g.rig.visible, "the dead guard leaves no corpse animation")
	for i in range(40):
		lv._add_blood_splatter(origin)
	check(lv.blood_splats.size() == 41, "every stain remains for the duration of the level without a cap")
	print("V64 COMBAT %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
