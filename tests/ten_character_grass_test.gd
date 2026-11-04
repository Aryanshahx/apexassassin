extends SceneTree
## Run with isolated synthetic XDG user directories, never a player's real data.
const Choice := preload("res://scripts/game/ten_character_selection.gd")
const Fixture := preload("res://tests/v65_test_fixtures.gd")
var checks := 0
var failures := 0

func _init() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)

func _read(path: String) -> String:
	if not FileAccess.file_exists(path): return ""
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_as_text() if f else ""

func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f: f.store_string(text)

func _restore(path: String, existed: bool, text: String) -> void:
	if existed: _write(path, text)
	elif FileAccess.file_exists(path): DirAccess.remove_absolute(path)

func _run() -> void:
	var gs = root.get_node("GameState")
	gs.sound_enabled = false
	gs.haptics_enabled = false
	var had_legacy := FileAccess.file_exists(Choice.LEGACY_SELECTION_PATH)
	var had_new := FileAccess.file_exists(Choice.SAVE_PATH)
	var old_legacy := _read(Choice.LEGACY_SELECTION_PATH)
	var old_new := _read(Choice.SAVE_PATH)
	DirAccess.remove_absolute(Choice.SAVE_PATH)
	var sentinel := '{"look":"blue_tactical","weapon":"thor","legacy_marker":723}'
	_write(Choice.LEGACY_SELECTION_PATH, sentinel)
	var migrated := Choice.read_selection()
	check(migrated.look == "standard" and migrated.weapon == "thor", "new roster defaults to approved Standard and migrates the existing weapon")
	check(_read(Choice.LEGACY_SELECTION_PATH) == sentinel, "migration does not modify the legacy selection file")
	check(Choice.LOOKS.size() == 10 and Choice.WEAPONS.size() == 5, "ten characters and five interchangeable weapons")
	check(not Choice.save_selection("missing", "thor"), "invalid character is not persisted")
	check(not Choice.save_selection("standard", "missing"), "invalid weapon is not persisted")
	check(not FileAccess.file_exists(Choice.SAVE_PATH), "invalid input does not create a selection file")
	for tier in [10, 20, 30, 40]:
		var speed_id := "speed_%d" % tier
		var health_id := "health_%d" % tier
		var multiple := 1.0 + float(tier) / 100.0
		check(is_equal_approx(Choice.speed_multiplier(speed_id), multiple), speed_id + " gets the listed speed")
		check(is_equal_approx(Choice.health_multiplier(speed_id), 1.0), speed_id + " gets no unlisted health bonus")
		check(is_equal_approx(Choice.health_multiplier(health_id), multiple), health_id + " gets the listed health")
		check(is_equal_approx(Choice.speed_multiplier(health_id), 1.0), health_id + " gets no unlisted speed bonus")
		check(Choice.bonus_label(speed_id) == "+%d%% SPEED" % tier, speed_id + " label matches")
		check(Choice.bonus_label(health_id) == "+%d%% HEALTH" % tier, health_id + " label matches")
	for id in ["standard", "shadow"]:
		check(is_equal_approx(Choice.health_multiplier(id), 1.0) and is_equal_approx(Choice.speed_multiplier(id), 1.0), id + " gets no invented bonus")
		check(Choice.bonus_label(id) == "NO BONUS", id + " states no new bonus")
	check(Choice.save_selection("health_40", "leviathan"), "selection writes its own file")
	check(Choice.read_selection().look == "health_40" and Choice.read_selection().weapon == "leviathan", "selection and weapon round-trip independently")
	check(_read(Choice.LEGACY_SELECTION_PATH) == sentinel, "new selection never overwrites old selection")

	# Determine grass reachability for all existing authored levels without ever
	# changing map data, obstacles, or pathing. The separate RNG is deterministic.
	var Level = load("res://scripts/game/level.gd")
	var no_grass := []
	var inaccessible := []
	var generated_count := 0
	for n in range(1, 101):
		var map = Level.new()
		map._load_level(n)
		map._build_grid()
		map._build_walkable_regions()
		var before = map.blocking_rects.duplicate()
		map._build_grass()
		if map.grass_rects.is_empty(): no_grass.append(n)
		var reachable := false
		var player_region := int(map.region_by_cell.get(map._to_cell(map.player_pos), -1))
		for patch in map.grass_rects:
			var cell = map._to_cell(patch.get_center())
			if int(map.region_by_cell.get(cell, -2)) == player_region and map.in_grass(patch.get_center()): reachable = true
		if not reachable: inaccessible.append(n)
		check(map.blocking_rects == before, "level %d grass adds no obstacle collision" % n)
		var same = map.grass_rects.duplicate()
		map._build_grass()
		check(map.grass_rects == same, "level %d grass placement is deterministic" % n)
		generated_count += map.grass_rects.size()
		map.free()
	check(no_grass.is_empty(), "all 100 levels have grass: " + str(no_grass))
	check(inaccessible.is_empty(), "all 100 levels have player-reachable grass: " + str(inaccessible))
	print("GRASS MAP COVERAGE: ", generated_count, " patches in 100 levels")

	# A real level verifies the selected multiplier, health bar, and guard AI.
	gs.selected_assassin = "nova"  # preserve a pre-existing +10% legacy stat
	gs.upgrades = {"speed": 2, "health": 3, "damage": 1}
	var base_speed: float = gs.player_speed()
	var base_health: float = gs.max_health()
	var legacy_character: String = gs.selected_assassin
	var legacy_upgrades: Dictionary = gs.upgrades.duplicate(true)
	gs.start_level(1)
	await process_frame
	await process_frame
	var lv = current_scene
	lv.set_physics_process(false)
	check(lv.active_look == "health_40", "level loads the equipped new character")
	check(is_equal_approx(lv.player_hp, base_health * 1.4), "level starts with full +40% max health")
	check(is_equal_approx(lv.player_health_bar.max_value, base_health * 1.4), "health bar uses boosted maximum")
	for id in Choice.LOOKS:
		lv.active_look = id
		check(is_equal_approx(lv._player_speed(), base_speed * Choice.speed_multiplier(id)), id + " speed composes with saved stats")
		check(is_equal_approx(lv._player_max_health(), base_health * Choice.health_multiplier(id)), id + " health composes with saved stats")
	check(gs.selected_assassin == legacy_character and gs.upgrades == legacy_upgrades, "bonuses do not mutate saved legacy character or upgrades")

	var origin: Vector2 = Fixture.open_arena(lv)
	var g: Dictionary = lv.guards[0]
	lv.guards.clear(); lv.guards.append(g)
	g.pos = origin; g.face = 0.0; g.speed = 0.0; g.vision = 300.0
	g.state = lv.GState.PATROL; g.sees_player = false; g.alive = true
	lv.player_pos = origin + Vector2(160, 0)
	lv.grass_rects.clear()
	lv._update_guards(0.01)
	check(g.sees_player and g.state == lv.GState.ALERT, "exposed player is detected normally")
	var last_known: Vector2 = g.last_seen
	# Move farther into a patch after sight was established. The guard may chase
	# last_known, but must not discover the player's new position or shoot.
	lv.grass_rects.append(Rect2(origin + Vector2(150, -55), Vector2(130, 110)))
	lv.player_pos = origin + Vector2(200, 0)
	lv.bullets.clear()
	lv._update_guards(0.05)
	check(lv.in_grass(lv.player_pos), "player is inside the visible grass patch")
	check(not g.sees_player and g.last_seen.is_equal_approx(last_known), "grass breaks sight and stops live tracking")
	lv.player_pos = origin + Vector2(225, 10)
	lv._update_guards(0.05)
	check(not g.sees_player and g.last_seen.is_equal_approx(last_known), "hidden movement does not update last-known position")
	lv._fire(g)
	check(lv.bullets.is_empty(), "even a direct fire call cannot shoot at a hidden player")
	lv._update_stealth_hud()
	check(lv.status_label.text == "HIDDEN IN GRASS", "HUD explains concealment")
	# Grass is floor-only, so the normal movement path continues across it.
	var old_position: Vector2 = lv.player_pos
	lv.player_path = PackedVector2Array([old_position + Vector2(20, 0)])
	lv._move_player(0.05)
	check(lv.player_pos.distance_to(old_position) > 0.0, "player can traverse grass normally")
	lv.player_pos = origin + Vector2(300, 0)
	g.face = 0.0
	lv._update_guards(0.05)
	check(not lv.in_grass(lv.player_pos) and g.sees_player, "enemies can reacquire the player after leaving grass")
	check(g.last_seen.is_equal_approx(lv.player_pos), "last known position updates after reacquisition")
	check(_read(Choice.LEGACY_SELECTION_PATH) == sentinel, "running level preserves the legacy selection file")
	_restore(Choice.LEGACY_SELECTION_PATH, had_legacy, old_legacy)
	_restore(Choice.SAVE_PATH, had_new, old_new)
	print("TEN CHARACTER AND GRASS ", checks, " checks; ", failures, " failures")
	quit(1 if failures else 0)
