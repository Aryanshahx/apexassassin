extends Node2D
## Immutable depot floor, props, shadows, walls and crates. CanvasItem retains
## these draw commands between frames; the level's dynamic items draw above it.
const CELL := 32.0
const ORIGIN := Vector2(24, 140)
const OBSTACLE_GROW := 3.0
const OBSTACLE_SCALE := 1.20
const FLOOR_TILE := 90.0
const SRC_THICK := 91.0
const CONTAINER_KEYS := ["blue", "red", "olive"]
const GRADE_FLOOR := Color(0.76, 0.86, 0.94)
const GRADE_OUTSIDE := Color(0.40, 0.48, 0.58)
const GRADE_WALL := Color(1.0, 0.98, 1.0)
const GRADE_CRATE := Color(1.0, 0.98, 0.94)
const GRADE_PROP := Color(0.95, 0.97, 1.0)
const FLOOR := preload("res://assets/environment/depot/floor_real.png")
const CRATE_TOP := preload("res://assets/environment/depot/crate_real_top.png")
const CRATE_DEPTH := preload("res://assets/environment/depot/crate_real_depth.png")
const DRAIN_TEX := preload("res://assets/environment/depot/drain_real.png")
const ARROW_TEX := preload("res://assets/environment/depot/arrow_real.png")
var draw_count := 0
var cover_only := false
var data: Dictionary
var wall_rects: Array[Rect2] = []
var crate_rects: Array[Rect2] = []
var shadow_rects: Array[Rect2] = []
var floor_details: Array[Dictionary] = []
var l_wall_colors := {}
var _c_cap_a := {}
var _c_cap_b := {}
var _c_cap_l := {}
var _c_cap_r := {}
var _c_mid := {}
var _c_mid_h := {}
var _c_depth := {}
var _c_depth_h := {}

func setup(level, only_cover: bool = false) -> void:
	cover_only = only_cover
	data = level.data
	wall_rects = level.wall_rects
	crate_rects = level.crate_rects
	shadow_rects = level.shadow_rects
	floor_details = level.floor_details
	l_wall_colors.clear()
	for shape in data.get("l_shapes", []):
		for index in shape.arms:
			l_wall_colors[int(index)] = String(shape.color)
	_c_cap_a = level._c_cap_a
	_c_cap_b = level._c_cap_b
	_c_cap_l = level._c_cap_l
	_c_cap_r = level._c_cap_r
	_c_mid = level._c_mid
	_c_mid_h = level._c_mid_h
	_c_depth = level._c_depth
	_c_depth_h = level._c_depth_h

func _draw() -> void:
	draw_count += 1
	if cover_only:
		for i in range(wall_rects.size()):
			_draw_wall(wall_rects[i], String(l_wall_colors.get(i, "")))
		for r in crate_rects:
			_draw_crate(r)
		return
	# Tiled floor, clipped to the map rectangle.
	var map_rect := Rect2(ORIGIN, Vector2(data.width, data.height) * CELL)
	# Two repeating textured quads replace hundreds of floor draw commands.
	# The original 256-pixel texture still tiles every 90 world units.
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	var tile_scale := FLOOR_TILE / float(FLOOR.get_size().x)
	var out_rect := map_rect.grow(384.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * tile_scale)
	draw_texture_rect(FLOOR, Rect2(out_rect.position / tile_scale, out_rect.size / tile_scale), true, GRADE_OUTSIDE)
	draw_set_transform(ORIGIN, 0.0, Vector2.ONE * tile_scale)
	draw_texture_rect(FLOOR, Rect2(Vector2.ZERO, map_rect.size / tile_scale), true, GRADE_FLOOR)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Painted floor details, deterministic per level.
	for d in floor_details:
		if d.kind == "drain":
			draw_texture_rect(DRAIN_TEX, Rect2(d.pos - Vector2(20, 20), Vector2(40, 40)), false, GRADE_PROP)
		else:
			draw_set_transform(d.pos, d.rot, Vector2.ONE)
			draw_texture_rect(ARROW_TEX, Rect2(-23, -17, 46, 35), false, GRADE_PROP)
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	# Shadows.
	for r in shadow_rects:
		var sr := r.intersection(map_rect)
		if sr.size.x > 0 and sr.size.y > 0:
			draw_rect(sr, Color(0.05, 0.07, 0.12, 0.18))

