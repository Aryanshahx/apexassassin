extends SceneTree
## User-reported v0.6.7 regressions: event ordering, no repeated audio,
## bounded alarms, nearby kill reaction, separated patrols, anti-stall and HUD.
## Always run with an isolated XDG_DATA_HOME.
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

func playing(sfx: Node, stream: AudioStream) -> bool:
	for player in sfx.players:
		if player.playing and player.stream == stream:
			return true
	return false

func reset_guard(g: Dictionary, point: Vector2, state: int, speed: float = 58.0) -> void:
	g.pos = point
	g.rig.position = point
	g.rig.visible = true
	g.alive = true
	g.hp = 1
	g.state = state
	g.face = PI
	g.wait = 999.0
	g.speed = speed
	g.vision = 250.0
	g.shoot = 99.0
	g.sees_player = false
	g.alert_repath = 0.0
	g.chase_left = 8.0
	g.last_seen = Vector2.ZERO
	g.blocked_t = 0.0
	g.avoid_time = 0.0
	g.avoid_direction = Vector2.ZERO
	g.traffic_wait = false
	g.traffic_stall = 0.0
	g.yield_partner = -1
	g.yield_side = Vector2.ZERO
	g.yield_left = 0.0
	g.route_goal = Vector2(INF, INF)
	g.stuck_time = 0.0
	g.progress_anchor = point
	g.recover_left = 0.0
	g.recover_direction = Vector2.ZERO
	g.recover_count = 0
	g.path.clear()
	g.pi = 0

