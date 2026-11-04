extends Node2D
## User-selected art direction: retained floor and collision-aligned cover.
## Visible cover occupies level.wall_rects/crate_rects. The existing movement,
## bullet and vision blockers add their normal 4-unit collision clearance.
const ART := "res://assets/environment/v71/"
const FLOOR_TILE := 64.0
const FLOORS := {
    "warehouse": preload("res://assets/environment/v71/floor_warehouse.png"),
    "factory": preload("res://assets/environment/v71/floor_factory.png"),
    "dockyard": preload("res://assets/environment/v71/floor_dockyard.png"),
    "military": preload("res://assets/environment/v71/floor_military.png"),
    "night": preload("res://assets/environment/v71/floor_night.png"),
    "desert": preload("res://assets/environment/v71/floor_desert.png"),
    "snow": preload("res://assets/environment/v71/floor_snow.png"),
    "rooftop": preload("res://assets/environment/v71/floor_rooftop.png"),
}
const WALL_H := preload("res://assets/environment/v71/wall_h.png")
const WALL_V := preload("res://assets/environment/v71/wall_v.png")
const GRASS := preload("res://assets/environment/stealth-grass.png")
const MARK_H := preload("res://assets/environment/v71/hazard_mark_h.png")
const MARK_V := preload("res://assets/environment/v71/hazard_mark_v.png")
const GLOW := preload("res://assets/environment/v71/glow_warm.png")
const FLOOR_GRATE := preload("res://assets/environment/v71/floor_grate.png")
const LAMP := preload("res://assets/environment/v71/lamp.png")
const PROPS := {
    "crate_wood": preload("res://assets/environment/v71/crate_wood.png"),
    "crate_tan": preload("res://assets/environment/v71/crate_tan.png"),
    "crate_green": preload("res://assets/environment/v71/crate_green.png"),
    "crate_blue": preload("res://assets/environment/v71/crate_blue.png"),
    "crate_red": preload("res://assets/environment/v71/crate_red.png"),
    "crate_steel": preload("res://assets/environment/v71/crate_steel.png"),
    "sandbags": preload("res://assets/environment/v71/sandbags.png"),
    "barrel_pallet": preload("res://assets/environment/v71/barrel_pallet.png"),
}
var level: Node2D
var cover_only := false
var theme := "warehouse"
var draw_count := 0

func setup(lv: Node2D, cover_layer: bool = false) -> void:
    level = lv
    cover_only = cover_layer
    theme = str(level.data.get("theme", "warehouse"))
    texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    queue_redraw()

func _draw() -> void:
    draw_count += 1
    if level == null or level.data.is_empty():
        return
    if cover_only:
        _draw_cover()
    else:
        _draw_floor()
        _draw_source_grass()
        _draw_floor_details()
        _draw_ambient_light()

func _draw_floor() -> void:
    var tex: Texture2D = FLOORS.get(theme, FLOORS["warehouse"])
    var size: Vector2 = Vector2(float(level.data.width),float(level.data.height)) * float(level.CELL)
    var area := Rect2(level.ORIGIN,size)
    draw_rect(area,Color("282b2d"))
    # Source tile edges are at half-cell offset. Align the chosen 2-cell floor
    # artwork with those edges, clipping boundary repetitions to the arena.
    var shift := float(level.data.get("source_tile_offset", 0.5)) * float(level.CELL)
    var start: Vector2 = level.ORIGIN + Vector2.ONE * (shift - FLOOR_TILE)
    var nx := ceili((size.x + FLOOR_TILE * 2.0) / FLOOR_TILE)
    var ny := ceili((size.y + FLOOR_TILE * 2.0) / FLOOR_TILE)
    var factor := tex.get_size() / FLOOR_TILE
    for y in range(ny):
        for x in range(nx):
            var tile := Rect2(start + Vector2(x,y) * FLOOR_TILE,Vector2.ONE * FLOOR_TILE)
            var clipped := tile.intersection(area)
            if clipped.size.x > 0.0 and clipped.size.y > 0.0:
                var source := Rect2((clipped.position-tile.position)*factor,clipped.size*factor)
                draw_texture_rect_region(tex,clipped,source)

