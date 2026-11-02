extends SceneTree
## Headless gameplay + data smoke tests. Run:
## godot --headless --path . --script tests/smoke_test.gd
var failures := 0
var checks := 0

func _init() -> void:
	call_deferred("_run")

func check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		printerr("FAIL: ", msg)

# Source crates may share edges, but their interiors must not overlap.
func crates_separated(lv: Dictionary, cell: float, origin: Vector2, grow: float, factor: float) -> bool:
	var walls: Array[Rect2] = []
	var crates: Array[Rect2] = []
	for item in lv.walls:
		var old := Rect2(origin + Vector2(item[0], item[1]) * cell, Vector2(item[2], item[3]) * cell).grow(grow)
		walls.append(Rect2(old.get_center() - old.size * factor * 0.5, old.size * factor))
	for item in lv.crates:
		var old := Rect2(origin + Vector2(item[0], item[1]) * cell, Vector2(item[2], item[3]) * cell).grow(grow)
		var actual := Rect2(old.get_center() - old.size * factor * 0.5, old.size * factor)
		for wall in walls:
			if actual.grow(-0.1).intersects(wall.grow(-0.1)):
				return false
		for other in crates:
			if actual.grow(-0.1).intersects(other.grow(-0.1)):
				return false
		crates.append(actual)
	return true

