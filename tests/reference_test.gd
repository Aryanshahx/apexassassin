extends SceneTree
## Roster, save, reconstructed rig, weapon and live selector regression suite.
## This writes user:// saves. Run only with an isolated XDG_DATA_HOME.
## godot --headless --path . --script tests/reference_test.gd
var failures := 0
var checks := 0

func _init() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", message)

func _write_save(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write isolated test save")
		quit(1)
		return
	file.store_string(JSON.stringify(data))
	file.close()

func _run() -> void:
	var gs = root.get_node("GameState")
	var reference_rig = load("res://scripts/game/reference_rig.gd")
	gs.sound_enabled = false
	var fixture := {
		"schema": 4, "gems": 733, "cash": 512, "current_level": 34,
		"unlocked_level": 40, "total_kills": 62, "flawless_count": 3,
		"mission1_claimed": true, "mission2_claimed": false,
		"mission3_claimed": true, "sound_enabled": false, "haptics_enabled": true,
		"upgrades": {"health": 1, "damage": 2, "speed": 1},
		"selected_assassin": "fiesta", "unlocked_assassins": {"ronin": true, "nova": true, "fiesta": true},
		"selected_knife": "frost", "unlocked_knives": {"standard": true, "frost": true},
		"best_stars": {"7": 3, "12": 2}, "last_wheel_day": "2026-10-29",
	}
	_write_save(gs.SAVE_PATH, fixture)
	gs.unlocked_assassins = {"ronin": true}
	gs.unlocked_knives = {"standard": true}
	gs.selected_assassin = "ronin"
	gs.selected_knife = "standard"
	gs.load_game()
	check(gs.selected_assassin == "fiesta", "v0.5.3/v0.5.4 legacy selection reloads")
	check(gs.is_unlocked("nova") and gs.is_unlocked("fiesta") and not gs.is_unlocked("oni"), "legacy unlocks preserved")
	check(gs.selected_knife == "frost" and gs.is_knife_unlocked("frost"), "legacy knife selection and unlock preserved")
	check(gs.gems == 733 and gs.cash == 512 and gs.unlocked_level == 40 and gs.current_level == 34, "legacy currency and levels preserved")
	check(gs.total_kills == 62 and gs.flawless_count == 3 and int(gs.best_stars.get("7", 0)) == 3, "legacy stats and stars preserved")
	check(gs.mission1_claimed and gs.mission3_claimed and gs.last_wheel_day == "2026-10-29", "legacy mission and wheel data preserved")
	check(absf(gs.player_speed() - (190.0 * 1.40 + 14.0)) < 0.001, "legacy fiesta speed unchanged")
	check(gs.LEGACY_ORDER.size() == 10 and gs.REFERENCE_ORDER.size() == 12 and gs.CHARACTER_ORDER.size() == 22, "12 reference and 10 legacy characters exposed")

	var speeds := [0.10, 0.0, 0.15, 0.0, 0.20, 0.0, 0.25, 0.0, 0.30, 0.0, 0.35, 0.0]
	var healths := [0.0, 0.10, 0.0, 0.15, 0.0, 0.20, 0.0, 0.25, 0.0, 0.30, 0.0, 0.35]
	for i in range(12):
		var id := "ref%02d" % (i + 1)
		check(gs.REFERENCE_ORDER[i] == id and gs.reference_art_index(id) == i + 1, "%s maps to correct art" % id)
		check(gs.is_unlocked(id) and int(gs.CHARACTERS[id].cost) == 0, "%s immediately available free" % id)
		check(absf(float(gs.CHARACTERS[id].speed_bonus) - float(speeds[i])) < 0.001 and absf(float(gs.CHARACTERS[id].health_bonus) - float(healths[i])) < 0.001, "%s screenshot bonuses" % id)
		check(gs.select_character(id) and gs.selected_assassin == id, "%s selectable" % id)
		check(absf(gs.player_speed() - (190.0 * (1.0 + float(speeds[i])) + 14.0)) < 0.001, "%s speed applies" % id)
		check(absf(gs.max_health() - (3.0 * (1.0 + float(healths[i])) + 1.0)) < 0.001, "%s health applies" % id)
		# Force a fresh read of the file to ensure the free selection survives reload.
		gs.selected_assassin = "ronin"
		gs.load_game()
		check(gs.selected_assassin == id, "%s selection persists" % id)
		check(gs.gems == 733 and gs.cash == 512 and gs.is_unlocked("fiesta") and gs.last_wheel_day == "2026-10-29", "%s selection retains legacy save fields" % id)
		check(ResourceLoader.exists("res://assets/reference/characters/%02d.png" % (i + 1)) and ResourceLoader.exists("res://assets/reference/cards/%02d.png" % (i + 1)), "%s source sprite and card packaged" % id)
	# Removed selections migrate without discarding money, levels, knives or unlocks.
	for i in range(12):
		var id := "new%02d" % (i + 1)
		check(not gs.CHARACTERS.has(id) and not gs.is_unlocked(id) and not gs.select_character(id), "%s removed from playable roster" % id)
		var removed_save := fixture.duplicate(true)
		removed_save.selected_assassin = id
		removed_save.unlocked_assassins[id] = true
		_write_save(gs.SAVE_PATH, removed_save)
		gs.load_game()
		check(gs.selected_assassin == "ronin", "%s saved selection falls back safely" % id)
		check(gs.gems == 733 and gs.cash == 512 and gs.current_level == 34 and gs.is_unlocked("fiesta") and gs.selected_knife == "frost", "%s migration preserves other progress" % id)
	_write_save(gs.SAVE_PATH, fixture)
	gs.load_game()
	check(not gs.select_character("not-a-character"), "unknown character rejected")
	for i in range(gs.LEGACY_ORDER.size()):
		var id: String = gs.LEGACY_ORDER[i]
		check(gs.CHARACTERS.has(id) and gs.reference_art_index(id) == i + 1, "legacy %s identity and new visual mapping" % id)

	# All 17 original knife mechanics are still selectable and numerically unchanged.
	var damages := [1, 1, 2, 1, 2, 2, 2, 3, 2, 2, 3, 2, 3, 2, 4, 3, 4]
	var cooldowns := [0.32, 0.30, 0.34, 0.26, 0.30, 0.26, 0.30, 0.40, 0.28, 0.24, 0.34, 0.26, 0.32, 0.22, 0.42, 0.24, 0.26]
	var ranges := [54.0, 60.0, 54.0, 58.0, 62.0, 60.0, 58.0, 52.0, 60.0, 56.0, 56.0, 64.0, 58.0, 60.0, 54.0, 66.0, 68.0]
	check(gs.KNIFE_ORDER.size() == 17, "17 knife IDs retained")
	for i in range(gs.KNIFE_ORDER.size()):
		var knife: String = gs.KNIFE_ORDER[i]
		gs.unlocked_knives[knife] = true
		check(gs.select_knife(knife), "%s can be equipped" % knife)
		check(gs.player_damage() == int(damages[i]) + 2 and absf(gs.attack_cooldown() - float(cooldowns[i])) < 0.001 and absf(gs.attack_range() - float(ranges[i])) < 0.001, "%s damage, cooldown and reach retained" % knife)
		check(ResourceLoader.exists("res://assets/knives/%s.png" % knife), "%s art exists" % knife)
	gs.selected_knife = "standard"
	gs.load_game()
	check(gs.selected_knife == "apex" and gs.is_knife_unlocked("apex"), "equipped special knife persists")

	# Instantiate each screenshot rig with every knife, then advance the actual clips.
	for i in range(12):
		var id := "ref%02d" % (i + 1)
		var rig = reference_rig.new()
		rig.setup(id, "player")
		root.add_child(rig)
		var pose := rig.art.get_node("Pose") as Sprite2D
		check(pose != null and pose.texture.resource_path.ends_with("/characters/parts/%02d_body.png" % (i + 1)), "%s uses its own layered screenshot pixels" % id)
		check(absf(rig.ART_WORLD_EXTENT - 55.0) < 0.001 and rig.original_blade.visible and not rig.custom_blade.visible, "%s bounded size and original standard blade" % id)
		for knife in gs.KNIFE_ORDER:
			rig.set_knife(knife)
			if knife == "standard":
				check(rig.original_blade.visible and not rig.custom_blade.visible, "%s/%s original blade" % [id, knife])
			else:
				check(not rig.original_blade.visible and rig.custom_blade.visible and rig.custom_blade.texture != null and rig.custom_blade.texture.resource_path.ends_with("/knives/%s.png" % knife), "%s/%s equipped blade displayed" % [id, knife])
		rig.set_knife("standard")
		rig.set_moving(true)
		rig.anim.advance(0.13)
		rig.anim.advance(0.03)
		check(rig._current == "run" and rig.foot_a.visible and rig.foot_b == null and rig.foot_a.position.distance_to(rig.foot_rest_a) > 0.1, "%s single authentic boot moves smoothly without a duplicate" % id)
		rig.play_anim("attack", true)
		rig.anim.advance(0.08)
		check(absf(rig.blade.rotation) > 0.20, "%s blade attack moves" % id)
		rig.anim.advance(0.40)
		check(rig._current == "run", "%s attack returns to running" % id)
		rig.play_anim("hurt", true)
		rig.anim.advance(0.07)
		check(rig.body.modulate.g < 0.8, "%s hurt flashes" % id)
		rig.die()
		rig.anim.advance(0.30)
		check(rig.dead and absf(rig.body.rotation) > 0.5 and rig.foot_a.visible, "%s death retains the boot" % id)
		root.remove_child(rig)
		rig.free()


	for type in ["guard", "elite"]:
		var enemy = reference_rig.new()
		enemy.setup(type, "guard")
		root.add_child(enemy)
		var pose := enemy.art.get_node("Pose") as Sprite2D
		check(pose.texture.resource_path.ends_with("/guards/parts/%s_body.png" % type), "%s uses layered gameplay-reference pixels" % type)
		check(absf(enemy.GUARD_WORLD_EXTENT - 60.0) < 0.001, "%s bounded artwork size" % type)
		check(enemy.anim.has_animation("idle") and enemy.anim.has_animation("run") and enemy.anim.has_animation("shoot") and enemy.anim.has_animation("hurt") and enemy.anim.has_animation("death"), "%s enemy clips present" % type)
		check(enemy.foot_a.get_child(0).texture != enemy.foot_b.get_child(0).texture and enemy.guard_gun.get_node("Weapon").texture != null, "%s has two separate boot layers and a rifle" % type)
		enemy.set_moving(true)
		enemy.anim.advance(0.15)
		enemy.anim.advance(0.03)
		var a_step: Vector2 = enemy.foot_a.position - enemy.foot_rest_a
		var b_step: Vector2 = enemy.foot_b.position - enemy.foot_rest_b
		check(enemy._current == "run" and enemy.foot_a.visible and enemy.foot_b.visible and a_step.dot(b_step) < 0, "%s pivoted boots move in counterphase" % type)
		enemy.set_aiming(true, 0.25)
		enemy._process(0.4)
		check(enemy.guard_aim_amount > 0.99 and enemy.guard_gun.rotation > enemy.guard_raise_angle, "%s raises and turns gun" % type)
		enemy.set_aiming(false)
		enemy._process(0.4)
		check(is_zero_approx(enemy.guard_aim_amount) and is_zero_approx(enemy.guard_gun.rotation), "%s lowers rifle when no target" % type)
		enemy.play_anim("shoot", true)
		enemy.anim.advance(0.05)
		check(enemy.muzzle.modulate.a > 0.5 and enemy.muzzle.get_parent() == enemy.guard_gun, "%s muzzle flash stays on gun" % type)
		enemy.anim.advance(0.30)
		check(enemy._current == "run", "%s shooting returns to patrol" % type)
		enemy.die()
		enemy.anim.advance(0.30)
		check(enemy.dead and absf(enemy.body.rotation) > 0.5 and enemy.foot_a.visible, "%s death retains layered legs" % type)
		root.remove_child(enemy)
		enemy.free()

	# Exercise the real concept-inspired selection screen and its actual controls.
	gs.select_character("ref01")
	change_scene_to_file("res://scenes/home/home.tscn")
	await process_frame
	await process_frame
	var home = current_scene
	check(home.find_child("SelectedHomeConcept", true, false) != null and home.find_child("StartGameButton", true, false) != null, "selected home concept and live start control present")
	check(home.gems_label.text == str(gs.gems) and home.cash_label.text == str(gs.cash), "home currency counters use saved values")
	home._open_assassins()
	await process_frame
	await process_frame
	var roster = home.overlay.find_child("Roster", true, false)
	check(roster != null and roster.get_child_count() == 22, "selector exposes the 22 retained characters")
	check(home.overlay.find_child("WarehouseBackdrop", true, false) != null and home.overlay.find_child("HeroArt", true, false) != null, "live warehouse selector and featured art present")
	# Push actual pointer events: browsing previews without spending/equipping.
	var click_card := home.overlay.find_child("ReferenceCard02", true, false) as Button
	var click_at := click_card.get_global_rect().get_center()
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = click_at
	down.global_position = click_at
	root.push_input(down, true)
	await process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = click_at
	up.global_position = click_at
	root.push_input(up, true)
	await process_frame
	check(home.overlay.preview_id == "ref02" and gs.selected_assassin == "ref01", "pointer previews without silently equipping")
	var select_btn := home.overlay.find_child("SelectButton", true, false) as Button
	click_at = select_btn.get_global_rect().get_center()
	down.position = click_at
	down.global_position = click_at
	up.position = click_at
	up.global_position = click_at
	root.push_input(down, true)
	await process_frame
	root.push_input(up, true)
	await process_frame
	check(gs.selected_assassin == "ref02" and select_btn.disabled, "pointer SELECT equips highlighted character")
	for i in range(12):
		var id := "ref%02d" % (i + 1)
		var card = home.overlay.find_child("ReferenceCard%02d" % (i + 1), true, false)
		check(card != null and card.get_node("Portrait").texture.resource_path.ends_with("/characters/%02d.png" % (i + 1)), "%s correct reference portrait in UI" % id)
		card.pressed.emit()
		await process_frame
		check(home.overlay.preview_id == id, "%s thumbnail previews" % id)
		if not select_btn.disabled:
			select_btn.pressed.emit()
		await process_frame
		check(gs.selected_assassin == id and home.card_art.texture.resource_path.ends_with("/characters/%02d.png" % (i + 1)), "%s SELECT updates home portrait" % id)
		check(select_btn.disabled and home.overlay.hero.texture == card.get_node("Portrait").texture, "%s selected state and featured art" % id)
	check(gs.gems == 733 and gs.is_unlocked("fiesta"), "free UI selections preserve gems and legacy unlocks")
	var scroller := home.overlay.find_child("AssassinScroll", true, false) as ScrollContainer
	var target = home.overlay.find_child("ReferenceCard10", true, false)
	target.pressed.emit()
	await create_timer(0.22).timeout
	var old_scroll := scroller.scroll_horizontal
	select_btn.pressed.emit()
	await process_frame
	check(old_scroll > 0 and scroller.scroll_horizontal == old_scroll, "selection preserves horizontal collection scroll")
	# A real touch swipe must pan the long collection without selecting a card.
	scroller.scroll_horizontal = 1000
	await process_frame
	var swipe_before := scroller.scroll_horizontal
	var preview_before: String = home.overlay.preview_id
	var swipe_start := scroller.get_global_rect().get_center()
	var touch_down := InputEventScreenTouch.new()
	touch_down.index = 0
	touch_down.pressed = true
	touch_down.position = swipe_start
	root.push_input(touch_down, true)
	var touch_move := InputEventScreenDrag.new()
	touch_move.index = 0
	touch_move.position = swipe_start + Vector2(140, 0)
	touch_move.relative = Vector2(140, 0)
	root.push_input(touch_move, true)
	var touch_up := InputEventScreenTouch.new()
	touch_up.index = 0
	touch_up.pressed = false
	touch_up.position = touch_move.position
	root.push_input(touch_up, true)
	await process_frame
	check(scroller.scroll_horizontal < swipe_before - 50, "touch swipe scrolls the roster")
	check(home.overlay.preview_id == preview_before and gs.selected_assassin == "ref10", "touch swipe does not change the selection")
	# Mouse users can drag the same collection, and ordinary pointer clicks remain usable.
	await create_timer(0.22).timeout
	scroller.scroll_horizontal = 1000
	await process_frame
	swipe_before = scroller.scroll_horizontal
	down.position = swipe_start
	down.global_position = swipe_start
	root.push_input(down, true)
	var mouse_move := InputEventMouseMotion.new()
	mouse_move.position = swipe_start + Vector2(120, 0)
	mouse_move.global_position = mouse_move.position
	mouse_move.relative = Vector2(120, 0)
	mouse_move.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(mouse_move, true)
	up.position = mouse_move.position
	up.global_position = mouse_move.position
	root.push_input(up, true)
	await process_frame
	check(scroller.scroll_horizontal < swipe_before - 50 and home.overlay.preview_id == preview_before, "mouse drag browses without selecting")
	await create_timer(0.22).timeout
	# Locked legacy preview must not charge until the explicit unlock action.
	home.overlay._preview("oni")
	var before_gems: int = gs.gems
	check(not gs.is_unlocked("oni") and gs.gems == before_gems, "locked legacy preview is non-destructive")
	select_btn.pressed.emit()
	await process_frame
	check(gs.is_unlocked("oni") and gs.selected_assassin == "oni" and gs.gems == before_gems - 260, "legacy unlock spends correct gems only on confirm")

	# Verify that a selection and equipped special knife make it into a real level.
	gs.select_character("ref11")
	gs.select_knife("apex")
	gs.start_level(4)
	await process_frame
	await process_frame
	await process_frame
	var level = current_scene
	check(level.player_rig.kind == "ref11" and level.player_rig.role == "player", "selected screenshot character enters gameplay")
	check(level.player_rig.custom_blade.visible and level.player_rig.custom_blade.texture.resource_path.ends_with("/apex.png"), "equipped special knife enters gameplay")
	var enemies_correct := true
	for guard in level.guards:
		if guard.rig.role != "guard" or not guard.rig.art.get_node("Pose").texture.resource_path.contains("/assets/reference/guards/parts/"):
			enemies_correct = false
	check(enemies_correct, "real level uses screenshot guards")
	check(level.player_rig.scale.is_equal_approx(Vector2.ONE * 0.92), "real level player root scale unchanged")

	# Older v2 fallback save still migrates when the v3 file is absent.
	var old_fixture := {"gems": 17, "cash": 219, "selected_assassin": 1, "unlocked_assassins": {"ronin": true, "nova": true}, "unlocked_level": 9}
	_write_save(gs.OLD_SAVE_PATH, old_fixture)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.SAVE_PATH))
	gs.unlocked_assassins = {"ronin": true}
	gs.unlocked_knives = {"standard": true}
	gs.load_game()
	check(gs.selected_assassin == "nova" and gs.is_unlocked("nova") and gs.gems == 17 and gs.unlocked_level == 9, "v2 numeric selection and progress migrate")

	print("REFERENCE %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
