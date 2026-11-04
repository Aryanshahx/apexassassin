extends SceneTree
## Synthetic saves and silent, in-memory audio only. No real user files change.
const Choice := preload("res://scripts/game/ten_character_selection.gd")
const Rig := preload("res://scripts/game/ten_character_player.gd")
const Fixture := preload("res://tests/v65_test_fixtures.gd")
var checks := 0
var failures := 0

func _init() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)

func _wave() -> AudioStreamWAV:
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_8_BITS
	sound.mix_rate = 22050
	sound.data = PackedByteArray([128, 128, 128, 128])
	sound.loop_mode = AudioStreamWAV.LOOP_FORWARD
	sound.loop_end = 4
	return sound

func _playing(sfx: Node, sound: AudioStream) -> bool:
	for player in sfx.players:
		if player.playing and player.stream == sound:
			return true
	return false

func _stop_audio(sfx: Node) -> void:
	for player in sfx.players:
		player.stop()
		player.stream = null

func _swipe(from: Vector2, delta: Vector2) -> void:
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.pressed = true
	down.position = from
	Input.parse_input_event(down)
	await process_frame
	for i in range(1, 7):
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = from + delta * float(i) / 6.0
		drag.relative = delta / 6.0
		Input.parse_input_event(drag)
		await process_frame
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.pressed = false
	up.position = from + delta
	Input.parse_input_event(up)
	await process_frame

