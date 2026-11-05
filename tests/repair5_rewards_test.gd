extends SceneTree
## The harness supplies disposable XDG paths. Never run against player data.
const Choice := preload("res://scripts/game/ten_character_selection.gd")
var checks := 0
var failures := 0
func _init() -> void: call_deferred("_run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ",message)
func point(control: Control) -> Vector2:
	return root.get_stretch_transform() * control.get_global_rect().get_center()
func tap(control: Control) -> void:
	var down := InputEventScreenTouch.new()
	down.index = 0; down.pressed = true; down.position = point(control)
	Input.parse_input_event(down); await process_frame
	var up := InputEventScreenTouch.new()
	up.index = 0; up.pressed = false; up.position = point(control)
	Input.parse_input_event(up); await process_frame; await process_frame
func file_text(path: String) -> String:
	var f := FileAccess.open(path,FileAccess.READ)
	return f.get_as_text() if f != null else ""
func obstruct_temp(gs: Node) -> String:
	# Only creates an empty directory inside the declared synthetic user root.
	var path: String = ProjectSettings.globalize_path(gs.SAVE_PATH + ".tmp")
	var result := DirAccess.make_dir_absolute(path)
	check(result == OK, "synthetic save-failure obstruction was created")
	return path
func clear_obstruction(path: String) -> void:
	check(DirAccess.remove_absolute(path) == OK, "synthetic obstruction removed")

