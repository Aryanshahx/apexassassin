extends SceneTree
## Run with isolated synthetic XDG data. No player's saves or audio are changed.
const Choice := preload("res://scripts/game/ten_character_selection.gd")
const Player := preload("res://scripts/game/ten_character_player.gd")
const Fixture := preload("res://tests/v65_test_fixtures.gd")
var checks := 0
var failures := 0

func _init() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)

func _run() -> void:
	var gs = root.get_node("GameState")
	gs.sound_enabled = false
	gs.haptics_enabled = false
	var Level = load("res://scripts/game/level.gd")
	var layouts := {}
	var grouped_patches := 0
	var full_tiles := 0
	for n in range(1, 101):
		var map = Level.new()
		map._load_level(n)
		map._build_grid()
		map._build_walkable_regions()
		var blockers: Array = map.blocking_rects.duplicate()
		map._build_grass()
		var region: int = int(map.region_by_cell.get(map._to_cell(map.player_pos), -1))
		check(map.grass_groups.size() == 3, "level %d has three connected grass groups" % n)
		check(not map.in_grass(map.player_pos), "level %d spawn is not suddenly concealed" % n)
		var group_tile_total := 0
		for group: Dictionary in map.grass_groups:
			grouped_patches += 1
			layouts[group.layout] = int(layouts.get(group.layout, 0)) + 1
			var tiles: Array = group.tiles
			var cells: Array = group.cells
			group_tile_total += tiles.size()
			check(tiles.size() >= 3 and tiles.size() == cells.size(), "level %d group contains at least three complete tiles" % n)
			var tile_ok := true
			var navigable_guard_tile := false
			for i in range(tiles.size()):
				var tile: Rect2 = tiles[i]
				var cell: Vector2i = cells[i]
				full_tiles += 1
				if tile.size != Vector2.ONE * map.GRASS_TILE or not map.in_grass(tile.get_center()) or int(map.region_by_cell.get(map._to_cell(tile.get_center()), -2)) != region:
					tile_ok = false
				for obstacle: Rect2 in blockers:
					if obstacle.intersects(tile, true): tile_ok = false
				var nav_cell: Vector2i = map._to_cell(tile.get_center())
				if map.guard_grid.is_in_boundsv(nav_cell) and not map.guard_grid.is_point_solid(nav_cell):
					navigable_guard_tile = true
			check(tile_ok, "level %d group has whole uncut reachable tiles clear of cover" % n)
			check(navigable_guard_tile, "level %d grass group offers a guard-traversable tile" % n)
			var visited := {}
			var queue: Array[Vector2i] = [cells[0]]
			visited[cells[0]] = true
			while not queue.is_empty():
				var current: Vector2i = queue.pop_front()
				for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var neighbour: Vector2i = current + direction
					if cells.has(neighbour) and not visited.has(neighbour):
						visited[neighbour] = true
						queue.append(neighbour)
			check(visited.size() == cells.size(), "level %d grass group is physically connected" % n)
		check(group_tile_total == map.grass_rects.size(), "level %d has no standalone grass tiles" % n)
		check(map.blocking_rects == blockers, "level %d grass never changes collision" % n)
		var first: Array = map.grass_rects.duplicate()
		map._build_grass()
		check(first == map.grass_rects, "level %d grass is repeatable" % n)
		map.free()
	check(layouts.size() >= 3, "connected grass uses a variety of complete-tile layouts")
	check(is_equal_approx(Level.GRASS_TILE * 2.0, 64.0), "four complete grass tiles form a 64-unit crate-sized block")
	check(float(full_tiles) * Level.GRASS_TILE * Level.GRASS_TILE > 3000.0 * 32.0 * 32.0 * 1.35, "connected grass keeps substantial coverage across all levels")
	print("GROUPED GRASS: ", grouped_patches, " groups, ", full_tiles, " complete tiles in 100 levels; layouts ", layouts)

	gs.selected_assassin = "ronin"
	gs.selected_knife = "standard"
	gs.upgrades = {"speed": 0, "health": 0, "damage": 0}
	gs.start_level(100)
	await process_frame
	await process_frame
	var lv = current_scene
	lv.set_physics_process(false)
	var by_type := {}
	for guard: Dictionary in lv.guards:
		if not by_type.has(guard.variant): by_type[guard.variant] = guard
	check(by_type.size() == 12, "all twelve real enemy types spawn at level 100")
	if by_type.size() != 12:
		quit(1)
		return
	var origin: Vector2 = Fixture.open_arena(lv)
	var g: Dictionary = by_type.guard
	lv.guards.clear()
	lv.guards.append(g)
	g.pos = origin
	g.face = 0.0
	g.speed = 0.0
	g.vision = 300.0
	g.state = lv.GState.PATROL
	g.alive = true
	g.sees_player = false
	g.touching_player = false
	g.shot_lock = 0.0
	g.shoot = 0.0
	g.wait = 100.0
	g.path.clear()
	g.shots_fired = 0
	lv.grass_rects.clear()
	lv.grass_rects.append(Rect2(origin - Vector2(90, 90), Vector2(360, 200)))
	lv.player_pos = origin + Vector2(160, 0)
	lv.bullets.clear()
	for i in range(10): lv._update_guards(0.1)
	check(lv.in_grass(lv.player_pos) and not g.sees_player and g.state == lv.GState.PATROL, "flashlight and vision cannot spot a hidden player")
	check(lv.bullets.is_empty() and not lv._fire(g), "direct fire cannot target a concealed non-contact player")
	g.state = lv.GState.ALERT
	g.chase_left = 3.0
	g.last_seen = origin + Vector2(65, 65)
	var last_known: Vector2 = g.last_seen
	lv.player_pos = origin + Vector2(180, 0)
	lv._update_guards(0.1)
	check(not g.sees_player and g.last_seen.is_equal_approx(last_known), "already-alerted guard cannot live-track hidden motion")

	# Collision works regardless of facing, and starts a real shot immediately.
	g.state = lv.GState.PATROL
	g.sees_player = false
	g.touching_player = false
	g.shot_lock = 0.0
	g.shoot = 99.0
	g.face = PI
	g.shots_fired = 0
	var touch_radius: float = lv.PLAYER_HIT_RADIUS + lv.GUARD_TOUCH_RADIUS * absf(g.rig.scale.x)
	lv.player_pos = origin + Vector2(touch_radius - 1.0, 0)
	lv.bullets.clear()
	check(lv._guard_touches_player(g), "actual body footprints overlap without a wall")
	lv._update_guards(0.016)
	check(g.sees_player and g.state == lv.GState.ALERT and g.shots_fired == 1 and lv.bullets.size() == 1, "body touch in grass immediately fires once even outside the cone")
	lv._update_stealth_hud()
	check(lv.status_label.text == "SPOTTED!", "HUD does not claim hidden during actual contact")
	lv.player_hp = 2000.0
	lv.invuln = 0.0
	var damage: float = float(g.shot_damage)
	lv._update_bullets(0.05)
	check(is_equal_approx(lv.player_hp, 2000.0 - damage), "contact uses the real projectile and health damage path")
	for i in range(4): lv._update_guards(0.02)
	check(g.shots_fired == 1, "holding contact respects the enemy shot interval")
	lv.player_pos = origin + Vector2(touch_radius + 5.0, 0)
	lv._update_guards(0.02)
	check(not g.sees_player and lv.in_grass(lv.player_pos), "leaving body contact restores grass concealment")
	lv.player_pos = origin + Vector2(touch_radius - 1.0, 0)
	lv._update_guards(0.02)
	check(g.shots_fired == 1, "separating and retouching cannot bypass shot cooldown")
	lv._update_guards(float(g.shot_interval) + 0.05)
	check(g.shots_fired == 2, "continued contact fires again when the cooldown expires")

	# A thin wall between overlapping footprints prevents false body contact.
	g.state = lv.GState.PATROL
	g.sees_player = false
	g.touching_player = false
	g.shot_lock = 0.0
	g.shoot = 0.0
	g.wait = 100.0
	g.face = 0.0
	lv.player_pos = origin + Vector2(20, 0)
	lv.blocking_rects.append(Rect2(origin + Vector2(9, -12), Vector2(2, 24)))
	lv.bullets.clear()
	check(not lv._guard_touches_player(g) and not lv._fire(g), "wall blocks contact and direct shots even at overlapping radii")
	lv._update_guards(0.016)
	check(g.state == lv.GState.PATROL and not g.sees_player and lv.bullets.is_empty(), "no contact alert or shot through a wall")
	lv.blocking_rects.clear()
	# A projectile already in flight is not deleted just because grass hides us.
	lv.player_pos = origin + Vector2(160, 0)
	lv.player_hp = 2000.0
	lv.invuln = 0.0
	lv.bullets.append({"pos": lv.player_pos + Vector2(-20, 0), "vel": Vector2(420, 0), "life": 1.0, "damage": 50.0})
	lv._update_bullets(0.05)
	check(is_equal_approx(lv.player_hp, 1950.0), "in-flight projectile can still hit a hidden player")

	# Every look and equipped weapon one-hits each of the real twelve variants,
	# including arbitrarily high HP and a head-on, already-alerted opponent.
	lv.grass_rects.clear()
	lv.blocking_rects.clear()
	lv.player_pos = origin
	var original_rig: Node2D = lv.player_rig
	var combinations := 0
	for look in Choice.LOOKS:
		var rig := Player.new()
		lv.add_child(rig)
		rig.setup(look, "player")
		lv.player_rig = rig
		lv.active_look = look
		for weapon in Choice.WEAPONS:
			rig.set_knife(weapon)
			for kind in ["guard", "soldier", "officer", "heavy", "swat", "sniper", "medic", "engineer", "bomber", "shield", "mutant", "boss"]:
				g = by_type[kind]
				lv.guards.clear()
				lv.guards.append(g)
				g.pos = origin + Vector2(40, 0)
				g.face = PI
				g.state = lv.GState.ALERT
				g.hp = 9999
				g.alive = true
				g.rig.visible = true
				lv.attack_cd = 0.0
				var before: int = lv.kills
				lv._auto_attack()
				check(not g.alive and g.hp == 0 and lv.kills == before + 1, "%s/%s one-hits high-HP %s from the front" % [look, weapon, kind])
				combinations += 1
		rig.queue_free()
	lv.player_rig = original_rig
	g = by_type.guard
	lv.guards.clear(); lv.guards.append(g)
	g.pos = origin + Vector2(40, 0)
	g.face = 0.0
	g.state = lv.GState.PATROL
	g.hp = 9999
	g.alive = true
	g.rig.visible = true
	g.elite = false
	lv.attack_cd = 0.0
	var old_backstabs: int = lv.backstabs
	var old_money: int = lv.money_collected
	lv._auto_attack()
	check(not g.alive and lv.backstabs == old_backstabs + 1 and lv.money_collected == old_money + lv.MONEY_STANDARD + lv.MONEY_SILENT_BONUS, "backstab still awards its existing silent bonus")
	g.alive = true
	g.hp = 9999
	g.pos = origin + Vector2(40, 0)
	lv.attack_cd = 0.0
	lv.blocking_rects.append(Rect2(origin + Vector2(18, -10), Vector2(4, 20)))
	lv._auto_attack()
	check(g.alive, "one-hit melee still cannot attack through a wall")
	lv.blocking_rects.clear()
	g.pos = origin + Vector2(gs.attack_range() + 10.0, 0)
	lv._auto_attack()
	check(g.alive, "one-hit melee still respects attack range")
	print("GRASS CONTACT AND ONE-HIT: ", checks, " checks; ", failures, " failures; ", combinations, " look/weapon/enemy combinations")
	current_scene = null
	lv.queue_free()
	await process_frame
	by_type.clear()
	g = {}
	quit(1 if failures else 0)
