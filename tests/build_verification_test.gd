extends SceneTree
## Isolated regression for startup fairness and an identifiable installed APK.
const Fixture := preload("res://tests/v65_test_fixtures.gd")
var checks := 0
var failures := 0
func _init() -> void: call_deferred("_run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; printerr("FAIL: ", message)
func _run() -> void:
	var gs = root.get_node("GameState")
	gs.sound_enabled = false; gs.haptics_enabled = false; gs.active_bonus_level = 0; gs.pending_bonus_level = 0
	gs.current_level = 3
	var level = load("res://scenes/level/level.tscn").instantiate()
	level.set_physics_process(false)
	root.add_child(level); current_scene = level
	level.rng.seed = 71003
	var start_player: Vector2 = level.player_pos
	var obstacles: Array = level.blocking_rects.duplicate()
	var hp: float = level.player_hp
	for guard in level.guards: guard.wait = 0.0
	for frame in range(180):
		level._update_guards(1.0/60.0)
		level._update_bullets(1.0/60.0)
	check(not level.was_alerted and is_equal_approx(level.player_hp,hp), "level 3 is fair for a stationary player under the reproduced seed")
	check(level.player_pos == start_player and level.blocking_rects == obstacles and level.guards.size() == 4, "opening patrol safety leaves map, spawn, and guard count unchanged")
	# The opening protection changes patrol target choice only. Detection,
	# alertness, pursuit and real body contact are not delayed or disabled.
	var guard: Dictionary = level.guards[0]
	level.guards.clear(); level.guards.append(guard)
	var origin: Vector2 = Fixture.open_arena(level)
	guard.pos = origin; guard.rig.position = origin; guard.alive = true; guard.state = level.GState.PATROL
	guard.face = 0.0; guard.wait = 0.0; guard.vision = 250.0; guard.speed = 58.0; guard.sees_player = false
	guard.shoot = 0.0; guard.shot_lock = 0.0; guard.path.clear(); guard.pi = 0; guard.route_goal = Vector2(INF,INF)
	level.player_pos = origin + Vector2(96,0); level._opening_patrol_time = 0.0
	level._update_guards(1.0/60.0)
	check(guard.sees_player and guard.state == level.GState.ALERT, "a visible moving player can be spotted immediately during opening")
	check(guard.pos.distance_to(origin) > 0.1, "alert pursuit is not held back by the opening patrol rule")
	level.queue_free(); await process_frame
	var home = load("res://scenes/home/home.tscn").instantiate()
	root.add_child(home); current_scene = home
	await process_frame
	home._open_settings()
	await process_frame
	var identity := home.find_child("BuildIdentity",true,false) as Label
	check(identity != null and identity.text == "BUILD: REPAIR-6", "settings visibly identify this exact APK generation")
	if identity != null:
		check(identity.is_visible_in_tree() and ScreenUtil.safe_rect(root).encloses(identity.get_global_rect()), "build identifier is visible inside safe viewport")
	home.queue_free(); await process_frame
	print("BUILD ID AND START SAFETY: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
