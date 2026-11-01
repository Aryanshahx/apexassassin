extends Node2D
## Retained floor and cover for the user-supplied Hunter Files map adaptation.
## Every visible wall/box is drawn into its cover Rect2; the existing collision
## code adds its normal four-unit clearance. Shadows are cosmetic.
const ART := "res://assets/environment/v70/"
const FLOOR_TILE := 64.0
const FLOORS := {
    "warehouse": preload("res://assets/environment/v70/floor_both/floor1.png"),
    "factory": preload("res://assets/environment/v70/floor_indoors/floor14.png"),
    "dockyard": preload("res://assets/environment/v70/floor_both/floor8.png"),
    "military": preload("res://assets/environment/v70/floor_outdoors/floor13.png"),
    "night": preload("res://assets/environment/v70/floor_outdoors/floor19.png"),
    "desert": preload("res://assets/environment/v70/floor_outdoors/floor5.png"),
    "snow": preload("res://assets/environment/v70/floor_both/floor12.png"),
    "rooftop": preload("res://assets/environment/v70/floor_indoors/floor15.png"),
}
const FLOOR_TINT := {
    "warehouse": Color(0.67, 0.71, 0.73),
    "factory": Color(0.71, 0.72, 0.74),
    "dockyard": Color(0.73, 0.77, 0.77),
    "military": Color(0.75, 0.78, 0.68),
    "night": Color(0.46, 0.56, 0.61),
    "desert": Color(0.88, 0.80, 0.67),
    "snow": Color(0.84, 0.91, 0.94),
    "rooftop": Color(0.71, 0.75, 0.79),
}
const WALL_TEXTURES := {
    "warehouse": preload("res://assets/environment/v70/wallBorder/1.border/edge.png"),
    "factory": preload("res://assets/environment/v70/wallBorder/2.border/edge.png"),
    "dockyard": preload("res://assets/environment/v70/wallBorder/3.border/edge.png"),
    "military": preload("res://assets/environment/v70/wallBorder/5.border/edge.png"),
    "night": preload("res://assets/environment/v70/wallBorder/8.border/edge.png"),
    "desert": preload("res://assets/environment/v70/wallBorder/10.border/edge.png"),
    "snow": preload("res://assets/environment/v70/wallBorder/11.border/edge.png"),
    "rooftop": preload("res://assets/environment/v70/wallBorder/12.border/edge.png"),
}
const GRASS := preload("res://assets/environment/v70/floor_outdoors/floor13.png")
const GATE := preload("res://assets/environment/v70/mainGates/2.png")
const WALL_BASE := {
    "warehouse": Color("4b5557"), "factory": Color("53555a"),
    "dockyard": Color("455962"), "military": Color("536153"),
    "night": Color("303b49"), "desert": Color("786955"),
    "snow": Color("667a87"), "rooftop": Color("484f5c"),
}

var level: Node2D
var cover_only := false
var theme := "warehouse"
var prop_cache := {}
var draw_count := 0  # regression instrumentation for retained draw commands

func setup(lv: Node2D, cover_layer: bool = false) -> void:
    level = lv
    cover_only = cover_layer
    theme = str(level.data.get("theme", "warehouse"))
    texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    # Cache the dynamically chosen user-supplied crate sprites once per layer.
    if cover_only:
        for item in level.data.get("crates", []):
            if item.size() >= 5:
                var source_path := ART + str(item[4])
                if not prop_cache.has(source_path):
                    var texture := load(source_path) as Texture2D
                    if texture != null:
                        prop_cache[source_path] = texture
    queue_redraw()

func _draw() -> void:
    draw_count += 1
    if level == null or level.data.is_empty():
        return
    if not cover_only:
        _draw_floor()
        _draw_source_grass()
    else:
        _draw_cover()

