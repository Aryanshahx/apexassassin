extends SceneTree
## Spotlight home is rebuilt as live controls, not example values.
## This writes a save; run only with isolated XDG_DATA_HOME.
var checks := 0
var failures := 0
func _init() -> void:
	call_deferred("_run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)
func button(node: Node, name: String) -> BaseButton:
	return node.find_child(name, true, false) as BaseButton
func _run() -> void:
	var gs = root.get_node("GameState")
	gs.sound_enabled = false
	gs.cash = 520
	gs.gems = 733
	gs.current_level = 9
	gs.unlocked_level = 9
	gs.total_kills = 29
	gs.flawless_count = 0
	gs.mission1_claimed = false
	gs.mission2_claimed = false
	gs.mission3_claimed = false
	gs.last_wheel_day = ""
	gs.select_character("ref01")
	gs.save_game()
	change_scene_to_file("res://scenes/home/home.tscn")
	await process_frame
	await process_frame
	var home = current_scene
	check(home.find_child("SelectedHomeConcept", true, false) != null, "approved warehouse background appears")
	check(home.find_child("HomeTitle", true, false).text == "APEX ASSASSIN", "new home title appears")
	check(home.find_child("CharacterSpotlight", true, false) != null, "new golden character spotlight appears")
	check(home.find_child("MissionsPanel", true, false) != null, "missions are grouped in the new layout")
	# Exercise touch targets and safe-area layout at several realistic phone sizes.
	for safe in [Rect2(0, 0, 320, 568), Rect2(0, 0, 360, 640), Rect2(0, 0, 400, 850), Rect2(0, 0, 428, 926), Rect2(14, 24, 360, 740)]:
		home._layout_in_safe_rect(safe)
		var controls: Array[Control] = []
		for name in ["DiamondsButton", "CashButton", "SettingsButton", "AssassinButton", "KnivesButton", "WheelButton", "ShopButton", "MissionsPanel", "StartGameButton"]:
			var n := home.find_child(name, true, false) as Control
			controls.append(n)
			check(safe.grow(0.1).encloses(n.get_global_rect()), "%s within safe area %s" % [name, safe])
		for a in range(controls.size()):
			for b in range(a + 1, controls.size()):
				check(not controls[a].get_global_rect().intersects(controls[b].get_global_rect()), "no overlap: %s / %s at %s" % [controls[a].name, controls[b].name, safe])
	home._fit()
	check(home.cash_label.text == "520" and home.gems_label.text == "733", "currency uses real values, not mockup numbers")
	check(home.card_art.texture.resource_path.ends_with("/characters/01.png"), "chosen assassin portrait is real")
	check(home.selected_name_label.text == "BANDAGED", "only the selected assassin's live name is shown")
	check(home.find_children("SelectedAssassinPortrait", "TextureRect", true, false).size() == 1, "home shows exactly one selected-character portrait")
	check(home.find_child("CurrentLevelLabel", true, false).text == "LEVEL 9", "start button shows current level")
	for name in ["DiamondsButton", "CashButton", "SettingsButton", "WheelButton", "ShopButton", "AssassinButton", "KnivesButton", "StartGameButton"]:
		check(button(home, name) != null, name + " is a real control")
	var m1 := button(home, "Mission1Button")
	var m2 := button(home, "Mission2Button")
	var m3 := button(home, "Mission3Button")
	check(m1 != null and m1.disabled and m2 != null and not m2.disabled and m3 != null and m3.disabled, "mission buttons match incomplete/claimable state")
	check(home.wheel_badge != null, "unclaimed wheel displays badge")
	m2.pressed.emit()
	await process_frame
	await process_frame
	home = current_scene
	check(gs.cash == 720 and gs.mission2_claimed, "mission claim adds exactly 200 cash")
	check(home.cash_label.text == "720" and button(home, "Mission2Button").disabled, "claim refreshes balance and disables button")
	home._claim_mission(2)
	check(gs.cash == 720, "claimed mission cannot pay twice")
	button(home, "SettingsButton").pressed.emit()
	await process_frame
	check(home.overlay != null and home.overlay.find_children("*", "Button", true, false).size() >= 4, "settings opens")
	home._close_overlay()
	await process_frame
	button(home, "DiamondsButton").pressed.emit()
	await process_frame
	check(home.overlay != null, "diamond plus opens help")
	home._close_overlay()
	button(home, "CashButton").pressed.emit()
	await process_frame
	check(home.overlay != null, "cash plus opens help")
	home._close_overlay()
	button(home, "KnivesButton").pressed.emit()
	await process_frame
	check(home.overlay != null and home.overlay.find_children("*", "Button", true, false).size() > 17, "knives collection opens")
	home._close_overlay()
	button(home, "ShopButton").pressed.emit()
	await process_frame
	check(home.overlay != null, "shop opens")
	home._close_overlay()
	button(home, "AssassinButton").pressed.emit()
	await process_frame
	var selector = home.overlay
	check(selector != null and selector.find_child("Roster", true, false).get_child_count() == 22, "assassin selector opens retained roster")
	selector._preview("ref02")
	var select_btn := button(selector, "SelectButton")
	select_btn.pressed.emit()
	await process_frame
	check(gs.selected_assassin == "ref02" and home.card_art.texture.resource_path.ends_with("/characters/02.png"), "selection immediately updates the home portrait")
	check(home.selected_name_label.text == "ORANGE BEAST", "selection immediately updates the home name")
	home._close_overlay()
	button(home, "WheelButton").pressed.emit()
	await process_frame
	var wheel = home.overlay
	check(wheel != null and wheel.spin_btn != null, "wheel opens")
	gs.claim_wheel(0)
	wheel.closed.emit()
	wheel.queue_free()
	await process_frame
	check(home.cash_label.text == str(gs.cash) and home.wheel_badge == null, "closing wheel refreshes resources and badge")
	button(home, "StartGameButton").pressed.emit()
	await process_frame
	await process_frame
	check(current_scene != null and current_scene.has_method("_move_player") and gs.current_level == 9, "start loads the chosen saved level")
	print("HOME %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