func _run() -> void:
	var gs = root.get_node("GameState")
	gs.sound_enabled = false
	var f := FileAccess.open("res://data/levels/levels.json", FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	var levels: Array = parsed.levels
	check(levels.size() == 100, "100 levels")
	for lv in levels:
		check(lv.guards.size() >= 1, "level %d has a guard or boss roster" % lv.id)
		check(lv.spawn.size() == 2, "spawn")
	gs.gems = 1000
	gs.cash = 1000
	gs.upgrades = {"health": 0, "damage": 0, "speed": 0}
	gs.unlocked_assassins = {"ronin": true}
	gs.selected_assassin = "ronin"
	gs.unlocked_knives = {"standard": true}
	gs.selected_knife = "standard"
	check(gs.unlock_character("nova"), "unlock nova")
	check(gs.selected_assassin == "nova", "nova selected")
	check(gs.player_speed() > 200, "nova faster")
	check(gs.select_character("ronin"), "select ronin")
	check(gs.buy_upgrade("speed"), "buy speed upgrade")
	check(gs.CHARACTER_ORDER.size() == 23 and gs.REFERENCE_ORDER.size() == 12 and gs.LEGACY_ORDER.size() == 10, "12 reference and 10 legacy characters plus one new locker character; rejected 12 remain removed")
	check(gs.KNIFE_ORDER.size() == 17, "17 knives")
	check(gs.unlock_character("oni"), "unlock oni")
	check(gs.max_health() > 4.0, "oni health bonus")
	check(gs.select_character("ronin"), "select ronin again")
	check(gs.buy_knife("apex"), "buy apex knife")
	check(gs.player_damage() >= 4, "apex damage")
	check(gs.select_knife("standard"), "select standard knife")
	# Lucky wheel: weighted roll in range, single claim per day, balance credited.
	gs.last_wheel_day = ""
	check(gs.can_spin_wheel(), "wheel available")
	var wi: int = gs.roll_wheel()
	check(wi >= 0 and wi < gs.WHEEL_PRIZES.size(), "wheel roll in range")
	var before_gems: int = gs.gems
	var before_cash: int = gs.cash
	var prize: Dictionary = gs.claim_wheel(wi)
	check(not prize.is_empty(), "wheel prize claimed")
	var credited: bool = (gs.gems > before_gems) if String(prize.kind) == "gems" else (gs.cash > before_cash)
	check(credited, "wheel prize credited to balance")
	check(not gs.can_spin_wheel(), "wheel locked after spin")
	check(gs.claim_wheel(0).is_empty(), "second claim same day blocked")
	gs.last_wheel_day = ""
	gs.start_level(4)
	await process_frame
	await process_frame
	await process_frame
	var level = current_scene
	check(level != null and level.total == 5, "level 4 has 5 guards")
	# Every cover item scales exactly 20% about its original v0.6.1 centre.
	check(level.OBSTACLE_GROW == 3.0 and is_equal_approx(level.OBSTACLE_SCALE, 1.2), "cover scales 20% from v0.6.1")
	var wd: Array = level.data.walls[0]
	var wall_original := Rect2(level.ORIGIN + Vector2(wd[0], wd[1]) * level.CELL, Vector2(wd[2], wd[3]) * level.CELL)
	var wall_prior := wall_original.grow(level.OBSTACLE_GROW)
	var wall_expanded := Rect2(wall_prior.get_center() - wall_prior.size * 0.6, wall_prior.size * 1.2)
	check(level.wall_rects[0].position.distance_to(wall_expanded.position) < 0.001 and level.wall_rects[0].size.distance_to(wall_expanded.size) < 0.001, "wall geometry enlarged")
	var cd: Array = level.data.crates[0]
	var crate_original := Rect2(level.ORIGIN + Vector2(cd[0], cd[1]) * level.CELL, Vector2(cd[2], cd[3]) * level.CELL)
	var crate_prior := crate_original.grow(level.OBSTACLE_GROW)
	var crate_expanded := Rect2(crate_prior.get_center() - crate_prior.size * 0.6, crate_prior.size * 1.2)
	check(level.crate_rects[0].position.distance_to(crate_expanded.position) < 0.001 and level.crate_rects[0].size.distance_to(crate_expanded.size) < 0.001, "crate geometry enlarged")
	var original_key: String = level.CONTAINER_KEYS[int(abs(wall_original.position.x * 7 + wall_original.position.y * 13)) % level.CONTAINER_KEYS.size()]
	check(level._wall_colour(level.wall_rects[0]) == original_key, "container colour unchanged")
	var outer_probe := Vector2(wall_original.get_center().x, wall_original.position.y - 5.0)
	check(not wall_original.grow(4.0).has_point(outer_probe) and level._solid(outer_probe), "larger cover blocks sight and bullets at its new edge")
	check(level.player_rig.scale.is_equal_approx(Vector2.ONE * level.PLAYER_SCALE) and level.PLAYER_SCALE > 0.98, "player is visibly larger than the guards")
	var guard_scales_ok := true
	for g in level.guards:
		var expected_guard_scale := 0.98 if bool(g.elite) else 0.92
		if not g.rig.scale.is_equal_approx(Vector2.ONE * expected_guard_scale):
			guard_scales_ok = false
	check(guard_scales_ok, "enemy sizes unchanged")
	for lv in levels:
		check(crates_separated(lv, level.CELL, level.ORIGIN, level.OBSTACLE_GROW, level.OBSTACLE_SCALE), "level %d source crates may touch but must not overlap solid interiors" % int(lv.id))
	check(level.player_rig.anim.has_animation("run"), "run animation")
	check(level.player_rig.anim.has_animation("attack"), "attack animation")
	check(level.player_rig.anim.has_animation("death"), "death animation")
	# v0.5.3: wider follow camera. It must show 15 cells across, not shrink to fit the map.
	var cam_safe := ScreenUtil.safe_rect(root)
	check(level.CAM_VIEW_CELLS == 15.0, "camera shows 15 cells across")
	check(absf(level.cam_scale - cam_safe.size.x / (15.0 * level.CELL)) < 0.001, "camera zoom uses viewport width")
	var pre_camera_player: Vector2 = level.player_pos
	level.player_pos = level._cell_center(int(level.data.width) / 2, int(level.data.height) / 2)
	level._update_camera(1.0)
	var screen_player: Vector2 = level.to_global(level.player_pos)
	var cam_focus: Vector2 = cam_safe.position + Vector2(cam_safe.size.x * 0.5, cam_safe.size.y * 0.54)
	check(screen_player.distance_to(cam_focus) < 1.0, "camera centres the player in open map")
	level.player_pos = level._cell_center(0, 0)
	level._update_camera(1.0)
	var arena_top_left: Vector2 = level.to_global(level.ORIGIN)
	check(arena_top_left.x <= cam_safe.position.x + 0.1 and arena_top_left.y <= cam_safe.position.y + 0.1, "camera clamps at arena edge")
	level.player_pos = pre_camera_player
	level._update_camera(1.0)

	var target: Vector2 = level._cell_center(10, 20)
	level._path_to(target)
	check(level.player_path.size() > 0, "path found")
	level.player_pos = level.guards[0].pos + Vector2(20, 0)
	level.guards[0].diamond_carrier = true
	var money_before_kill: int = gs.cash
	var diamonds_before_kill: int = gs.gems
	level.attack_cd = 0.0
	level._auto_attack()
	check(level.kills == 1, "auto blade kill")
	check(gs.cash > money_before_kill and level.money_collected > 0, "kill awards and shows money")
	check(gs.gems == diamonds_before_kill + 1 and level.gems_collected == 1, "carrier awards one diamond")
	check(level.loot_particles.is_empty() and level.blood_splats.size() == 1 and level.gem_label.text == str(gs.gems), "kill leaves blood while the saved diamond total is visible")
	for i in range(level.guards.size()):
		if level.guards[i].alive:
			level._kill_guard(i)
	level._win()
	check(level.finished, "level finished")
	check(gs.unlocked_level >= 5, "next level unlocked")
	check(gs.best_stars.get("4", 0) >= 1, "stars saved")
	# --- v0.5 mechanics ---
	gs.start_level(6)
	await process_frame
	await process_frame
	var lv2 = current_scene
	check(lv2 != null and lv2.guards.size() >= 3, "level 6 loaded")
	# Backstab: stand directly behind an unaware guard -> instant silent kill.
	lv2.set_physics_process(false)
	var g0: Dictionary = lv2.guards[0]
	# Pick an unobstructed backstab fixture instead of assuming the random
	# guard's spawn/facing leaves an empty 20-unit space behind it.
	var clear_point := Vector2.ZERO
	for yy in range(2, int(lv2.data.height) - 2):
		for xx in range(2, int(lv2.data.width) - 2):
			var point: Vector2 = lv2._cell_center(xx, yy)
			if not lv2._solid(point) and not lv2._solid(point + Vector2(-20, 0)) and lv2._los(point, point + Vector2(-20, 0)):
				clear_point = point
				break
		if clear_point != Vector2.ZERO:
			break
	g0.pos = clear_point
	g0.face = 0.0
	lv2.player_pos = clear_point + Vector2(-20, 0)
	g0.state = 0
	var other_lives := []
	for index in range(1, lv2.guards.size()):
		other_lives.append(lv2.guards[index].alive)
		lv2.guards[index].alive = false
	lv2.attack_cd = 0.0
	var kills_before: int = lv2.kills
	lv2._auto_attack()
	for index in range(1, lv2.guards.size()):
		lv2.guards[index].alive = other_lives[index - 1]
	check(lv2.kills == kills_before + 1, "backstab kills unaware guard")
	check(lv2.backstabs == 1, "backstab counted")
	check(lv2.money_collected >= lv2.MONEY_STANDARD + lv2.MONEY_SILENT_BONUS, "backstab awards bonus money")
	# Gunfire informs all living guards in the same traversable area.
	var spotter: Dictionary = {}
	for g in lv2.guards:
		if g.alive:
			spotter = g
			break
	if not spotter.is_empty():
		var area: int = lv2.guard_region_by_cell.get(lv2._to_cell(spotter.pos), -1)
		var expected := 0
		for g in lv2.guards:
			if g.alive and g != spotter and lv2.guard_region_by_cell.get(lv2._to_cell(g.pos), -2) == area:
				expected += 1
		lv2._alarm_others(spotter)
		var alerted := 0
		for g in lv2.guards:
			if g.alive and g != spotter and lv2.guard_region_by_cell.get(lv2._to_cell(g.pos), -2) == area and g.state == lv2.GState.ALERT:
				alerted += 1
		check(alerted == expected, "gunfire alerts every living guard in the same area")
	# Drag steering re-paths toward the finger.
	lv2.dragging = true
	lv2.hunt_target = -1
	lv2.drag_target = lv2._cell_center(int(lv2.data.spawn[0]), int(lv2.data.spawn[1]))
	lv2.drag_repath = 0.0
	lv2._path_to(lv2.drag_target)
	check(lv2.player_path.size() > 0, "drag target path found")
	# Depot environment textures are wired.
	check(lv2.floor_details.size() > 0, "depot floor details placed")
	check(lv2.CONTAINER_KEYS.size() == 3, "3 container colours")
	check(lv2._c_mid.size() == 3 and lv2._c_depth.size() == 3, "real container strips loaded")
	print("SMOKE %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
