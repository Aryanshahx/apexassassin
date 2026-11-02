extends SceneTree
## Every map retains the previous minimum; old profile logic is unchanged,
## while later levels increase damage, armor and modestly increase fire rate.
var checks := 0
var failures := 0
func _init() -> void: call_deferred("_run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ",message)
func guard_of(lv: Node, variant: String) -> Dictionary:
	for g in lv.guards:
		if g.variant == variant: return g
	return {}
func _run() -> void:
	var gs = root.get_node("GameState")
	gs.sound_enabled = false
	var previous: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/source_maps/v70/v069-level-catalog.json"))
	var actual: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels/levels.json"))
	var total := 0
	for i in range(100):
		var old: Dictionary = previous.levels[i]
		var now: Dictionary = actual.levels[i]
		check(now.id == old.id and now.guards.size() >= old.guards.size(), "level %d retains at least its prior roster" % (i+1))
		check(now.reward_cash == old.reward_cash, "level %d clear reward is unchanged" % (i+1))
		total += now.guards.size()
	check(total == 1066, "all 1066 restored/current guards are present")
	gs.start_level(1)
	await process_frame
	await process_frame
	var lv = current_scene
	lv.set_physics_process(false)
	var early := guard_of(lv,"guard")
	check(not early.is_empty(), "level 1 contains the guard profile")
	var early_damage := float(early.get("shot_damage",0.0))
	var early_interval := float(early.get("shot_interval",0.0))
	var early_hp := int(early.get("hp",0))
	var early_speed := float(early.get("speed",0.0))
	var early_vision := float(early.get("vision",0.0))
	gs.start_level(100)
	await process_frame
	await process_frame
	lv = current_scene
	lv.set_physics_process(false)
	var late := guard_of(lv,"guard")
	check(not late.is_empty(), "level 100 contains the same guard profile")
	check(float(late.shot_damage) > early_damage * 1.5, "later guards do progressively more damage")
	check(float(late.shot_interval) < early_interval and int(late.hp) > early_hp, "later guards fire modestly faster and have the existing progressive armor")
	check(is_equal_approx(float(late.speed),early_speed) and is_equal_approx(float(late.vision),early_vision), "existing patrol speed, vision and AI behavior remain compatible")
	var variants := {"guard":"guard","scout":"soldier","heavy":"heavy","ranger":"sniper","captain":"officer","breacher":"shield"}
	for variant in variants:
		check(String(lv.ActorRigScript.ENEMY_LOOK[variant]) == variants[variant], variant + " uses the correct user-supplied appearance")
	print("V72 PROGRESSION %d checks, %d failures; total guards=%d" % [checks,failures,total])
	quit(1 if failures else 0)
