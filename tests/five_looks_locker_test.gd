extends SceneTree
## v0.6.3 save migration, key routes, persistent nine-locker rewards and recovery.
## Run with an isolated XDG_DATA_HOME: this writes several test saves.
const Choice := preload("res://scripts/game/ten_character_selection.gd")
var checks := 0
var failures := 0

func _init() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)

func _write_save(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

func _run() -> void:
	var gs = root.get_node("GameState")
	var fixture := {
		"schema": 4, "gems": 733, "cash": 512, "current_level": 34,
		"unlocked_level": 40, "total_kills": 62, "flawless_count": 3,
		"mission1_claimed": true, "mission2_claimed": false, "mission3_claimed": true,
		"sound_enabled": false, "haptics_enabled": false,
		"upgrades": {"health": 1, "damage": 2, "speed": 1},
		"selected_assassin": "fiesta", "unlocked_assassins": {"ronin": true, "nova": true, "fiesta": true},
		"selected_knife": "frost", "unlocked_knives": {"standard": true, "frost": true},
		"best_stars": {"7": 3, "12": 2}, "last_wheel_day": "2026-10-29",
	}
	_write_save(gs.SAVE_PATH, fixture)
	gs.unlocked_assassins = {"ronin": true}
	gs.unlocked_knives = {"standard": true}
	gs.load_game()
	check(gs.gems == 733 and gs.cash == 512 and gs.current_level == 34 and gs.unlocked_level == 40, "existing v0.6.3 currencies and levels survive")
	check(gs.selected_assassin == "fiesta" and gs.is_unlocked("nova") and gs.is_unlocked("fiesta"), "existing selection and character unlocks survive")
	check(gs.selected_knife == "frost" and gs.is_knife_unlocked("frost") and int(gs.best_stars["7"]) == 3, "existing weapons and stars survive")
	check(gs.total_kills == 62 and gs.flawless_count == 3 and gs.mission1_claimed and gs.mission3_claimed and gs.last_wheel_day == "2026-10-29", "existing stats, missions and wheel survive")
	check(gs.keys_collected == 0 and gs.key_levels_claimed.is_empty() and not gs.locker_pending(), "old save starts with no keys or pending board")
	check(not gs.is_unlocked(gs.VAULT_CHARACTER) and not gs.unlock_character(gs.VAULT_CHARACTER) and not gs.select_character(gs.VAULT_CHARACTER), "secret assassin cannot be bought or selected before a locker win")
	for i in range(1,13):
		check(not gs.CHARACTERS.has("new%02d" % i), "rejected character %d stays removed" % i)

	# Verify real generated key placement and route endpoints on every eligible map.
	var level_script = load("res://scripts/game/level.gd")
	var probe = level_script.new()
	var key_levels: Array[int] = []
	for number in range(1, 101):
		check(gs.level_has_key(number) == gs.level_has_key(number), "key assignment is stable for level %d" % number)
		if not gs.level_has_key(number):
			continue
		key_levels.append(number)
		probe.wall_rects.clear()
		probe.crate_rects.clear()
		probe._load_level(number)
		probe._build_grid()
		probe._build_walkable_regions()
		probe.guards.clear()
		for authored in probe.data.guards:
			probe.guards.append({"pos": probe._cell_center(int(authored.x), int(authored.y))})
		probe._place_level_key()
		var start_cell: Vector2i = probe._to_cell(probe.player_pos)
		var key_cell: Vector2i = probe._to_cell(probe.key_position)
		var clear_guards := true
		for guard in probe.guards:
			if guard.pos.distance_to(probe.key_position) < 150.0:
				clear_guards = false
		check(probe.key_on_floor and not probe._guard_solid(probe.key_position) and clear_guards and probe.key_position.distance_to(probe.player_pos) >= 260.0, "level %d has a clear, separated key" % number)
		check(int(probe.region_by_cell.get(key_cell, -2)) == int(probe.region_by_cell.get(start_cell, -1)), "level %d key is in the player's connected region" % number)
		probe._path_to(probe.key_position)
		var points: PackedVector2Array = probe._route_visual_points()
		var valid := points.size() >= 2 and points[points.size()-1].distance_to(probe.key_position) < 0.1
		for i in range(1, points.size()):
			if not probe._los(points[i-1], points[i]):
				valid = false
		check(valid, "level %d highlighted route actually reaches its key without crossing cover" % number)
	check(key_levels.size() >= 25 and key_levels.size() <= 60, "keys appear in a subset of random-seeded levels")
	check(not gs.level_has_key(0) and not gs.level_has_key(101), "out-of-range levels never contain keys")
	print("KEY LEVELS ", key_levels.size())
	probe.free()

	# Test real movement to three keys, persistent queuing, and post-win reveal.
	if key_levels.size() < 3:
		printerr("Cannot continue without three key levels")
		quit(1)
		return
	for i in range(3):
		var number: int = key_levels[i]
		gs.start_level(number)
		await process_frame
		await process_frame
		var lv = current_scene
		lv.set_physics_process(false)
		check(lv.key_on_floor and lv.key_label.text == "%d/3" % i, "level %d shows a collectible key and correct counter" % number)
		check(not lv.money_panel.visible and not lv.gem_panel.visible and not lv.money_caption.visible and not lv.gem_caption.visible, "in-level currency backgrounds and words are hidden")
		check(lv.money_icon.visible and lv.gem_icon.visible and lv.money_label.text == "512" and lv.gem_label.text == "733", "in-level currency icons and real saved totals stay visible")
		check(lv.key_guide.visible, "key level offers an optional find-key guide")
		lv._guide_to_key()
		var guided: PackedVector2Array = lv._route_visual_points()
		check(guided.size() >= 2 and guided[guided.size()-1].distance_to(lv.key_position) < 0.1, "find-key button highlights the real route to the key")
		for frame in range(1200):
			lv._move_player(1.0 / 60.0)
			lv._collect_key_if_close()
			if not lv.key_on_floor:
				break
		check(not lv.key_on_floor and not gs.key_available(number) and not lv.key_guide.visible, "actual movement collects level %d key only once and hides the guide" % number)
		check(not gs.collect_level_key(number), "level %d cannot award the same key twice" % number)
		gs.load_game()
		if i < 2:
			check(gs.keys_collected == i + 1 and not gs.locker_pending(), "key %d is saved without prematurely opening lockers" % (i + 1))
		else:
			check(gs.keys_collected == 0 and gs.locker_pending(), "third key saves a pending board")
			check(lv.locker_ui == null and not gs.locker_ready() and lv.key_label.text == "3/3", "third pickup queues 3/3 without interrupting the level")
			check(gs.open_locker(0).is_empty(), "a queued board cannot be opened before a win")
			lv._win()
			await process_frame
			await process_frame
			check(gs.locker_ready() and lv.locker_ui != null and lv.locker_ui.buttons.size() == 9, "a genuine level win opens the queued 3x3 board")
			if lv.locker_ui == null:
				quit(1)
				return
			check(lv.locker_ui.remaining.text.contains("3"), "board announces three choices")
			var before_elapsed: float = lv.elapsed
			lv._physics_process(0.5)
			check(is_equal_approx(lv.elapsed, before_elapsed), "gameplay is paused while the board is open")
			var secret: int = int(gs.locker_board.character_slot)
			var first := (secret + 1) % 9
			var amount: int = int(gs.locker_board.amounts[first])
			lv.locker_ui._pick(first)
			check(gs.gems == 733 + amount and gs.locker_board.opened.size() == 1, "a diamond locker saves its exact reward")
			lv.locker_ui._pick(first)
			check(gs.gems == 733 + amount and gs.locker_board.opened.size() == 1, "opening a locker twice cannot duplicate rewards")
			gs.load_game()
			check(gs.gems == 733 + amount and int(gs.locker_board.character_slot) == secret and gs.locker_board.opened.size() == 1, "partial board, secret slot and award survive reload without reroll")
			check(gs.selected_assassin == "fiesta" and gs.cash == 512 + 50 + number * 5 and gs.is_knife_unlocked("frost"), "the win and locker preserve selection, credit earned cash and preserve weapons")

	# A pending board must reappear on the home screen after closing the level.
	change_scene_to_file("res://scenes/home/home.tscn")
	await process_frame
	await process_frame
	await process_frame
	var home = current_scene
	var recovered = home.find_child("LockerRewards", true, false)
	check(recovered != null and recovered.buttons.size() == 9, "home restores an unfinished 3x3 locker board")
	if recovered == null:
		quit(1)
		return
	check(gs.locker_board.opened.size() == 1 and not recovered.done.visible, "recovered board retains first choice and requires two more")
	var original_selected: String = gs.selected_assassin
	var secret: int = int(gs.locker_board.character_slot)
	var target: String = str(gs.locker_board.character_id)
	recovered._pick(secret)
	check(gs.is_superior_unlocked(target) and gs.selected_assassin == original_selected, "winning the saved Superior unlocks it without changing the legacy selection")
	var third := (secret + 2) % 9
	var before: int = gs.gems
	var expected: int = int(gs.locker_board.amounts[third])
	recovered._pick(third)
	check(gs.gems == before + expected and gs.locker_board.opened.size() == 3 and recovered.done.visible, "third unique pick awards diamonds and enables continue")
	check(recovered.buttons.all(func(b): return b.disabled), "all nine lockers are disabled after three openings")
	await process_frame
	var unopened := (secret + 3) % 9
	check(recovered.buttons[unopened].get_node("Caption").text == "LOCKED", "unopened lockers no longer invite a fourth pick")
	check(gs.open_locker((secret + 3) % 9).is_empty(), "a fourth opening is rejected")
	gs.load_game()
	check(gs.is_superior_unlocked(target) and gs.locker_board.opened.size() == 3 and gs.gems == before + expected, "three picks and secret unlock persist before continue")
	recovered._finish()
	check(not gs.locker_pending() and gs.key_levels_claimed.is_empty(), "continue completes the board and permits another key cycle")
	check(gs.key_available(key_levels[0]), "previous key levels can be replayed for a new board")
	gs.load_game()
	check(not gs.locker_pending() and gs.is_superior_unlocked(target) and gs.selected_assassin == original_selected and gs.gems == before + expected, "finished board and all rewards remain saved")
	check(Choice.save_selection(target, "aurora"), "won Superior can be equipped through the actual active selector")
	gs.load_game()
	check(Choice.read_selection().look == target and gs.is_superior_unlocked(target) and gs.selected_assassin == original_selected, "Superior selection survives restart without overwriting the legacy selection")
	home._refresh_card()
	check(home.card_art.rig.current_look == target and home.card_art.rig.moving, "home displays the actually equipped Superior")

	# With every Superior owned, new boards still award diamonds everywhere.
	for id in Choice.SUPERIOR_LOOKS: gs.superior_unlocks[id] = true
	gs._make_locker_board(64001)
	check(int(gs.locker_board.character_slot) == -1 and str(gs.locker_board.character_id).is_empty(), "all-owned boards do not duplicate a character")
	check(not gs.locker_ready() and gs.open_locker(0).is_empty(), "another new board is also gated until a win")
	gs.complete_level(0, false, 1)
	var later: Dictionary = gs.open_locker(0)
	check(String(later.kind) == "diamonds" and int(later.amount) > 0, "later boards award diamonds instead")
	print("V64 LOCKERS %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
