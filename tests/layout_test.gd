extends SceneTree
## All 100 source-adapted levels, real Godot geometry and runtime guard starts.
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
    var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels/levels.json"))
    check(str(doc.get("layout_revision", "")) == "0.7.0-user-supplied-grids", "source-derived catalog is selected")
    check(doc.levels.size() == 100, "100 level IDs are retained")
    var raw_config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/source_maps/v70/recovered_remote_config.json"))
    check(raw_config.remoteMaps.size() == 100, "100 static source configurations are retained")
    var lv = load("res://scripts/game/level.gd").new()
    var theme_counts := {}
    var map_pairs := {}
    var guard_count := 0
    var obstacle_count := 0
    var compared_cells := 0
    for number in range(1, 101):
        lv.wall_rects.clear()
        lv.crate_rects.clear()
        lv._load_level(number)
        lv._build_grid()
        lv._build_walkable_regions()
        var source: Dictionary = raw_config.remoteMaps[number - 1]
        var expected_theme: String = THEMES[(number - 1) % THEMES.size()]
        var actual_theme := str(lv.data.get("theme", ""))
        theme_counts[actual_theme] = int(theme_counts.get(actual_theme, 0)) + 1
        check(int(lv.data.id) == number and actual_theme == expected_theme, "level %d keeps its themed identity" % number)
        check(str(lv.data.source_map_id) == str(source.mapId) and bool(lv.data.source_flip_x) == bool(source.get("flipX", false)) and bool(lv.data.source_flip_y) == bool(source.get("flipY", false)), "level %d selects its own source map and flips" % number)
        var pair := "%s/%s/%s" % [lv.data.source_map_id, lv.data.source_flip_x, lv.data.source_flip_y]
        map_pairs[pair] = true
        check(int(lv.data.width) >= 24 and int(lv.data.height) >= 48 and lv.data.walls.size() >= 5 and lv.data.crates.size() >= 1, "level %d has usable source-derived dimensions and cover" % number)
        var exact_grid := true
        for y in range(int(lv.data.height)):
            for x in range(int(lv.data.width)):
                var cell := Vector2i(x, y)
                var point: Vector2 = lv._cell_center(x, y)
                if lv.grid.is_point_solid(cell) != lv._solid(point) or lv.guard_grid.is_point_solid(cell) != lv._guard_solid(point):
                    exact_grid = false
                compared_cells += 1
        check(exact_grid, "level %d optimized grids equal the original all-rectangles collision rule at every cell" % number)
        var spawn: Vector2i = lv._to_cell(lv.player_pos)
        var player_region := int(lv.region_by_cell.get(spawn, -1))
        check(not lv._solid(lv.player_pos) and player_region >= 0 and lv.guard_walkable_regions.size() == 1, "level %d has a clear spawn and a single guard-clear region" % number)
        var clearance := true
        for i in range(lv.crate_rects.size()):
            var expanded: Rect2 = lv.crate_rects[i].grow(13.99)
            for wall in lv.wall_rects:
                if expanded.intersects(wall): clearance = false
            for j in range(i):
                if expanded.intersects(lv.crate_rects[j]): clearance = false
        check(clearance, "level %d visible boxes have safe separation from walls and each other" % number)
        var guards_ok := true
        var points: Array[Vector2] = []
        var runtime: PackedVector2Array = lv._distributed_guard_starts()
        if runtime.size() != lv.data.guards.size(): guards_ok = false
        for i in range(lv.data.guards.size()):
            var guard: Dictionary = lv.data.guards[i]
            var point: Vector2 = lv._cell_center(int(guard.x), int(guard.y))
            var cell: Vector2i = lv._to_cell(point)
            if point.distance_to(lv.player_pos) < 560.0 or lv._guard_solid(point) or not lv.guard_region_by_cell.has(cell) or int(lv.region_by_cell.get(cell, -2)) != player_region:
                guards_ok = false
            if i >= runtime.size() or runtime[i].distance_to(point) > 0.01:
                guards_ok = false
            for previous in points:
                if point.distance_to(previous) < 159.9: guards_ok = false
            for route_cell in guard.route:
                var route: Vector2i = Vector2i(int(route_cell[0]), int(route_cell[1]))
                if not lv.guard_region_by_cell.has(route): guards_ok = false
            if guard.route.size() >= 2:
                var a: Vector2 = lv._cell_center(int(guard.route[0][0]), int(guard.route[0][1]))
                var b: Vector2 = lv._cell_center(int(guard.route[1][0]), int(guard.route[1][1]))
                if not lv._guard_line_clear(a, b): guards_ok = false
            points.append(point)
            guard_count += 1
        check(guards_ok, "level %d adapted guards and patrol endpoints are safe, separated and used at runtime" % number)
        obstacle_count += lv.wall_rects.size() + lv.crate_rects.size()
    check(guard_count == 1064, "all 1064 project guards are retained")
    check(map_pairs.size() == 64, "source configuration has the expected 64 distinct grid/flip combinations")
    check(theme_counts.size() == 8, "all eight existing themes are represented")
    for theme in THEMES:
        check(int(theme_counts.get(theme, 0)) >= 12, "%s appears throughout the catalog" % theme)
    lv.free()
    print("V70 LAYOUT %d checks, %d failures; %d guards, %d obstacles, %d cell comparisons; themes=%s; source-pairs=%d" % [checks, failures, guard_count, obstacle_count, compared_cells, theme_counts, map_pairs.size()])
    quit(1 if failures else 0)