func _run() -> void:
	var sandbox := OS.get_environment("APEX_REDSCARF_TEST_ROOT").simplify_path()
	var userdir := OS.get_user_data_dir().simplify_path()
	if sandbox in ["","/"] or not userdir.begins_with(sandbox + "/"):
		printerr("Refusing test outside disposable user data"); quit(1); return
	var gs = root.get_node("GameState")
	gs.sound_enabled = false; gs.haptics_enabled = false
	gs.gems = 311; gs.cash = 229; gs.current_level = 27; gs.unlocked_level = 40
	gs.upgrades = {"speed":2,"health":3,"damage":1}
	gs.selected_assassin = "v72_elite"
	gs.unlocked_assassins = {"ronin":true,"v72_elite":true,"vault_phantom":true,"legacy_custom":true}
	gs.superior_unlocks = {"blue_swat":true,"warrior_monk":true}
	gs.keys_collected = 2; gs.key_levels_claimed = {}; gs.locker_board = {}
	check(Choice.save_selection("standard","thor"), "synthetic existing active character and weapon are set")
	check(gs.save_game(), "synthetic pre-existing progress is saved")
	var eligible_key := 0
	for n in range(1,101):
		if gs.level_has_key(n): eligible_key = n; break
	check(eligible_key > 0 and gs.collect_level_key(eligible_key), "third key creates the queued board")
	check(gs.locker_pending() and not gs.locker_ready() and gs.displayed_key_count() == 3, "three keys queue one board until a win")
	var target: String = str(gs.locker_board.get("character_id",""))
	var slot: int = int(gs.locker_board.character_slot)
	var original_board: Dictionary = gs.locker_board.duplicate(true)
	check(Choice.SUPERIOR_LOOKS.has(target) and not gs.is_superior_unlocked(target) and slot >= 0 and slot < 9, "new board preselects a real still-locked Superior and a fixed slot")
	check(gs.open_locker(slot).is_empty(), "queued board cannot bypass its win gate")
	gs.load_game()
	check(gs.locker_board == original_board and str(gs.locker_board.character_id) == target and int(gs.locker_board.character_slot) == slot, "target, slot, amounts and gate survive reload before display")
	check(gs.is_unlocked("v72_elite") and gs.is_unlocked("vault_phantom") and bool(gs.unlocked_assassins.get("legacy_custom",false)) and gs.is_superior_unlocked("blue_swat") and gs.is_superior_unlocked("warrior_monk"), "all earlier Elite, unknown legacy and Superior unlocks survive")
	check(gs.gems == 311 and gs.cash == 229 and gs.current_level == 27 and gs.upgrades.health == 3 and gs.selected_assassin == "v72_elite" and Choice.read_selection() == {"look":"standard","weapon":"thor"}, "currencies, levels, upgrades and both selections survive")
	gs.locker_board.eligible = true
	check(gs.save_game(), "eligible board is saved")

	root.size = Vector2i(360,640)
	var Locker = load("res://scripts/ui/locker_rewards.gd")
	var ui = Locker.new(); root.add_child(ui); await process_frame; await process_frame
	check(ui.stage.get_node_or_null("SpecialRewardsReference") == null and ui.buttons.size() == 9, "screen is made of nine real controls, not a pasted reference board")
	check(ui.feature_art.texture.resource_path == Choice.portrait_path(target) and ui.feature_name.text == str(Choice.LOOK_LABELS[target]).to_upper(), "featured name and supplied portrait match the fixed prize ID")
	check(ui.feature_note.text.contains("one of nine") and ui.remaining.text.begins_with("3"), "screen accurately describes the hidden prize and three picks")
	for button: Button in ui.buttons:
		check(button.visible and not button.disabled and button.get_node_or_null("LockerArtwork") != null and bool(button.get_meta("apex_suppress_ui_tap",false)), "each distinct locker is a usable touch button with individual artwork")
	# All catalogue names and portraits fit the designed hero panel, not just one.
	for id in Choice.SUPERIOR_LOOKS:
		gs.locker_board.character_id = id
		ui._refresh_feature()
		var fs: int = ui.feature_name.get_theme_font_size("font_size")
		var width: float = ui.feature_name.get_theme_font("font").get_string_size(ui.feature_name.text,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x
		check(ui.feature_art.texture.resource_path == Choice.portrait_path(id) and width <= ui.feature_name.size.x, id + " real feature art and name fit")
	gs.locker_board.character_id = target; ui._refresh_feature()
	for size in [Vector2i(320,568),Vector2i(400,860),Vector2i(900,500)]:
		root.size = size; await process_frame; await process_frame
		var safe := ScreenUtil.safe_rect(root)
		var inside := true
		for card: Button in ui.buttons:
			if not safe.encloses(card.get_global_rect()): inside = false
		check(inside and safe.encloses(ui.feature_art.get_global_rect()) and safe.encloses(ui.done.get_global_rect()), "all controls and feature fit the safe viewport " + str(size))
	root.size = Vector2i(360,640); await process_frame; await process_frame
	var diamond := (slot + 1) % 9
	var amount: int = int(gs.locker_board.amounts[diamond])
	await tap(ui.buttons[diamond])
	check(gs.gems == 311 + amount and gs.locker_board.opened.size() == 1 and ui.buttons[diamond].disabled and ui.remaining.text.begins_with("2"), "real touch opens and persists the first diamond locker")
	ui.queue_free(); await process_frame; gs.load_game()
	ui = Locker.new(); root.add_child(ui); await process_frame; await process_frame
	check(ui.buttons[diamond].disabled and ui.buttons[diamond].get_node_or_null("RevealedPrize/Artwork") != null and ui.remaining.text.begins_with("2"), "partial board reopens with the saved diamond and two keys")
	await tap(ui.buttons[slot])
	var awarded: Dictionary = gs.locker_board.opened[1]
	check(gs.is_superior_unlocked(target) and str(awarded.kind) == "character" and str(awarded.character_id) == target, "touch awards the precise Superior ID through the real entitlement")
	check(ui.buttons[slot].get_node("RevealedPrize/Artwork").texture.resource_path == Choice.portrait_path(target) and ui.status.text.contains(str(Choice.LOOK_LABELS[target]).to_upper()), "revealed card shows exactly the awarded character")
	check(Choice.read_selection() == {"look":"standard","weapon":"thor"} and gs.selected_assassin == "v72_elite", "winning never silently changes either equipped selection")
	ui.queue_free(); await process_frame; gs.load_game()
	check(gs.is_superior_unlocked(target) and str(gs.locker_board.opened[1].character_id) == target and gs.gems == 311 + amount, "won Superior ID and diamond balance survive restart")
	check(Choice.save_selection(target,"thor") and Choice.read_selection().look == target, "won Superior can be equipped without buying again")
	ui = Locker.new(); root.add_child(ui); await process_frame; await process_frame
	check(ui.buttons[slot].get_node("RevealedPrize/Artwork").texture.resource_path == Choice.portrait_path(target), "recovered reveal retains the same real portrait")
	var third := (slot + 2) % 9
	var third_amount: int = int(gs.locker_board.amounts[third])
	await tap(ui.buttons[third])
	check(gs.locker_board.opened.size() == 3 and gs.gems == 311 + amount + third_amount and ui.done.visible, "third real touch awards its saved diamonds and enables continue")
	check(ui.buttons.all(func(b):return b.disabled) and gs.open_locker((slot+3)%9).is_empty(), "no fourth pick or double award is possible")
	var before_finish: Dictionary = gs.locker_board.duplicate(true)
	var disk_before_finish := file_text(gs.SAVE_PATH)
	print("EXPECTING a synthetic write error: completed-board rollback")
	var obstruction := obstruct_temp(gs)
	check(not gs.finish_locker_board() and gs.locker_board == before_finish and file_text(gs.SAVE_PATH) == disk_before_finish, "failed save cannot discard a completed-but-unfinished board")
	clear_obstruction(obstruction)
	ui._finish(); await process_frame
	gs.load_game()
	check(not gs.locker_pending() and gs.is_superior_unlocked(target) and Choice.read_selection().look == target and gs.is_unlocked("v72_elite"), "continue saves all rewards and preserves the earlier Elite")

	# Buying the preselected target while the board is queued pays a full-price
	# diamond replacement at its original slot, never a duplicate or lost prize.
	gs.superior_unlocks.erase("green_ghillie")
	gs.gems = 100
	gs.locker_board = {"reward_version":2,"character_id":"green_ghillie","character_slot":4,"amounts":[5,6,7,8,9,10,11,12,13],"opened":[],"eligible":true}
	gs.save_game()
	check(gs.buy_superior("green_ghillie",40) and gs.gems == 60, "preselected target can be bought while a board waits")
	ui = Locker.new(); root.add_child(ui); await process_frame
	check(ui.feature_note.text.contains("Already owned"), "duplicate handling is disclosed before the choice")
	var replacement: Dictionary = gs.open_locker(4)
	check(str(replacement.kind) == "diamonds" and int(replacement.amount) == 40 and str(replacement.replacement_for) == "green_ghillie" and gs.gems == 100, "already-owned target becomes its full diamond price")
	gs.load_game(); ui._refresh()
	check(str(gs.locker_board.opened[0].replacement_for) == "green_ghillie" and ui.buttons[4].get_node("RevealedPrize/Artwork").texture.resource_path == "res://assets/ui/gem.png", "duplicate compensation and its diamond artwork survive reload")
	ui.queue_free(); await process_frame

	# All-owned boards are still legitimate diamond boards, never a phantom hero.
	for id in Choice.SUPERIOR_LOOKS: gs.superior_unlocks[id] = true
	gs._make_locker_board(941); gs.locker_board.eligible = true; gs.save_game(); gs.load_game()
	check(int(gs.locker_board.character_slot) == -1 and str(gs.locker_board.character_id).is_empty(), "all-owned board has no fake character slot")
	ui = Locker.new(); root.add_child(ui); await process_frame
	check(ui.feature_art.texture.resource_path == "res://assets/ui/gem.png" and ui.feature_note.text.contains("Every locker"), "all-owned board visibly and honestly advertises diamonds")
	var all_prize: Dictionary = gs.open_locker(0)
	check(str(all_prize.kind) == "diamonds" and int(all_prize.amount) > 0, "all-owned board pays diamonds normally")
	ui.queue_free(); await process_frame

	# A pre-update partially opened board retains the old Elite prize and does
	# not reroll. Earlier earned Superior and all other legacy unlocks remain.
	gs.unlocked_assassins = {"ronin":true,"legacy_custom":true}
	gs.locker_board = {"character_slot":4,"amounts":[5,6,7,8,9,10,11,12,13],"opened":[{"index":0,"kind":"diamonds","amount":5}],"eligible":true}
	gs.save_game(); gs.load_game()
	check(not gs.locker_board.has("reward_version") and gs.locker_board.opened.size() == 1 and int(gs.locker_board.character_slot) == 4, "unfinished legacy board and paid diamond survive without reroll")
	ui = Locker.new(); root.add_child(ui); await process_frame
	check(ui.feature_art.texture.resource_path == "res://assets/actors/v72/players/elite.png" and ui.feature_name.text == "ELITE", "legacy board previews its real Elite, not a Superior or reference image")
	ui._pick(4)
	check(gs.is_unlocked(gs.VAULT_CHARACTER) and bool(gs.unlocked_assassins.get("legacy_custom",false)) and gs.superior_unlocks.size() == 10, "legacy board awards Elite and preserves all existing Superior and unknown unlocks")
	check(ui.buttons[4].get_node("RevealedPrize/Artwork").texture.resource_path == "res://assets/actors/v72/players/elite.png", "legacy revealed card shows actual Elite art")
	ui.queue_free(); await process_frame; gs.load_game()
	check(gs.is_unlocked(gs.VAULT_CHARACTER) and str(gs.locker_board.opened[1].kind) == "character", "legacy Elite prize and partial board remain saved")

	# Failed persistence cannot reveal/credit a Superior or consume the third key.
	gs.superior_unlocks.erase("purple_reaper")
	gs.locker_board = {"reward_version":2,"character_id":"purple_reaper","character_slot":2,"amounts":[5,6,7,8,9,10,11,12,13],"opened":[],"eligible":true}
	gs.save_game()
	var disk_before := file_text(gs.SAVE_PATH)
	var old_gems: int = gs.gems
	print("EXPECTING a synthetic write error: unrevealed reward rollback")
	obstruction = obstruct_temp(gs)
	check(gs.open_locker(2).is_empty() and not gs.is_superior_unlocked("purple_reaper") and gs.locker_board.opened.is_empty() and gs.gems == old_gems and file_text(gs.SAVE_PATH) == disk_before, "failed save rolls back the reward and leaves its card unopened")
	clear_obstruction(obstruction)
	check(str(gs.open_locker(2).kind) == "character" and gs.is_superior_unlocked("purple_reaper"), "same choice succeeds after persistence recovers")
	gs.locker_board = {}; gs.keys_collected = 2; gs.key_levels_claimed = {}; gs.save_game()
	disk_before = file_text(gs.SAVE_PATH)
	print("EXPECTING a synthetic write error: third-key rollback")
	obstruction = obstruct_temp(gs)
	check(not gs.collect_level_key(eligible_key) and gs.keys_collected == 2 and gs.key_levels_claimed.is_empty() and gs.locker_board.is_empty() and file_text(gs.SAVE_PATH) == disk_before, "failed save leaves the third key available and creates no volatile board")
	clear_obstruction(obstruction)
	check(gs.collect_level_key(eligible_key) and gs.locker_pending(), "third key can be collected after persistence recovers")
	print("REPAIR-5 REWARDS / LEGACY / TOUCH / SAVE FAILURE: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
