extends Node2D
## Reference-sheet environments. User-provided pixels were isolated as sprites;
## the scene is still fully interactive: collision geometry, actors, flashlight
## cones, bullets, paths and saved progress remain independent of the artwork.
const CELL := 32.0
const ORIGIN := Vector2(24, 140)
const FLOOR_TILE := 92.0 # 256px texture contains two 46-world-unit squares
const FLOORS := {
	"warehouse": preload("res://assets/environment/v68/floor_warehouse.png"),
	"factory": preload("res://assets/environment/v68/floor_factory.png"),
	"dockyard": preload("res://assets/environment/v68/floor_dockyard.png"),
	"military": preload("res://assets/environment/v68/floor_military.png"),
	"night": preload("res://assets/environment/v68/floor_night.png"),
	"desert": preload("res://assets/environment/v68/floor_desert.png"),
	"snow": preload("res://assets/environment/v68/floor_snow.png"),
	"rooftop": preload("res://assets/environment/v68/floor_rooftop.png"),
}
const PROPS := {
	"crate_wood": preload("res://assets/environment/v68/crate_wood.png"),
	"crate_wood_small": preload("res://assets/environment/v68/crate_wood_small.png"),
	"crate_green": preload("res://assets/environment/v68/crate_green.png"),
	"crate_steel": preload("res://assets/environment/v68/crate_steel.png"),
	"crate_hazard": preload("res://assets/environment/v68/crate_hazard.png"),
	"crate_camo": preload("res://assets/environment/v68/crate_camo.png"),
	"crate_metal": preload("res://assets/environment/v68/crate_metal.png"),
	"barrel_red": preload("res://assets/environment/v68/barrel_red.png"),
	"barrel_blue": preload("res://assets/environment/v68/barrel_blue.png"),
	"sandbags": preload("res://assets/environment/v68/sandbags.png"),
	"tires": preload("res://assets/environment/v68/tires.png"),
	"pallet": preload("res://assets/environment/v68/pallet.png"),
	"wall_hazard": preload("res://assets/environment/v68/wall_hazard.png"),
	"wall_barrier": preload("res://assets/environment/v68/wall_barrier.png"),
	"fence": preload("res://assets/environment/v68/fence.png"),
	"pipe_v": preload("res://assets/environment/v68/pipe_v.png"),
	"pipe_h": preload("res://assets/environment/v68/pipe_h.png"),
	"vent": preload("res://assets/environment/v68/vent.png"),
	"grate": preload("res://assets/environment/v68/grate.png"),
	"manhole": preload("res://assets/environment/v68/manhole.png"),
	"camera": preload("res://assets/environment/v68/camera.png"),
	"plant": preload("res://assets/environment/v68/plant.png"),
	"bush": preload("res://assets/environment/v68/bush.png"),
	"container_blue_h": preload("res://assets/environment/v68/container_blue_h.png"),
	"container_blue_v": preload("res://assets/environment/v68/container_blue_v.png"),
	"container_red_h": preload("res://assets/environment/v68/container_red_h.png"),
	"container_red_v": preload("res://assets/environment/v68/container_red_v.png"),
}
const WALL := preload("res://assets/environment/v68/wall_concrete.png")
const WALL_HAZARD := preload("res://assets/environment/v68/wall_hazard.png")
const LAMP := preload("res://assets/environment/v68/lamp.png")
const WARM_GLOW := preload("res://assets/environment/v68/glow_warm.png")
const COOL_GLOW := preload("res://assets/environment/v68/glow_cool.png")
const SHADOW := preload("res://assets/environment/v68/shadow_soft.png")
const SNOW_CAP := preload("res://assets/environment/v68/snow_cap.png")

var draw_count := 0
var cover_only := false
var data: Dictionary = {}
var theme := "warehouse"
var wall_rects: Array[Rect2] = []
var crate_rects: Array[Rect2] = []
var shadow_rects: Array[Rect2] = []

