extends SceneTree
## Uses only a declared, disposable user-data root. Exercises the new roster,
## gallery patch sizes, actual touch input and an interrupted saved board.
const Choice := preload("res://scripts/game/ten_character_selection.gd")
const Rig := preload("res://scripts/game/ten_character_player.gd")
const Meta := preload("res://scripts/game/ten_character_art_meta.gd")
var checks := 0
var failures := 0
func _init() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)
func point(control: Control) -> Vector2:
	return root.get_stretch_transform() * control.get_global_rect().get_center()
func tap(at: Vector2) -> void:
	var down := InputEventScreenTouch.new()
	down.index = 0; down.pressed = true; down.position = at
	Input.parse_input_event(down); await process_frame
	var up := InputEventScreenTouch.new()
	up.index = 0; up.pressed = false; up.position = at
	Input.parse_input_event(up); await process_frame; await process_frame
func swipe(at: Vector2, delta: Vector2) -> void:
	var down := InputEventScreenTouch.new()
	down.index = 0; down.pressed = true; down.position = at
	Input.parse_input_event(down); await process_frame
	for i in range(1, 7):
		var drag := InputEventScreenDrag.new()
		drag.index = 0; drag.position = at + delta * float(i) / 6.0
		drag.relative = delta / 6.0
		Input.parse_input_event(drag); await process_frame
	var up := InputEventScreenTouch.new()
	up.index = 0; up.pressed = false; up.position = at + delta
	Input.parse_input_event(up); await process_frame; await process_frame

