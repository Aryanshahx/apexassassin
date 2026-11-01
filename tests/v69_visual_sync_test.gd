extends SceneTree
## Assert the v0.6.9 floor/prop alignment and placement contract on all maps.
const World = preload("res://scripts/game/world_backplate.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var back = World.new()
	var lv = load("res://scripts/game/level.gd").new()
	check(is_equal_approx(back.CELL, lv.CELL) and back.ORIGIN == lv.ORIGIN, "floor and physical cover use the same grid and origin")
	check(is_equal_approx(back.FLOOR_TILE, lv.CELL * 2.0), "each two-cell floor texture repeats on exactly two gameplay cells")
	var h: Texture2D = back.WALL_H
	var v: Texture2D = back.WALL_V
	check(h != v and h.get_width() > h.get_height() and v.get_height() > v.get_width(), "walls use separately lit horizontal/vertical renders")
	for theme in back.FLOORS:
		var tex: Texture2D = back.FLOORS[theme]
		var img := tex.get_image()
		check(tex.resource_path.begins_with("res://assets/environment/v69/") and img.get_width() == 256 and img.get_height() == 256, "%s uses the original v69 two-cell tile" % theme)
		var edges_ok := true
		for k in range(0, 256, 13):
			if img.get_pixel(0, k) != img.get_pixel(255, k) or img.get_pixel(k, 0) != img.get_pixel(k, 255):
				edges_ok = false
		check(edges_ok, "%s floor texture wraps seamlessly" % theme)
	for kind in back.PROPS:
		var tex: Texture2D = back.PROPS[kind]
		var img := tex.get_image()
		var bounds := img.get_used_rect()
		var close_to_bounds: bool = bounds.position.x <= 4 and bounds.position.y <= 4 and img.get_width() - bounds.end.x <= 4 and img.get_height() - bounds.end.y <= 4
		check(tex.resource_path.begins_with("res://assets/environment/v69/") and close_to_bounds, "%s art is original and tightly fits its cover rectangle" % kind)
	var total := 0
	var light_total := 0
	for number in range(1, 101):
		lv.wall_rects.clear()
		lv.crate_rects.clear()
		lv._load_level(number)
		var covered := true
		for item in lv.data.crates:
			var kind := String(item[4]) if item.size() >= 5 else "crate_wood"
			if kind != "wood_cluster" and not back.PROPS.has(kind):
				covered = false
			total += 1
		check(covered and lv.crate_rects.size() == lv.data.crates.size(), "level %d has original art for every physical cover object" % number)
		var light_clear := true
		for lamp in lv.data.get("scenery_lights", []):
			var pos: Vector2 = lv._cell_center(int(lamp[0]), int(lamp[1]))
			for r in lv.wall_rects + lv.crate_rects:
				if r.grow(19.0).has_point(pos):
					light_clear = false
			light_total += 1
		check(light_clear, "level %d recessed lamps are not buried under obstacles" % number)
	check(total == 1661 and light_total == 400, "all redesigned cover objects and 400 unobstructed lights are represented")
	back.free()
	lv.free()
	print("V69 VISUAL SYNC %d checks, %d failures; %d cover objects, %d clear lamps" % [checks, failures, total, light_total])
	quit(1 if failures else 0)