func _draw_source_grass() -> void:
    # The same ground rectangles used for stealth are drawn here. These are
    # decoration only: cover, pathfinding and collision are untouched.
    for patch in level.grass_rects:
        draw_texture_rect(GRASS, patch, false)

func _draw_floor_details() -> void:
    # Existing precomputed details are purely cosmetic, remain walkable, and
    # do not add new traps or blockers. Both designs match the selected set.
    for detail in level.floor_details:
        var center: Vector2 = detail.pos
        if str(detail.kind) == "drain":
            draw_texture_rect(FLOOR_GRATE,Rect2(center-Vector2.ONE*18.0,Vector2.ONE*36.0),false,Color(1,1,1,0.88))
        else:
            draw_set_transform(center,float(detail.rot),Vector2.ONE)
            var ink := Color(0.80,0.79,0.62,0.38) if theme != "snow" else Color(0.35,0.45,0.49,0.42)
            draw_line(Vector2(-14,0),Vector2(12,0),ink,3.0)
            draw_line(Vector2(12,0),Vector2(4,-7),ink,3.0)
            draw_line(Vector2(12,0),Vector2(4,7),ink,3.0)
            draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)

func _lamp_outside(r: Rect2, index: int) -> Vector2:
    # Mounted on the wall; its light is floor-only and does not affect AI.
    if index < 4 or index % 7 != 0 or r.size.x < FLOOR_TILE:
        return Vector2(INF,INF)
    var point := Vector2(r.get_center().x,r.position.y-20.0)
    return point if not level._solid(point) else Vector2(INF,INF)

func _draw_ambient_light() -> void:
    for i in range(level.wall_rects.size()):
        var point := _lamp_outside(level.wall_rects[i],i)
        if is_inf(point.x): continue
        var color := Color(1.0,0.92,0.78,0.75) if theme != "night" else Color(0.68,0.80,1.0,0.55)
        draw_texture_rect(GLOW,Rect2(point-Vector2.ONE*86.0,Vector2.ONE*172.0),false,color)

func _draw_cover() -> void:
    var kinds: Dictionary = level.data.get("wall_kinds",{})
    for i in range(level.wall_rects.size()):
        var r: Rect2 = level.wall_rects[i]
        _draw_shadow(r)
        var horizontal := r.size.x >= r.size.y
        var tex: Texture2D = WALL_H if horizontal else WALL_V
        draw_texture_rect(tex,r,false)
        if str(kinds.get(str(i),"wall")) == "gate":
            var mark: Texture2D = MARK_H if horizontal else MARK_V
            draw_texture_rect(mark,r.grow(-4.0),false,Color(1,1,1,0.9))
        var lamp_point := _lamp_outside(r,i)
        if not is_inf(lamp_point.x):
            draw_texture_rect(LAMP,Rect2(Vector2(lamp_point.x-14.0,r.position.y+2.0),Vector2(28.0,10.0)),false)
    for i in range(level.crate_rects.size()):
        var r: Rect2 = level.crate_rects[i]
        var item: Array = level.data.crates[i]
        var kind := str(item[4]) if item.size() > 4 else "crate_wood"
        var tex: Texture2D = PROPS.get(kind,PROPS["crate_wood"])
        _draw_shadow(r)
        # Wide crate groups represent two adjacent source BB cells: draw a
        # matching crate per cell instead of stretching a square sprite.
        if kind.begins_with("crate_") and r.size.x > r.size.y * 1.4:
            var half := r.size.x * 0.5
            draw_texture_rect(tex,Rect2(r.position,Vector2(half,r.size.y)),false)
            draw_texture_rect(tex,Rect2(r.position+Vector2(half,0),Vector2(r.size.x-half,r.size.y)),false)
        else:
            draw_texture_rect(tex,r,false)

func _draw_shadow(r: Rect2) -> void:
    draw_rect(Rect2(r.position+Vector2(3,3),r.size),Color(0.02,0.025,0.03,0.24))
