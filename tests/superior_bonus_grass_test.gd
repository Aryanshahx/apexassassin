extends SceneTree
## All tests use disposable XDG data. In CI, MP3 checks use the actual approved files.
const Choice := preload("res://scripts/game/ten_character_selection.gd")
const Rig := preload("res://scripts/game/ten_character_player.gd")
var checks := 0
var failures := 0

func _init() -> void: call_deferred("_run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)

func _run() -> void:
	var sandbox := OS.get_environment("APEX_REDSCARF_TEST_ROOT").simplify_path()
	var userdir := OS.get_user_data_dir().simplify_path()
	if sandbox in ["", "/"] or not userdir.begins_with(sandbox + "/"):
		printerr("Refusing to test on non-disposable user data")
		quit(1); return
	var gs = root.get_node("GameState")
	var sfx = root.get_node("Sfx")
	var old := {"schema": 4, "cash": 500, "gems": 1000, "current_level": 10, "unlocked_level": 10,
		"total_kills": 133, "flawless_count": 3, "mission1_claimed": true, "mission2_claimed": false,
		"mission3_claimed": true, "mission_claims": {"kills_100": true, "levels_25": true, "future": true},
		"selected_assassin": "ronin", "unlocked_assassins": {"ronin": true},
		"selected_knife": "standard", "unlocked_knives": {"standard": true},
		"upgrades": {"speed": 1, "health": 2, "damage": 1}, "best_stars": {"1": 3},
		"sound_enabled": true, "haptics_enabled": false, "keys_collected": 1}
	var file := FileAccess.open(gs.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(old)); file.close()
	gs.load_game()
	check(gs.cash == 500 and gs.gems == 1000 and gs.keys_collected == 1 and gs.mission1_claimed, "old progress and money load")
	check(bool(gs.mission_claims.get("kills_100")) and bool(gs.mission_claims.get("levels_25")) and bool(gs.mission_claims.get("future")), "removed and unknown mission claim records are preserved")
	check(gs.MISSION_MILESTONES.size() == 2 and gs.MISSION_MILESTONES[0].id == "levels_10" and gs.MISSION_MILESTONES[1].id == "stars_10", "only the two requested extra milestones remain")
	check(Choice.LOOKS.size() == 10 and Choice.SUPERIOR_LOOKS.size() == 10, "original ten and ten Superior characters are separate")
	var expected := [
		["crimson_blade",1.10,1.0], ["frost_tech",1.0,1.10], ["gold_knight",1.15,1.0], ["yellow_goggles",1.0,1.15],
		["green_ghillie",1.20,1.0], ["blue_swat",1.0,1.20], ["purple_reaper",1.25,1.0], ["red_samurai",1.0,1.25],
		["neon_cyber",1.30,1.0], ["warrior_monk",1.0,1.30],
	]
	check(not Choice.save_selection("crimson_blade", "aurora"), "a locked Superior cannot be equipped")
	check(not gs.buy_superior("crimson_blade", 0) and gs.gems == 1000, "forged cost cannot buy a character")
	root.size = Vector2i(360,640)
	var home = load("res://scenes/home/home.tscn").instantiate()
	root.add_child(home); current_scene = home
	await process_frame; await process_frame
	home._open_assassins("superior")
	await process_frame; await process_frame
	var grid = home.find_child("SuperiorCharacterGrid", true, false)
	check(grid != null and grid.get_child_count() == 10 and home.find_child("SuperiorCategoryButton", true, false) != null, "Superior tab shows all ten")
	check(home.find_child("LookCard_crimson_blade", true, false).find_child("SuperiorLock", true, false) != null, "unowned Superior has a lock")
	home._on_look_pressed("crimson_blade")
	await process_frame
	var confirm = home.find_child("SuperiorPurchaseConfirmation", true, false)
	check(confirm != null and gs.gems == 1000 and not gs.is_superior_unlocked("crimson_blade"), "purchase requires confirmation before spending")
	if confirm:
		confirm.emit_signal("confirmed")
		await process_frame; await process_frame
	check(gs.gems == 980 and gs.is_superior_unlocked("crimson_blade") and Choice.read_selection().look == "crimson_blade", "confirmed purchase spends exactly 20 and equips")
	check(not gs.buy_superior("crimson_blade", 20) and gs.gems == 980, "an owned character cannot be charged twice")
	for row in expected:
		var id := String(row[0])
		check(is_equal_approx(Choice.speed_multiplier(id), float(row[1])) and is_equal_approx(Choice.health_multiplier(id), float(row[2])), id + " has the precise pictured bonus")
		if not gs.is_superior_unlocked(id):
			check(gs.buy_superior(id, int(Choice.SUPERIOR_COSTS[id])), id + " purchases with listed diamonds")
		check(Choice.save_selection(id, "aurora") and Choice.read_selection().look == id, id + " saves and reloads selection")
		var actor := Rig.new(); root.add_child(actor); actor.setup(id, "player"); actor.set_process(false)
		check(actor.current_look == id and actor.knife_shoulder != null and actor.free_shoulder != null and actor.ankle_a != null and actor.ankle_b != null, id + " has animated shoulders and both ankles")
		actor.set_moving(true); actor._process(1.0 / 12.0)
		check(actor.knife_shoulder.rotation * actor.free_shoulder.rotation < 0.0, id + " swings shoulders in opposite directions")
		for weapon in Choice.WEAPONS:
			actor.set_knife(weapon)
			check(actor.weapon_art.texture != null and actor.weapon_art.get_parent() == actor.wrist, id + " supports " + String(weapon))
		actor.free()
	gs.save_game(); gs.superior_unlocks = {}; gs.mission_claims = {}; gs.load_game()
	check(gs.superior_unlocks.size() == 10 and bool(gs.mission_claims.get("kills_100")) and bool(gs.mission_claims.get("future")), "unlocks and hidden mission claims survive reload")
	check(gs.upgrades.health == 2 and gs.keys_collected == 1 and gs.total_kills == 133, "purchasing does not reset upgrades, keys or kills")
	home._close_overlay(); home.queue_free(); await process_frame

	# Every milestone schedules one bonus stage after its normal win. Reloading
	# the save retains the queue and completing never advances normal levels.
	gs.pending_bonus_level = 0; gs.completed_bonus_levels = {}; gs.active_bonus_level = 0
	for n in range(10, 101, 10):
		gs.current_level = n; gs.unlocked_level = n
		gs.complete_level(2, false, 2)
		check(gs.pending_bonus_level == n and gs.current_level == mini(n + 1, 100), "level %d queues its bonus after normal progress" % n)
		var next: int = gs.current_level
		if n == 10:
			gs.load_game()
			check(gs.pending_bonus_level == 10 and gs.current_level == 11, "queued bonus survives save and restart")
			gs.start_level(11)
			await process_frame; await process_frame
			var lv = current_scene
			lv.set_physics_process(false)
			check(lv.is_bonus_level and lv.bonus_milestone == 10 and lv.data.id == 5, "actual extra level uses a different arena from the milestone")
			var health: float = lv.player_hp
			lv.invuln = 0.0
			check(not lv._damage_player(100000.0) and lv.player_hp == health and not lv.finished, "bonus enemies cannot damage the player")
			lv._detonate_projectile({"ability":"bomber", "damage":100000.0}, lv.player_pos)
			lv.poison_ticks = 1; lv.poison_timer = 0.0; lv.poison_damage = 100000.0; lv._update_player_status(1.0)
			check(lv.player_hp == health and lv.damage_taken == 0, "blast and poison cannot damage bonus player")
			check(lv.bonus_badge != null and not lv.key_on_floor, "bonus is identified and does not duplicate normal key")
		var cash: int = gs.cash; var gems: int = gs.gems
		check(gs.complete_bonus_level(n, 2), "bonus %d completes" % n)
		check(gs.current_level == next and gs.pending_bonus_level == 0 and gs.cash == cash + 100 + n * 5 and gs.gems == gems + 10, "bonus %d pays once without changing normal level" % n)
		check(not gs.complete_bonus_level(n, 2), "bonus %d cannot pay twice" % n)
		gs.current_level = n; gs.complete_level(0, false, 1)
		check(gs.pending_bonus_level == 0, "replaying milestone %d does not requeue its paid bonus" % n)
	gs.pending_bonus_level = 0; gs.start_level(1)
	await process_frame; await process_frame
	var lv = current_scene; lv.set_physics_process(false)
	check(not lv.is_bonus_level, "normal play is not invincible")
	lv.invuln = 0; var hp: float = lv.player_hp
	check(lv._damage_player(10.0) and lv.player_hp == hp - 10.0, "normal enemies still damage the player")
	check(sfx.streams.get("grass") is AudioStreamMP3 and sfx.streams.grass.data == FileAccess.get_file_as_bytes("res://assets/audio/grass.mp3") and sfx.streams.grass.get_length() > 0.0, "grass uses the exact, playable supplied MP3 bytes")
	check(load("res://scripts/game/background_music.gd").GAME_MUSIC.ends_with("gameplay3.mp3"), "gameplay music selects gameplay3.mp3")
	lv.blocking_rects.clear(); lv.grass_rects.clear()
	var origin: Vector2 = lv.player_pos + Vector2(200, 0)
	for y in range(2):
		for x in range(2): lv.grass_rects.append(Rect2(origin + Vector2(x,y) * lv.GRASS_TILE, Vector2.ONE * lv.GRASS_TILE))
	check(lv.GRASS_TILE == 32.0 and lv.in_grass(origin + Vector2(32,32)) and lv.in_grass(origin + Vector2(31.99,32)), "four grass tiles make a seamless crate-sized square")
	for player in sfx.players: player.stop()
	gs.sound_enabled = true; sfx.enabled = true
	lv.map_grass.ripples.clear(); lv.map_grass.since_last = 1.0
	lv._grass_boundary_events(origin + Vector2(-10,20), origin + Vector2(74,20))
	var playing_grass := 0
	for player in sfx.players:
		if player.playing and player.stream == sfx.streams.grass: playing_grass += 1
	check(playing_grass >= 2 and not lv.map_grass.ripples.is_empty(), "crossing the patch plays grass sound on entry and exit and triggers bounce")
	lv.map_grass._process(0.1)
	check(float(lv.map_grass.ripples[0].age) > 0.0, "grass spring animates")
	gs.key_levels_claimed = {}; gs.locker_board = {}
	var key_level := 0
	for n in range(1,101):
		if gs.key_available(n): key_level = n; break
	lv.data = lv.data.duplicate(true); lv.data.id = key_level
	lv.key_on_floor = true; lv.key_magnet_active = false; lv.key_position = lv.player_pos + Vector2(90,0)
	var dist: float = lv.key_position.distance_to(lv.player_pos)
	lv._magnetize_key(0.1)
	check(lv.key_magnet_active and lv.key_position.distance_to(lv.player_pos) < dist, "nearby key visibly attracts toward player")
	lv._magnetize_key(0.5)
	check(not lv.key_on_floor and gs.key_levels_claimed.has(str(key_level)), "magnetic key collects and saves once")
	gs.key_levels_claimed = {}; lv.key_on_floor = true; lv.key_magnet_active = false; lv.key_position = lv.player_pos + Vector2(90,0)
	lv.blocking_rects.append(Rect2(lv.player_pos + Vector2(40,-20), Vector2(8,40)))
	var blocked: Vector2 = lv.key_position
	lv._magnetize_key(0.5)
	check(lv.key_on_floor and lv.key_position == blocked, "magnet cannot pull a key through cover")
	print("SUPERIOR BONUS GRASS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
