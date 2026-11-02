extends SceneTree
## User-visible fairness regression: across all 100 maps, an idle player must
## not be spotted or damaged in the first three seconds. This changes no AI,
## combat, or invulnerability: it exercises the actual Godot patrol and bullets.
func _init() -> void:
    call_deferred("_run")
func _run() -> void:
    var gs = root.get_node("GameState")
    gs.sound_enabled = false
    gs.haptics_enabled = false
    var seed_base := int(OS.get_environment("APEX_SAFETY_SEED")) if OS.has_environment("APEX_SAFETY_SEED") else 70000
    var spotted := []
    var harmed := []
    for number in range(1, 101):
        gs.start_level(number)
        await process_frame
        await process_frame
        var lv = current_scene
        lv.set_physics_process(false)
        lv.rng.seed = seed_base + number
        var hp: float = lv.player_hp
        for guard in lv.guards:
            guard.wait = 0.0
        for frame in range(180):
            lv._update_guards(1.0 / 60.0)
            lv._update_bullets(1.0 / 60.0)
            if lv.was_alerted and not spotted.has(number): spotted.append(number)
            if lv.player_hp < hp and not harmed.has(number): harmed.append(number)
        if number % 25 == 0:
            print("START SAFETY through ", number, ": spotted=", spotted.size(), " damaged=", harmed.size())
    print("V71 START SAFETY 100 levels, seed=" + str(seed_base) + ", 3 idle seconds each: spotted=", spotted, "; damaged=", harmed)
    quit(1 if not spotted.is_empty() or not harmed.is_empty() else 0)
