extends SceneTree
## Same-connected-area alarms, outside-cone LOS fire, exact doubled cadence,
## blood-only kills, audio byte identity and event hooks. Use isolated saves.
var checks := 0
var failures := 0
func _init() -> void:
	call_deferred("_run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)
func stop_audio(sfx: Node) -> void:
	for player in sfx.players:
		player.stop()
func is_playing(sfx: Node, stream: AudioStream) -> bool:
	for player in sfx.players:
		if player.playing and player.stream == stream:
			return true
	return false
func reset_guard(g: Dictionary, p: Vector2, state: int) -> void:
	g.pos = p
	g.rig.position = p
	g.rig.visible = true
	g.alive = true
	g.state = state
	g.face = PI
	g.sees_player = false
	g.shoot = 0.0
	g.wait = 999.0
	g.speed = 0.0
	g.vision = 250.0
	g.path.clear()
	g.last_seen = Vector2.ZERO
	g.chase_left = 0.0

func _run() -> void:
	var gs = root.get_node("GameState")
	var sfx = root.get_node("Sfx")
	gs.sound_enabled = true
	gs.haptics_enabled = false
	gs.start_level(6)
	await process_frame
	await process_frame
	var lv = current_scene
	lv.set_physics_process(false)
	var stab: Variant = sfx.streams.get("stab")
	var suspect: Variant = sfx.streams.get("suspect")
	for pair in [["stab", stab], ["suspect", suspect]]:
		var path: String = "res://assets/audio/%s2.mp3" % pair[0]
		var bytes := FileAccess.get_file_as_bytes(path)
		check(bytes.size() > 0 and ResourceLoader.exists(path), pair[0] + " MP3 was installed and imported")
		check(pair[1] is AudioStreamMP3, pair[0] + " is registered as an MP3 stream")
		if pair[1] is AudioStreamMP3:
			check(pair[1].data == bytes and pair[1].get_length() > 0.0, pair[0] + " uses exact, playable file bytes")
		else:
			check(false, pair[0] + " uses exact, playable file bytes")
	var baseline := {"scout": 0.65, "guard": 1.0, "heavy": 1.45, "ranger": 0.8, "breacher": 1.15, "captain": 0.95}
	for kind in baseline:
		check(is_equal_approx(float(lv.ENEMY_PROFILES[kind].interval) * 2.0, float(baseline[kind])), kind + " has exactly half the previous shot interval")
	var original: Array = lv.guards.duplicate()
	var source: Dictionary = original[0]
	var witness: Dictionary = original[1]
	var far: Dictionary = original[2]
	var origin: Vector2 = load("res://tests/v65_test_fixtures.gd").open_arena(lv)
	lv.guards.clear()
	lv.guards.append(source)
	lv.guards.append(witness)
	lv.guards.append(far)
	reset_guard(source, origin, lv.GState.PATROL)
	reset_guard(witness, origin + Vector2(0, 140), lv.GState.PATROL)
	reset_guard(far, origin + Vector2(0, 600), lv.GState.PATROL)
	source.face = 0.0
	lv.player_pos = origin + Vector2(150, 0)
	check(not lv._can_see(witness.pos, witness.face, lv.player_pos, witness.vision), "witness initially faces away from the player")
	stop_audio(sfx)
	lv.bullets.clear()
	lv._update_guards(1.0 / 60.0)
	check(source.state == lv.GState.ALERT and witness.state == lv.GState.ALERT and far.state == lv.GState.ALERT, "spotter alerts every living guard in the same connected area, including beyond 480 units")
	check(witness.last_seen.distance_to(lv.player_pos) < 0.01 and far.last_seen.distance_to(lv.player_pos) < 0.01, "the alarm communicates the player's position without the witnesses' original cones")
	check(witness.sees_player and lv.bullets.size() >= 2, "an informed witness turns and fires when it has direct LOS, even outside its original cone")
	check(suspect is AudioStream and is_playing(sfx, suspect), "spotting triggers the selected suspect MP3")
	# The v0.6.6 alarm tracks the live position even behind cover, but
	# physical cover still prevents aiming and shooting.
	lv.guards.clear()
	lv.guards.append(witness)
	reset_guard(witness, origin, lv.GState.ALERT)
	witness.last_seen = origin + Vector2(100, 0)
	witness.chase_left = lv._chase_duration(witness)
	lv.player_pos = origin + Vector2(160, 0)
	lv.blocking_rects.append(Rect2(origin + Vector2(70, -45), Vector2(12, 90)))
	lv.guard_blocking_rects.append(lv.blocking_rects[lv.blocking_rects.size() - 1].grow(lv.GUARD_WALL_MARGIN))
	lv.bullets.clear()
	stop_audio(sfx)
	lv._update_guards(0.05)
	check(not witness.sees_player and lv.bullets.is_empty() and witness.last_seen.distance_to(lv.player_pos) < 0.01, "an alerted guard tracks the live target but cannot see or shoot through a wall")
	check(suspect is AudioStream and not is_playing(sfx, suspect), "a hidden player does not trigger suspect audio")
	# A real wall splitting the navigation graph isolates the second room.
	lv.blocking_rects.clear()
	lv.guard_blocking_rects.clear()
	var divider := Rect2(lv.ORIGIN + Vector2(0, 20 * lv.CELL), Vector2(float(lv.data.width) * lv.CELL, 3 * lv.CELL))
	lv.blocking_rects.append(divider)
	lv.guard_blocking_rects.append(divider.grow(lv.GUARD_WALL_MARGIN))
	lv._build_grid()
	lv._build_walkable_regions()
	lv.guards.clear()
	lv.guards.append(source)
	lv.guards.append(witness)
	lv.guards.append(far)
	reset_guard(source, origin, lv.GState.ALERT)
	reset_guard(witness, origin + Vector2(0, 140), lv.GState.PATROL)
	reset_guard(far, origin + Vector2(0, 600), lv.GState.PATROL)
	lv.player_pos = origin + Vector2(150, 0)
	check(lv.guard_walkable_regions.size() == 2, "solid divider creates two genuinely disconnected guard areas")
	lv._alarm_others(source)
	check(witness.state == lv.GState.ALERT and far.state == lv.GState.PATROL, "alarm stays within the connected area and ignores the isolated room")
	# Killed guards leave blood alone, while the real saved loot still updates.
	load("res://tests/v65_test_fixtures.gd").open_arena(lv)
	lv.guards.clear()
	lv.guards.append(witness)
	reset_guard(witness, origin, lv.GState.PATROL)
	witness.hp = 1
	witness.face = 0.0
	witness.elite = false
	witness.diamond_carrier = true
	lv.player_pos = origin + Vector2(-40, 0)
	lv.attack_cd = 0.0
	lv.effects.clear()
	lv.loot_particles.clear()
	lv.blood_splats.clear()
	var cash_before: int = gs.cash
	var gems_before: int = gs.gems
	stop_audio(sfx)
	lv._auto_attack()
	check(stab is AudioStream and is_playing(sfx, stab), "a real stab triggers the selected stab MP3")
	check(not witness.alive and not witness.rig.visible and lv.blood_splats.size() == 1, "kill removes the body and creates one blood splatter")
	check(lv.effects.is_empty() and lv.loot_particles.is_empty(), "kill creates no slash, ring, poof, floating reward or loot particles")
	check(gs.cash > cash_before and gs.gems == gems_before + 1, "money and diamond rewards are still saved")
	var first_stain: Dictionary = lv.blood_splats[0].duplicate(true)
	lv._update_effects(3600.0)
	for i in range(40):
		lv._add_blood_splatter(origin)
	check(lv.blood_splats.size() == 41 and lv.blood_splats[0] == first_stain, "all blood remains unaltered, with no time fade or cap")
	var saved_cash: int = gs.cash
	var saved_gems: int = gs.gems
	gs.start_level(1)
	await process_frame
	await process_frame
	lv = current_scene
	lv.set_physics_process(false)
	check(lv.blood_splats.is_empty() and gs.cash == saved_cash and gs.gems == saved_gems, "a fresh level clears blood without losing rewards")
	# Important user-supplied audio is not lost if all pooled voices are busy.
	var busy := AudioStreamWAV.new()
	busy.mix_rate = 22050
	var samples := PackedByteArray()
	samples.resize(22050)
	busy.data = samples
	for name in ["stab", "suspect"]:
		for player in sfx.players:
			player.stop()
			player.stream = busy
			player.play()
		sfx.play(name)
		check(is_playing(sfx, sfx.streams[name]), name + " plays even when the audio pool is full")
	stop_audio(sfx)
	gs.sound_enabled = false
	sfx.play("stab")
	sfx.play("suspect")
	check(not is_playing(sfx, stab) and not is_playing(sfx, suspect), "sound setting mutes both new effects")
	for player in sfx.players:
		player.stop()
		player.stream = null
	await create_timer(0.3).timeout
	print("V65 COMBAT + AUDIO %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
