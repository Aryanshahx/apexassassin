extends Node2D
## Retained warehouse floor and cover, assembled from the user's screenshot.
## The images are textures, not flattened gameplay: the independent collision
## rectangles, visible guard cones, moving actors, gates and paths still work.
const CELL := 32.0
const ORIGIN := Vector2(24, 140)
const FLOOR_TILE := 90.0
const BLUE_TILE := 292.5
const ROOM_TILE := 127.5
const FLOOR := preload("res://assets/environment/v65/reference_floor.png")
const FLOOR_BLUE := preload("res://assets/environment/v65/reference_floor_blue.png")
const ROOM_FLOOR := preload("res://assets/environment/v65/reference_room_floor.png")
const GREEN_WALL := preload("res://assets/environment/v65/green_wall.png")
const GREEN_WALL_V := preload("res://assets/environment/v65/green_wall_vertical.png")
const GREEN_PANEL := preload("res://assets/environment/v65/green_panel.png")
const GATE := preload("res://assets/environment/v65/gate.png")
const RED := preload("res://assets/environment/v65/red_container.png")
const ORANGE := preload("res://assets/environment/v65/orange_hazard.png")
const HAZARD := preload("res://assets/environment/v65/orange_crate.png")
const WOOD := preload("res://assets/environment/v65/brown_crate.png")
const STACK := preload("res://assets/environment/v65/strapped_stack.png")
const CRATE_TEXTURES := [WOOD, STACK, ORANGE, WOOD, HAZARD, STACK, WOOD, ORANGE]

var draw_count := 0
var cover_only := false
var data: Dictionary
var wall_rects: Array[Rect2] = []
var crate_rects: Array[Rect2] = []
var shadow_rects: Array[Rect2] = []
var l_wall_colors := {}
var partition_wall_indices := {}

func setup(level, only_cover: bool = false) -> void:
	cover_only = only_cover
	data = level.data
	wall_rects = level.wall_rects
	crate_rects = level.crate_rects
	shadow_rects = level.shadow_rects
	l_wall_colors.clear()
	partition_wall_indices.clear()
	for index in data.get("partition_walls", []):
		partition_wall_indices[int(index)] = true
	for shape in data.get("l_shapes", []):
		for index in shape.arms:
			l_wall_colors[int(index)] = String(shape.color)