func _draw_floor() -> void:
    var tex: Texture2D = FLOORS.get(theme, FLOORS["warehouse"])
    var tint: Color = FLOOR_TINT.get(theme, Color.WHITE)
    var size: Vector2 = Vector2(float(level.data.width), float(level.data.height)) * float(level.CELL)
    var area := Rect2(level.ORIGIN, size)
    draw_rect(area, WALL_BASE.get(theme, Color.DIM_GRAY))
    # One source tile = two Godot grid cells. Drawing is retained, not rebuilt
    # each frame; source images are not modified or repackaged into an atlas.
    var nx := ceili(size.x / FLOOR_TILE)
    var ny := ceili(size.y / FLOOR_TILE)
    for y in range(ny):
        for x in range(nx):
            var tile := Rect2(level.ORIGIN + Vector2(x, y) * FLOOR_TILE, Vector2.ONE * FLOOR_TILE)
            draw_texture_rect(tex, tile, false, tint)

func _draw_source_grass() -> void:
    # The supplied parser labels :: as a grass tile; it remains non-colliding.
    var tint := Color(0.74, 0.84, 0.70, 0.78)
    if theme == "night":
        tint = Color(0.48, 0.61, 0.55, 0.72)
    elif theme == "snow":
        tint = Color(0.82, 0.92, 0.90, 0.55)
    for cell in level.data.get("source_grass", []):
        var top_left: Vector2 = level.ORIGIN + (Vector2(1, 1) + Vector2(float(cell[0]), float(cell[1])) * 2.0) * level.CELL
        draw_texture_rect(GRASS, Rect2(top_left, Vector2.ONE * FLOOR_TILE), false, tint)

func _draw_cover() -> void:
    var kinds: Dictionary = level.data.get("wall_kinds", {})
    for i in range(level.wall_rects.size()):
        var r: Rect2 = level.wall_rects[i]
        if str(kinds.get(str(i), "source_wall")) == "source_gate":
            _draw_gate(r)
        else:
            _draw_wall(r)
    for i in range(level.crate_rects.size()):
        var r: Rect2 = level.crate_rects[i]
        _draw_contact_shadow(r, 3.0)
        var item: Array = level.data.crates[i]
        var source_path := ART + str(item[4]) if item.size() >= 5 else ""
        var tex: Texture2D = prop_cache.get(source_path)
        if tex != null:
            # The supplied sprite and the collision rectangle share an exact
            # destination; the existing collision code still adds its normal
            # four-unit clearance around that physical cover rectangle.
            draw_texture_rect(tex, r, false)
        else:
            draw_rect(r, Color("805734"))
            draw_rect(r.grow(-2.0), Color("ad7a40"), false, 2.0)

func _draw_contact_shadow(r: Rect2, offset: float) -> void:
    draw_rect(Rect2(r.position + Vector2(offset, offset), r.size), Color(0.025, 0.03, 0.04, 0.22))

func _draw_gate(r: Rect2) -> void:
    _draw_contact_shadow(r, 3.0)
    draw_rect(r, WALL_BASE.get(theme, Color.DIM_GRAY))
    draw_texture_rect(GATE, r, false)

func _draw_wall(r: Rect2) -> void:
    _draw_contact_shadow(r, 3.0)
    draw_rect(r, WALL_BASE.get(theme, Color.DIM_GRAY))
    var tex: Texture2D = WALL_TEXTURES.get(theme, WALL_TEXTURES["warehouse"])
    # Source wall-border sprites run vertically; transpose UVs on long
    # horizontal segments. Segments are clipped to the physical wall area.
    var horizontal := r.size.x > r.size.y
    var span := r.size.x if horizontal else r.size.y
    var cursor := 0.0
    while cursor < span - 0.01:
        var length := minf(FLOOR_TILE, span - cursor)
        var part := Rect2(r.position + (Vector2(cursor, 0) if horizontal else Vector2(0, cursor)),
                          Vector2(length, r.size.y) if horizontal else Vector2(r.size.x, length))
        draw_texture_rect(tex, part, false, Color.WHITE, horizontal)
        cursor += length
    draw_rect(r, Color(0.08, 0.11, 0.13, 0.5), false, 1.0)
