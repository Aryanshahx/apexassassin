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

func _run() -> void:
	var gs = root.get_node("GameState")
	gs.sound_enabled = false
	var f := FileAccess.open("res://data/levels/levels.json", FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	var levels: Array = parsed.levels
	check(levels.size() == 100, "100 levels")
	for lv in levels:
		check(lv.guards.size() >= 3, "level %d guards" % lv.id)
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
	check(gs.CHARACTER_ORDER.size() == 10, "10 characters")
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
	check(level.player_rig.anim.has_animation("run"), "run animation")
	check(level.player_rig.anim.has_animation("attack"), "attack animation")
	check(level.player_rig.anim.has_animation("death"), "death animation")
	var target: Vector2 = level._cell_center(10, 20)
	level._path_to(target)
	check(level.player_path.size() > 0, "path found")
	level.player_pos = level.guards[0].pos + Vector2(20, 0)
	level.attack_cd = 0.0
	level._auto_attack()
	check(level.kills == 1, "auto blade kill")
	check(level.gems.size() >= 1, "gem dropped")
	level.player_pos = level.gems[0].pos
	level._update_gems(0.1)
	check(level.gems_collected >= 1, "gem collected")
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
	var g0: Dictionary = lv2.guards[0]
	var facing := Vector2.from_angle(g0.face)
	lv2.player_pos = g0.pos - facing * 20.0
	g0.state = 0
	lv2.attack_cd = 0.0
	var kills_before: int = lv2.kills
	lv2._auto_attack()
	check(lv2.kills == kills_before + 1, "backstab kills unaware guard")
	check(lv2.backstabs == 1, "backstab counted")
	check(lv2.gems.size() >= 8, "backstab drops bonus gems")
	# Level-wide alarm: a confirmed sighting sends patrolling guards to search.
	var spotter: Dictionary = {}
	for g in lv2.guards:
		if g.alive:
			spotter = g
			break
	if not spotter.is_empty():
		var patrolling := 0
		for g in lv2.guards:
			if g.alive and g != spotter and g.state == 0:
				patrolling += 1
		lv2._alarm_others(spotter)
		var searching := 0
		for g in lv2.guards:
			if g.alive and g != spotter and g.state == 3:
				searching += 1
		check(searching == patrolling, "alarm puts patrol guards into search")
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
