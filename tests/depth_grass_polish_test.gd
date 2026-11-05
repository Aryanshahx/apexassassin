extends SceneTree
## All data paths are temporary under the test harness; never touch real saves.
const Rig := preload("res://scripts/game/ten_character_player.gd")
const Choice := preload("res://scripts/game/ten_character_selection.gd")
const World := preload("res://scripts/game/world_backplate.gd")
const Fixture := preload("res://tests/v65_test_fixtures.gd")
var checks := 0
var failures := 0
func _init() -> void: call_deferred("_run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)

func touching(a: Rect2, b: Rect2) -> bool:
	var vertical := (absf(a.end.x - b.position.x) < 0.001 or absf(b.end.x - a.position.x) < 0.001) and minf(a.end.y,b.end.y) - maxf(a.position.y,b.position.y) > 1.0
	var horizontal := (absf(a.end.y - b.position.y) < 0.001 or absf(b.end.y - a.position.y) < 0.001) and minf(a.end.x,b.end.x) - maxf(a.position.x,b.position.x) > 1.0
	return vertical or horizontal

func main_component_fraction(texture: Texture2D) -> float:
	var im := texture.get_image()
	if im == null: return 0.0
	if im.is_compressed(): im.decompress()
	var scale: float = minf(1.0, 120.0 / maxf(float(im.get_width()), float(im.get_height())))
	im.resize(maxi(1,roundi(im.get_width()*scale)), maxi(1,roundi(im.get_height()*scale)), Image.INTERPOLATE_NEAREST)
	var width := im.get_width(); var height := im.get_height()
	var seen := PackedByteArray(); seen.resize(width*height)
	var total := 0; var largest := 0
	for y in range(height):
		for x in range(width):
			var idx := y*width+x
			if im.get_pixel(x,y).a > 0.16:
				seen[idx] = 1; total += 1
	for y in range(height):
		for x in range(width):
			var idx := y*width+x
			if seen[idx] != 1: continue
			var q := PackedInt32Array([idx]); seen[idx] = 2; var cursor := 0
			while cursor < q.size():
				var pos := q[cursor]; cursor += 1
				var px := int(pos % width); var py := int(pos / width)
				for oy in range(-1,2):
					for ox in range(-1,2):
						var nx := px+ox; var ny := py+oy
						if nx < 0 or ny < 0 or nx >= width or ny >= height: continue
						var next := ny*width+nx
						if seen[next] == 1: seen[next] = 2; q.append(next)
			largest = maxi(largest, q.size())
	return float(largest) / maxf(1.0,float(total))

func guard_can_approach(lv: Node2D, group: Dictionary) -> bool:
	# Sample outer sides for a guard-clear entry and reachable interior tile,
	# using the real enlarged guard collision geometry.
	var b: Rect2 = group.bounds
	for side in range(4):
		var dir: Vector2 = [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT][side]
		for fraction in [0.25,0.5,0.75]:
			var edge := b.get_center()
			match side:
				0: edge = Vector2(lerpf(b.position.x,b.end.x,fraction),b.end.y)
				1: edge = Vector2(lerpf(b.position.x,b.end.x,fraction),b.position.y)
				2: edge = Vector2(b.end.x,lerpf(b.position.y,b.end.y,fraction))
				3: edge = Vector2(b.position.x,lerpf(b.position.y,b.end.y,fraction))
			var start: Vector2 = edge - dir * 18.0
			if lv._guard_solid(start) or lv._guard_solid(edge + dir * 5.0): continue
			if int(lv.guard_region_by_cell.get(lv._to_cell(start),-1)) < 0: continue
			var probe: Vector2 = lv._grass_probe_for_guard({"pos":start},edge+dir*5.0,dir)
			if is_finite(probe.x): return true
	return false

func _run() -> void:
	var Level = load("res://scripts/game/level.gd")
	var gs = root.get_node("GameState")
	var sfx = root.get_node("Sfx")
	gs.haptics_enabled = false; gs.sound_enabled = false
	var shape_counts := {}; var group_count := 0; var tile_count := 0
	for number in range(1,101):
		var m = Level.new(); m._load_level(number); m._build_grid(); m._build_walkable_regions()
		var before: Array = m.blocking_rects.duplicate(); var guard_before: Array = m.guard_blocking_rects.duplicate()
		m._build_grass()
		check(m.grass_groups.size() >= 2 and m.grass_groups.size() <= 3, "level %d has only two or three grass spots" % number)
		for g: Dictionary in m.grass_groups:
			group_count += 1; tile_count += g.tiles.size(); shape_counts[g.layout] = true
			var patch: Rect2 = g.bounds
			if int(g.prop_index) >= 0:
				var prop: Rect2 = m.crate_rects[int(g.prop_index)]
				var centered := (absf(patch.get_center().x-prop.get_center().x)<0.01 or absf(patch.get_center().y-prop.get_center().y)<0.01)
				check(not bool(g.gallery) and touching(patch,prop) and centered, "level %d prop patch is centered and touches without a gap" % number)
			else:
				check(bool(g.gallery) and m._gallery_clear_of_props(patch), "level %d open patch stays away from props" % number)
			var clear := true
			for cover: Rect2 in m.wall_rects + m.crate_rects:
				if patch.intersects(cover,false): clear = false
			check(clear, "level %d grass does not cover any wall or prop" % number)
			check(is_equal_approx(patch.size.x,patch.size.y) and patch.size.x in [64.0,96.0] and g.tiles.size() in [4,9], "level %d uses a compact 2x2 or 3x3 tile square" % number)
			var guard_tile := false
			for tile: Rect2 in g.tiles:
				var cell: Vector2i = m._to_cell(tile.get_center())
				if not m.guard_grid.is_point_solid(cell) and not m._guard_solid(tile.get_center()): guard_tile = true
			check(guard_tile, "level %d has a guard-accessible spot" % number)
			check(guard_can_approach(m,g), "level %d grass has a guard-clear entry and reachable search tile" % number)
		check(m.blocking_rects == before and m.guard_blocking_rects == guard_before, "level %d adds no collision or blockers" % number)
		m.free()
	check(shape_counts.size() == 4 and group_count >= 200 and group_count <= 300, "both square sizes occur in open and prop-edge locations")
	print("WALKABLE GALLERY GRASS: ", group_count, " spots and ",tile_count," tiles across 100 levels")

	var world := World.new()
	for i in range(15): check(world._progressive_prop_name(10,i).is_empty(), "no newly introduced prop before level 11")
	var seen := {}
	for number in [11,26,51,76,100]:
		for i in range(30):
			var kind := world._progressive_prop_name(number,i)
			if not kind.is_empty():
				check(world.NEW_PROPS.has(kind) and world.NEW_PROPS[kind] is Texture2D, "new prop %s loads at level %d" % [kind,number])
				seen[kind] = true
	check(seen.size() == 6, "six new prop varieties appear progressively")
	world.free()

	for id in Choice.ALL_LOOKS:
		var actor := Rig.new(); root.add_child(actor); actor.setup(id,"player"); actor.set_process(false)
		check(not actor.leg_a.visible and not actor.leg_b.visible and not actor.ankle_a.visible and not actor.ankle_b.visible, id + " starts with legs hidden")
		actor.set_moving(true); actor._process(0.11)
		var expected_legs: bool = not Choice.SUPERIOR_LOOKS.has(id)
		check(actor.leg_a.visible == expected_legs and actor.leg_b.visible == expected_legs and actor.ankle_a.visible == expected_legs and actor.ankle_b.visible == expected_legs, id + " uses appropriate moving leg visibility")
		check(not is_zero_approx(actor.knife_shoulder.rotation) and not is_zero_approx(actor.free_shoulder.rotation), id + " still animates both shoulders")
		actor.set_knife("leviathan")
		check(actor.weapon_art.get_parent() == actor.wrist and actor.weapon_art.texture != null, id + " still holds an independent weapon")
		actor.set_moving(false)
		check(not actor.leg_a.visible and not actor.leg_b.visible and not actor.ankle_a.visible and not actor.ankle_b.visible, id + " hides legs again when stopped")
		actor.free()
	for id in Choice.SUPERIOR_LOOKS:
		var path := "res://assets/characters/superior-roster-v2/%s.webp" % id
		var tex := load(path) as Texture2D
		check(tex != null and main_component_fraction(tex) > 0.996, id + " has one clean connected supplied character silhouette")
	for id in ["health_10","health_30"]:
		for part in ["body", "upper", "free_arm"]:
			var path := "res://assets/characters/character-repair/%s/%s.png" % [id,part]
			var tex := load(path) as Texture2D
			check(tex != null and main_component_fraction(tex) > 0.996, id + " has a clean coherent " + part)

	gs.gems = 0; gs.mission2_claimed = false
	var home: Control = load("res://scenes/home/home.tscn").instantiate(); root.add_child(home); await process_frame
	var claim: Button = home.find_child("Mission2Button",true,false)
	check(claim != null and not claim.disabled and claim.get_node_or_null("ClaimButtonShine") != null, "a claimable mission button shines")
	var old_cash: int = gs.cash; home._claim_mission(2)
	check(claim.disabled and claim.get_node_or_null("ClaimButtonShine") == null and gs.cash == old_cash + 200, "shine stops once the reward is claimed exactly once")
	home._claim_mission(2); check(gs.cash == old_cash + 200, "mission cannot be claimed twice")
	home._open_assassins("superior"); await process_frame
	home._on_look_pressed("green_ghillie"); await process_frame
	check(home.find_child("CenteredToast",true,false) == null, "home no longer displays claim or insufficient-diamond transient notices")
	var initial_view := root.size
	for size in [Vector2i(320,568),Vector2i(400,860),Vector2i(900,500)]:
		root.size = size; await process_frame
		home._toast("This old notice is intentionally suppressed")
		check(home.find_child("CenteredToast",true,false) == null, "transient home notices stay suppressed at viewport " + str(size))
	root.size = initial_view; await process_frame
	home.queue_free(); await process_frame

	gs.pending_bonus_level = 0; gs.start_level(6); await process_frame; await process_frame
	var lv = current_scene; lv.set_physics_process(false)
	lv.key_on_floor = true; lv._refresh_wallet(); lv._layout_hud()
	check(lv.key_guide != null and lv.key_guide.text.is_empty(), "gameplay contains no FIND KEY message")
	check(lv.key_guide.visible and lv.key_guide.position == lv.key_icon.position, "existing key icon still offers the optional guide")
	var map_before: Array = lv.blocking_rects.duplicate(); var existing = lv.map_cover
	var probe_rect := Rect2(lv.player_pos + Vector2(30,20), Vector2(64,64))
	lv.player_velocity = Vector2.ZERO; var top_a: Rect2 = existing._cover_top_rect(probe_rect)
	var draws_before: int = existing.draw_count
	lv.player_pos += Vector2(40,20); lv.player_velocity = Vector2(180,50)
	var top_b: Rect2 = existing._cover_top_rect(probe_rect)
	await process_frame
	check(top_a == probe_rect and top_b == top_a and existing.draw_count == draws_before, "cover artwork is static and no longer redraws or shifts with player motion")
	check(lv.blocking_rects == map_before, "fixed shading leaves physics, map geometry and paths untouched")

	# A real authored gallery patch must also be enterable; choose an
	# unobstructed outer approach without moving or removing any cover.
	var real_guard: Dictionary = lv.guards[0]
	lv.guards.clear(); lv.guards.append(real_guard)
	var found_real := false
	for group: Dictionary in lv.grass_groups:
		var box: Rect2 = group.bounds
		var dir := [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT][int(group.side)] as Vector2
		var edge := box.get_center()
		match int(group.side):
			0: edge.y = box.end.y
			1: edge.y = box.position.y
			2: edge.x = box.end.x
			3: edge.x = box.position.x
		var start: Vector2 = edge - dir * 85.0
		var cell: Vector2i = lv._to_cell(start)
		if not lv.guard_grid.is_in_boundsv(cell) or lv.guard_grid.is_point_solid(cell) or lv._guard_solid(start) or not lv._guard_line_clear(start, edge + dir * 3.0):
			continue
		real_guard.pos = start; real_guard.rig.position = start; real_guard.alive = true
		real_guard.state = lv.GState.ALERT; real_guard.last_seen = edge - dir*5.0; real_guard.sees_player = false
		real_guard.speed = 80.0; real_guard.vision = 250.0; real_guard.chase_left = 7.0
		real_guard.path.clear(); real_guard.pi = 0; real_guard.alert_repath = 0.0; real_guard.route_goal = Vector2(INF,INF)
		real_guard.blocked_t = 0.0; real_guard.avoid_time = 0.0; real_guard.yield_partner = -1; real_guard.recover_left = 0.0
		real_guard.progress_anchor = start; real_guard.stuck_time = 0.0
		lv._grass_boundary_events(edge-dir*5.0,edge+dir*8.0)
		var probe: Vector2 = lv._grass_probe_for_guard(real_guard,lv.grass_entry_point,dir)
		if not is_finite(probe.x): continue
		lv.player_pos = box.get_center()
		var entered_real := false
		for tick in range(150):
			lv._update_guards(0.025)
			if lv.in_grass(real_guard.pos): entered_real = true; break
		check(entered_real, "alert guard enters an actual gallery grass spot without crossing cover")
		found_real = true
		break
	check(found_real, "real level provides an accessible gallery guard approach")

	# Search an observed grass entry from all four sides in a collision-free
	# synthetic arena. Concealment still hides the player's live position.
	Fixture.open_arena(lv)
	var guard: Dictionary = lv.guards[0]; lv.guards.clear(); lv.guards.append(guard)
	var patch_origin: Vector2 = lv._cell_center(12,16)
	var patch := Rect2(patch_origin,Vector2(128,128))
	lv.grass_rects.clear(); var tiles: Array[Rect2] = []
	for y in range(4):
		for x in range(4):
			var tile := Rect2(patch.position + Vector2(x,y)*32.0,Vector2(32,32))
			tiles.append(tile); lv.grass_rects.append(tile)
	lv.grass_groups.clear(); lv.grass_groups.append({"bounds":patch,"tiles":tiles})
	var entries := [
		[Vector2(patch.position.x,patch.get_center().y), Vector2.RIGHT],
		[Vector2(patch.end.x,patch.get_center().y), Vector2.LEFT],
		[Vector2(patch.get_center().x,patch.position.y), Vector2.DOWN],
		[Vector2(patch.get_center().x,patch.end.y), Vector2.UP],
	]
	for entry in entries:
		var edge: Vector2 = entry[0]; var direction: Vector2 = entry[1]
		guard.pos = edge - direction*115.0; guard.rig.position = guard.pos; guard.rig.visible = true
		guard.alive = true; guard.state = lv.GState.ALERT; guard.last_seen = edge - direction*5.0
		guard.speed = 80.0; guard.vision = 250.0; guard.chase_left = 7.0; guard.sees_player = false
		guard.path.clear(); guard.pi = 0; guard.alert_repath = 0.0; guard.route_goal = Vector2(INF,INF)
		guard.blocked_t = 0.0; guard.avoid_time = 0.0; guard.yield_partner = -1; guard.recover_left = 0.0
		guard.progress_anchor = guard.pos; guard.stuck_time = 0.0; guard.traffic_stall = 0.0
		lv._grass_boundary_events(edge-direction*6.0,edge+direction*8.0)
		lv.player_pos = edge + direction*110.0
		lv._update_guards(0.025)
		check(bool(guard.get("grass_search",false)) and lv.in_grass(guard.last_seen), "alert guard targets a reachable interior tile from " + str(direction))
		check(not guard.sees_player and guard.last_seen.distance_to(lv.player_pos) > 10.0, "grass search does not live-track the hidden player")
		var entered: bool = lv.in_grass(guard.pos)
		for step in range(160):
			lv._update_guards(0.025)
			if lv.in_grass(guard.pos): entered = true; break
		check(entered, "alert guard can actually walk into grass from " + str(direction))

	# Direct kill: reward and cosmetic effects occur once, without the coin clip.
	for player in sfx.players: player.stop()
	gs.sound_enabled = true; sfx.enabled = true
	guard.alive = true; guard.hp = 1; guard.elite = false; guard.diamond_carrier = true
	var cash: int = gs.cash; var gems: int = gs.gems
	lv.money_collected = 0; lv.gems_collected = 0; lv.loot_particles.clear()
	lv._kill_guard(0,false)
	var coin_playing := false
	for player in sfx.players:
		if player.playing and sfx.streams.has("coin") and player.stream == sfx.streams.coin: coin_playing = true
	check(not coin_playing, "enemy kill plays no money-collection sound")
	check(gs.cash == cash + lv.MONEY_STANDARD and gs.gems == gems + 1 and not lv.loot_particles.is_empty(), "visual loot and single currency credit remain")
	lv._kill_guard(0,false); check(gs.cash == cash + lv.MONEY_STANDARD and gs.gems == gems + 1, "a dead enemy cannot award twice")
	print("DEPTH / GRASS / ANIMATION POLISH: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