func _wall_colour(r: Rect2) -> String:
	# Recover the original unscaled grid origin to keep colour stable.
	var original_size := r.size / OBSTACLE_SCALE - Vector2.ONE * OBSTACLE_GROW * 2.0
	var original_pos := r.get_center() - original_size * 0.5
	return CONTAINER_KEYS[int(abs(original_pos.x * 7 + original_pos.y * 13)) % CONTAINER_KEYS.size()]

func _draw_wall(r: Rect2, l_color: String = "") -> void:
	# 9-slice the real container art: fixed hazard caps + tiled ribbed middle,
	# then the original depth face along the bottom edge.
	var key := l_color if CONTAINER_KEYS.has(l_color) else _wall_colour(r)
	var horizontal := r.size.x > r.size.y
	var thick := minf(r.size.x, r.size.y)
	var sc := thick / SRC_THICK
	var cap_a := 21.0 * sc
	var cap_b := 22.0 * sc
	var dt: Texture2D = _c_depth_h[key] if horizontal else _c_depth[key]
	var depth_h := float(dt.get_size().y) * sc
	# Cast shadow (down-right, like the concept).
	draw_rect(Rect2(r.position + Vector2(6, 9) * maxf(sc, 0.5), r.size + Vector2(2, depth_h)), Color(0, 0, 0, 0.30))
	# The entire visible lid and depth face stay inside r, matching collision.
	if horizontal:
		var mid_w := r.size.x - cap_a - cap_b
		draw_texture_rect(_c_cap_l[key], Rect2(r.position, Vector2(cap_a, thick)), false, GRADE_WALL)
		draw_texture_rect(_c_cap_r[key], Rect2(Vector2(r.end.x - cap_b, r.position.y), Vector2(cap_b, thick)), false, GRADE_WALL)
		if mid_w > 1.0:
			var tex: Texture2D = _c_mid_h[key]
			var unit := float(tex.get_size().x) * sc
			var n := maxi(1, int(ceil(mid_w / maxf(unit, 1.0))))
			var seg := mid_w / float(n)
			for i in range(n):
				draw_texture_rect(tex, Rect2(Vector2(r.position.x + cap_a + i * seg, r.position.y), Vector2(seg, thick)), false, GRADE_WALL)
	else:
		var mid_h := r.size.y - cap_a - cap_b
		draw_texture_rect(_c_cap_a[key], Rect2(r.position, Vector2(thick, cap_a)), false, GRADE_WALL)
		draw_texture_rect(_c_cap_b[key], Rect2(Vector2(r.position.x, r.end.y - cap_b), Vector2(thick, cap_b)), false, GRADE_WALL)
		if mid_h > 1.0:
			var tex: Texture2D = _c_mid[key]
			var unit := float(tex.get_size().y) * sc
			var n := maxi(1, int(ceil(mid_h / maxf(unit, 1.0))))
			var seg := mid_h / float(n)
			for i in range(n):
				draw_texture_rect(tex, Rect2(Vector2(r.position.x, r.position.y + cap_a + i * seg), Vector2(thick, seg)), false, GRADE_WALL)
	# Draw the front face INSIDE the collision footprint, not over open floor.
	depth_h = minf(depth_h, r.size.y * 0.25)
	var unit_d := maxf(float(dt.get_size().x) * sc, 8.0)
	var dn := maxi(1, int(ceil(r.size.x / unit_d)))
	var dw := r.size.x / float(dn)
	for i in range(dn):
		draw_texture_rect(dt, Rect2(Vector2(r.position.x + i * dw, r.end.y - depth_h), Vector2(dw, depth_h)), false, GRADE_WALL)

func _draw_crate(r: Rect2) -> void:
	var dh := r.size.y * 0.24
	draw_rect(Rect2(r.position + Vector2(5, 8), r.size), Color(0, 0, 0, 0.22))
	draw_texture_rect(CRATE_TOP, r, false, GRADE_CRATE)
	draw_texture_rect(CRATE_DEPTH, Rect2(Vector2(r.position.x, r.end.y - dh), Vector2(r.size.x, dh)), false, GRADE_CRATE)