func _run() -> void:
	var gs = root.get_node("GameState")
	var sfx = root.get_node("Sfx")
	gs.sound_enabled = true
	gs.haptics_enabled = false
	gs.selected_assassin = "ronin"
	gs.selected_knife = "standard"
	gs.upgrades = {"speed": 0, "health": 0, "damage": 0}
	gs.start_level(6)
	await process_frame
	await process_frame
	var lv = current_scene
	lv.set_physics_process(false)
	var originals: Array = lv.guards.duplicate()
	var source: Dictionary = originals[0]
	var witness: Dictionary = originals[1]
	var far: Dictionary = originals[2]
	var fourth: Dictionary = originals[3]
	var suspect: AudioStream = sfx.streams.get("suspect")
	check(suspect is AudioStreamMP3 and suspect.resource_path.ends_with("/suspect2.mp3"), "selected suspect2 recording is loaded")
	var origin: Vector2 = load("res://tests/v65_test_fixtures.gd").open_arena(lv)
	lv.guards.clear()
	lv.guards.append(source)
	lv.guards.append(witness)
	lv.guards.append(far)

	# First light contact changes only the spotter until a real shot is fired.
	reset_guard(source, origin, lv.GState.PATROL)
	reset_guard(witness, origin + Vector2(0, 200), lv.GState.PATROL, 0.0)
	reset_guard(far, origin + Vector2(0, 550), lv.GState.PATROL, 0.0)
	source.face = 0.0
	lv.player_pos = origin + Vector2(180, 0)
	lv.bullets.clear()
	stop_audio(sfx)
	lv._update_guards(1.0 / 60.0)
	check(source.state == lv.GState.ALERT and witness.state == lv.GState.PATROL and far.state == lv.GState.PATROL, "light contact alerts only the spotting guard")
	check(lv.bullets.is_empty() and source.pos.distance_to(origin) > 1.0, "spotter physically pursues before the first shot")
	check(playing(sfx, suspect), "first light contact plays the user's suspect2 sound")
	for frame in range(20):
		lv._update_guards(1.0 / 60.0)
	check(lv.bullets.is_empty() and witness.state == lv.GState.PATROL and far.state == lv.GState.PATROL, "other guards remain calm before the first shot")
	# If a second guard personally sees the player during the same episode,
	# it can pursue too, but the suspect sound must not be replayed.
	stop_audio(sfx)
	witness.face = (lv.player_pos - witness.pos).angle()
	lv._update_guards(1.0 / 60.0)
	check(witness.state == lv.GState.ALERT and not playing(sfx, suspect), "another flashlight during an existing alarm does not replay suspect2")

	# A shot from one spotter informs both near and distant connected witnesses.
	reset_guard(source, origin, lv.GState.PATROL)
	reset_guard(witness, origin + Vector2(0, 200), lv.GState.PATROL, 0.0)
	reset_guard(far, origin + Vector2(0, 550), lv.GState.PATROL, 0.0)
	source.face = 0.0
	lv.player_pos = origin + Vector2(180, 0)
	lv.bullets.clear()
	stop_audio(sfx)
	lv._update_guards(1.0 / 60.0)
	stop_audio(sfx)
	for frame in range(34):
		lv._update_guards(1.0 / 60.0)
	check(not lv.bullets.is_empty(), "spotter fires after its short reaction delay")
	check(witness.state == lv.GState.ALERT and far.state == lv.GState.ALERT, "gunfire alerts all guards in the same connected area, including distant ones")
	check(witness.last_seen.distance_to(lv.player_pos) < 0.01 and far.last_seen.distance_to(lv.player_pos) < 0.01, "gunfire reports the live player location")
	check(not playing(sfx, suspect), "gunfire and informed guards do not replay suspect2")

	# All kills, even stealth backstabs, alert nearby but not distant guards.
	lv.guards.clear()
	lv.guards.append(source)
	lv.guards.append(witness)
	lv.guards.append(fourth)
	lv.guards.append(far)
	reset_guard(source, origin, lv.GState.PATROL, 0.0)
	reset_guard(witness, origin + Vector2(0, 160), lv.GState.PATROL, 0.0)
	reset_guard(fourth, origin + Vector2(0, 300), lv.GState.PATROL, 0.0)
	reset_guard(far, origin + Vector2(0, 550), lv.GState.PATROL, 0.0)
	source.face = 0.0
	source.elite = false
	source.diamond_carrier = false
	lv.player_pos = origin + Vector2(-40, 0)
	lv.attack_cd = 0.0
	stop_audio(sfx)
	lv._auto_attack()
	check(not source.alive, "real rear melee performs the takedown")
	check(witness.state == lv.GState.ALERT and fourth.state == lv.GState.ALERT, "nearby guards immediately chase after even a stealth takedown")
	check(far.state == lv.GState.PATROL, "distant guard is not alerted by a kill alone")
	check(witness.last_seen.distance_to(lv.player_pos) < 0.01 and not playing(sfx, suspect), "kill witnesses pursue the player without triggering suspect2")

	# Once nobody can see or hear a new shot, finite alert becomes search then patrol.
	lv.guards.clear()
	lv.guards.append(source)
	lv.guards.append(witness)
	load("res://tests/v65_test_fixtures.gd").open_arena(lv)
	reset_guard(source, origin, lv.GState.ALERT, 0.0)
	reset_guard(witness, origin + Vector2(160, 0), lv.GState.ALERT, 0.0)
	source.chase_left = lv._chase_duration(source)
	witness.chase_left = lv._chase_duration(witness)
	lv.player_pos = origin + Vector2(0, 1000)
	lv.bullets.clear()
	stop_audio(sfx)
	for frame in range(60):
		lv._update_guards(1.0 / 60.0)
	check(source.state == lv.GState.ALERT and source.chase_left < lv._chase_duration(source) - 0.9, "alert memory counts down when player is out of sight")
	for frame in range(660):
		lv._update_guards(1.0 / 60.0)
	check(source.state != lv.GState.ALERT and witness.state != lv.GState.ALERT, "guards stop permanent pursuit after losing sight")
	for frame in range(240):
		lv._update_guards(1.0 / 60.0)
	check(source.state == lv.GState.PATROL and witness.state == lv.GState.PATROL and not lv._any_guard_alerted(), "search finishes and both guards return to patrol")
	check(lv.bullets.is_empty() and not playing(sfx, suspect), "unseen player triggers neither gunfire nor suspect audio")

	# Real narrow-lane blockage: the moving guard must back up safely instead of
	# waiting/glitching forever behind a stationary teammate.
	lv.guards.clear()
	lv.guards.append(source)
	lv.guards.append(witness)
	load("res://tests/v65_test_fixtures.gd").open_arena(lv)
	var left_wall := Rect2(origin + Vector2(-100, -300), Vector2(64, 900))
	var right_wall := Rect2(origin + Vector2(36, -300), Vector2(64, 900))
	lv.blocking_rects.append(left_wall)
	lv.blocking_rects.append(right_wall)
	lv.guard_blocking_rects.append(left_wall.grow(lv.GUARD_WALL_MARGIN))
	lv.guard_blocking_rects.append(right_wall.grow(lv.GUARD_WALL_MARGIN))
	lv._build_grid()
	lv._build_walkable_regions()
	reset_guard(source, origin, lv.GState.ALERT)
	reset_guard(witness, origin + Vector2(0, 80), lv.GState.ALERT, 0.0)
	lv.player_pos = origin + Vector2(0, 400)
	source.last_seen = lv.player_pos
	witness.last_seen = lv.player_pos
	source.chase_left = 9.0
	witness.chase_left = 9.0
	var travel := 0.0
	var bad_moves := 0
	var min_gap := INF
	for frame in range(200):
		var before: Vector2 = source.pos
		lv._update_guards(1.0 / 60.0)
		travel += before.distance_to(source.pos)
		if not lv._guard_line_clear(before, source.pos):
			bad_moves += 1
		min_gap = minf(min_gap, source.pos.distance_to(witness.pos))
	print("RECOVERY probe origin=",origin," pos=",source.pos," witness=",witness.pos," moves=",travel," recover_count=",source.recover_count," state=",source.state," stuck=",source.stuck_time," region=",lv.guard_region_by_cell.get(lv._to_cell(source.pos),-1))
	check(source.recover_count > 0 and travel > 80.0 and source.pos.distance_to(origin) > 40.0, "stuck guard uses physical recovery instead of freezing in a lane")
	check(bad_moves == 0 and min_gap >= lv.GUARD_GAP - 0.06, "recovery never crosses walls or overlaps the blocking guard")

	# Full-map spread: same level geometry and counts; starts remain reachable,
	# safely distant from the player and substantially farther apart on average.
	var catalog: Node2D = load("res://scripts/game/level.gd").new()
	var old_nearest_sum := 0.0
	var new_nearest_sum := 0.0
	var guard_total := 0
	var paired_guards := 0
	var bad_levels := []
	for number in range(1, 101):
		catalog.wall_rects.clear()
		catalog.crate_rects.clear()
		catalog._load_level(number)
		catalog._build_grid()
		catalog._build_walkable_regions()
		var points: PackedVector2Array = catalog._distributed_guard_starts()
		var previous: Array[Vector2] = []
		for authored in catalog.data.guards:
			previous.append(catalog._cell_center(authored.x, authored.y))
		for i in range(points.size()):
			var nearest := INF
			var old_nearest := INF
			for j in range(points.size()):
				if i != j:
					nearest = minf(nearest, points[i].distance_to(points[j]))
					old_nearest = minf(old_nearest, previous[i].distance_to(previous[j]))
			if nearest < 160.0 or points[i].distance_to(catalog.player_pos) < 280.0 or catalog._guard_solid(points[i]) or not catalog.guard_region_by_cell.has(catalog._to_cell(points[i])):
				bad_levels.append(number)
			if points.size() > 1:
				new_nearest_sum += nearest
				old_nearest_sum += old_nearest
				paired_guards += 1
			guard_total += 1
	check(bad_levels.is_empty() and guard_total == 1066, "all 100 levels retain every guard with safe, reachable, separated starts")
	# Source-derived starts are pre-separated in the catalog, so runtime now
	# intentionally preserves them rather than redistributing a second time.
	check(new_nearest_sum >= old_nearest_sum * 0.999 and new_nearest_sum >= 160.0 * paired_guards, "adapted guard starts remain safely distributed without drifting from supplied hints")
	print("DISTRIBUTION total=", guard_total, " old_mean=", old_nearest_sum / maxi(1, paired_guards), " new_mean=", new_nearest_sum / maxi(1, paired_guards), " invalid=", bad_levels.size())
	catalog.free()
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(FileAccess.get_file_as_bytes("res://data/levels/levels.json"))
	check(hash.finish().hex_encode() != "027ff49eb2a8880231b7de7530d89d56150c2c9ac92e7fafc4a9a17a02bf273a", "the user-requested new layouts replace the v0.6.5 catalog")
	check(is_equal_approx(lv.ENEMY_DAMAGE_MULTIPLIER, 1.25) and is_equal_approx(lv.BULLET_DAMAGE, 125.0), "enemy bullet damage and fallback are increased by exactly 25 percent")

	# Home labels and both icons/amounts are aligned along the same actual row.
	gs.cash = 123456789
	gs.gems = 987654321
	change_scene_to_file("res://scenes/home/home.tscn")
	await process_frame
	await process_frame
	var home = current_scene
	var controls: Array[Control] = []
	for node_name in ["DiamondsIcon", "DiamondsCaption", "GemsValue", "DiamondsButton", "CashIcon", "CashCaption", "CashValue", "CashButton"]:
		var node := home.find_child(node_name, true, false) as Control
		if node != null:
			controls.append(node)
	check(controls.size() == 8, "diamond and cash icons, captions, values and buttons exist")
	var same_row := controls.size() == 8
	if same_row:
		var y := controls[0].get_global_rect().get_center().y
		for node in controls:
			if absf(node.get_global_rect().get_center().y - y) > 0.6:
				same_row = false
	check(same_row, "both home resource groups share one horizontal centerline")
	check(home.find_child("DiamondsCaption", true, false).text == "DIAMOND" and home.find_child("CashCaption", true, false).text == "CASH", "diamond and cash captions are visible")
	var amounts_fit := true
	for label in [home.cash_label, home.gems_label]:
		var font: Font = label.get_theme_font("font")
		var size: int = label.get_theme_font_size("font_size")
		if font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > label.size.x - 2.0:
			amounts_fit = false
	check(amounts_fit and home.cash_label.text == "123456789" and home.gems_label.text == "987654321", "large real balances remain complete and fit their allotted space")
	stop_audio(sfx)
	print("V67 BEHAVIOR %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
