extends SceneTree
## Supplied textures must load, with cover artwork using actual cover rects.
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
    check(is_equal_approx(back.FLOOR_TILE, lv.CELL * 2.0), "source floor tile matches two gameplay cells")
    check(back.FLOORS.size() == 8 and back.WALL_TEXTURES.size() == 8, "all eight themes use supplied floor and wall art")
    for theme in back.FLOORS:
        var floor_tex: Texture2D = back.FLOORS[theme]
        var wall_tex: Texture2D = back.WALL_TEXTURES[theme]
        check(floor_tex != null and floor_tex.resource_path.begins_with(back.ART) and floor_tex.get_width() > 1, "%s source floor loads" % theme)
        check(wall_tex != null and wall_tex.resource_path.begins_with(back.ART) and wall_tex.get_width() > 1, "%s source wall loads" % theme)
    var resources := {}
    var all_geometry := true
    for n in range(1, 101):
        lv.wall_rects.clear()
        lv.crate_rects.clear()
        lv._load_level(n)
        for pair in [[lv.data.walls, lv.wall_rects], [lv.data.crates, lv.crate_rects]]:
            for i in range(pair[0].size()):
                var item: Array = pair[0][i]
                var expected: Rect2 = lv._cover_rect(item)
                var actual: Rect2 = pair[1][i]
                if expected.position.distance_to(actual.position) > 0.001 or expected.size.distance_to(actual.size) > 0.001:
                    all_geometry = false
        for item in lv.data.crates:
            var path: String = str(back.ART) + str(item[4])
            resources[path] = true
    check(all_geometry, "all cover art is drawn on its actual cover rectangle")
    for path in resources:
        var texture: Texture2D = load(path) as Texture2D
        check(texture != null and texture.resource_path == path and texture.get_width() >= 64 and texture.get_height() >= 64, "%s exists as supplied texture" % path)
    check(resources.size() >= 50, "varied supplied props are used across the catalog")
    lv.free()
    back.free()
    print("V70 VISUAL %d checks, %d failures; %d distinct supplied prop textures" % [checks, failures, resources.size()])
    quit(1 if failures else 0)
