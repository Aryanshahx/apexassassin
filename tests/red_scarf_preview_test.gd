extends SceneTree
## Run ONLY with a new isolated XDG_DATA_HOME and APEX_REDSCARF_TEST_ROOT.
## Uses a synthetic save; it must never be pointed at a player's real user data.
var checks := 0
var failures := 0

func _initialize() -> void:
    call_deferred("run_checks")

func check(value: bool, message: String) -> void:
    checks += 1
    if value:
        print("PASS ", message)
    else:
        failures += 1
        printerr("FAIL: ", message)

func find_button(node: Node, caption: String) -> Button:
    if node is Button and node.text == caption:
        return node
    for child in node.get_children():
        var found := find_button(child, caption)
        if found != null:
            return found
    return null

func run_checks() -> void:
    var sandbox := OS.get_environment("APEX_REDSCARF_TEST_ROOT").simplify_path()
    var data_dir := OS.get_user_data_dir().simplify_path()
    if sandbox == "" or sandbox == "/" or not data_dir.begins_with(sandbox + "/"):
        printerr("Refusing save test: XDG_DATA_HOME is not the declared disposable test directory.")
        quit(1)
        return
    var gs := root.get_node_or_null("GameState")
    var sfx := root.get_node_or_null("Sfx")
    check(gs != null and sfx != null, "original state and audio autoloads are present")
    if gs == null or sfx == null:
        quit(1)
        return
    var fixture := {
        "schema": 4, "cash": 512, "gems": 733,
        "current_level": 1, "unlocked_level": 40,
        "selected_assassin": "fiesta",
        "unlocked_assassins": {"ronin": true, "fiesta": true, "prior_unknown": true},
        "selected_knife": "frost", "unlocked_knives": {"standard": true, "frost": true},
        "sound_enabled": false, "haptics_enabled": false,
        "upgrades": {"speed": 2, "health": 1, "damage": 1},
        "best_stars": {"12": 3}, "keys_collected": 1, "key_levels_claimed": {"3": true}
    }
    var file := FileAccess.open(gs.SAVE_PATH, FileAccess.WRITE)
    check(file != null, "synthetic save created inside isolated test directory")
    if file == null:
        quit(1)
        return
    file.store_string(JSON.stringify(fixture))
    file.close()
    gs.load_game()
    check(gs.cash == 512 and gs.gems == 733 and gs.unlocked_level == 40, "legacy currency and progress load")
    check(gs.selected_assassin == "fiesta" and gs.is_unlocked("fiesta"), "legacy selected ID and entitlement remain")
    check(gs.selected_knife == "frost" and gs.is_knife_unlocked("frost"), "selected melee knife and unlock remain")
    check(gs.keys_collected == 1 and gs.key_levels_claimed.get("3", false), "collected key and key history load")
    check(gs.upgrades.speed == 2 and gs.best_stars.get("12", 0) == 3, "upgrades and stars load")
    var speed: float = gs.player_speed()
    gs.save_game()
    var reread: Variant = JSON.parse_string(FileAccess.get_file_as_string(gs.SAVE_PATH))
    check(reread is Dictionary and reread.get("cash", -1) == 512 and reread.get("gems", -1) == 733, "synthetic save round-trips currency")
    check(reread is Dictionary and reread.get("selected_assassin", "") == "fiesta" and reread.get("selected_knife", "") == "frost", "synthetic save round-trips selected loadout")
    check(reread is Dictionary and reread.get("unlocked_assassins", {}).get("prior_unknown", false), "unknown prior entitlement survives")
    check(reread is Dictionary and reread.get("key_levels_claimed", {}).get("3", false), "synthetic save round-trips key history")
    var home: Control = load("res://scenes/home/home.tscn").instantiate()
    root.add_child(home)
    current_scene = home
    await process_frame
    check(home.start_button != null, "home start button exists")
    check(home.selected_name_label.text == "RED SCARF (TEST)", "home labels the appearance as test art")
    check(home._character_portrait("anything").resource_path == "res://assets/characters/red-scarf-preview/test-v3-reference-home-portrait.png", "home shows the selected reference-derived portrait")
    home._open_assassins()
    await process_frame
    check(home.overlay != null and home.find_child("AssassinSelector", true, false) == null, "old playable roster is not offered")
    home._close_overlay()
    await process_frame
    home.start_button.pressed.emit()
    await process_frame
    await process_frame
    var level = current_scene
    check(level != null and level.scene_file_path == "res://scenes/level/level.tscn", "home opens original level")
    if level == null or level.scene_file_path != "res://scenes/level/level.tscn":
        quit(1)
        return
    check(gs.selected_assassin == "fiesta" and is_equal_approx(gs.player_speed(), speed), "selected legacy bonuses remain unchanged")
    check(level.player_rig != null and level.player_rig.get_script().resource_path == "res://scripts/game/red_scarf_preview.gd", "the red-scarf rig is the only player appearance")
    var rig = level.player_rig
    if rig == null:
        quit(1)
        return
    check(rig.get_node_or_null("ReferenceOnlyVisual/KnifeShoulder/KnifeElbow/KnifeHandPivot/HandArt") != null, "knife and hand follow the elbow")
    check(rig.get_node_or_null("ReferenceOnlyVisual/AnkleA/FootArt") != null and rig.get_node_or_null("ReferenceOnlyVisual/AnkleB/FootArt") != null, "both ankle pivots exist")
    check(level.guards.size() > 0, "guards still spawn")
    if level.guards.is_empty():
        quit(1)
        return
    var guard: Dictionary = level.guards[0]
    guard.pos = level.player_pos + Vector2(6, 0)
    guard.face = PI
    level._fire(guard)
    check(level.bullets.size() == 1, "guard can still fire its gun")
    level.bullets.clear()
    guard.hp = 1
    level.attack_cd = 0.0
    var kills: int = level.kills
    level._auto_attack()
    rig._process(0.075)
    check(level.kills == kills + 1 and absf(rig.knife_elbow.rotation) > 0.15, "real melee kill moves the elbow")
    check(absf(rig.knife_shoulder.rotation) > 0.04 and absf(rig.ankle_flex_a) > 7.0, "shoulder and ankle animate during the kill")
    check(level.bullets.is_empty(), "player melee attack does not throw a projectile")
    level._pause()
    await process_frame
    var back := find_button(level.overlay, "Home")
    check(back != null, "pause menu retains Home")
    if back != null:
        back.pressed.emit()
        await process_frame
        await process_frame
        check(current_scene != null and current_scene.scene_file_path == "res://scenes/home/home.tscn", "Home returns to the original menu")
    check(gs.keys_collected == 1 and gs.key_levels_claimed.get("3", false), "test key data remains after the level transition")
    print("RED SCARF PREVIEW: ", checks, " checks; ", failures, " failures")
    quit(1 if failures else 0)
