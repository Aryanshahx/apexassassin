extends SceneTree
## Run only with isolated synthetic saves and generated test audio.
const Choice := preload("res://scripts/game/five_look_selection.gd")
const Player := preload("res://scripts/game/five_look_player.gd")
const Meta := preload("res://scripts/game/five_look_art_meta.gd")
var checks := 0
var failures := 0

func _init() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)

func _as_v(a: Array) -> Vector2: return Vector2(float(a[0]), float(a[1]))

func _sprite_bounds(view: Control, sprite: Sprite2D) -> Rect2:
	var used: Rect2i = sprite.texture.get_image().get_used_rect()
	var start := Vector2(used.position) + sprite.offset
	if sprite.centered: start -= sprite.texture.get_size() * 0.5
	var t: Transform2D = view.get_global_transform().affine_inverse() * sprite.get_global_transform()
	var points := [t * start, t * (start + Vector2(used.size.x, 0)), t * (start + Vector2(0, used.size.y)), t * (start + Vector2(used.size))]
	var result := Rect2(points[0], Vector2.ZERO)
	for p in points: result = result.expand(p)
	return result

func _run() -> void:
	var gs = root.get_node("GameState")
	var Enemy = load("res://scripts/game/six_enemy_rig.gd")
	gs.sound_enabled = false
	gs.haptics_enabled = false
	gs.selected_assassin = "ronin"
	gs.upgrades = {"speed": 0, "health": 0, "damage": 0}
	gs.start_level(100)
	await process_frame
	await process_frame
	var lv = current_scene
	lv.set_physics_process(false)
	var names := ["guard", "soldier", "officer", "heavy", "swat", "sniper"]
	var expected := {"guard": "AR-9", "soldier": "AK-47X", "officer": "M4A1-S", "heavy": "MG-500", "swat": "Vector-X", "sniper": "SR-98"}
	check(lv.ENEMY_PROFILES.size() == 6, "only the six requested enemy profiles are active")
	var by_type := {}
	for g in lv.guards:
		check(names.has(g.variant), "level 100 guard uses the requested active roster")
		if not by_type.has(g.variant): by_type[g.variant] = g
	for kind in names:
		check(lv.ENEMY_PROFILES.has(kind) and by_type.has(kind), kind + " actually spawns on level 100")
	if by_type.size() != 6:
		printerr("Actual spawned types: ", by_type.keys())
		quit(1)
		return
	var guard = lv.ENEMY_PROFILES.guard
	var soldier = lv.ENEMY_PROFILES.soldier
	var officer = lv.ENEMY_PROFILES.officer
	var heavy = lv.ENEMY_PROFILES.heavy
	var swat = lv.ENEMY_PROFILES.swat
	var sniper = lv.ENEMY_PROFILES.sniper
	check(float(soldier.damage) > float(guard.damage) and float(soldier.damage) > float(officer.damage), "soldier deals high damage")
	check(float(officer.spread) < float(guard.spread) and float(officer.spread) < float(soldier.spread) and float(officer.spread) < float(swat.spread), "officer has high aim accuracy")
	check(float(heavy.interval) < float(guard.interval) and float(heavy.interval) < float(swat.interval), "heavy has the highest fire rate")
	check(float(swat.speed) > float(guard.speed) and float(swat.damage) / float(swat.interval) > float(guard.damage) / float(guard.interval), "SWAT is fast and deadly")
	check(float(sniper.vision) > float(guard.vision) and float(sniper.damage) > float(soldier.damage), "sniper has long range and very high damage")
	check(not bool(sniper.get("one_shot", false)), "sniper is not an automatic one-hit defeat")
	var origin: Vector2 = load("res://tests/v65_test_fixtures.gd").open_arena(lv)
	check(origin != Vector2.ZERO, "test has open guard-clear floor")
	check(lv.player_health_bar.size.is_equal_approx(Vector2(64, 8)), "slim player health bar stays intact")
	for kind in names:
		var g: Dictionary = by_type[kind]
		var spec: Dictionary = Enemy.Art.ENEMY_ART[kind]
		check(g.weapon == expected[kind] and g.rig.look == kind, kind + " uses the correct gun and matching redraw")
		check(g.rig.art.texture.resource_path.ends_with("/six-enemy-update/" + kind + ".png"), kind + " loads its own sprite")
		var tip := _as_v(spec.tip)
		var tip_in_body: Vector2 = g.rig.art.transform * (tip - g.rig.art.texture.get_size() * 0.5)
		check(tip_in_body.distance_to(g.rig.muzzle.position) < 0.1 and g.rig.muzzle.position.y < -10.0 and absf(g.rig.muzzle.position.x) < 1.0, kind + " muzzle flash matches the pictured gun tip")
		lv.guards.clear()
		lv.guards.append(g)
		g.pos = origin
		g.state = lv.GState.PATROL
		lv.player_pos = origin + Vector2(180, 0)
		lv.bullets.clear()
		lv._fire(g)
		check(lv.bullets.size() == 1 and is_equal_approx(float(lv.bullets[0].damage), float(g.shot_damage)), kind + " projectile carries its actual damage")
		if not lv.bullets.is_empty():
			lv.bullets[0].pos = lv.player_pos + Vector2(-20, 0)
			lv.bullets[0].vel = Vector2(420, 0)
			lv.player_hp = 2000.0
			lv.invuln = 0.0
			lv._update_bullets(1.0 / 60.0)
			check(is_equal_approx(lv.player_hp, 2000.0 - float(g.shot_damage)), kind + " hit subtracts damage without bypassing health")
			if kind == "sniper": check(lv.player_hp > 0.0, "a healthy player can survive a sniper hit")
	# Gunfire alert behavior remains shared by all six.
	var spotter: Dictionary = by_type.guard
	var witness: Dictionary = by_type.soldier
	var distant: Dictionary = by_type.heavy
	lv.guards.clear(); lv.guards.append(spotter); lv.guards.append(witness); lv.guards.append(distant)
	spotter.pos = origin; spotter.state = lv.GState.ALERT; spotter.alive = true
	witness.pos = origin + Vector2(0, 400); witness.state = lv.GState.PATROL; witness.alive = true
	distant.pos = origin + Vector2(0, 520); distant.state = lv.GState.PATROL; distant.alive = true
	lv.player_pos = origin + Vector2(100, 0)
	lv._alarm_others(spotter)
	check(witness.state == lv.GState.ALERT and distant.state == lv.GState.ALERT, "gunfire still alerts the whole connected area")
	lv._sync_guard_marker(witness)
	check(witness.mark.visible and witness.mark.text == "?", "red alert marker remains available")
	# Collision geometry and gameplay stats are unchanged; rendered torso size is
	# corrected using the actual source bounds rather than weapon length.
	for look in Choice.LOOKS:
		var player = Player.new()
		root.add_child(player)
		player.setup(look, "player")
		player.scale = Vector2.ONE * lv.PLAYER_SCALE
		var body: Sprite2D = player.visual.get_node("ReferenceBody")
		var used: Rect2i = body.texture.get_image().get_used_rect()
		var body_size: float = float(maxi(used.size.x, used.size.y)) * (55.0 / 1514.0) * lv.PLAYER_SCALE
		check(body_size >= Enemy.BODY_WIDTH * 0.90, look + " body is now comparable to a guard body")
		for weapon in Choice.WEAPONS:
			player.set_knife(weapon)
			var handle: Vector2 = _as_v(Meta.WEAPON_GRIP[weapon])
			var handle_pixel: Color = player.weapon_art.texture.get_image().get_pixelv(Vector2i(handle))
			check(handle_pixel.a > 0.9, look + "/" + weapon + " uses a visible handle point")
			var hand: Sprite2D = player.wrist.get_node("HandArt")
			var hand_center: Vector2 = _as_v(Meta.HAND_GRIP_CENTRES[look]) - (player.wrist_anchor + hand.position)
			var grip_global: Vector2 = player.weapon_art.to_global(handle)
			var hand_global: Vector2 = hand.to_global(hand_center)
			check(grip_global.distance_to(hand_global) < 0.01 and player.weapon_art.get_index() < hand.get_index(), look + "/" + weapon + " handle is inside fist and behind it")
		player.queue_free()
	# Real home and each character selection card continuously use the equipped rig.
	check(Choice.save_selection("blue_tactical", "thor"), "saved synthetic cosmetic selection")
	var home: Control = load("res://scenes/home/home.tscn").instantiate()
	root.add_child(home)
	current_scene = home
	await process_frame
	check(home.card_art.rig.current_look == "blue_tactical" and home.card_art.rig.current_weapon == "thor" and home.card_art.rig.moving, "home shows equipped character and weapon running")
	for weapon in Choice.WEAPONS:
		home.card_art.rig.set_knife(weapon)
		check(Rect2(Vector2.ZERO, home.card_art.size).encloses(_sprite_bounds(home.card_art, home.card_art.rig.weapon_art)), "home displays all of " + weapon)
	home.card_art.rig.set_knife("thor")
	home._open_assassins()
	await process_frame
	var grid := home.find_child("FiveCharacterGrid", true, false)
	check(grid != null and grid.get_child_count() == 5, "character selection retains five looks")
	if grid != null:
		for card in grid.get_children():
			var preview = card.find_child("RunningCharacterWithEquippedWeapon", true, false)
			check(preview != null and preview.rig.current_weapon == "thor" and preview.rig.moving, card.name + " shows equipped weapon with continuous run")
			if preview != null:
				var before: float = preview.rig.walk_time
				preview.rig._process(0.2)
				check(preview.rig.walk_time > before, card.name + " running gait advances")
				for weapon in Choice.WEAPONS:
					preview.rig.set_knife(weapon)
					check(Rect2(Vector2.ZERO, preview.size).encloses(_sprite_bounds(preview, preview.rig.weapon_art)), card.name + " displays all of " + weapon)
	print("SIX ENEMIES UPDATE ", checks, " checks; ", failures, " failures")
	quit(1 if failures else 0)