func setup(level, only_cover: bool = false) -> void:
	cover_only = only_cover
	data = level.data
	theme = String(data.get("theme", "warehouse"))
	wall_rects = level.wall_rects
	crate_rects = level.crate_rects
	shadow_rects = level.shadow_rects

func _repeat_floor(tex: Texture2D, area: Rect2, units_wide: float, tint: Color = Color.WHITE) -> void:
	var tile_scale := units_wide / float(tex.get_size().x)
	draw_set_transform(area.position, 0.0, Vector2.ONE * tile_scale)
	draw_texture_rect(tex, Rect2(Vector2.ZERO, area.size / tile_scale), true, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw() -> void:
	draw_count += 1
	if cover_only:
		for rect in wall_rects:
			_draw_contact_shadow(rect)
		for rect in crate_rects:
			_draw_contact_shadow(rect)
		var kinds: Dictionary = data.get("wall_kinds", {})
		for index in range(wall_rects.size()):
			var kind := String(kinds.get(str(index), "wall_concrete"))
			_draw_concrete_wall(wall_rects[index], kind)
		for index in range(crate_rects.size()):
			_draw_prop(crate_rects[index], index)
		return
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	var map_rect := Rect2(ORIGIN, Vector2(float(data.width), float(data.height)) * CELL)
	var floor_tex: Texture2D = FLOORS.get(theme, FLOORS["warehouse"])
	_repeat_floor(floor_tex, map_rect.grow(384.0), FLOOR_TILE, Color(0.46, 0.48, 0.51))
	_repeat_floor(floor_tex, map_rect, FLOOR_TILE)
	_draw_theme_markings(map_rect)
	_draw_floor_details()
	_draw_lighting()

func _draw_theme_markings(map_rect: Rect2) -> void:
	if theme == "factory":
		# Faded industrial aisle markings, matching the factory example.
		for x in [8.0, 20.0]:
			var sx: float = ORIGIN.x + float(x) * CELL
			for y in range(4, int(data.height) - 3, 4):
				draw_line(Vector2(sx, ORIGIN.y + y * CELL), Vector2(sx, ORIGIN.y + (y + 2.0) * CELL), Color(0.90, 0.64, 0.16, 0.55), 3.0)
	elif theme == "military" and data.get("helipad", []).size() >= 3:
		var pad: Array = data.helipad
		var center := ORIGIN + Vector2(float(pad[0]), float(pad[1])) * CELL
		var radius := float(pad[2]) * CELL
		var box := Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
		draw_rect(box, Color(0.39, 0.41, 0.42, 0.56))
		draw_rect(box.grow(-3.0), Color(0.75, 0.76, 0.75, 0.45), false, 3.0)
		draw_arc(center, radius * 0.63, 0.0, TAU, 64, Color(0.95, 0.70, 0.18, 0.95), 6.0, true)
		var h := radius * 0.36
		draw_line(center + Vector2(-h * 0.55, -h), center + Vector2(-h * 0.55, h), Color(0.88, 0.90, 0.89, 0.90), 10.0, true)
		draw_line(center + Vector2(h * 0.55, -h), center + Vector2(h * 0.55, h), Color(0.88, 0.90, 0.89, 0.90), 10.0, true)
		draw_line(center + Vector2(-h * 0.55, 0), center + Vector2(h * 0.55, 0), Color(0.88, 0.90, 0.89, 0.90), 10.0, true)
	elif theme == "rooftop":
		# Restrained faded yellow roof-edge safety lines.
		var inset := map_rect.grow(-75.0)
		if inset.size.x > 0.0 and inset.size.y > 0.0:
			draw_rect(inset, Color(0.90, 0.72, 0.30, 0.28), false, 3.0)

func _draw_floor_details() -> void:
	for item in data.get("scenery_details", []):
		var name := String(item.get("kind", "grate"))
		var tex: Texture2D = PROPS.get(name, PROPS["grate"])
		var p := ORIGIN + Vector2(float(item.get("x", 0)) + 0.5, float(item.get("y", 0)) + 0.5) * CELL
		var size := Vector2(43.0, 43.0)
		if name == "plant" or name == "bush":
			size = Vector2(48.0, 48.0)
		draw_texture_rect(tex, Rect2(p - size * 0.5, size), false, Color(1, 1, 1, 0.78))

func _draw_lighting() -> void:
	var glow: Texture2D = COOL_GLOW if theme == "night" else WARM_GLOW
	for item in data.get("scenery_lights", []):
		var p := ORIGIN + Vector2(float(item[0]) + 0.5, float(item[1]) + 0.5) * CELL
		var size := Vector2(235, 225)
		draw_texture_rect(glow, Rect2(p - Vector2(size.x * 0.5, 44), size), false)
		draw_texture_rect(LAMP, Rect2(p - Vector2(22, 10), Vector2(44, 21)), false)

func _draw_contact_shadow(r: Rect2) -> void:
	# Soft offset contact shadows give the cropped pieces the same grounded
	# look as the reference while leaving gameplay collision unchanged.
	var box := Rect2(r.position + Vector2(-31, -3), r.size + Vector2(78, 88))
	draw_texture_rect(SHADOW, box, false, Color(1, 1, 1, 0.62 if theme == "snow" else 0.92))

func _tint() -> Color:
	match theme:
		"night": return Color(0.48, 0.63, 0.88)
		"desert": return Color(1.0, 0.94, 0.83)
		"snow": return Color(0.82, 0.91, 1.0)
		"rooftop": return Color(0.90, 0.94, 1.0)
		_: return Color.WHITE

func _draw_concrete_wall(r: Rect2, kind: String) -> void:
	var horizontal := r.size.x >= r.size.y
	var length := r.size.x if horizontal else r.size.y
	var thick := r.size.y if horizontal else r.size.x
	var tex: Texture2D = WALL_HAZARD if kind == "wall_hazard" else WALL
	var pieces := maxi(1, int(ceil(length / maxf(thick * 2.55, 1.0))))
	draw_set_transform(r.get_center(), 0.0 if horizontal else PI * 0.5, Vector2.ONE)
	for i in range(pieces):
		var piece := Rect2(Vector2(-length * 0.5 + length * float(i) / pieces, -thick * 0.5), Vector2(length / pieces + 0.5, thick))
		draw_texture_rect(tex, piece, false, _tint())
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_prop(r: Rect2, index: int) -> void:
	var props: Array = data.get("crates", [])
	var item: Array = props[index] if index < props.size() else []
	var kind := String(item[4]) if item.size() >= 5 else "crate_wood"
	if kind == "wood_cluster":
		var columns := maxi(1, int(round(r.size.x / 78.0)))
		var rows := maxi(1, int(round(r.size.y / 78.0)))
		var tile := Vector2(r.size.x / float(columns), r.size.y / float(rows))
		for y in range(rows):
			for x in range(columns):
				var box := Rect2(r.position + Vector2(x * tile.x, y * tile.y), tile)
				var variant := "crate_wood_small" if (index + x + y) % 3 == 0 else "crate_wood"
				var tex: Texture2D = PROPS[variant]
				draw_texture_rect(tex, box, false, _tint())
				if theme == "snow":
					_draw_snow_cap(box)
		return
	var tex: Texture2D = PROPS.get(kind, PROPS["crate_wood"])
	draw_texture_rect(tex, r, false, _tint())
	if theme == "snow" and not kind.begins_with("barrel"):
		_draw_snow_cap(r)

func _draw_snow_cap(r: Rect2) -> void:
	var h := minf(27.0, r.size.y * 0.25)
	draw_texture_rect(SNOW_CAP, Rect2(r.position + Vector2(0, -2), Vector2(r.size.x, h)), false)
