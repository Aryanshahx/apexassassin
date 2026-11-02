extends SceneTree
## The supplied designs replace visible art, without erasing old entitlements,
## selected legacy statistics, knives, currencies, level progress or stars.
var checks := 0
var failures := 0
func _init() -> void: call_deferred("_run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)
func write_save(gs: Node, data: Dictionary) -> void:
	var f := FileAccess.open(gs.SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
func _run() -> void:
	var gs = root.get_node("GameState")
	gs.sound_enabled = false
	gs.haptics_enabled = false
	var fixture := {"schema": 4, "gems": 733, "cash": 512, "current_level": 34,
		"unlocked_level": 40, "selected_assassin": "fiesta",
		"unlocked_assassins": {"ronin": true, "fiesta": true, "nova": true, "prior_unknown": true},
		"selected_knife": "frost", "unlocked_knives": {"standard": true, "frost": true},
		"sound_enabled": false, "upgrades": {"speed": 2, "health": 1, "damage": 1}, "best_stars": {"12": 3}}
	write_save(gs,fixture)
	gs.load_game()
	check(gs.CHARACTER_ORDER == ["v72_commando","v72_agent","v72_mercenary","v72_swat","v72_hunter","v72_elite"], "exactly the six supplied designs are visible in their supplied order")
	check(gs.selected_assassin == "fiesta" and gs.is_unlocked("fiesta") and gs.is_unlocked("nova"), "selected legacy ID and purchased legacy unlocks remain")
	check(gs.visible_character_id("fiesta") == "v72_swat" and gs.display_character_name("fiesta") == "SWAT", "old selection is presented using a supplied design")
	check(is_equal_approx(gs.player_speed(), (190.0 * 1.40 + 28.0) * 1.20) and is_equal_approx(gs.max_health(), 1100.0), "selected legacy bonuses and upgrades are unchanged")
	check(gs.cash == 512 and gs.gems == 733 and gs.unlocked_level == 40 and gs.best_stars["12"] == 3, "currency, progress and stars remain")
	check(gs.selected_knife == "frost" and gs.is_knife_unlocked("frost"), "selected knife and unlock remain")
	check(not gs.is_unlocked(gs.VAULT_CHARACTER) and not gs.select_character(gs.VAULT_CHARACTER) and not gs.unlock_character(gs.VAULT_CHARACTER), "Elite is a locker-only reward, not free or purchasable")
	gs.save_game()
	var reread: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(gs.SAVE_PATH))
	check(bool(reread.unlocked_assassins.get("prior_unknown",false)), "unknown historical entitlement fields survive a save")

	fixture.selected_assassin = "vault_phantom"
	fixture.unlocked_assassins["vault_phantom"] = true
	write_save(gs,fixture)
	gs.load_game()
	check(gs.selected_assassin == "vault_phantom" and gs.is_unlocked("vault_phantom") and gs.is_unlocked(gs.VAULT_CHARACTER), "previously won Vault Phantom grants Elite, while retaining its original selected ID")
	check(gs.visible_character_id("vault_phantom") == "v72_elite" and gs.character_portrait_path("vault_phantom").ends_with("/players/elite.png"), "legacy locker entitlement renders as Elite")
	check(is_equal_approx(gs.player_speed(), (190.0 * 1.15 + 28.0) * 1.20) and is_equal_approx(gs.max_health(), 1250.0), "old special bonus remains unchanged")

	var rig_script = load("res://scripts/game/v72_sprite_rig.gd")
	for id in gs.CHARACTER_ORDER:
		var rig = rig_script.new()
		rig.setup(id,"player")
		root.add_child(rig)
		check(rig.art.texture != null and rig.art.texture.resource_path == gs.character_portrait_path(id), id + " uses its real extracted still")
		check(is_equal_approx(rig.art.rotation, PI), id + " downward source pose is oriented to face up in gameplay")
		for knife in gs.KNIFE_ORDER:
			rig.set_knife(knife)
			check(rig.knife_sprite.texture != null and rig.knife_sprite.texture.resource_path.ends_with("/knives/%s.png" % knife), id + " displays equipped knife " + knife)
		rig.set_moving(true)
		rig.anim.advance(0.13)
		rig.anim.advance(0.03)
		check(rig._current == "run" and absf(rig.body.rotation) > 0.005, id + " uses a gentle whole-still run animation")
		rig.play_anim("attack",true)
		rig.anim.advance(0.08)
		check(absf(rig.blade.rotation) > 0.2, id + " animates the actual knife attack")
		rig.anim.advance(0.4)
		check(rig._current == "run", id + " returns to running after the attack")
		root.remove_child(rig)
		rig.free()
	var looks := {"guard":"guard","scout":"soldier","heavy":"heavy","ranger":"sniper","captain":"officer","breacher":"shield"}
	for variant in looks:
		var rig = rig_script.new()
		rig.setup(variant,"guard")
		root.add_child(rig)
		check(rig.look == looks[variant] and rig.art.texture.resource_path.ends_with("/enemies/%s.png" % looks[variant]), variant + " displays the intended supplied appearance")
		check(is_equal_approx(rig.art.rotation,PI) and rig.muzzle != null, variant + " faces the gameplay direction and retains the shooting flash")
		rig.play_anim("shoot",true)
		rig.anim.advance(0.05)
		check(rig.muzzle.modulate.a > 0.5, variant + " shoots with a visible flash")
		root.remove_child(rig)
		rig.free()

	change_scene_to_file("res://scenes/home/home.tscn")
	await process_frame
	await process_frame
	var home = current_scene
	check(home.card_art.texture.resource_path.ends_with("/players/elite.png") and home.selected_name_label.text == "ELITE", "home presents a selected legacy special as Elite")
	home.find_child("AssassinButton",true,false).pressed.emit()
	await process_frame
	var selector = home.overlay
	check(selector != null and selector.roster.get_child_count() == 6 and selector.preview_id == "v72_elite", "selector opens on the equivalent new design with only six cards")
	selector._preview("v72_swat")
	var saved_options: Array[String] = gs.character_loadouts("v72_swat")
	check(saved_options.has("fiesta"), "purchased Fiesta bonus remains a selectable SWAT loadout")
	for i in range(saved_options.size()):
		if selector.preview_loadout == "fiesta": break
		selector._cycle_loadout()
	check(selector.preview_loadout == "fiesta" and selector.speed_value.text == "+40%", "saved legacy bonuses can be browsed on the supplied design")
	selector._confirm()
	check(gs.selected_assassin == "fiesta" and home.card_art.texture.resource_path.ends_with("/players/swat.png"), "a saved legacy loadout can actually be re-equipped")
	check(is_equal_approx(gs.player_speed(), (190.0 * 1.40 + 28.0) * 1.20), "re-equipping the legacy loadout restores its exact original bonus")
	selector._preview("v72_hunter")
	selector._confirm()
	check(gs.selected_assassin == "v72_hunter" and home.card_art.texture.resource_path.ends_with("/players/hunter.png"), "selecting a supplied appearance changes the actual character")
	print("V72 ROSTER %d checks, %d failures" % [checks,failures])
	current_scene.queue_free()
	await process_frame
	quit(1 if failures else 0)
