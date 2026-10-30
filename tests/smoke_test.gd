extends SceneTree
## Headless gameplay + data smoke tests. Run:
## godot --headless --path . --script tests/smoke_test.gd
var failures := 0
var checks := 0

func _init() -> void:
	call_deferred("_run")

func check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		printerr("FAIL: ", msg)

func _run() -> void:
	var gs = root.get_node("GameState")
	gs.sound_enabled = false
	var f := FileAccess.open("res://data/levels/levels.json", FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	var levels: Array = parsed.levels
	check(levels.size() == 100, "100 levels")
	for lv in levels:
		check(lv.guards.size() >= 3, "level %d guards" % lv.id)
		check(lv.spawn.size() == 2, "spawn")
	gs.gems = 100
	gs.cash = 1000
	gs.unlocked_assassins = {"ronin": true}
	gs.selected_assassin = "ronin"
	check(gs.unlock_character("nova"), "unlock nova")
	check(gs.selected_assassin == "nova", "nova selected")
	check(gs.player_speed() > 200, "nova faster")
	check(gs.select_character("ronin"), "select ronin")
	check(gs.buy_upgrade("speed"), "buy speed upgrade")
	gs.start_level(4)
	await process_frame
	await process_frame
	await process_frame
	var level = current_scene
	check(level != null and level.total == 5, "level 4 has 5 guards")
	check(level.player_rig.anim.has_animation("run"), "run animation")
	check(level.player_rig.anim.has_animation("attack"), "attack animation")
	check(level.player_rig.anim.has_animation("death"), "death animation")
	var target: Vector2 = level._cell_center(10, 20)
	level._path_to(target)
	check(level.player_path.size() > 0, "path found")
	level.player_pos = level.guards[0].pos + Vector2(20, 0)
	level.attack_cd = 0.0
	level._auto_attack()
	check(level.kills == 1, "auto blade kill")
	check(level.gems.size() >= 1, "gem dropped")
	level.player_pos = level.gems[0].pos
	level._update_gems(0.1)
	check(level.gems_collected >= 1, "gem collected")
	for i in range(level.guards.size()):
		if level.guards[i].alive:
			level._kill_guard(i)
	level._win()
	check(level.finished, "level finished")
	check(gs.unlocked_level >= 5, "next level unlocked")
	check(gs.best_stars.get("4", 0) >= 1, "stars saved")
	print("SMOKE %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
