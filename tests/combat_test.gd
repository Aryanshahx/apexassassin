extends SceneTree
## Immediate light contact, nearby gunshot alert and 1000-point health UI.
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
	return load("res://tests/v65_test_fixtures.gd").open_arena(lv)

func _run() -> void:
	var gs = root.get_node("GameState")
	gs.sound_enabled = false
	gs.selected_assassin = "ronin"
	gs.upgrades = {"speed": 0, "health": 0, "damage": 0}
	gs.start_level(6)
	await process_frame
	await process_frame
	var lv = current_scene
	lv.set_physics_process(false)
	var origin := _open_origin(lv)
	check(origin != Vector2.ZERO, "test has an open floor area")
	check(is_equal_approx(gs.max_health(), 1000.0), "default full health is 1000")
	check(is_equal_approx(lv.player_hp, 1000.0) and is_equal_approx(lv.player_health_bar.value, 1000.0), "fresh level starts at 1000 on the bar")
	check(lv.player_health_label.text == "1000", "health bar visibly displays 1000")
	check(lv.player_health_anchor.get_parent() == lv and is_zero_approx(lv.player_health_anchor.rotation), "health bar is world-following and horizontal, not rotated with player")
	check(lv.find_child("PlayerHealthBar", true, false) != null, "one green player health bar exists")
	var has_heart := false
	for n in lv.find_children("*", "TextureRect", true, false):
		if n.texture != null and n.texture.resource_path.ends_with("/heart.png"):
			has_heart = true
	check(not has_heart, "heart lives are not shown")
	gs.selected_assassin = "ref02"
	check(is_equal_approx(gs.max_health(), 1100.0), "selected character health bonus remains effective")
	gs.upgrades.health = 2
	check(is_equal_approx(gs.max_health(), 1300.0), "saved health upgrades add 100 each")
	gs.selected_assassin = "ronin"
	gs.upgrades.health = 0
	lv.player_pos = origin + Vector2(70, 30)
	lv.player_rig.rotation = 2.1
	lv._move_player(0.0)
	check(lv.player_health_anchor.position.distance_to(lv.player_pos + Vector2(-lv.HEALTH_BAR_SIZE.x * 0.5, -52)) < 0.01 and is_zero_approx(lv.player_health_anchor.rotation), "bar follows the player without rotating")
	lv.bullets.clear()
	lv.bullets.append({"pos": lv.player_pos + Vector2(-20, 0), "vel": Vector2(420, 0), "life": 1.0})
	lv.invuln = 0.0
	lv._update_bullets(1.0 / 60.0)
	check(is_equal_approx(lv.player_hp, 900.0), "one bullet reduces health by 100")
	check(is_equal_approx(lv.player_health_bar.value, 900.0) and lv.player_health_label.text == "900", "bar fill and number reflect damage")
	check(lv.damage_taken == 1, "damage still counts against flawless missions")

	# Only the spotter and near/far witnesses participate in the alert test.
	var spotter: Dictionary = lv.guards[0]
	var nearby: Dictionary = lv.guards[1]
	var far: Dictionary = lv.guards[2]
	lv.guards.clear()
	lv.guards.append(spotter)
	lv.guards.append(nearby)
	lv.guards.append(far)
	spotter.pos = origin
	spotter.face = 0.0
	spotter.state = lv.GState.PATROL
	spotter.sees_player = false
	spotter.shoot = 99.0
	spotter.wait = 100.0
	spotter.path.clear()
	nearby.pos = origin + Vector2(0, 150)
	nearby.face = PI
	nearby.state = lv.GState.PATROL
	nearby.wait = 100.0
	nearby.sees_player = false
	nearby.path.clear()
	far.pos = origin + Vector2(0, 500)
	far.face = PI
	far.state = lv.GState.PATROL
	far.wait = 100.0
	far.sees_player = false
	far.path.clear()
	lv.player_pos = origin + Vector2(100, 0)
	lv.bullets.clear()
	check(lv._can_see(spotter.pos, spotter.face, lv.player_pos, spotter.vision), "open player is inside the visible cone")
	lv._update_guards(1.0 / 60.0)
	check(spotter.state == lv.GState.ALERT and lv.was_alerted, "light contact alerts the spotter in the same tick")
	check(lv.bullets.size() >= 1, "spotter fires on the first detection tick even with a previous cooldown")
	check(spotter.rig.guard_aim_amount > 0.99 and spotter.rig.guard_aim_target == 1.0, "gun points at the player on the first shot")
	check(nearby.state == lv.GState.ALERT and nearby.last_seen.distance_to(lv.player_pos) < 0.01, "gunshot informs a nearby guard of the player's location")
	check(far.state == lv.GState.ALERT, "gunshot also alerts a distant guard in the same connected area")
	nearby.state = lv.GState.SEARCH
	nearby.last_seen = lv.player_pos
	nearby.search_t = 1.0
	lv._alarm_others(spotter)
	check(nearby.state == lv.GState.ALERT and nearby.chase_left > 0.0, "a renewed alarm restarts pursuit from search")
	# Touching an edge of the visible cone also counts; shadows cannot delay a shot.
	var edge_angle := deg_to_rad(30.0) + asin(lv.PLAYER_LIGHT_RADIUS / 100.0) * 0.5
	var edge_target: Vector2 = origin + Vector2.from_angle(edge_angle) * 100.0
	check(lv._can_see(origin, 0.0, edge_target, 220.0), "player body touching the light cone is detected")
	var outside_target: Vector2 = origin + Vector2.from_angle(deg_to_rad(30.0) + asin(lv.PLAYER_LIGHT_RADIUS / 100.0) + 0.2) * 100.0
	check(not lv._can_see(origin, 0.0, outside_target, 220.0), "player beyond the beam and body radius is not falsely detected")
	lv.shadow_rects.clear()
	lv.shadow_rects.append(Rect2(lv.player_pos - Vector2.ONE * 10, Vector2.ONE * 20))
	check(lv.in_shadow(lv.player_pos) and lv._can_see(origin, 0.0, lv.player_pos, 220.0), "visible flashlight contact is immediate even in a shadow region")
	lv.shadow_rects.clear()
	# A wall between spotter and player still prevents detecting and firing.
	lv.guards.clear()
	lv.guards.append(spotter)
	spotter.pos = origin
	spotter.face = 0.0
	spotter.state = lv.GState.PATROL
	spotter.sees_player = false
	spotter.wait = 100.0
	lv.player_pos = origin + Vector2(100, 0)
	lv.blocking_rects.append(Rect2(origin + Vector2(45, -10), Vector2(10, 20)))
	lv.bullets.clear()
	lv._update_guards(1.0 / 60.0)
	check(lv.bullets.is_empty() and spotter.state == lv.GState.PATROL, "guard does not see or shoot through cover")
	lv.bullets.append({"pos": origin, "vel": Vector2(420, 0), "life": 1.0})
	lv.invuln = 0.0
	var hp_before_wall: float = lv.player_hp
	lv._update_bullets(0.4)
	check(lv.bullets.is_empty() and is_equal_approx(lv.player_hp, hp_before_wall), "low-frame-rate bullets cannot tunnel through a wall")
	lv.blocking_rects.remove_at(lv.blocking_rects.size() - 1)
	spotter.shoot = 99.0
	lv._update_guards(1.0 / 60.0)
	check(lv.bullets.size() == 1, "re-entering the light fires immediately, regardless of cooldown")
	# In the real physics order, contact is resolved even at melee distance.
	lv.bullets.clear()
	spotter.alive = true
	spotter.hp = 1
	spotter.pos = origin
	spotter.face = 0.0
	spotter.state = lv.GState.PATROL
	spotter.sees_player = false
	spotter.shoot = 99.0
	lv.player_pos = origin + Vector2(50, 0)
	lv.player_path.clear()
	lv.hit_stop = 0.0
	lv.invuln = 0.0
	lv.attack_cd = 0.0
	lv.finished = false
	lv.total = 99
	var hp_before_contact: float = lv.player_hp
	lv._physics_process(1.0 / 60.0)
	# A faster point-blank bullet may already hit and be removed this frame.
	check(not spotter.alive and (lv.bullets.size() == 1 or lv.player_hp < hp_before_contact), "light contact fires before point-blank auto-melee in the live physics loop")
	print("COMBAT %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