func _run() -> void:
	var sandbox := OS.get_environment("APEX_REDSCARF_TEST_ROOT").simplify_path()
	if sandbox in ["", "/"] or not OS.get_user_data_dir().simplify_path().begins_with(sandbox + "/"):
		printerr("Refusing test outside its disposable user-data root")
		quit(1); return
	var gs = root.get_node("GameState")
	gs.sound_enabled = false; gs.haptics_enabled = false
	gs.superior_unlocks = {}
	for id in Choice.SUPERIOR_LOOKS: gs.superior_unlocks[id] = true
	gs.gems = 987; gs.cash = 654; gs.current_level = 37; gs.unlocked_level = 37
	gs.keys_collected = 1; gs.mission2_claimed = false; gs.locker_board = {}
	gs.upgrades = {"speed":2,"health":3,"damage":1}
	gs.save_game()
	var ids := ["crimson_blade","frost_tech","gold_knight","yellow_goggles","green_ghillie","blue_swat","purple_reaper","red_samurai","neon_cyber","warrior_monk"]
	var labels := ["Mummy","Flame Fighter","Hazmat","Blue Brute","Neon Robot","Purple Assassin","Hooded Clown","Jester","Zombie","Golden Fighter"]
	var costs := [20,20,30,30,40,40,50,50,60,60]
	check(Choice.SUPERIOR_LOOKS == ids, "the original ten save-slot IDs retain their original order")
	for i in range(10):
		var id: String = ids[i]
		check(Choice.LOOK_LABELS[id] == labels[i], id + " has the new visible name")
		check(int(Choice.SUPERIOR_COSTS[id]) == costs[i], id + " keeps its original diamond price")
		var amount := 1.0 + (10.0 + float(int(i / 2)) * 5.0) / 100.0
		check(is_equal_approx(Choice.speed_multiplier(id), amount if i % 2 == 0 else 1.0) and is_equal_approx(Choice.health_multiplier(id), amount if i % 2 == 1 else 1.0), id + " keeps its exact slot bonus")
		check(gs.is_superior_unlocked(id) and Choice.save_selection(id,"dracula") and Choice.read_selection().look == id, id + " keeps its saved entitlement and selection")
		var tex := Choice.portrait(id)
		check(tex != null and tex.resource_path == "res://assets/characters/superior-roster-v2/%s.webp" % id, id + " loads the replacement supplied art")
		var actor := Rig.new(); root.add_child(actor); actor.setup(id, "player"); actor.set_process(false)
		var body := actor.visual.get_node("ReferenceBody") as Sprite2D
		var hand := actor.wrist.get_node("HandArt") as Sprite2D
		check(body.texture != null and hand.texture != null and actor.weapon_art.get_parent() == actor.wrist and actor.weapon_art.get_index() < hand.get_index(), id + " uses supplied art layers drawn over its independent weapon")
		for weapon in Choice.WEAPONS:
			actor.set_knife(weapon)
			var data: Array = Meta.WEAPON_GRIP[weapon]
			var grip := Vector2(float(data[0]), float(data[1]))
			var local: Vector2 = hand.to_local(actor.weapon_art.to_global(grip))
			var image := hand.texture.get_image()
			var pixel := Vector2i(roundi(local.x), roundi(local.y))
			check(Rect2i(Vector2i.ZERO,image.get_size()).has_point(pixel) and image.get_pixelv(pixel).a > 0.5, id + "/" + weapon + " grip lands inside an opaque fist pixel")
		actor.set_moving(true); actor._process(1.0 / 12.0)
		check(actor.leg_a.visible and actor.leg_b.visible and absf(actor.knife_shoulder.rotation) > 0.01, id + " retains running legs and shoulder motion")
		actor.play_anim("attack", true); actor._process(0.075)
		check(absf(actor.wrist.rotation) > 0.01, id + " independently animates the equipped weapon")
		actor.set_moving(false); check(not actor.leg_a.visible and not actor.leg_b.visible, id + " hides the moving legs at rest")
		actor.free()
	gs.load_game()
	check(gs.superior_unlocks.size() == 10 and Choice.read_selection() == {"look":"warrior_monk","weapon":"dracula"}, "old slot unlocks, final selection and weapon survive reload")
	check(gs.gems == 987 and gs.cash == 654 and gs.current_level == 37 and gs.keys_collected == 1 and gs.upgrades.health == 3, "roster replacement never resets money, level, keys or upgrades")

	# Every group is a filled, complete 2x2 or 3x3 tile square.
	var Level = load("res://scripts/game/level.gd")
	var group_total := 0; var tile_total := 0
	for n in range(1,101):
		var lv = Level.new(); lv._load_level(n); lv._build_grid(); lv._build_walkable_regions(); lv._build_grass()
		check(lv.grass_groups.size() >= 2 and lv.grass_groups.size() <= 3, "level %d has two or three patches" % n)
		for g: Dictionary in lv.grass_groups:
			group_total += 1; tile_total += g.tiles.size()
			var bounds: Rect2 = g.bounds
			var x := roundi(bounds.size.x / 32.0); var y := roundi(bounds.size.y / 32.0)
			var valid_shape := x == y and x in [2,3]
			check(valid_shape and g.tiles.size() == x*y and g.tiles.size() in [4,9], "level %d patch is exactly a 2x2 or 3x3 tile square" % n)
			var occupied := {}
			for tile: Rect2 in g.tiles:
				var offset := (tile.position - bounds.position) / 32.0
				occupied[Vector2i(roundi(offset.x),roundi(offset.y))] = true
			check(occupied.size() == x*y, "level %d patch has no gaps or overlapping tiles" % n)
		lv.free()
	print("GALLERY GRASS: ", group_total, " patches; ", tile_total, " tiles; all 100 levels")

	# Both bars are hidden but retain a scroll range, and actual swipes beginning
	# on their buttons still scroll without activating the button.
	root.size = Vector2i(360,640)
	var home = load("res://scenes/home/home.tscn").instantiate()
	root.add_child(home); current_scene = home
	await process_frame; await process_frame
	var mission: ScrollContainer = home.mission_scroll
	check(mission.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_SHOW_NEVER and not mission.get_v_scroll_bar().visible and mission.get_v_scroll_bar().max_value > mission.get_v_scroll_bar().page, "mission scrollbar is invisible but its scroll range remains")
	var claim := home.find_child("Mission2Button",true,false) as Button
	var before_cash: int = gs.cash
	await swipe(point(claim),Vector2(0,-110))
	check(mission.scroll_vertical > 50 and not gs.mission2_claimed and gs.cash == before_cash, "touch swipe over CLAIM scrolls without claiming")
	mission.scroll_vertical = 0; await process_frame
	var mission_wheel := InputEventMouseButton.new()
	mission_wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN; mission_wheel.pressed = true
	mission_wheel.position = mission.get_global_rect().get_center()
	home._input(mission_wheel)
	check(mission.scroll_vertical > 0, "mouse wheel still scrolls the mission list")
	await create_timer(0.32).timeout
	mission.scroll_vertical = 0; await process_frame
	await tap(point(claim))
	check(gs.mission2_claimed and gs.cash == before_cash + 200, "a deliberate tap still claims a mission")
	home._open_assassins("superior"); await process_frame; await process_frame; await process_frame
	var scroll: ScrollContainer = home.collection_scroll
	check(scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_SHOW_NEVER and not scroll.get_v_scroll_bar().visible and scroll.get_v_scroll_bar().max_value > scroll.get_v_scroll_bar().page, "character scrollbar is invisible but its scroll range remains")
	var card := home.find_child("LookCard_crimson_blade",true,false).get_node("PortraitButton") as Button
	var selected := Choice.read_selection(); var before_gems: int = gs.gems
	await swipe(point(card),Vector2(0,-110))
	check(scroll.scroll_vertical > 50 and Choice.read_selection() == selected and gs.gems == before_gems, "touch swipe over a Superior portrait scrolls without buying or selecting")
	# Mouse wheel input must also advance the invisible scrollbar.
	scroll.scroll_vertical = 0; await process_frame
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN; wheel.pressed = true; wheel.position = scroll.get_global_rect().get_center()
	home._input(wheel)
	check(scroll.scroll_vertical > 0, "mouse wheel still scrolls the character list")
	await create_timer(0.32).timeout
	scroll.scroll_vertical = 0; await process_frame
	await tap(point(card))
	check(Choice.read_selection().look == "crimson_blade", "a deliberate touch selects an already unlocked new character")
	home._close_overlay(); home.queue_free(); await process_frame
	check(Choice.save_selection("warrior_monk", "dracula"), "restore the synthetic selected save slot for the locker test")

	# An unfinished legacy Elite board must retain its real rewards after reload.
	gs.locker_board = {"character_slot":8, "amounts":[5,6,7,8,9,10,11,12,13], "opened":[], "eligible":true}
	gs.save_game()
	var Locker = load("res://scripts/ui/locker_rewards.gd")
	var board = Locker.new(); root.add_child(board); await process_frame; await process_frame
	check(board.stage.get_node_or_null("SpecialRewardsReference") == null and board.feature_art.texture.resource_path == "res://assets/actors/v72/players/elite.png", "legacy board uses real controls and shows the actual Elite reward, not a pasted board")
	check(board.buttons.size() == 9 and board.used_key_overlays.size() == 3 and board.remaining.text.begins_with("3"), "nine real crates and three available keys are shown")
	for button in board.buttons:
		check(button.visible and not button.disabled and ScreenUtil.safe_rect(root).encloses(button.get_global_rect()), button.name + " is a usable on-screen button")
	var before: int = gs.gems
	await tap(point(board.buttons[0]))
	check(gs.locker_board.opened.size() == 1 and gs.gems == before + 5 and board.buttons[0].disabled, "actual touch awards and saves the first real locker")
	check(board.used_key_overlays[0].visible and not board.used_key_overlays[1].visible and board.remaining.text.begins_with("2"), "one used key is dimmed and two picks remain")
	board.queue_free(); await process_frame; gs.load_game()
	board = Locker.new(); root.add_child(board); await process_frame; await process_frame
	check(board.buttons[0].disabled and board.buttons[0].get_node_or_null("RevealedPrize") != null and board.remaining.text.begins_with("2"), "a saved revealed prize and remaining keys resume on the designed board")
	await tap(point(board.buttons[8]))
	check(gs.is_unlocked(gs.VAULT_CHARACTER) and gs.locker_board.opened.size() == 2, "the real elite prize remains obtainable")
	await tap(point(board.buttons[1]))
	check(gs.locker_board.opened.size() == 3 and board.done.visible and board.used_key_overlays.all(func(x): return x.visible), "three picks consume all displayed keys and enable continue")
	check(board.buttons.all(func(x): return x.disabled) and gs.open_locker(2).is_empty(), "a fourth reward is impossible")
	for screen in [Vector2i(320,568), Vector2i(400,860), Vector2i(900,500)]:
		root.size = screen; await process_frame; await process_frame
		var safe := ScreenUtil.safe_rect(root)
		check(safe.encloses(board.buttons[0].get_global_rect()) and safe.encloses(board.buttons[8].get_global_rect()) and safe.encloses(board.done.get_global_rect()), "board, crate targets and continue stay in safe viewport " + str(screen))
	board._finish()
	gs.load_game()
	check(not gs.locker_pending() and gs.is_unlocked(gs.VAULT_CHARACTER) and gs.gems == before + 11, "continue preserves the exact saved rewards without another charge")
	check(Choice.read_selection().look == "warrior_monk" and gs.upgrades.health == 3 and gs.current_level == 37, "board changes do not affect the roster selection, upgrades or level")
	print("ROSTER / REWARDS / SCROLL: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
