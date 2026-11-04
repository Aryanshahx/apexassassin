extends SceneTree
## Real gameplay/UI tests in an isolated synthetic save. No user's files used.
const Choice := preload("res://scripts/game/ten_character_selection.gd")
const Fixture := preload("res://tests/v65_test_fixtures.gd")
var checks := 0
var failures := 0

func _init() -> void: call_deferred("_run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)

func _tap(point: Vector2) -> void:
	var down := InputEventScreenTouch.new()
	down.index = 0; down.pressed = true; down.position = point
	Input.parse_input_event(down)
	await process_frame
	var up := InputEventScreenTouch.new()
	up.index = 0; up.pressed = false; up.position = point
	Input.parse_input_event(up)
	await process_frame
	await process_frame

func _swipe(from: Vector2, displacement: Vector2) -> void:
	var down := InputEventScreenTouch.new()
	down.index = 0; down.pressed = true; down.position = from
	Input.parse_input_event(down)
	await process_frame
	for i in range(1, 7):
		var drag := InputEventScreenDrag.new()
		drag.index = 0; drag.position = from + displacement * float(i) / 6.0
		drag.relative = displacement / 6.0
		Input.parse_input_event(drag)
		await process_frame
	var up := InputEventScreenTouch.new()
	up.index = 0; up.pressed = false; up.position = from + displacement
	Input.parse_input_event(up)
	await process_frame
	await process_frame

func _input_point(control: Control) -> Vector2:
	return root.get_stretch_transform() * control.get_global_rect().get_center()

func _bullet(start: Vector2, velocity: Vector2, ability: String, damage := 100.0) -> Dictionary:
	return {"pos": start, "vel": velocity, "life": 2.0, "damage": damage, "ability": ability}

func _run() -> void:
	var sandbox := OS.get_environment("APEX_REDSCARF_TEST_ROOT").simplify_path()
	var userdir := OS.get_user_data_dir().simplify_path()
	if sandbox in ["", "/"] or not userdir.begins_with(sandbox + "/"):
		printerr("Refusing test outside disposable user-data root")
		quit(1); return
	var gs = root.get_node("GameState")
	# The type rotation is deterministic and keeps counts and geometry unchanged.
	var Level = load("res://scripts/game/level.gd")
	var encountered := {}
	for number in range(1, 101):
		var probe = Level.new()
		probe._load_level(number)
		var boss_count := 0
		for index in range(probe.data.guards.size()):
			var kind: String = probe._enemy_variant(number, index, probe.data.guards[index])
			encountered[kind] = true
			if kind == "boss": boss_count += 1
		check(boss_count == (1 if number >= 20 and number % 20 == 0 else 0), "level %d follows the milestone Boss rotation" % number)
		check(probe.data.guards.size() == gs.level_data(number).guards.size(), "level %d preserves the authored count" % number)
		probe.free()
	check(encountered.size() == 12, "all twelve enemy classes appear in the full progression")
	for number in [20, 40, 60, 80, 100]:
		var probe = Level.new()
		probe._load_level(number)
		probe._build_grid(); probe._build_walkable_regions(); probe._build_guards()
		var bosses := 0
		for guard in probe.guards:
			if guard.variant == "boss":
				bosses += 1
				check(Vector2(guard.pos).distance_to(probe.player_pos) >= 410.0, "level %d Boss is safely away from spawn" % number)
		check(bosses == 1, "level %d actually spawns one milestone Boss" % number)
		probe.free()
	gs.sound_enabled = false
	gs.haptics_enabled = false
	# An old schema-4 save has no new field. Existing claim flags, progress,
	# balances and upgrades must survive loading and every new claim.
	var saved := {"schema": 4, "cash": 321, "gems": 73, "current_level": 28,
		"unlocked_level": 28, "total_kills": 115, "flawless_count": 6,
		"mission1_claimed": true, "mission2_claimed": false, "mission3_claimed": true,
		"selected_assassin": "ronin", "unlocked_assassins": {"ronin": true},
		"selected_knife": "standard", "unlocked_knives": {"standard": true},
		"upgrades": {"health": 2, "speed": 1, "damage": 3}, "best_stars": {"1": 3, "2": 2, "27": 3},
		"sound_enabled": false, "haptics_enabled": false, "keys_collected": 1, "key_levels_claimed": {"17": true}}
	var file := FileAccess.open(gs.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(saved)); file.close()
	gs.load_game()
	check(gs.cash == 321 and gs.gems == 73 and gs.current_level == 28 and gs.total_kills == 115, "old balances and progress load")
	check(gs.mission1_claimed and not gs.mission2_claimed and gs.mission3_claimed and gs.mission_claims.is_empty(), "old three mission flags migrate unchanged")
	check(gs.upgrades.health == 2 and gs.upgrades.speed == 1 and gs.upgrades.damage == 3 and gs.keys_collected == 1, "old upgrades and key progress survive")
	check(gs.mission_progress("kills") == 115 and gs.mission_progress("levels") == 27 and gs.mission_progress("perfect") == 6 and gs.mission_progress("stars") == 2, "milestones use persistent old statistics")
	gs.best_stars["100"] = 1
	check(gs.mission_progress("levels") == 100, "a recorded level-100 win counts as completing 100")
	gs.best_stars.erase("100")
	Choice.save_selection("standard", "aurora")
	root.size = Vector2i(360, 640)
	var home = load("res://scenes/home/home.tscn").instantiate()
	root.add_child(home); current_scene = home
	await process_frame; await process_frame
	check(home.find_child("HomeTitle", true, false) == null and home.find_child("AssassinButton", true, false) == null, "home title and separate CHARACTERS button are gone")
	check(home.change_button != null and home.change_button.get_global_rect().encloses(home.card_art.get_global_rect()), "entire displayed character is a real touch target")
	await _tap(_input_point(home.card_art))
	check(home.overlay != null and home.find_child("TenCharacterGrid", true, false) != null, "tapping the actual displayed character opens the existing selector")
	home._close_overlay()
	await process_frame
	check(home.mission_nodes.size() == 3 + gs.MISSION_MILESTONES.size() and home.mission_scroll.get_v_scroll_bar().max_value > home.mission_scroll.get_v_scroll_bar().page, "new missions form a genuinely scrollable list")
	var claim2: Button = home.find_child("Mission2Button", true, false)
	check(claim2 != null and not claim2.disabled, "old free-supply mission still claimable")
	var before_cash: int = gs.cash
	await _swipe(_input_point(claim2), Vector2(0, -110))
	check(home.mission_scroll.scroll_vertical > 50, "dragging on a claim button scrolls the mission list")
	check(not gs.mission2_claimed and gs.cash == before_cash, "a swipe on CLAIM does not claim it")
	await create_timer(0.32).timeout
	home.mission_scroll.scroll_vertical = 0
	await process_frame
	claim2 = home.find_child("Mission2Button", true, false)
	await _tap(_input_point(claim2))
	check(gs.mission2_claimed and gs.cash == before_cash + 200, "real touch claims the old 200-cash mission once")
	var after_old: int = gs.cash
	home._claim_mission(2)
	check(gs.cash == after_old, "old claim cannot pay twice")
	# The first new milestone is past the three original cards.
	home.mission_scroll.scroll_vertical = 96
	await process_frame; await process_frame
	var claim4: Button = home.find_child("Mission4Button", true, false)
	await _tap(_input_point(claim4))
	check(bool(gs.mission_claims.get("kills_100", false)) and gs.cash == after_old + 250, "real touch claims the 100-kill milestone for 250")
	var after_new: int = gs.cash
	home._claim_mission(4)
	check(gs.cash == after_new, "new milestone cannot pay twice")
	check(home.cash_label.text == str(after_new), "claim updates the displayed balance")
	gs.mission_claims["future_unknown"] = true
	gs.save_game()
	gs.cash = 0; gs.mission_claims = {}; gs.mission1_claimed = false
	gs.load_game()
	check(gs.cash == after_new and gs.mission1_claimed and gs.mission2_claimed and gs.mission3_claimed, "old flags and claimed rewards survive save/reload")
	check(bool(gs.mission_claims.get("kills_100", false)) and bool(gs.mission_claims.get("future_unknown", false)), "new and unknown mission claim IDs survive save/reload")
	check(gs.gems == 73 and gs.upgrades.health == 2 and gs.keys_collected == 1 and gs.key_levels_claimed.has("17"), "mission claims leave currency, upgrades and keys intact")
	check(home.start_button.find_child("StartButtonShine", true, false) is ColorRect, "start shine is retained")
	await create_timer(0.4).timeout
	check(home.start_button.scale.x > 1.001 and home.start_button.scale.x >= 1.0 and home.start_button.pivot_offset == home.start_button.size * 0.5, "start grows from its centre without shrinking the touch target")
	await _tap(_input_point(home.start_button))
	await process_frame; await process_frame
	check(current_scene != home and current_scene.has_method("_update_guards"), "pulsing start button responds to an actual touch")
	# Level 100 contains the old and new classes without changing authored count.
	gs.start_level(100)
	await process_frame; await process_frame
	var lv = current_scene
	lv.set_physics_process(false)
	check(lv.guards.size() == lv.data.guards.size() and lv.guards.size() == 12, "level 100 keeps authored guard count")
	var by_type := {}
	for g in lv.guards: by_type[String(g.variant)] = g
	check(by_type.size() == 12, "all twelve types actually spawn on level 100")
	for kind in ["guard", "soldier", "officer", "heavy", "swat", "sniper", "medic", "engineer", "bomber", "shield", "mutant", "boss"]:
		check(by_type.has(kind), kind + " spawns")
	if by_type.size() != 12:
		quit(1); return
	var origin: Vector2 = Fixture.open_arena(lv)
	lv.grass_rects.clear()
	var medic: Dictionary = by_type.medic
	var ally: Dictionary = by_type.guard
	var dead: Dictionary = by_type.soldier
	lv.guards.clear(); lv.guards.append(medic); lv.guards.append(ally); lv.guards.append(dead)
	medic.pos = origin; medic.alive = true; medic.med_cooldown = 0.0
	ally.pos = origin + Vector2(80, 0); ally.alive = true; ally.hp = 1; ally.max_hp = 5; ally.support_left = 0.0
	dead.pos = origin + Vector2(40, 0); dead.alive = false; dead.hp = 0
	lv.effects.clear(); lv._update_medic_support(0.01)
	check(ally.hp == 3 and ally.support_left > 3.9, "Medic heals and buffs the nearest living ally")
	check(dead.hp == 0 and not dead.alive, "Medic never resurrects a defeated ally")
	check(lv.effects.any(func(e): return String(e.kind) == "med_beam"), "Medic visibly emits a support beam")
	lv.player_pos = origin + Vector2(210, 0); lv.bullets.clear()
	check(lv._fire(ally), "supported ally can fire")
	check(is_equal_approx(float(lv.bullets[0].damage), float(ally.shot_damage) * 1.22) and is_equal_approx(float(ally.shot_lock), float(ally.shot_interval) * 0.80), "Medic support really improves ally damage and fire rate")
	medic.alive = false
	lv._update_medic_support(4.1)
	check(float(ally.support_left) <= 0.0, "support expires after the medic is defeated")
	medic.alive = true
	ally.hp = 1; ally.support_left = 0.0; medic.med_cooldown = 0.0
	lv.blocking_rects.append(Rect2(origin + Vector2(40, -20), Vector2(10, 40)))
	lv._update_medic_support(0.01)
	check(ally.hp == 1 and float(ally.support_left) == 0.0, "Medic cannot heal or buff through cover")
	lv.blocking_rects.clear()
	lv.guards.clear()
	# Grass and cover are absolute firing gates for every new class.
	for kind in ["medic", "engineer", "bomber", "shield", "mutant", "boss"]:
		var g: Dictionary = by_type[kind]
		g.pos = origin; g.alive = true; g.support_left = 0.0
		lv.guards.clear(); lv.guards.append(g)
		lv.player_pos = origin + Vector2(160, 0); lv.bullets.clear()
		lv.grass_rects.clear(); lv.grass_rects.append(Rect2(lv.player_pos - Vector2.ONE * 22, Vector2.ONE * 44))
		check(not lv._fire(g) and lv.bullets.is_empty(), kind + " cannot shoot a concealed non-contact player")
		lv.grass_rects.clear(); lv.blocking_rects.append(Rect2(origin + Vector2(70, -20), Vector2(10, 40)))
		check(not lv._fire(g) and lv.bullets.is_empty(), kind + " cannot shoot through cover")
		lv.blocking_rects.clear()
	# Shield armor piercing scales against existing bonus health, not walls.
	var shield: Dictionary = by_type.shield
	lv.guards.clear(); lv.guards.append(shield); shield.pos = origin; shield.support_left = 0.0
	gs.upgrades.health = 0; lv.active_look = "standard"; lv.player_pos = origin + Vector2(180, 0)
	lv.bullets.clear(); check(lv._fire(shield), "Shield fires pulse rounds")
	var base_damage: float = lv.bullets[0].damage
	gs.upgrades.health = 5; lv.active_look = "health_40"
	lv.bullets.clear(); lv._fire(shield)
	check(float(lv.bullets[0].damage) > base_damage * 2.0 and gs.upgrades.health == 5, "armor-piercing pulse compensates for bonus health without deleting upgrades")
	gs.upgrades.health = 0; lv.active_look = "standard"
	# Engineer and Bomber detonate on an actual near miss. A blocker must stop
	# their radial damage, including when the projectile hits the wall itself.
	for kind in ["engineer", "bomber"]:
		lv.bullets.clear(); lv.blocking_rects.clear(); lv.player_hp = 2000.0; lv.invuln = 0.0; lv.shock_slow_left = 0.0
		lv.player_pos = origin + Vector2(100, 48 if kind == "engineer" else 70)
		var b := _bullet(origin, Vector2(100, 0), kind, 150.0); b.life = 0.5
		lv.bullets.append(b); lv._update_bullets(1.0)
		check(is_equal_approx(lv.player_hp, 1850.0) and lv.bullets.is_empty(), kind + " causes real area damage on a near miss")
		check(lv.effects.any(func(e): return String(e.kind) == ("shock_area" if kind == "engineer" else "blast_area")), kind + " shows the matching area effect")
		if kind == "engineer":
			var slowed: float = lv._player_speed()
			check(lv.shock_slow_left > 0.0, "Tesla shock temporarily slows the player")
			lv._update_player_status(1.0)
			check(lv.shock_slow_left == 0.0 and lv._player_speed() > slowed, "shock slowing expires")
		lv.bullets.clear(); lv.player_hp = 2000.0; lv.invuln = 0.0
		lv.player_pos = origin + Vector2(120, 0)
		lv.blocking_rects.append(Rect2(origin + Vector2(90, -20), Vector2(10, 100)))
		lv.bullets.append(_bullet(origin, Vector2(100, 0), kind, 150.0)); lv._update_bullets(1.0)
		check(lv.player_hp == 2000.0 and lv.bullets.is_empty(), kind + " area damage cannot cross a wall")
		lv.blocking_rects.clear()
		lv.player_pos = origin + Vector2(90, 0); lv.invuln = 0.0; lv.player_hp = 2000.0
		lv.bullets.append(_bullet(origin, Vector2(200, 0), kind, 150.0)); lv._update_bullets(0.75)
		check(is_equal_approx(lv.player_hp, 1850.0), kind + " direct hit causes damage exactly once at low frame rate")
	# Mutant direct hit actually creates periodic poison, respecting invulnerability.
	lv.bullets.clear(); lv.blocking_rects.clear(); lv.player_pos = origin + Vector2(100, 0)
	lv.player_hp = 2000.0; lv.invuln = 0.0; lv.poison_ticks = 0
	lv.bullets.append(_bullet(lv.player_pos - Vector2(20, 0), Vector2(420, 0), "mutant", 100.0))
	lv._update_bullets(0.05)
	check(is_equal_approx(lv.player_hp, 1900.0) and lv.poison_ticks == 3, "Bio-Rifle applies immediate hit plus three poison ticks")
	for i in range(3):
		lv.invuln = 0.0; lv._update_player_status(0.76)
	check(is_equal_approx(lv.player_hp, 1825.0) and lv.poison_ticks == 0, "poison causes three timed damage ticks and ends")
	lv.poison_ticks = 1; lv.poison_timer = 0.0; lv.poison_damage = 25.0; lv.invuln = 1.0
	var protected: float = lv.player_hp
	lv._update_player_status(0.01)
	check(lv.player_hp == protected, "poison respects existing invulnerability")
	var boss: Dictionary = by_type.boss
	check(float(lv.ENEMY_PROFILES.boss.damage) > float(lv.ENEMY_PROFILES.bomber.damage) and boss.weapon == "Plasma-Rifle", "Boss has its powerful plasma weapon")
	lv.guards.clear(); lv.guards.append(boss); boss.pos = origin; boss.alive = true; boss.support_left = 0.0
	lv.invuln = 0.0; lv.player_pos = origin + Vector2(180, 0); lv.bullets.clear()
	check(lv._fire(boss) and String(lv.bullets[0].ability) == "boss" and float(lv.bullets[0].damage) == float(boss.shot_damage), "Boss fires its real high-power plasma projectile")
	# Poison can trigger the normal defeat sequence rather than silently killing.
	lv.player_hp = 10.0; lv.invuln = 0.0; lv.poison_ticks = 1; lv.poison_timer = 0.0; lv.poison_damage = 25.0
	lv._update_player_status(0.01)
	check(lv.player_hp == 0.0 and lv.finished, "poison uses the normal defeat path")
	lv.queue_free(); await process_frame
	print("SPECIAL ENEMIES AND MISSIONS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
