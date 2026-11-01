extends SceneTree
## Validate new reference-sheet maps and the original gameplay safety invariants.
var checks := 0
var failures := 0
const THEMES := ["warehouse", "factory", "dockyard", "military", "night", "desert", "snow", "rooftop"]
func _init() -> void:
	call_deferred("_run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)
func _run() -> void:
	var raw := FileAccess.get_file_as_string("res://data/levels/levels.json")
	var doc: Dictionary = JSON.parse_string(raw)
	check(String(doc.get("layout_revision", "")) == "0.6.8-reference-sheet", "new environment catalog is selected")
	check(doc.levels.size() == 100, "100 level IDs are retained")
	var lv = load("res://scripts/game/level.gd").new()
	var guard_count := 0
	var props_count := 0
	var unique_layouts := {}
	var theme_counts := {}
	for number in range(1, 101):
		lv.wall_rects.clear()
		lv.crate_rects.clear()
		lv._load_level(number)
		lv._build_grid()
		lv._build_walkable_regions()
		var expected_theme: String = THEMES[(number - 1) % THEMES.size()]
		var actual_theme := String(lv.data.get("theme", ""))
		theme_counts[actual_theme] = int(theme_counts.get(actual_theme, 0)) + 1
		check(int(lv.data.id) == number and actual_theme == expected_theme, "level %d has the expected themed identity" % number)
		check(int(lv.data.width) == 29 and int(lv.data.height) == 46 and lv.data.walls.size() >= 4 and lv.data.crates.size() >= 10, "level %d has a substantial new playable layout" % number)
		var signature := JSON.stringify([lv.data.walls, lv.data.crates])
		check(not unique_layouts.has(signature), "level %d layout is not duplicated" % number)
		unique_layouts[signature] = true
		var spawn: Vector2i = lv._to_cell(lv.player_pos)
		var player_region := int(lv.region_by_cell.get(spawn, -1))
		check(not lv._solid(lv.player_pos) and player_region >= 0 and lv.guard_walkable_regions.size() == 1, "level %d has a clear spawn and one connected guard-clear area" % number)
		check(not lv._los(lv.player_pos, lv.player_pos + Vector2(0, -180)), "level %d has starter cover between the player and the long sightline" % number)
		var geometry_ok: bool = lv.wall_rects.size() == lv.data.walls.size() and lv.crate_rects.size() == lv.data.crates.size()
		for pair in [[lv.data.walls, lv.wall_rects], [lv.data.crates, lv.crate_rects]]:
			for i in range(pair[0].size()):
				var item: Array = pair[0][i]
				var original := Rect2(lv.ORIGIN + Vector2(item[0], item[1]) * lv.CELL, Vector2(item[2], item[3]) * lv.CELL).grow(3.0)
				var actual: Rect2 = pair[1][i]
				if actual.get_center().distance_to(original.get_center()) > 0.001 or actual.size.distance_to(original.size * 1.2) > 0.001:
					geometry_ok = false
		check(geometry_ok, "level %d visual cover matches its 20%%-enlarged physical boxes" % number)
		var clear := true
		for i in range(lv.crate_rects.size()):
			var expanded: Rect2 = lv.crate_rects[i].grow(13.99)
			for wall in lv.wall_rects:
				if expanded.intersects(wall): clear = false
			for j in range(i):
				if expanded.intersects(lv.crate_rects[j]): clear = false
		check(clear, "level %d crates and real walls are separated" % number)
		var guards_ok := true
		var positions: Array[Vector2] = []
		for guard in lv.data.guards:
			var cell := Vector2i(int(guard.x), int(guard.y))
			var pos: Vector2 = lv._cell_center(cell.x, cell.y)
			if pos.distance_to(lv.player_pos) < 280.0 or lv._guard_solid(pos) or not lv.guard_region_by_cell.has(cell) or int(lv.region_by_cell.get(cell, -2)) != player_region:
				guards_ok = false
			for prior in positions:
				if pos.distance_to(prior) < 159.9: guards_ok = false
			for point in guard.route:
				var route_cell := Vector2i(int(point[0]), int(point[1]))
				if not lv.guard_region_by_cell.has(route_cell): guards_ok = false
			positions.append(pos)
			guard_count += 1
		check(guards_ok, "level %d authored guards and routes are safe, clear, connected and separated" % number)
		var runtime_ok := true
		var distributed: PackedVector2Array = lv._distributed_guard_starts()
		for i in range(distributed.size()):
			var point: Vector2 = distributed[i]
			if point.distance_to(lv.player_pos) < 280.0 or lv._guard_solid(point) or not lv.guard_region_by_cell.has(lv._to_cell(point)):
				runtime_ok = false
			for j in range(i):
				if point.distance_to(distributed[j]) < 159.9: runtime_ok = false
		check(runtime_ok and distributed.size() == lv.data.guards.size(), "level %d runtime guards are safely spread" % number)
		var detail_ok := true
		for detail in lv.data.get("scenery_details", []):
			var p: Vector2 = lv._cell_center(int(detail.x), int(detail.y))
			if lv._guard_solid(p): detail_ok = false
		check(detail_ok, "level %d floor details sit on clear floor" % number)
		if actual_theme == "military":
			var pad: Array = lv.data.get("helipad", [])
			var pad_clear := pad.size() == 3
			if pad_clear:
				var center: Vector2 = lv.ORIGIN + Vector2(float(pad[0]), float(pad[1])) * lv.CELL
				var radius: float = float(pad[2]) * lv.CELL
				var box := Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
				for r in lv.wall_rects + lv.crate_rects:
					if box.intersects(r): pad_clear = false
			check(pad_clear, "level %d has a clear walkable helipad" % number)
		props_count += lv.data.crates.size()
	check(guard_count == 1064, "all original 1064 guards retained across the catalog")
	check(unique_layouts.size() == 100, "all 100 layouts are distinct")
	check(theme_counts.size() == 8, "all eight requested environment styles are represented")
	for theme in THEMES:
		check(int(theme_counts.get(theme, 0)) >= 12, "%s appears across the level catalog" % theme)
		check(ResourceLoader.exists("res://assets/environment/v68/floor_%s.png" % theme), "%s has its own floor texture" % theme)
	lv.free()
	print("V68 LAYOUT %d checks, %d failures, %d guards, %d props, themes=%s" % [checks, failures, guard_count, props_count, theme_counts])
	quit(1 if failures else 0)
