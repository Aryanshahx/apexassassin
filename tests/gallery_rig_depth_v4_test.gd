extends SceneTree
## Runs only with disposable user data. Verifies actual visible layers and
## Standard-equivalent joint rotations, plus all authored walkable galleries.
const Choice := preload("res://scripts/game/ten_character_selection.gd")
const Rig := preload("res://scripts/game/ten_character_player.gd")
const Meta := preload("res://scripts/game/ten_character_art_meta.gd")
const World := preload("res://scripts/game/world_backplate.gd")
var checks := 0
var failures := 0
func _init() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",message)
func rotations(actor: Node2D) -> Array:
	return [actor.knife_shoulder.rotation,actor.knife_elbow.rotation,actor.wrist.rotation,actor.free_shoulder.rotation,actor.free_pivot.rotation]
func same_pose(a: Array, b: Array) -> bool:
	for i in range(a.size()):
		if not is_equal_approx(float(a[i]),float(b[i])): return false
	return true
func _run() -> void:
	var sandbox := OS.get_environment("APEX_REDSCARF_TEST_ROOT").simplify_path()
	if sandbox in ["","/"] or not OS.get_user_data_dir().simplify_path().begins_with(sandbox + "/"):
		printerr("Refusing test outside its disposable user-data root"); quit(1); return
	var gs = root.get_node("GameState")
	gs.sound_enabled = false; gs.haptics_enabled = false
	var standard := Rig.new(); root.add_child(standard); standard.setup("standard","player"); standard.set_process(false)
	standard.set_moving(true); standard._process(0.11)
	var walking := rotations(standard)
	standard.play_anim("attack",true); standard._process(0.075)
	var attacking := rotations(standard)
	check(absf(walking[1]) > 0.001 and absf(attacking[1]) > 0.15, "Standard actually bends its elbow for comparison")
	var weapon_combinations := 0
	for id in Choice.SUPERIOR_LOOKS:
		var actor := Rig.new(); root.add_child(actor); actor.setup(id,"player"); actor.set_process(false)
		var body := actor.visual.get_node("ReferenceBody") as Sprite2D
		var upper := actor.knife_shoulder.get_node("Art") as Sprite2D
		var forearm := actor.knife_elbow.get_node("ForearmArt") as Sprite2D
		var hand := actor.wrist.get_node("HandArt") as Sprite2D
		var other_arm := actor.free_shoulder.get_node("Art") as Sprite2D
		var other_hand := actor.free_pivot.get_node("HandArt") as Sprite2D
		for sprite in [body,upper,forearm,hand,other_arm,other_hand]:
			check(sprite.texture != null and sprite.texture.get_image().get_used_rect().has_area(), id + " has a nonempty visible " + sprite.name + " layer")
		check(actor.knife_elbow.get_parent() == actor.knife_shoulder and actor.wrist.get_parent() == actor.knife_elbow and actor.free_pivot.get_parent() == actor.free_shoulder, id + " has articulated connected shoulders, elbow and both hands")
		var hand_before := hand.to_global(Vector2.ZERO); var other_before := other_hand.to_global(Vector2.ZERO)
		actor.set_moving(true); actor._process(0.11)
		check(same_pose(rotations(actor),walking), id + " matches all five Standard walking-joint rotations")
		check(hand_before.distance_to(hand.to_global(Vector2.ZERO)) > 0.01 and other_before.distance_to(other_hand.to_global(Vector2.ZERO)) > 0.01, id + " actually moves both visible hand sprites while walking")
		actor.play_anim("attack",true); actor._process(0.075)
		check(same_pose(rotations(actor),attacking), id + " matches all five Standard attack-joint rotations")
		check(actor.weapon_art.get_parent() == actor.wrist and actor.weapon_art.get_index() < hand.get_index(), id + " weapon remains behind the articulated fist")
		for weapon in Choice.WEAPONS:
			actor.set_knife(weapon); weapon_combinations += 1
			var g: Array = Meta.WEAPON_GRIP[weapon]
			var grip := Vector2(float(g[0]),float(g[1]))
			var local := hand.to_local(actor.weapon_art.to_global(grip))
			var pixel := Vector2i(roundi(local.x),roundi(local.y))
			var im := hand.texture.get_image()
			check(Rect2i(Vector2i.ZERO,im.get_size()).has_point(pixel) and im.get_pixelv(pixel).a > 0.5, id + "/" + weapon + " grip stays on an opaque moving fist pixel during attack")
		actor.free()
	standard.free()

	var Level = load("res://scripts/game/level.gd")
	var group_count := 0; var square_levels := 0; var extrusions := 0
	for n in range(1,101):
		var map = Level.new(); map._load_level(n); map._build_grid(); map._build_walkable_regions()
		var blockers: Array = map.blocking_rects.duplicate(); var guard_blockers: Array = map.guard_blocking_rects.duplicate()
		map._build_grass()
		check(map.grass_groups.size() in [2,3], "level %d has two or three connected patches" % n)
		check(map._has_free_gallery(), "level %d has a genuinely open-path patch away from props" % n)
		var has_square := false
		for group: Dictionary in map.grass_groups:
			group_count += 1
			var box: Rect2 = group.bounds
			if is_equal_approx(box.size.x,box.size.y): has_square = true
			check(bool(group.get("gallery",false)) and map._gallery_is_corridor(box.get_center()), "level %d patch is in a reachable gallery rather than generated from a prop" % n)
			var clear := true
			for cover: Rect2 in map.wall_rects + map.crate_rects:
				if box.intersects(cover,false): clear = false
			check(clear and not box.has_point(map.player_pos), "level %d patch stays on floor and off the spawn" % n)
		if has_square: square_levels += 1
		if n == 8:
			var expected := [Rect2(map.ORIGIN+Vector2(16.5,35.5)*32.0,Vector2(128,64)),Rect2(map.ORIGIN+Vector2(15.5,45.5)*32.0,Vector2(192,64)),Rect2(map.ORIGIN+Vector2(8.5,50.5)*32.0,Vector2(96,96))]
			for rect: Rect2 in expected:
				var found := false
				for group: Dictionary in map.grass_groups:
					if group.bounds == rect: found = true
				check(found,"level 8 matches a screenshot-marked corridor or square")
		check(map.blocking_rects == blockers and map.guard_blocking_rects == guard_blockers, "level %d leaves player and guard physics untouched" % n)
		var world := World.new(); world.setup(map,true)
		var all_inside := true; var all_have_faces := true
		for cover: Rect2 in map.wall_rects + map.crate_rects:
			var top := world._cover_top_rect(cover); extrusions += 1
			if not cover.encloses(top): all_inside = false
			if cover.end.y - top.end.y < 7.9: all_have_faces = false
		check(all_inside and all_have_faces, "level %d cover has a visible 2.5D face wholly inside every existing footprint" % n)
		world.free(); map.free()
	check(square_levels >= 20, "square grass patches appear in many levels")
	var probe = Level.new(); probe._load_level(8); probe._build_grid(); probe._build_walkable_regions()
	var world := World.new(); world.setup(probe,true)
	var sample := Rect2(probe.player_pos + Vector2(30,20),Vector2(64,64))
	probe.player_velocity = Vector2.ZERO; var top_before := world._cover_top_rect(sample)
	probe.player_pos += Vector2(40,20); probe.player_velocity = Vector2(180,50)
	var top_after := world._cover_top_rect(sample)
	check(top_before.position.distance_to(top_after.position) > 1.0 and absf(top_before.size.y-top_after.size.y) > 0.25, "visible top and front height react to player/camera motion")
	check(sample.encloses(top_before) and sample.encloses(top_after), "moving perspective never changes or exceeds physical cover")
	world.free(); probe.free()
	print("GALLERY / ARTICULATED RIG / DEPTH: ",checks," checks, ",failures," failures; ",group_count," patches, ",square_levels," square levels, ",extrusions," cover faces, ",weapon_combinations," Superior/weapon combinations")
	quit(1 if failures else 0)