func _run() -> void:
	var sandbox := OS.get_environment("APEX_REDSCARF_TEST_ROOT").simplify_path()
	var userdir := OS.get_user_data_dir().simplify_path()
	if sandbox in ["", "/"] or not userdir.begins_with(sandbox + "/"):
		printerr("Refusing test: user data is not inside its declared disposable root")
		quit(1)
		return
	var gs = root.get_node("GameState")
	var sfx = root.get_node("Sfx")
	gs.sound_enabled = false
	gs.haptics_enabled = false
	sfx.enabled = true

	# Every character has connected, opposite shoulder motion while walking.
	for look in Choice.LOOKS:
		var actor := Rig.new()
		actor.setup(look, "player")
		root.add_child(actor)
		actor.set_process(false)
		actor.set_moving(true)
		actor._process(1.0 / 12.0)
		check(absf(actor.knife_shoulder.rotation) > 0.05 and absf(actor.free_shoulder.rotation) > 0.05, look + " moves both shoulders while walking")
		check(actor.knife_shoulder.rotation * actor.free_shoulder.rotation < 0.0, look + " shoulders swing in opposite directions")
		check(actor.knife_elbow.get_parent() == actor.knife_shoulder and actor.wrist.get_parent() == actor.knife_elbow and actor.weapon_art.get_parent() == actor.wrist, look + " retains connected elbow, fist and weapon")
		actor.set_moving(false)
		actor._process(0.02)
		check(absf(actor.knife_shoulder.rotation) < 0.001 and absf(actor.free_shoulder.rotation) < 0.001, look + " shoulders settle when standing")
		actor.free()

	# Real swipe events begin on portrait buttons, not only on empty padding.
	root.size = Vector2i(360, 640)
	Choice.save_selection("standard", "aurora")
	var home = load("res://scenes/home/home.tscn").instantiate()
	root.add_child(home)
	current_scene = home
	await process_frame
	await process_frame
	var button_shine = home.start_button.find_child("StartButtonShine", true, false)
	check(button_shine is ColorRect and button_shine.mouse_filter == Control.MOUSE_FILTER_IGNORE and button_shine.material is ShaderMaterial, "start button has a nonblocking animated shine")
	home._open_assassins()
	await process_frame
	await process_frame
	await process_frame
	var scroll = home.collection_scroll
	var portrait = home.find_child("LookCard_standard", true, false).get_node("PortraitButton")
	check(scroll.get_v_scroll_bar().max_value > scroll.get_v_scroll_bar().page, "all ten characters exceed the scroll viewport")
	var previous := Choice.read_selection()
	var touch_point: Vector2 = root.get_stretch_transform() * portrait.get_global_rect().get_center()
	await _swipe(touch_point, Vector2(0, -110))
	check(scroll.scroll_vertical > 100, "finger drag on portrait scrolls the actual character screen")
	check(Choice.read_selection() == previous, "swiping a portrait does not select it")
	home._on_look_pressed("health_40")
	check(Choice.read_selection() == previous, "release of a drag cannot equip a different character")
	var viewport_point: Vector2 = root.get_stretch_transform() * scroll.get_global_rect().get_center()
	await _swipe(viewport_point, Vector2(0, -250))
	await process_frame
	var bar = scroll.get_v_scroll_bar()
	var maximum := maxi(0, roundi(bar.max_value - bar.page))
	check(maximum > 0 and scroll.scroll_vertical >= maximum - 3, "touch swipe can reach the final character")
	var position_at_bottom: int = scroll.scroll_vertical
	await create_timer(0.32).timeout
	home._on_look_pressed("health_40")
	await process_frame
	await process_frame
	await process_frame
	check(Choice.read_selection().look == "health_40", "a deliberate selection still equips a character")
	check(home.collection_scroll.scroll_vertical >= position_at_bottom - 3, "equipping preserves the character screen's scroll position")
	home._close_overlay()

	var splash = load("res://scenes/splash/splash.tscn").instantiate()
	root.add_child(splash)
	await process_frame
	splash._fit()
	check(splash.title_shine.texture.resource_path.ends_with("splash_logo_shine_mask.png") and splash.title_shine.material is ShaderMaterial, "splash logo uses the animated lettering mask")
	check(splash.title_shine.mouse_filter == Control.MOUSE_FILTER_IGNORE, "splash shine does not intercept input")
	check(splash.title_shine.size.x > 0.0 and splash.title_shine.size.y > 0.0, "splash shine tracks image scaling")
	splash.queue_free()
	home.queue_free()
	await process_frame
	gs.locker_board = {}
	gs.selected_assassin = "ronin"
	gs.upgrades = {"speed": 0, "health": 0, "damage": 0}
	gs.start_level(100)
	await process_frame
	await process_frame
	var lv = current_scene
	lv.set_physics_process(false)
	check(lv.map_grass != null and lv.map_grass.z_index > lv.player_rig.z_index and lv.map_grass.z_index < lv.player_health_anchor.z_index, "grass canopy renders above actors and below the health HUD")
	check(lv.map_grass.z_index > lv.guards[0].rig.z_index, "guards are also drawn underneath grass")
	var enemies := {}
	for enemy: Dictionary in lv.guards:
		if not enemies.has(enemy.variant):
			enemies[enemy.variant] = enemy
	check(enemies.has("guard") and enemies.has("sniper"), "guard and sniper are available for real behavior tests")
	if not enemies.has("guard") or not enemies.has("sniper"):
		quit(1)
		return
	var origin: Vector2 = Fixture.open_arena(lv)
	lv.grass_rects.clear()
	for y in range(3):
		for x in range(3):
			lv.grass_rects.append(Rect2(origin + Vector2(x - 1, y - 1) * lv.GRASS_TILE, Vector2.ONE * lv.GRASS_TILE))
	var guard: Dictionary = enemies.guard
	lv.guards.clear()
	lv.guards.append(guard)
	guard.pos = origin + Vector2(-90, 0)
	guard.path.clear()
	guard.pi = 0
	guard.roam_valid = true
	guard.roam_target = origin + Vector2(100, 0)
	guard.wait = 0.0
	guard.speed = 85.0
	guard.vision = 10.0
	guard.state = lv.GState.PATROL
	guard.alive = true
	lv.player_pos = origin + Vector2(300, 250)
	lv.map_grass.ripples.clear()
	lv.map_grass.since_last = 1.0
	var crossed := false
	var guard_rustled := false
	for i in range(30):
		lv._update_guards(0.1)
		crossed = crossed or lv.in_grass(guard.pos)
		guard_rustled = guard_rustled or not lv.map_grass.ripples.is_empty()
	check(crossed and guard.pos.x > origin.x + 60.0, "enemy actually walks through and out of a grass group")
	check(guard_rustled, "enemy movement disturbs the canopy")
	lv.map_grass.ripples.clear()
	lv.map_grass.since_last = 1.0
	lv.player_pos = origin + Vector2(-50, 0)
	lv.player_path = PackedVector2Array([origin + Vector2(20, 0)])
	lv._move_player(1.0)
	check(lv.in_grass(lv.player_pos) and not lv.map_grass.ripples.is_empty(), "walking player makes grass bounce")
	check(lv.player_velocity.length() > 1.0, "movement exposes measured velocity for accurate sniper leading")
	lv.player_path.clear()
	lv._move_player(0.1)
	check(lv.player_velocity == Vector2.ZERO, "standing player has zero measured velocity")
	lv.map_grass._process(0.1)
	check(not lv.map_grass.ripples.is_empty() and float(lv.map_grass.ripples[0].age) > 0.0, "grass ripple animates over time")
	lv.map_grass._process(1.0)
	check(lv.map_grass.ripples.is_empty(), "grass bounce settles without accumulating effects")

	# A real kill decal overlaps nearby props, and shoes pick up blood only after
	# intersecting a wet pool. Prints alternate and are bounded for mobile.
	lv.blood_splats.clear()
	lv.blood_footprints.clear()
	lv.blood_steps_remaining = 0
	lv.blood_step_distance = 0.0
	guard.pos = origin
	guard.alive = true
	var kills_before: int = lv.kills
	lv._kill_guard(0)
	check(lv.kills == kills_before + 1 and lv.blood_splats.size() == 1, "an actual enemy kill creates the blood splatter")
	check(lv.blood_splats.size() == 1 and lv.blood_splats[0].drops.size() == 12 and lv.BLOOD_TEX.get_image().get_used_rect().has_area(), "kill blood uses a textured persistent splatter")
	var near_prop := Rect2(origin + Vector2(35, -20), Vector2(42, 40))
	var far_prop := Rect2(origin + Vector2(500, 500), Vector2(42, 40))
	check(lv.map_cover._prop_stain_overlap(lv.blood_splats[0], near_prop).has_area(), "nearby prop receives blood only where the decal intersects")
	check(not lv.map_cover._prop_stain_overlap(lv.blood_splats[0], far_prop).has_area(), "distant prop does not receive unrelated blood")
	lv.player_pos = origin + Vector2(-50, 0)
	lv.player_path = PackedVector2Array([origin + Vector2(80, 0)])
	lv._move_player(1.0)
	check(lv.blood_footprints.size() >= 2, "real player movement across blood stamps footprints")
	lv.blood_footprints.clear()
	lv.blood_steps_remaining = 0
	lv.blood_step_distance = 0.0
	lv._update_bloody_steps(origin + Vector2(-70, 0), origin + Vector2(140, 0))
	check(lv.blood_footprints.size() >= 4, "walking across blood leaves multiple footprints")
	if lv.blood_footprints.size() >= 2:
		check(bool(lv.blood_footprints[0].left) != bool(lv.blood_footprints[1].left), "blood footprints alternate left and right")
		check(lv.blood_footprints[0].pos.x >= origin.x - lv.BLOOD_PICKUP_RADIUS, "no footprint is stamped before blood contact")
	var count_before: int = lv.blood_footprints.size()
	lv._update_bloody_steps(origin + Vector2(140, 0), origin + Vector2(500, 0))
	check(lv.blood_footprints.size() <= 12 and lv.blood_footprints.size() > count_before and lv.blood_steps_remaining == 0, "tracked blood runs out after a limited number of steps")
	for i in range(25):
		lv._update_bloody_steps(origin + Vector2(-40, 0), origin + Vector2(200, 0))
	check(lv.blood_footprints.size() <= lv.BLOOD_PRINT_LIMIT, "footprint count is bounded for mobile performance")

	# Compare an actual sniper's straight projectile against a constant moving
	# target. The previous direct-at-current-position shot would miss badly.
	var sniper: Dictionary = enemies.sniper
	lv.guards.clear()
	lv.guards.append(sniper)
	sniper.pos = origin + Vector2(0, 100)
	sniper.alive = true
	sniper.shots_fired = 0
	lv.grass_rects.clear()
	lv.blocking_rects.clear()
	for speed in [80.0, 150.0, 250.0]:
		for sign in [-1.0, 1.0]:
			lv.player_pos = sniper.pos + Vector2(280, 0)
			lv.player_velocity = Vector2(0, speed * sign)
			lv.bullets.clear()
			check(lv._fire(sniper), "sniper fires at an exposed moving target")
			var bullet: Dictionary = lv.bullets[0]
			var relative: Vector2 = bullet.pos - lv.player_pos
			var relative_velocity: Vector2 = bullet.vel - lv.player_velocity
			var closest := clampf(-relative.dot(relative_velocity) / relative_velocity.length_squared(), 0.0, 1.6)
			var miss: float = (relative + relative_velocity * closest).length()
			check(miss < 2.0, "sniper leads lateral motion at speed %.0f, closest miss %.2f" % [speed, miss])
			var plain_dir := Vector2.RIGHT
			var muzzle: float = absf(sniper.rig.muzzle.position.y) * sniper.rig.scale.x - 0.1
			var direct_relative: Vector2 = sniper.pos + plain_dir * muzzle - lv.player_pos
			var direct_velocity: Vector2 = plain_dir * lv.BULLET_SPEED - lv.player_velocity
			var direct_t := clampf(-direct_relative.dot(direct_velocity) / direct_velocity.length_squared(), 0.0, 1.6)
			check((direct_relative + direct_velocity * direct_t).length() > lv.PLAYER_HIT_RADIUS, "old unled shot would miss the same moving target")
	var velocity_before: Vector2 = lv.bullets[0].vel
	lv.invuln = 0.0
	lv.player_hp = 2000.0
	lv._update_bullets(0.01)
	check(not lv.bullets.is_empty() and lv.bullets[0].vel == velocity_before, "sniper bullets remain straight, not homing")
	lv.bullets.clear()
	lv.blocking_rects.append(Rect2(sniper.pos + Vector2(80, -20), Vector2(10, 40)))
	check(not lv._fire(sniper) and lv.bullets.is_empty(), "accurate sniper still cannot fire through a wall")
	lv.blocking_rects.clear()
	lv.grass_rects.append(Rect2(lv.player_pos - Vector2.ONE * 20, Vector2.ONE * 40))
	check(not lv._fire(sniper) and lv.bullets.is_empty(), "accurate sniper cannot shoot a concealed non-contact player")
	lv.grass_rects.clear()

	# Locker cards suppress only the global click; the actual reward dispatches
	# unlockkey, while unrelated buttons still have the normal tap sound.
	gs.locker_board = {"character_slot": 8, "amounts": [5,6,7,8,9,10,11,12,13], "opened": [], "eligible": true}
	gs.sound_enabled = true
	var ui_tap := _wave()
	var unlock := _wave()
	var old_tap = sfx.streams.get("ui_tap")
	var old_unlock = sfx.streams.get("unlockkey")
	sfx.streams["ui_tap"] = ui_tap
	sfx.streams["unlockkey"] = unlock
	_stop_audio(sfx)
	var board = load("res://scripts/ui/locker_rewards.gd").new()
	root.add_child(board)
	await process_frame
	var card: Button = board.buttons[0]
	check(bool(card.get_meta("apex_suppress_ui_tap", false)), "locker card is explicitly exempt from generic tap audio")
	card.button_down.emit()
	check(not _playing(sfx, ui_tap), "touching a locker does not play the UI tap")
	card.pressed.emit()
	check(_playing(sfx, unlock) and not _playing(sfx, ui_tap), "opening a locker plays unlockkey alone")
	_stop_audio(sfx)
	var ordinary := Button.new()
	root.add_child(ordinary)
	ordinary.button_down.emit()
	check(_playing(sfx, ui_tap), "normal buttons retain the existing tap sound")
	_stop_audio(sfx)
	if old_tap != null: sfx.streams["ui_tap"] = old_tap
	else: sfx.streams.erase("ui_tap")
	if old_unlock != null: sfx.streams["unlockkey"] = old_unlock
	else: sfx.streams.erase("unlockkey")
	ordinary.queue_free()
	board.queue_free()
	lv.queue_free()
	var music = sfx.get_node_or_null("BackgroundMusic")
	if music != null:
		music.set_process(false)
		music.player.stop()
		music.player.stream = null
	await process_frame
	await create_timer(0.15).timeout
	print("WORLD EFFECTS AND UI: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
