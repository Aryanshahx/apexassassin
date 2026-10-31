extends SceneTree
## Enemy archetypes, real damage/cadence, wider alert and the slim health UI.
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
	for y in range(2, int(lv.data.height) - 6):
		for x in range(2, int(lv.data.width) - 6):
			var ok := true
			for dy in range(6):
				for dx in range(6):
					if lv.guard_grid.is_point_solid(Vector2i(x + dx, y + dy)):
						ok = false
			if ok:
				return lv._cell_center(x + 1, y + 2)
	return Vector2.ZERO
func _run() -> void:
	var gs = root.get_node("GameState")
	gs.sound_enabled = false
	gs.selected_assassin = "ronin"
	gs.upgrades = {"speed": 0, "health": 0, "damage": 0}
	gs.start_level(1)
	await process_frame
	await process_frame
	var lv = current_scene
	lv.set_physics_process(false)
	var origin := _open_origin(lv)
	check(origin != Vector2.ZERO, "test has open guard-clear floor")
	check(lv.player_health_bar.size.is_equal_approx(Vector2(64, 8)), "green health fill is actually 64 by 8 after Godot layout")
	check(lv.player_health_anchor.size.is_equal_approx(Vector2(64, 8)) and lv.player_health_label.text == "1000", "slim bar retains numeric 1000 health")
	var by_type := {}
	for g in lv.guards:
		if not by_type.has(g.variant):
			by_type[g.variant] = g
	check(by_type.has("scout") and by_type.has("guard") and by_type.has("heavy"), "three differentiated enemy types appear from level one")
	if by_type.size() != 3:
		print("ENEMY TYPES %d checks, %d failures" % [checks, failures])
		quit(1)
		return
	check(by_type.scout.rig.modulate != by_type.guard.rig.modulate and by_type.heavy.rig.modulate != by_type.guard.rig.modulate, "enemy variants have distinguishable artwork tints")
	var damage_by_type := {"scout": 65.0, "guard": 100.0, "heavy": 160.0}
	var interval_by_type := {"scout": 0.65, "guard": 1.0, "heavy": 1.45}
	for kind in ["scout", "guard", "heavy"]:
		var g: Dictionary = by_type[kind]
		check(is_equal_approx(g.shot_damage, damage_by_type[kind]) and is_equal_approx(g.shot_interval, interval_by_type[kind]), kind + " has its own damage and fire interval")
		lv.guards.clear()
		lv.guards.append(g)
		g.pos = origin
		g.state = lv.GState.PATROL
		lv.player_pos = origin + Vector2(100, 0)
		lv.bullets.clear()
		lv._fire(g)
		check(lv.bullets.size() == 1 and is_equal_approx(lv.bullets[0].damage, damage_by_type[kind]), kind + " projectile carries the right damage")
		lv.bullets[0].pos = lv.player_pos + Vector2(-20, 0)
		lv.bullets[0].vel = Vector2(420, 0)
		lv.player_hp = 1000.0
		lv.invuln = 0.0
		lv._update_bullets(1.0 / 60.0)
		check(is_equal_approx(lv.player_hp, 1000.0 - damage_by_type[kind]), kind + " actually removes its own damage from health")
	var counts := {}
	for kind in ["scout", "guard", "heavy"]:
		var g: Dictionary = by_type[kind]
		lv.guards.clear()
		lv.guards.append(g)
		lv.bullets.clear()
		g.pos = origin
		g.face = 0.0
		g.state = lv.GState.PATROL
		g.sees_player = false
		g.shoot = 0.0
		g.wait = 100.0
		lv.player_pos = origin + Vector2(100, 0)
		for frame in range(240):
			lv._update_guards(1.0 / 60.0)
		counts[kind] = lv.bullets.size()
	check(counts.scout > counts.guard and counts.guard > counts.heavy, "actual continuous fire rates differ: scout > guard > heavy")
	print("FIRE COUNTS ", counts)
	# A witness outside the old 320 radius but inside 480 now becomes alert.
	var spotter: Dictionary = by_type.guard
	var witness: Dictionary = by_type.scout
	var distant: Dictionary = by_type.heavy
	lv.guards.clear()
	lv.guards.append(spotter)
	lv.guards.append(witness)
	lv.guards.append(distant)
	spotter.pos = origin
	spotter.state = lv.GState.ALERT
	witness.pos = origin + Vector2(0, 400)
	witness.state = lv.GState.PATROL
	distant.pos = origin + Vector2(0, 520)
	distant.state = lv.GState.PATROL
	lv.player_pos = origin + Vector2(100, 0)
	lv._sync_guard_marker(spotter)
	lv._sync_guard_marker(witness)
	lv._sync_guard_marker(distant)
	lv._alarm_others(spotter)
	check(is_equal_approx(lv.GUNSHOT_HEARING_RADIUS, 480.0) and witness.state == lv.GState.INVESTIGATE, "gunfire informs a guard 400 units away")
	check(distant.state == lv.GState.PATROL and not distant.mark.visible, "distant guard outside alert radius remains unalerted")
	check(spotter.mark.visible and witness.mark.visible and spotter.mark.text == "?" and witness.mark.text == "?", "red question marks appear above spotter and alerted witness")
	var red: Color = witness.mark.get_theme_color("font_color")
	check(red.r > 0.9 and red.g < 0.3 and red.b < 0.3, "alert question mark is red")
	witness.state = lv.GState.SEARCH
	lv._sync_guard_marker(witness)
	check(witness.mark.visible, "question mark stays visible while searching")
	witness.state = lv.GState.PATROL
	lv._sync_guard_marker(witness)
	check(not witness.mark.visible, "question mark disappears once patrol resumes")
	witness.alive = false
	witness.state = lv.GState.ALERT
	lv._sync_guard_marker(witness)
	check(not witness.mark.visible, "defeated guards have no alert marker")
	print("ENEMY TYPES %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