func _repeat_floor(tex: Texture2D, area: Rect2, units_wide: float, tint: Color = Color.WHITE) -> void:
	var tile_scale := units_wide / float(tex.get_size().x)
	draw_set_transform(area.position, 0.0, Vector2.ONE * tile_scale)
	draw_texture_rect(tex, Rect2(Vector2.ZERO, area.size / tile_scale), true, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw() -> void:
	draw_count += 1
	if cover_only:
		for i in range(wall_rects.size()):
			if partition_wall_indices.has(i):
				_draw_bunker_wall(wall_rects[i])
			elif l_wall_colors.has(i):
				_draw_crate(wall_rects[i])
			else:
				_draw_outer_wall(wall_rects[i])
		for r in crate_rects:
			_draw_crate(r)
		return
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	var map_rect := Rect2(ORIGIN, Vector2(data.width, data.height) * CELL)
	_repeat_floor(FLOOR, map_rect.grow(384.0), FLOOR_TILE, Color(0.52, 0.54, 0.56))
	_repeat_floor(FLOOR, map_rect, FLOOR_TILE)
	# The reference has a subtle blue weathered area over the gray herringbone.
	_repeat_floor(FLOOR_BLUE, map_rect, BLUE_TILE, Color(1, 1, 1, 0.25))
	var room: Array = data.get("room_floor", [])
	if room.size() == 2:
		var room_rect := Rect2(ORIGIN + Vector2(0, float(room[0]) * CELL), Vector2(float(data.width) * CELL, float(room[1] - room[0]) * CELL))
		_repeat_floor(ROOM_FLOOR, room_rect, ROOM_TILE)
	for gate in data.get("gate_decor", []):
		_draw_gate_decor(gate)
	# Faint shadows continue to correspond to the existing stealth regions.
	for r in shadow_rects:
		var sr := r.intersection(map_rect)
		if sr.size.x > 0 and sr.size.y > 0:
			draw_rect(sr, Color(0.05, 0.07, 0.12, 0.10))

func _draw_outer_wall(r: Rect2) -> void:
	# Dark blue edge trim from the reference's right-hand perimeter.
	draw_rect(r, Color("192d3b"))
	var inner := r.grow(-4.0)
	if inner.size.x > 0.0 and inner.size.y > 0.0:
		draw_rect(inner, Color("284456"))
	if r.size.y > r.size.x:
		for i in range(int(ceil(r.size.y / 22.0))):
			var y := r.position.y + i * 22.0
			draw_line(Vector2(r.position.x + 3, y), Vector2(r.end.x - 3, y), Color("142630"), 2.0)
	else:
		for i in range(int(ceil(r.size.x / 22.0))):
			var x := r.position.x + i * 22.0
			draw_line(Vector2(x, r.position.y + 3), Vector2(x, r.end.y - 3), Color("142630"), 2.0)

func _draw_bunker_wall(r: Rect2) -> void:
	# Same green armoured plates and dark metal frame as the actual screenshot.
	draw_rect(Rect2(r.position + Vector2(4, 6), r.size), Color(0, 0, 0, 0.23))
	if r.size.x / maxf(r.size.y, 1.0) > 0.70 and r.size.x / maxf(r.size.y, 1.0) < 1.40:
		draw_texture_rect(GREEN_PANEL, r, false)
		return
	var horizontal := r.size.x >= r.size.y
	var tex: Texture2D = GREEN_WALL if horizontal else GREEN_WALL_V
	var length := r.size.x if horizontal else r.size.y
	var thickness := r.size.y if horizontal else r.size.x
	var native_length := float(tex.get_size().x if horizontal else tex.get_size().y)
	var native_thickness := float(tex.get_size().y if horizontal else tex.get_size().x)
	var pieces := maxi(1, int(ceil(length / maxf(1.0, thickness * native_length / native_thickness))))
	for i in range(pieces):
		var box := Rect2(r.position + (Vector2(length * float(i) / pieces, 0) if horizontal else Vector2(0, length * float(i) / pieces)), Vector2(length / pieces, thickness) if horizontal else Vector2(thickness, length / pieces))
		draw_texture_rect(tex, box, false)

func _draw_gate_decor(item: Array) -> void:
	# Match the rendered threshold to the actual open gap between the two walls;
	# the yellow strip itself is decorative and remains traversable.
	var row := int(item[1])
	var pair := [4, 5] if row == int(data.get("area_breaks", [17,25])[0]) else [6, 7]
	if wall_rects.size() <= int(pair[1]):
		return
	var left: float = wall_rects[pair[0]].end.x
	var right: float = wall_rects[pair[1]].position.x
	var center_y := ORIGIN.y + (float(item[1]) + 0.5) * CELL
	if right > left:
		draw_texture_rect(GATE, Rect2(left, center_y - CELL * 0.58, right - left, CELL * 1.16), false)

func _draw_crate(r: Rect2) -> void:
	# A stack is one physical cover rectangle. Its tops are individual crops
	# from the screenshot, with the same wood, red metal and hazard details.
	draw_rect(Rect2(r.position + Vector2(4, 6), r.size), Color(0, 0, 0, 0.22))
	var columns := maxi(1, int(round(r.size.x / (CELL * 1.85))))
	var rows := maxi(1, int(round(r.size.y / (CELL * 1.85))))
	var tile := Vector2(r.size.x / float(columns), r.size.y / float(rows))
	var seed := int(absf(r.position.x * 0.17 + r.position.y * 0.31))
	for y in range(rows):
		for x in range(columns):
			var box := Rect2(r.position + Vector2(x * tile.x, y * tile.y), tile)
			var index := (seed + x * 3 + y * 5) % CRATE_TEXTURES.size()
			var tex: Texture2D = CRATE_TEXTURES[index]
			if rows == 1 and columns >= 2 and x == 0 and seed % 4 == 0:
				tex = RED
			draw_texture_rect(tex, box, false)
