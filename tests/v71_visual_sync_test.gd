extends SceneTree
## Selected art must load and all source-derived cover must use the same
## rectangles as the collision geometry, across every existing level.
const World = preload("res://scripts/game/world_backplate.gd")
var checks := 0
var failures := 0
func _init() -> void:
    call_deferred("_run")
func check(value: bool, message: String) -> void:
    checks += 1
    if not value:
        failures += 1
        printerr("FAIL: ", message)
func _run() -> void:
    var back = World.new()
    var lv = load("res://scripts/game/level.gd").new()
    check(is_equal_approx(back.FLOOR_TILE, lv.CELL * 2.0), "floor artwork matches the source tile size")
    check(back.FLOORS.size() == 8 and back.PROPS.size() >= 8, "eight floor themes and selected cover variants exist")
    for theme in back.FLOORS:
        var tex: Texture2D = back.FLOORS[theme]
        check(tex != null and tex.resource_path.begins_with(back.ART) and tex.get_width() >= 64, "%s selected floor loads" % theme)
    for tex in [back.WALL_H, back.WALL_V, back.MARK_H, back.MARK_V, back.GLOW, back.FLOOR_GRATE, back.LAMP]:
        check(tex != null and tex.resource_path.begins_with(back.ART) and tex.get_width() > 1, "selected wall, hazard and decorative textures load")
    check(back.GRASS != null and back.GRASS.resource_path == "res://assets/environment/stealth-grass.png" and back.GRASS.get_width() >= 64, "reference-guided stealth grass texture loads")
    var all_geometry := true
    var kind_count := {}
    for n in range(1, 101):
        lv.wall_rects.clear()
        lv.crate_rects.clear()
        lv._load_level(n)
        for pair in [[lv.data.walls, lv.wall_rects], [lv.data.crates, lv.crate_rects]]:
            if pair[0].size() != pair[1].size():
                all_geometry = false
                continue
            for i in range(pair[0].size()):
                var expected: Rect2 = lv._cover_rect(pair[0][i])
                var actual: Rect2 = pair[1][i]
                if expected.position.distance_to(actual.position) > 0.001 or expected.size.distance_to(actual.size) > 0.001:
                    all_geometry = false
        for item in lv.data.crates:
            var kind := str(item[4]) if item.size() > 4 else ""
            kind_count[kind] = true
            if not back.PROPS.has(kind):
                all_geometry = false
    check(all_geometry, "all 100 levels draw the actual blocking cover rectangles with mapped artwork")
    for kind in kind_count:
        var tex: Texture2D = back.PROPS[kind]
        check(tex != null and tex.resource_path.begins_with(back.ART) and tex.get_width() >= 64, "%s selected prop loads" % kind)
    check(kind_count.size() >= 8, "crate colours, sandbags and barrel cover are used across the catalog")
    lv.free()
    back.free()
    print("V71 VISUAL %d checks, %d failures; %d used cover variants" % [checks, failures, kind_count.size()])
    quit(1 if failures else 0)
