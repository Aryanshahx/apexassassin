extends SceneTree
## Synthetic data only. HOME and XDG_DATA_HOME must be isolated from launch.
const Choice := preload("res://scripts/game/ten_character_selection.gd")
const Rig := preload("res://scripts/game/ten_character_player.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run_checks")

func check(ok: bool, name: String) -> void:
	checks += 1
	if ok:
		print("PASS ", name)
	else:
		failures += 1
		printerr("FAIL ", name)

func run_checks() -> void:
	var sandbox := OS.get_environment("APEX_FIVE_TEST_ROOT").simplify_path()
	var userdir := OS.get_user_data_dir().simplify_path()
	if sandbox in ["", "/"] or not userdir.begins_with(sandbox + "/"):
		printerr("Refusing test: user data is not inside declared disposable test root")
		quit(1)
		return
	var gs = root.get_node_or_null("GameState")
	var sfx = root.get_node_or_null("Sfx")
	check(gs != null and sfx != null, "original state and audio autoloads present")
	if gs == null or sfx == null:
		quit(1)
		return
	sfx.enabled = false
	var fixture := {
		"schema": 4, "cash": 512, "gems": 733,
		"current_level": 1, "unlocked_level": 40, "total_kills": 42,
		"selected_assassin": "fiesta",
		"unlocked_assassins": {"ronin": true, "fiesta": true, "prior_unknown": true},
		"selected_knife": "frost", "unlocked_knives": {"standard": true, "frost": true},
		"sound_enabled": false, "haptics_enabled": false,
		"upgrades": {"speed": 2, "health": 1, "damage": 1},
		"best_stars": {"12": 3}, "keys_collected": 1, "key_levels_claimed": {"3": true}
	}
	var save := FileAccess.open(gs.SAVE_PATH, FileAccess.WRITE)
	check(save != null, "created synthetic save in isolated user directory")
	if save == null:
		quit(1)
		return
	save.store_string(JSON.stringify(fixture))
	save.close()
	gs.load_game()
	var before := FileAccess.get_file_as_string(gs.SAVE_PATH)
	var speed: float = gs.player_speed()
	var damage: int = gs.player_damage()
	var health: float = gs.max_health()
	var cooldown: float = gs.attack_cooldown()
	check(gs.selected_assassin == "fiesta" and gs.selected_knife == "frost", "legacy chosen stats loaded")
	check(gs.cash == 512 and gs.gems == 733 and gs.keys_collected == 1, "legacy wallet and key progress loaded")
	check(Choice.LOOKS.size() == 10 and Choice.WEAPONS.size() == 5, "exactly ten characters and five melee weapons")
	check(Choice.read_selection() == {"look":"standard","weapon":"aurora"}, "safe cosmetic defaults on first run")
	check(not Choice.save_selection("unknown", "aurora"), "invalid look rejected")
	check(not Choice.save_selection("standard", "unknown"), "invalid weapon rejected")
	check(not FileAccess.file_exists(Choice.SAVE_PATH), "invalid selection did not create a file")
	for look in Choice.LOOKS:
		check(Choice.portrait(look) != null, "portrait loads: " + look)
		var rig := Rig.new()
		rig.setup(look, "player")
		root.add_child(rig)
		rig.set_process(false)
		check(rig.current_look == look, "rig loads look " + look)
		check(rig.knife_elbow.get_parent() == rig.knife_shoulder and rig.wrist.get_parent() == rig.knife_elbow, "hand follows elbow for " + look)
		check(rig.ankle_a != null and rig.ankle_b != null and rig.free_shoulder != null, "two ankles and free shoulder for " + look)
		for weapon in Choice.WEAPONS:
			check(Choice.save_selection(look, weapon), "persist selection " + look + "/" + weapon)
			var loaded := Choice.read_selection()
			check(loaded.look == look and loaded.weapon == weapon, "reload selection " + look + "/" + weapon)
			rig.set_knife(weapon)
			check(rig.weapon_art.texture != null and rig.weapon_art.texture.resource_path.ends_with("/" + weapon + "-grip.png"), "real selected weapon appears " + look + "/" + weapon)
			check(rig.weapon_art.get_parent() == rig.wrist and rig.weapon_art.get_index() < rig.wrist.get_node("HandArt").get_index(), "weapon behind gripping hand " + look + "/" + weapon)
		rig.set_moving(true)
		rig.play_anim("attack", true)
		rig._process(0.075)
		check(absf(rig.knife_elbow.rotation) > 0.15 and absf(rig.knife_shoulder.rotation) > 0.04, "elbow and shoulder swing " + look)
		check(absf(rig.ankle_flex_a) > 7.0 and absf(rig.ankle_flex_b) > 5.0, "ankles flex in attack " + look)
		rig.queue_free()
	check(FileAccess.get_file_as_string(gs.SAVE_PATH) == before, "all 50 selections leave original save bytes unchanged")
	check(gs.selected_assassin == "fiesta" and gs.selected_knife == "frost" and is_equal_approx(gs.player_speed(), speed) and gs.player_damage() == damage and is_equal_approx(gs.max_health(), health) and is_equal_approx(gs.attack_cooldown(), cooldown), "legacy combat bonuses/stats unchanged by 50 choices")
	check(Choice.save_selection("standard","aurora"), "reset synthetic cosmetic selection")
	var home: Control = load("res://scenes/home/home.tscn").instantiate()
	root.add_child(home)
	current_scene = home
	await process_frame
	home._open_assassins()
	await process_frame
	var look_grid := home.find_child("TenCharacterGrid",true,false)
	check(look_grid != null and look_grid.get_child_count() == 10, "home displays only the ten chosen character cards")
	check(home.find_child("LookCard_shadow",true,false) != null and home.find_child("LookCard_standard",true,false) != null, "character cards include shadow and standard")
	home._on_look_pressed("speed_30")
	await process_frame
	await process_frame
	check(Choice.read_selection().look == "speed_30" and home.selected_name_label.text == "ELECTRIC RUNNER", "selecting look updates home and sidecar")
	home._open_knives()
	await process_frame
	await process_frame
	var weapon_grid := home.find_child("FiveWeaponGrid",true,false)
	check(weapon_grid != null and weapon_grid.get_child_count() == 5, "home displays only the five chosen melee weapon cards")
	check(home.find_child("StatUpgradesButton",true,false) != null, "existing stat upgrades remain available")
	home._on_new_weapon_pressed("thor")
	await process_frame
	await process_frame
	check(Choice.read_selection().weapon == "thor", "selecting weapon updates sidecar")
	check(FileAccess.get_file_as_string(gs.SAVE_PATH) == before, "UI cosmetic choices did not rewrite original save")
	home._close_overlay()
	await process_frame
	home.start_button.pressed.emit()
	await process_frame
	await process_frame
	var level = current_scene
	check(level != null and level.scene_file_path == "res://scenes/level/level.tscn", "start opens original level")
	if level == null or level.scene_file_path != "res://scenes/level/level.tscn":
		quit(1)
		return
	var player = level.player_rig
	check(player.current_look == "speed_30" and player.current_weapon == "thor", "selected look and weapon visible in level")
	check(gs.selected_assassin == "fiesta" and gs.selected_knife == "frost" and is_equal_approx(gs.player_speed(),speed) and gs.player_damage() == damage, "level retains original combat loadout")
	check(is_equal_approx(level._player_speed(), speed * 1.30) and is_equal_approx(level._player_max_health(), health), "selected speed character applies its +30% bonus without changing health")
	check(level.guards.size() > 0, "guards retained")
	if not level.guards.is_empty():
		var guard: Dictionary = level.guards[0]
		guard.pos = level.player_pos + Vector2(6, 0)
		guard.face = PI
		level._fire(guard)
		check(level.bullets.size() == 1, "guard retains gun fire")
		level.bullets.clear()
		guard.hp = 1
		level.attack_cd = 0.0
		var kills: int = level.kills
		level._auto_attack()
		player._process(0.075)
		check(level.kills == kills + 1, "selected weapon performs existing melee kill")
		check(level.bullets.is_empty(), "player melee does not throw or shoot")
		check(absf(player.knife_elbow.rotation) > 0.15 and absf(player.ankle_flex_a) > 7.0, "kill animates elbow and ankle")
	check(gs.keys_collected == 1 and gs.key_levels_claimed.get("3", false), "synthetic key progress retained")
	print("TEN CHARACTER SELECTION: ",checks," checks; ",failures," failures")
	quit(1 if failures else 0)
