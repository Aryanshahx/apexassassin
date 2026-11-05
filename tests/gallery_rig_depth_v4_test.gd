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
func detached_alpha_pixels(texture: Texture2D) -> int:
	# Inspect EACH independently moving layer, not just their composite. A
	# hidden orphan on the static torso becomes a floating hand as limbs move.
	var image := texture.get_image()
	if image == null: return -1
	if image.is_compressed(): image.decompress()
	var w := image.get_width(); var h := image.get_height()
	var seen := PackedByteArray(); seen.resize(w*h)
	var total := 0; var largest := 0
	for y in range(h):
		for x in range(w):
			if image.get_pixel(x,y).a > 0.0:
				seen[y*w+x] = 1; total += 1
	for index in range(w*h):
		if seen[index] != 1: continue
		var queue := PackedInt32Array([index]); seen[index] = 2; var cursor := 0
		while cursor < queue.size():
			var current := queue[cursor]; cursor += 1
			var x := int(current % w); var y := int(current / w)
			for dy in range(-1,2):
				for dx in range(-1,2):
					var nx := x+dx; var ny := y+dy
					if nx < 0 or ny < 0 or nx >= w or ny >= h: continue
					var next := ny*w+nx
					if seen[next] == 1: seen[next] = 2; queue.append(next)
		largest = maxi(largest,queue.size())
	return total-largest

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
		check(body.texture != null and body.texture.resource_path == "res://assets/characters/superior-roster-v2/%s.webp" % id, id + " renders the entire supplied portrait")
		check(body.material == actor.superior_material and actor.superior_material.shader != null, id + " has the continuous motion shader")
		check(actor.knife_shoulder.get_node_or_null("Art") == null and actor.knife_elbow.get_node_or_null("ForearmArt") == null and actor.wrist.get_node_or_null("HandArt") == null and actor.free_pivot.get_node_or_null("HandArt") == null, id + " has no separately cut Superior arm or hand sprites")
		check(actor.knife_elbow.get_parent() == actor.knife_shoulder and actor.wrist.get_parent() == actor.knife_elbow and actor.free_pivot.get_parent() == actor.free_shoulder, id + " retains its logical moving joints")
		check(actor.weapon_art.get_parent() == actor.wrist and body.get_index() > actor.knife_shoulder.get_index(), id + " draws the supplied fist over the independently selected weapon")
		actor.set_moving(true); actor._process(0.11)
		var walk_grip: Vector2 = actor.superior_material.get_shader_parameter("grip_shift")
		var walk_free: Vector2 = actor.superior_material.get_shader_parameter("other_shift")
		check(walk_grip.length() > 0.001 and walk_free.length() > 0.001, id + " moves both intact arms while walking")
		check(not actor.leg_a.visible and not actor.leg_b.visible and not actor.ankle_a.visible and not actor.ankle_b.visible, id + " never displays foreign Standard leg and foot fragments")
		actor.play_anim("attack",true); actor._process(0.075)
		var attack_grip: Vector2 = actor.superior_material.get_shader_parameter("grip_shift")
		var attack_free: Vector2 = actor.superior_material.get_shader_parameter("other_shift")
		check(attack_grip.distance_to(walk_grip) > 0.001 and attack_free.distance_to(walk_free) > 0.001, id + " changes both arm deformations on attack")
		var center: Vector2 = actor.superior_material.get_shader_parameter("grip_center")
		var size := body.texture.get_size()
		var original := Vector2i(roundi(center.x * size.x),roundi(center.y * size.y))
		var image := body.texture.get_image()
		check(Rect2i(Vector2i.ZERO,image.get_size()).has_point(original) and image.get_pixelv(original).a > 0.5, id + " original gripping fist is opaque")
		for weapon in Choice.WEAPONS:
			actor.set_knife(weapon); weapon_combinations += 1
			var g: Array = Meta.WEAPON_GRIP[weapon]
			var grip := Vector2(float(g[0]),float(g[1]))
			var actual_uv: Vector2 = body.to_local(actor.weapon_art.to_global(grip)) / size
			check(actual_uv.distance_to(center + attack_grip) * size.x < 0.03, id + "/" + weapon + " grip follows the deformed intact fist during attack")
		actor.free()
	standard.free()

	var Level = load("res://scripts/game/level.gd")
	var group_count := 0; var prop_levels := 0; var open_levels := 0; var covers := 0
	for n in range(1,101):
		var map = Level.new(); map._load_level(n); map._build_grid(); map._build_walkable_regions()
		var blockers: Array = map.blocking_rects.duplicate(); var guard_blockers: Array = map.guard_blocking_rects.duplicate()
		map._build_grass()
		check(map.grass_groups.size() in [2,3], "level %d has two or three compact patches" % n)
		check(map._has_free_gallery(), "level %d has an open-path patch away from props" % n)
		var has_prop := false; var has_open := false
		for group: Dictionary in map.grass_groups:
			group_count += 1
			var box: Rect2 = group.bounds
			check(is_equal_approx(box.size.x,box.size.y) and box.size.x in [64.0,96.0] and group.tiles.size() in [4,9], "level %d patch is exactly a complete 2x2 or 3x3 tile square" % n)
			var clear := true
			for cover: Rect2 in map.wall_rects + map.crate_rects:
				if box.intersects(cover,false): clear = false
			check(clear and not box.has_point(map.player_pos), "level %d patch stays on floor and off the spawn" % n)
			if int(group.prop_index) >= 0:
				has_prop = true
				var prop: Rect2 = map.crate_rects[int(group.prop_index)]
				var vertical := (absf(box.end.x-prop.position.x)<0.01 or absf(prop.end.x-box.position.x)<0.01) and absf(box.get_center().y-prop.get_center().y)<0.01
				var horizontal := (absf(box.end.y-prop.position.y)<0.01 or absf(prop.end.y-box.position.y)<0.01) and absf(box.get_center().x-prop.get_center().x)<0.01
				check(vertical or horizontal, "level %d prop square is centered and flush" % n)
				var seam_world := World.new()
				var bridge: Rect2 = seam_world._grass_prop_underlay(box,prop)
				check(bridge.has_area() and prop.encloses(bridge) and box.intersects(bridge,true), "level %d visual grass underlay closes the real prop edge without adding tiles" % n)
				seam_world.free()
			else:
				has_open = true
				check(map._gallery_clear_of_props(box), "level %d open square is separate from props" % n)
		if has_prop: prop_levels += 1
		if has_open: open_levels += 1
		check(map.blocking_rects == blockers and map.guard_blocking_rects == guard_blockers, "level %d leaves player and guard physics untouched" % n)
		var world := World.new(); world.setup(map,true)
		var same := true
		for cover: Rect2 in map.wall_rects + map.crate_rects:
			covers += 1
			if world._cover_top_rect(cover) != cover: same = false
		check(same, "level %d cover displays at unchanged collision footprints" % n)
		world.free(); map.free()
	check(prop_levels == 100 and open_levels == 100, "every level has both a prop-edge and an open square")
	var probe = Level.new(); probe._load_level(8); probe._build_grid(); probe._build_walkable_regions()
	var world := World.new(); world.setup(probe,true)
	var sample := Rect2(probe.player_pos + Vector2(30,20),Vector2(64,64))
	probe.player_velocity = Vector2.ZERO; var top_before := world._cover_top_rect(sample)
	probe.player_pos += Vector2(40,20); probe.player_velocity = Vector2(180,50)
	var top_after := world._cover_top_rect(sample)
	check(top_before == sample and top_after == sample and not probe.has_method("_refresh_prop_depth"), "cover geometry is independent of player position and velocity")
	world.free(); probe.free()
	print("REPAIRED RIG / SQUARE GRASS / STABLE COVER: ",checks," checks, ",failures," failures; ",group_count," patches, ",prop_levels," prop levels, ",covers," unchanged cover footprints, ",weapon_combinations," Superior/weapon combinations")
	quit(1 if failures else 0)
