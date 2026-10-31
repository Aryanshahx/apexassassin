extends Node2D
## Apex Assassin core stealth loop.
## Tap floor to move, tap a guard to hunt. Auto-blade in range. Guards patrol,
## investigate noise, chase on sight, fire line-of-sight bullets, and search.
## Cover blocks sight/bullets; flashlight contact triggers immediate fire.
## Nearby guards hear gunfire and investigate. Kills drop gems.

const CELL := 32.0
## Increase each existing obstacle footprint by 20%, about its own centre.
## The repaired authored layouts leave space for this larger art and collision.
const OBSTACLE_GROW := 3.0
const OBSTACLE_SCALE := 1.20
const ORIGIN := Vector2(24, 140)
const FONT := preload("res://assets/fonts/Baloo2.ttf")
const FLOOR := preload("res://assets/environment/depot/floor_real.png")
## Real pixels cut from the approved depot concept (tools/extract_depot_art.py).
const DEPOT := "res://assets/environment/depot/"
const CONTAINER_KEYS := ["blue", "red", "olive"]
const SRC_THICK := 91.0          # container width in the concept art
## Bright, colourful original depot art, while beams stay legible.
const GRADE_FLOOR := Color(0.76, 0.86, 0.94)
const GRADE_OUTSIDE := Color(0.40, 0.48, 0.58)
const GRADE_WALL := Color(1.0, 0.98, 1.0)
const GRADE_CRATE := Color(1.0, 0.98, 0.94)
const GRADE_PROP := Color(0.95, 0.97, 1.0)
## Camera: visible grid cells across the width. 15 shows 25% more world
## than the old 12-cell view (actors are 20% smaller), and still follows the player.
const CAM_VIEW_CELLS := 15.0
var cam_scale := 1.0
const FLOOR_TILE := 90.0         # 256px concept tile at world scale
var _c_cap_a := {}
var _c_cap_b := {}
var _c_cap_l := {}
var _c_cap_r := {}
var _c_mid := {}
var _c_mid_h := {}
var _c_depth := {}
var _c_depth_h := {}
const CRATE_TOP := preload("res://assets/environment/depot/crate_real_top.png")
const CRATE_DEPTH := preload("res://assets/environment/depot/crate_real_depth.png")
const DRAIN_TEX := preload("res://assets/environment/depot/drain_real.png")
const ARROW_TEX := preload("res://assets/environment/depot/arrow_real.png")
const TARGET_TEX := preload("res://assets/ui/target.png")
const GEM_TEX := preload("res://assets/ui/gem_drop.png")
const SLASH_TEX := preload("res://assets/fx/slash.png")
const SPARK_TEX := preload("res://assets/fx/spark.png")
const ActorRigScript := preload("res://scripts/game/reference_rig.gd")
const WorldBackplate := preload("res://scripts/game/world_backplate.gd")
# Account for the guard artwork's visible footprint, not just its centre.
const GUARD_GAP := 66.0
# Body clearance beyond the universal four-unit blocker: wider than before.
const GUARD_WALL_MARGIN := 20.0
const GUARD_AVOID_HOLD := 0.55
const PLAYER_SCALE := 1.40
const PLAYER_HIT_RADIUS := 16.0
const PLAYER_LIGHT_RADIUS := 22.0
const BULLET_DAMAGE := 100.0 # fallback for legacy/test bullets
const GUNSHOT_HEARING_RADIUS := 480.0
const HEALTH_BAR_SIZE := Vector2(64, 8)
const ENEMY_PROFILES := {
	"scout": {"damage": 65.0, "interval": 0.65, "speed": 68.0, "vision": 250.0, "tint": Color(0.55, 0.88, 1.0)},
	"guard": {"damage": 100.0, "interval": 1.00, "speed": 58.0, "vision": 250.0, "tint": Color.WHITE},
	"heavy": {"damage": 160.0, "interval": 1.45, "speed": 48.0, "vision": 220.0, "tint": Color(1.0, 0.78, 0.68)},
}
const DRAG_REPATH_INTERVAL := 0.045

enum GState { PATROL, INVESTIGATE, ALERT, SEARCH, DEAD }

var data: Dictionary = {}
var grid := AStarGrid2D.new()
# Guards need a wider navigation clearance than the player.
var guard_grid := AStarGrid2D.new()
var wall_rects: Array[Rect2] = []
var crate_rects: Array[Rect2] = []
# Pre-grown once; used by movement, bullet blocking and the analytic vision rays.
var blocking_rects: Array[Rect2] = []
# Separate wider guard-clearance geometry; player, bullet and light collision stay unchanged.
var guard_blocking_rects: Array[Rect2] = []
var shadow_rects: Array[Rect2] = []
var player_pos := Vector2.ZERO
var player_face := -PI / 2
var player_path := PackedVector2Array()
var player_hp := 1000.0
var invuln := 0.0
var attack_cd := 0.0
var hunt_target := -1
var repath := 0.0
var player_rig: Node2D
var guards: Array[Dictionary] = []
var bullets: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var gems: Array[Dictionary] = []
var kills := 0
var total := 0
var gems_collected := 0
var damage_taken := 0
var was_alerted := false
var finished := false
var elapsed := 0.0
var counter: Label
var gem_label: Label
var status_label: Label
var overlay: Control
var hud: Control
var hint: Label
var player_health_anchor: Control
var player_health_bar: ProgressBar
var player_health_label: Label
var rng := RandomNumberGenerator.new()
var floor_details: Array[Dictionary] = []
var shake := 0.0
var hit_stop := 0.0
var base_position := Vector2.ZERO
var dragging := false
var drag_target := Vector2.ZERO
var drag_repath := 0.0
var drag_dirty := false
var walkable_regions: Array = []
var region_by_cell := {}
var guard_walkable_regions: Array = []
var guard_region_by_cell := {}
var map_backplate: Node2D
var map_cover: Node2D
var fx_font: FontVariation
var backstabs := 0
var pause_btn: Button
var target_icon: TextureRect
var gem_icon: TextureRect

func _load_depot() -> void:
	var shared := GameState.depot_textures()
	for k in CONTAINER_KEYS:
		_c_cap_a[k] = shared[k + "_cap_a"]
		_c_cap_b[k] = shared[k + "_cap_b"]
		_c_cap_l[k] = shared[k + "_cap_l"]
		_c_cap_r[k] = shared[k + "_cap_r"]
		_c_mid[k] = shared[k + "_mid"]
		_c_mid_h[k] = shared[k + "_mid_h"]
		_c_depth[k] = shared[k + "_depth"]
		_c_depth_h[k] = shared[k + "_depth_h"]

func _ready() -> void:
	_load_depot()
	rng.seed = 9000 + GameState.current_level
	_load_level(GameState.current_level)
	_build_grid()
	_build_walkable_regions()
	_build_shadows()
	_build_floor_details()
	# Static floor and cover are recorded once instead of rebuilt every frame.
	map_backplate = WorldBackplate.new()
	map_backplate.setup(self)
	map_backplate.show_behind_parent = true
	add_child(map_backplate)
	# A separate retained cover layer sits above path/flashlights and below
	# actors, so the original obstacle/lighting appearance remains unchanged.
	map_cover = WorldBackplate.new()
	map_cover.setup(self, true)
	add_child(map_cover)
	fx_font = FontVariation.new()
	fx_font.base_font = FONT
	fx_font.variation_embolden = 1.0
	_build_guards()
	_build_player()
	_build_hud()
	player_hp = GameState.max_health()
	_build_player_health_bar()
	get_viewport().size_changed.connect(_fit_world)
	get_viewport().size_changed.connect(_layout_hud)
	_fit_world()
	_layout_hud()
	if GameState.current_level == 1:
		hint.text = "Tap to move  •  Tap a guard to hunt  •  Stay out of the light"
		var tw := create_tween()
		tw.tween_interval(5.0)
		tw.tween_property(hint, "modulate:a", 0.0, 0.8)
	queue_redraw()

func _fit_world() -> void:
	if data.is_empty():
		return
	var safe := ScreenUtil.safe_rect(get_viewport())
	# Zoom in on the player instead of shrinking the whole arena to fit.
	cam_scale = maxf(0.1, safe.size.x / (CAM_VIEW_CELLS * CELL))
	scale = Vector2.ONE * cam_scale
	_update_camera(1.0)
	queue_redraw()

func _update_camera(delta: float) -> void:
	if data.is_empty():
		return
	var safe := ScreenUtil.safe_rect(get_viewport())
	var map_rect := Rect2(ORIGIN, Vector2(float(data.width), float(data.height)) * CELL)
	# Keep the player a little below centre so the HUD does not cover them.
	var focus := safe.position + Vector2(safe.size.x * 0.5, safe.size.y * 0.54)
	var target := focus - player_pos * cam_scale
	# Clamp so the arena always covers the screen; centre it if it is smaller.
	var min_x := safe.end.x - map_rect.end.x * cam_scale
	var max_x := safe.position.x - map_rect.position.x * cam_scale
	target.x = (min_x + max_x) * 0.5 if min_x > max_x else clampf(target.x, min_x, max_x)
	var min_y := safe.end.y - map_rect.end.y * cam_scale
	var max_y := safe.position.y - map_rect.position.y * cam_scale
	target.y = (min_y + max_y) * 0.5 if min_y > max_y else clampf(target.y, min_y, max_y)
	base_position = base_position.lerp(target, minf(1.0, delta * 9.0))
	position = base_position

func _apply_shake(delta: float) -> void:
	if shake > 0.0:
		shake = maxf(0.0, shake - delta * 26.0)
		position = base_position + Vector2(rng.randf_range(-shake, shake), rng.randf_range(-shake, shake))
	elif position != base_position:
		position = base_position

func _layout_hud() -> void:
	var safe := ScreenUtil.safe_rect(get_viewport())
	if target_icon:
		target_icon.position = safe.position + Vector2(28, 24)
	if counter:
		counter.position = safe.position + Vector2(100, 20)
	if gem_icon:
		gem_icon.position = safe.position + Vector2(250, 32)
	if gem_label:
		gem_label.position = safe.position + Vector2(300, 30)
	if status_label:
		status_label.position = safe.position + Vector2(30, 96)
	if pause_btn:
		pause_btn.position = Vector2(safe.end.x - 84, safe.position.y + 24)
	if hint:
		hint.position = Vector2(safe.position.x, safe.end.y - 50)
		hint.size = Vector2(safe.size.x, 40)

func _load_level(n: int) -> void:
	data = GameState.level_data(n)
	if data.is_empty():
		return
	player_pos = _cell_center(data.spawn[0], data.spawn[1])
	for w in data.walls:
		wall_rects.append(_cover_rect(w))
	for c in data.crates:
		crate_rects.append(_cover_rect(c))
	blocking_rects.clear()
	for rect in wall_rects:
		blocking_rects.append(rect.grow(4.0))
	for rect in crate_rects:
		blocking_rects.append(rect.grow(4.0))
	guard_blocking_rects.clear()
	for rect in blocking_rects:
		guard_blocking_rects.append(rect.grow(GUARD_WALL_MARGIN))

func _cover_rect(item: Array) -> Rect2:
	# Keep the old obstacle centre fixed while enlarging both dimensions by 20%.
	var previous := Rect2(ORIGIN + Vector2(item[0], item[1]) * CELL, Vector2(item[2], item[3]) * CELL).grow(OBSTACLE_GROW)
	var new_size := previous.size * OBSTACLE_SCALE
	return Rect2(previous.get_center() - new_size * 0.5, new_size)

func _cell_center(x: int, y: int) -> Vector2:
	return ORIGIN + Vector2(x + 0.5, y + 0.5) * CELL

func _to_cell(p: Vector2) -> Vector2i:
	return Vector2i(int(floor((p.x - ORIGIN.x) / CELL)), int(floor((p.y - ORIGIN.y) / CELL)))

func _configure_grid(target: AStarGrid2D, diagonals: int) -> void:
	# A level may be reloaded into an existing instance during tests/tools.
	target.clear()
	target.region = Rect2i(0, 0, int(data.width), int(data.height))
	target.cell_size = Vector2.ONE * CELL
	target.offset = ORIGIN + Vector2.ONE * CELL * 0.5
	target.diagonal_mode = diagonals
	target.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	target.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	target.update()

func _build_grid() -> void:
	_configure_grid(grid, AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES)
	# Four-way guard routes stay inside the conservative body-clearance grid.
	_configure_grid(guard_grid, AStarGrid2D.DIAGONAL_MODE_NEVER)
	for y in range(int(data.height)):
		for x in range(int(data.width)):
			var cell := Vector2i(x, y)
			var point := _cell_center(x, y)
			if _solid(point):
				grid.set_point_solid(cell, true)
			if _guard_solid(point):
				guard_grid.set_point_solid(cell, true)

# Separate connected regions stop patrol and search from selecting a cell
# that is player-accessible but too narrow for a guard body.
func _build_walkable_regions() -> void:
	_fill_regions(grid, walkable_regions, region_by_cell)
	_fill_regions(guard_grid, guard_walkable_regions, guard_region_by_cell)

func _fill_regions(source: AStarGrid2D, regions: Array, lookup: Dictionary) -> void:
	regions.clear()
	lookup.clear()
	var directions := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	for y in range(int(data.height)):
		for x in range(int(data.width)):
			var cell := Vector2i(x, y)
			if source.is_point_solid(cell) or lookup.has(cell):
				continue
			var rid := regions.size()
			var queue: Array[Vector2i] = [cell]
			lookup[cell] = rid
			var cursor := 0
			while cursor < queue.size():
				var here := queue[cursor]
				cursor += 1
				for d in directions:
					var next: Vector2i = here + d
					if source.is_in_boundsv(next) and not source.is_point_solid(next) and not lookup.has(next):
						lookup[next] = rid
						queue.append(next)
			regions.append(queue)

func _guard_solid(p: Vector2) -> bool:
	for rect in guard_blocking_rects:
		if rect.has_point(p):
			return true
	return false

func _solid(p: Vector2) -> bool:
	for rect in blocking_rects:
		if rect.has_point(p):
			return true
	return false

# Exact ray/rectangle intersections replace repeated 64-step point sampling.
# The light still uses 40 rays, but this eliminates thousands of rectangle
# checks per guard per frame, a major source of mobile frame-time spikes.
func _raycast_distance(origin: Vector2, direction: Vector2, max_distance: float, nearby: Array[Rect2] = []) -> float:
	var closest := max_distance
	var candidates: Array[Rect2] = nearby if not nearby.is_empty() else blocking_rects
	for rect in candidates:
		var enter := 0.0
		var leave := closest
		if absf(direction.x) < 0.000001:
			if origin.x < rect.position.x or origin.x >= rect.end.x:
				continue
		else:
			var ax := (rect.position.x - origin.x) / direction.x
			var bx := (rect.end.x - origin.x) / direction.x
			enter = maxf(enter, minf(ax, bx))
			leave = minf(leave, maxf(ax, bx))
			if enter > leave:
				continue
		if absf(direction.y) < 0.000001:
			if origin.y < rect.position.y or origin.y >= rect.end.y:
				continue
		else:
			var ay := (rect.position.y - origin.y) / direction.y
			var by := (rect.end.y - origin.y) / direction.y
			enter = maxf(enter, minf(ay, by))
			leave = minf(leave, maxf(ay, by))
			if enter > leave:
				continue
		if leave >= 0.0 and enter <= closest:
			closest = maxf(0.0, enter)
	return closest

func _build_shadows() -> void:
	# Cast short soft shadows down-right from every obstacle.
	for r in wall_rects + crate_rects:
		var s := Rect2(r.position + Vector2(6, 10), r.size + Vector2(10, 14))
		shadow_rects.append(s)

func _build_floor_details() -> void:
	# Scatter drains/arrows on open floor only, using the level RNG for stability.
	var tries := 0
	var placed := 0
	while placed < 9 and tries < 220:
		tries += 1
		var cx := rng.randi_range(1, int(data.width) - 2)
		var cy := rng.randi_range(1, int(data.height) - 2)
		var p := _cell_center(cx, cy)
		if _solid(p) or in_shadow(p):
			continue
		var too_close := false
		for d in floor_details:
			if d.pos.distance_to(p) < 150:
				too_close = true
				break
		if too_close:
			continue
		if placed % 3 == 0:
			floor_details.append({"kind": "drain", "pos": p, "rot": 0.0})
		else:
			floor_details.append({"kind": "arrow", "pos": p, "rot": float(rng.randi_range(0, 3)) * PI / 2.0})
		placed += 1

func in_shadow(p: Vector2) -> bool:
	for r in shadow_rects:
		if r.has_point(p):
			return true
	return false

func _build_player() -> void:
	player_rig = ActorRigScript.new()
	player_rig.setup(GameState.selected_assassin, "player")
	player_rig.set_knife(GameState.selected_knife)
	# Player art was smaller than the guards; enlarge only its visual rig.
	player_rig.scale = Vector2.ONE * PLAYER_SCALE
	player_rig.position = player_pos
	player_rig.rotation = player_face + PI / 2
	add_child(player_rig)

func _build_guards() -> void:
	for index in range(data.guards.size()):
		var g: Dictionary = data.guards[index]
		var route := PackedVector2Array()
		for c in g.route:
			route.append(_cell_center(c[0], c[1]))
		# Three visually differentiated archetypes, present from the first level.
		var variant := "heavy" if bool(g.get("elite", false)) or index % 5 == 2 else ("scout" if index % 3 == 1 else "guard")
		var profile: Dictionary = ENEMY_PROFILES[variant]
		var kind := "elite" if variant == "heavy" else "guard"
		var rig := ActorRigScript.new()
		rig.setup(kind, "guard")
		rig.scale = Vector2.ONE * (0.98 if kind == "elite" else 0.92)
		rig.modulate = profile.tint
		rig.position = _cell_center(g.x, g.y)
		rig.rotation = deg_to_rad(float(g.face)) + PI / 2
		add_child(rig)
		# The red question mark is a world-space sibling, never rotated with the actor.
		var mark := _label(30, 5)
		mark.name = "GuardAlertMark%d" % index
		mark.text = "?"
		mark.size = Vector2(30, 36)
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mark.add_theme_color_override("font_color", Color("ff2938"))
		mark.z_index = 101
		mark.visible = false
		add_child(mark)
		guards.append({
			"id": index, "variant": variant, "shot_damage": float(profile.damage),
			"shot_interval": float(profile.interval), "mark": mark,
			"pos": rig.position, "face": deg_to_rad(float(g.face)),
			"route": route, "ri": 0, "wait": rng.randf_range(0.0, 1.2),
			"hp": 2 if kind == "elite" else 1, "elite": kind == "elite",
			"state": GState.PATROL, "alert": 0.0, "shoot": 0.0, "burst": 0,
			"alive": true, "path": PackedVector2Array(), "pi": 0,
			"last_seen": Vector2.ZERO, "search_t": 0.0, "rig": rig,
			"speed": float(profile.speed), "vision": float(profile.vision),
			"roam_target": Vector2.ZERO, "roam_valid": false,
			"blocked_t": 0.0, "avoid_side": 1.0, "avoid_time": 0.0,
			"avoid_direction": Vector2.ZERO, "walk_hold": 0.0, "sees_player": false,
			"travel_dir": Vector2.ZERO, "traffic_wait": false, "traffic_stall": 0.0,
			"yield_partner": -1, "yield_forward": Vector2.ZERO,
			"yield_side": Vector2.ZERO, "yield_left": 0.0,
			"light_valid": false, "light_age": 0.0, "light_pos": Vector2.ZERO,
			"light_face": 0.0, "light_segments": [],
		})
	total = guards.size()

func _sync_guard_marker(g: Dictionary) -> void:
	var mark: Label = g.mark
	mark.visible = bool(g.alive) and g.state in [GState.INVESTIGATE, GState.ALERT, GState.SEARCH]
	mark.position = g.pos + Vector2(-15, -62)

func _build_hud() -> void:
	var cl := CanvasLayer.new()
	add_child(cl)
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(hud)
	var icon := TextureRect.new()
	target_icon = icon
	icon.texture = TARGET_TEX
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.position = Vector2(28, 24)
	icon.size = Vector2(64, 64)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(icon)
	counter = _label(52, 10)
	counter.position = Vector2(100, 20)
	hud.add_child(counter)
	_update_counter()
	var gi := TextureRect.new()
	gem_icon = gi
	gi.texture = GEM_TEX
	gi.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gi.position = Vector2(250, 32)
	gi.size = Vector2(44, 44)
	gi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(gi)
	gem_label = _label(36, 6)
	gem_label.position = Vector2(300, 30)
	gem_label.text = "0"
	hud.add_child(gem_label)
	status_label = _label(24, 4)
	status_label.position = Vector2(30, 96)
	status_label.add_theme_color_override("font_color", Color("7CFC7C"))
	status_label.text = "HIDDEN"
	hud.add_child(status_label)
	var pause := Button.new()
	pause_btn = pause
	pause.text = "II"
	pause.position = Vector2(636, 24)
	pause.size = Vector2(60, 60)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.11, 0.16, 0.8)
	sb.set_corner_radius_all(14)
	pause.add_theme_stylebox_override("normal", sb)
	pause.add_theme_font_size_override("font_size", 28)
	pause.pressed.connect(_pause)
	hud.add_child(pause)
	hint = _label(22, 4)
	hint.position = Vector2(0, 1230)
	hint.size = Vector2(720, 40)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(hint)

func _build_player_health_bar() -> void:
	# Sibling of the rotating actor: stays horizontal and follows over their head.
	player_health_anchor = Control.new()
	player_health_anchor.name = "PlayerHealthBar"
	player_health_anchor.size = HEALTH_BAR_SIZE
	player_health_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_health_anchor.z_index = 100
	add_child(player_health_anchor)
	player_health_bar = ProgressBar.new()
	player_health_bar.name = "Fill"
	player_health_bar.show_percentage = false
	player_health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("1b2a22")
	bg.border_color = Color("0b1611")
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(3)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("39de5a")
	fill.set_corner_radius_all(3)
	player_health_bar.add_theme_stylebox_override("background", bg)
	player_health_bar.add_theme_stylebox_override("fill", fill)
	player_health_anchor.add_child(player_health_bar)
	# Size after disabling percentage/applying theme: Godot's default font-based
	# minimum would otherwise leave the green bar 27 units tall.
	player_health_bar.size = HEALTH_BAR_SIZE
	player_health_label = _label(17, 3)
	player_health_label.name = "Value"
	# Keep the numeric health readable above the slim green fill.
	player_health_label.position = Vector2(0, -27)
	player_health_label.size = Vector2(HEALTH_BAR_SIZE.x, 27)
	player_health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_health_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	player_health_anchor.add_child(player_health_label)
	_update_player_health_bar()

func _update_player_health_bar() -> void:
	if player_health_anchor == null:
		return
	player_health_anchor.position = player_pos + Vector2(-HEALTH_BAR_SIZE.x * 0.5, -52)
	player_health_bar.max_value = GameState.max_health()
	player_health_bar.value = clampf(player_hp, 0.0, player_health_bar.max_value)
	player_health_label.text = str(maxi(0, ceili(player_hp)))

func _label(size: int, outline: int) -> Label:
	var l := Label.new()
	var fv := FontVariation.new()
	fv.base_font = FONT
	fv.variation_embolden = 0.7
	l.add_theme_font_override("font", fv)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_constant_override("outline_size", outline)
	l.add_theme_color_override("font_outline_color", Color("101218"))
	l.add_theme_color_override("font_color", Color.WHITE)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _update_counter() -> void:
	counter.text = "%d/%d" % [kills, total]

func _physics_process(delta: float) -> void:
	if finished or overlay != null:
		return
	# Micro hit-stop makes each takedown feel weighty.
	if hit_stop > 0.0:
		hit_stop -= delta
		_update_effects(delta)
		_update_camera(delta)
		_apply_shake(delta)
		queue_redraw()
		return
	_update_camera(delta)
	_apply_shake(delta)
	elapsed += delta
	invuln = maxf(0, invuln - delta)
	attack_cd = maxf(0, attack_cd - delta)
	repath = maxf(0, repath - delta)
	# Continuous steering while dragging.
	if dragging and hunt_target < 0:
		drag_repath -= delta
		if drag_dirty and drag_repath <= 0.0:
			drag_repath = DRAG_REPATH_INTERVAL
			drag_dirty = false
			_path_to(drag_target)
	_update_hunt()
	_move_player(delta)
	# Resolve light contact before melee so a guard can fire immediately even
	# when the player enters the beam at point-blank range.
	_update_guards(delta)
	_auto_attack()
	_update_bullets(delta)
	_update_gems(delta)
	_update_effects(delta)
	_update_stealth_hud()
	if kills >= total and not finished:
		_win()
	queue_redraw()

func _update_hunt() -> void:
	if hunt_target < 0 or hunt_target >= guards.size():
		return
	var g: Dictionary = guards[hunt_target]
	if not g.alive:
		hunt_target = -1
		return
	if repath <= 0:
		repath = 0.25
		_path_to(g.pos)

func _move_player(delta: float) -> void:
	var speed: float = GameState.player_speed()
	var budget := speed * delta
	var before := player_pos
	while player_path.size() > 0 and budget > 0.0:
		var target: Vector2 = player_path[0]
		var d := player_pos.distance_to(target)
		if d <= 0.001:
			player_path.remove_at(0)
		elif d <= budget:
			player_pos = target
			player_path.remove_at(0)
			budget -= d
		else:
			player_pos += (target - player_pos) / d * budget
			budget = 0.0
	var displacement := player_pos - before
	var moved := displacement.length_squared() > 0.0001
	if moved:
		# Smooth facing across route corners instead of snapping to every grid turn.
		player_face = lerp_angle(player_face, displacement.angle(), 1.0 - exp(-16.0 * delta))
	player_rig.position = player_pos
	player_rig.rotation = player_face + PI / 2
	if player_health_anchor:
		player_health_anchor.position = player_pos + Vector2(-HEALTH_BAR_SIZE.x * 0.5, -52)
	player_rig.set_moving(moved)
	if invuln > 0 and int(invuln * 12) % 2 == 0:
		player_rig.modulate = Color(1, 0.5, 0.5)
	else:
		player_rig.modulate = Color.WHITE

func _path_to(target: Vector2) -> void:
	var from := _to_cell(player_pos)
	var requested := _to_cell(target)
	requested.x = clampi(requested.x, 0, int(data.width) - 1)
	requested.y = clampi(requested.y, 0, int(data.height) - 1)
	if not grid.is_in_boundsv(from) or grid.is_point_solid(from):
		player_path.clear()
		return
	var rid := int(region_by_cell.get(from, -1))
	if rid < 0:
		player_path.clear()
		return
	var destination := requested
	if int(region_by_cell.get(requested, -1)) != rid:
		# Nearest reachable cell to a tap on cover/outside/disconnected space.
		# This avoids AStar's expensive partial search toward a solid end node.
		var closest := INF
		for c in walkable_regions[rid]:
			var dist: float = _cell_center(c.x, c.y).distance_squared_to(target)
			if dist < closest:
				closest = dist
				destination = c
	var route: PackedVector2Array = grid.get_point_path(from, destination)
	if route.is_empty():
		player_path.clear()
		return
	if route.size() == 1:
		route.clear()
	elif _los(player_pos, route[1]):
		route.remove_at(0)
	var map_rect := Rect2(ORIGIN, Vector2(float(data.width), float(data.height)) * CELL)
	if destination == requested and map_rect.has_point(target) and not _solid(target):
		var last: Vector2 = route[route.size() - 1] if not route.is_empty() else player_pos
		if last.distance_to(target) > 0.5 and _los(last, target):
			route.append(target)
	player_path = route

func _route_visual_points() -> PackedVector2Array:
	# This is the actual remaining AStar route, not a straight-line guess.
	var points := PackedVector2Array()
	if player_path.is_empty():
		return points
	points.append(player_pos)
	for waypoint in player_path:
		if points[points.size() - 1].distance_squared_to(waypoint) > 0.01:
			points.append(waypoint)
	return points if points.size() > 1 else PackedVector2Array()

func _route_arrow_points() -> PackedVector2Array:
	var route := _route_visual_points()
	if route.size() < 2:
		return PackedVector2Array()
	var tip: Vector2 = route[route.size() - 1]
	# Find a point a fixed distance back ALONG the real route, rather than
	# scaling to the final tiny AStar fragment. Tiny end fragments used to make
	# the arrow flash, shrink and rotate erratically while the player walked.
	var remaining := 14.0
	var anchor := tip
	var length := 0.0
	for i in range(route.size() - 1, 0, -1):
		var end: Vector2 = route[i]
		var start: Vector2 = route[i - 1]
		var segment := end.distance_to(start)
		if segment <= 0.001:
			continue
		var used := minf(segment, remaining)
		anchor = end.lerp(start, used / segment)
		length += used
		remaining -= used
		if remaining <= 0.001:
			break
	var direction := (tip - anchor).normalized()
	if direction.length_squared() < 0.001 or length < 2.0:
		return PackedVector2Array()
	var size := minf(12.0, length * 0.80)
	var side := Vector2(-direction.y, direction.x) * size * 0.48
	var base := tip - direction * size
	return PackedVector2Array([tip, base + side, base - side])

func _draw_route() -> void:
	var points := _route_visual_points()
	if points.size() < 2:
		return
	draw_polyline(points, Color(0.02, 0.08, 0.12, 0.70), 7.0, true)
	draw_polyline(points, Color(0.42, 0.94, 1.0, 0.92), 3.2, true)
	# A small arrowhead belongs to the actual path endpoint, not a tap pulse.
	var arrow := _route_arrow_points()
	if arrow.size() == 3:
		draw_colored_polygon(arrow, Color(0.42, 0.94, 1.0, 0.96))

func _auto_attack() -> void:
	if attack_cd > 0:
		return
	var best := -1
	var best_d := GameState.attack_range()
	for i in range(guards.size()):
		var g: Dictionary = guards[i]
		if not g.alive:
			continue
		var d: float = player_pos.distance_to(g.pos)
		if d < best_d and _los(player_pos, g.pos):
			best_d = d
			best = i
	if best < 0:
		return
	var g: Dictionary = guards[best]
	attack_cd = GameState.attack_cooldown()
	# Behind the guard's facing arc => silent instant kill, no alert noise.
	var to_player: Vector2 = (player_pos - g.pos).normalized()
	var facing := Vector2.from_angle(g.face)
	var from_behind := facing.dot(to_player) < -0.25
	var unaware: bool = g.state != GState.ALERT
	player_face = (g.pos - player_pos).angle()
	player_rig.rotation = player_face + PI / 2
	player_rig.play_anim("attack", true)
	effects.append({"pos": g.pos, "t": 0.22, "max": 0.22, "kind": "slash", "angle": player_face})
	Sfx.play("blade")
	GameState.vibrate(18)
	if from_behind and unaware:
		g.hp = 0
		backstabs += 1
		effects.append({"pos": g.pos + Vector2(0, -34), "t": 0.8, "max": 0.8, "kind": "backstab"})
	else:
		g.hp -= GameState.player_damage()
	if g.hp <= 0:
		_kill_guard(best, from_behind and unaware)
	else:
		g.alert = 1.0
		g.state = GState.ALERT
		g.last_seen = player_pos
		g.rig.play_anim("hurt", true)

func _kill_guard(index: int, silent := false) -> void:
	var g: Dictionary = guards[index]
	g.alive = false
	g.state = GState.DEAD
	_sync_guard_marker(g)
	g.rig.die()
	kills += 1
	_update_counter()
	effects.append({"pos": g.pos, "t": 0.4, "max": 0.4, "kind": "poof"})
	# Hunter-Assassin style takedown feedback: shock ring + gem fountain + counter pop.
	effects.append({"pos": g.pos, "t": 0.45, "max": 0.45, "kind": "killring"})
	var drop := (12 if g.elite else 8) if silent else (8 if g.elite else 5)
	effects.append({"pos": g.pos + Vector2(0, -18), "t": 0.9, "max": 0.9, "kind": "gemtext", "amount": drop})
	shake = maxf(shake, 5.0)
	hit_stop = 0.055
	for i in range(drop):
		var a := TAU * float(i) / float(drop) + rng.randf_range(-0.3, 0.3)
		var sp := rng.randf_range(90, 190)
		gems.append({"pos": g.pos + Vector2.from_angle(a) * 6.0,
			"vel": Vector2.from_angle(a) * sp, "t": 0.0})
	# Nearby guards hear the takedown unless deep in shadow.
	var noise := 0.0 if silent else (70.0 if in_shadow(player_pos) else 130.0)
	for other in guards:
		if other.alive and other.pos.distance_to(g.pos) < noise and other.state == GState.PATROL:
			_investigate(other, g.pos)
	if hunt_target == index:
		hunt_target = -1

func _alarm_others(source: Dictionary) -> void:
	# A gunshot alerts nearby guards, not the entire map. They investigate the
	# last known player position and still need line of sight before shooting.
	for other in guards:
		if other == source or not other.alive or other.state == GState.ALERT:
			continue
		if other.pos.distance_squared_to(source.pos) > GUNSHOT_HEARING_RADIUS * GUNSHOT_HEARING_RADIUS:
			continue
		var new_target := player_pos
		var target_changed: bool = other.last_seen.distance_squared_to(new_target) > CELL * CELL * 4.0
		if other.state == GState.SEARCH and not target_changed:
			# Repeated bursts should not jerk a searching guard back into a
			# new path toward the same overcrowded point every 0.14 seconds.
			other.search_t = maxf(other.search_t, 3.0)
		elif other.state != GState.INVESTIGATE or target_changed:
			_investigate(other, new_target)
		else:
			other.last_seen = new_target
			other.search_t = 3.0
		_sync_guard_marker(other)

func _investigate(g: Dictionary, p: Vector2) -> void:
	g.state = GState.INVESTIGATE
	g.last_seen = p
	g.search_t = 3.0
	g.blocked_t = 0.0
	g.avoid_time = 0.0
	g.path.clear()

func _update_guards(delta: float) -> void:
	for g in guards:
		if not g.alive:
			_sync_guard_marker(g)
			continue
		var previous_position: Vector2 = g.pos
		g.light_age += delta
		var sees := _can_see(g.pos, g.face, player_pos, g.vision)
		var first_contact: bool = sees and not g.sees_player
		if sees:
			# Visible flashlight contact means immediate detection and the first
			# shot in this physics tick, including after reacquiring the player.
			if first_contact:
				g.shoot = 0.0
				g.burst = 0
			if g.state != GState.ALERT:
				Sfx.play("alert")
				was_alerted = true
			g.alert = 1.0
			g.last_seen = player_pos
			g.state = GState.ALERT
		else:
			g.alert = maxf(0, g.alert - delta * 0.7)
		g.sees_player = sees
		match g.state:
			GState.PATROL:
				_patrol(g, delta)
			GState.INVESTIGATE:
				_seek(g, g.last_seen, delta, g.speed * 1.25)
				if g.pos.distance_to(g.last_seen) < 18 or g.blocked_t > 2.5:
					# If other guards occupy the target, search from here rather
					# than endlessly squeezing together and jittering.
					g.state = GState.SEARCH
					g.search_t = 2.5
					g.blocked_t = 0.0
					g.path.clear()
			GState.ALERT:
				var target_angle: float = (player_pos - g.pos).angle()
				g.face = target_angle if first_contact else lerp_angle(g.face, target_angle, minf(1.0, delta * 10))
				if sees:
					# Snap the gun to the target on the first frame so the visible
					# muzzle matches the immediate shot instead of raising late.
					g.rig.set_aiming(true, angle_difference(g.face, target_angle), first_contact)
					g.shoot -= delta
					if g.shoot <= 0:
						_fire(g)
						g.shoot = float(g.shot_interval)
				else:
					_seek(g, g.last_seen, delta, g.speed * 1.5)
					if g.pos.distance_to(g.last_seen) < 18 or g.blocked_t > 2.5:
						g.state = GState.SEARCH
						g.search_t = 3.0
						g.blocked_t = 0.0
						g.path.clear()
			GState.SEARCH:
				g.search_t -= delta
				g.face += delta * 1.6
				if g.search_t <= 0:
					g.state = GState.PATROL
					g.alert = 0.0
					g.path.clear()
		g.rig.position = g.pos
		g.rig.rotation = g.face + PI / 2
		var did_move: bool = g.pos.distance_squared_to(previous_position) > 0.0001
		g.walk_hold = 0.12 if did_move else maxf(0.0, g.walk_hold - delta)
		g.rig.set_moving(did_move or g.walk_hold > 0.0)
		var player_direction: Vector2 = player_pos - g.pos
		var aim_offset: float = angle_difference(g.face, player_direction.angle()) if player_direction.length_squared() > 0.001 else 0.0
		g.rig.set_aiming(sees, aim_offset)
		_sync_guard_marker(g)

func _fire(g: Dictionary) -> void:
	var toward_player: Vector2 = player_pos - g.pos
	var dir: Vector2 = toward_player.normalized() if toward_player.length_squared() > 0.001 else Vector2.from_angle(g.face)
	# Never place a point-blank muzzle beyond the player.
	var muzzle_offset := minf(24.0, maxf(0.0, toward_player.length() - PLAYER_HIT_RADIUS * 0.5))
	bullets.append({"pos": g.pos + dir * muzzle_offset, "vel": dir * 420.0,
		"life": 1.6, "damage": float(g.get("shot_damage", BULLET_DAMAGE))})
	# The muzzle flash is attached to the moving gun, not floating in the world.
	g.rig.play_anim("shoot", true)
	Sfx.play("shot")
	_alarm_others(g)

func _choose_roam_target(g: Dictionary) -> bool:
	var from := _to_cell(g.pos)
	var region := int(guard_region_by_cell.get(from, -1))
	if region < 0:
		return false
	var cells: Array = guard_walkable_regions[region]
	if cells.size() < 2:
		return false
	var choice := from
	var fallback := from
	var best_distance := 0.0
	var fallback_distance := 0.0
	# Prefer a long-range route whose first step does not push directly into
	# another guard. This also helps clear a queue after a crowded doorway.
	for attempt in range(mini(36, cells.size() * 2)):
		var cell: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
		var point := _cell_center(cell.x, cell.y)
		var distance := point.distance_squared_to(g.pos)
		var occupied := false
		for other in guards:
			if other.rig != g.rig and other.alive and point.distance_squared_to(other.pos) < (GUARD_GAP * 1.25) * (GUARD_GAP * 1.25):
				occupied = true
				break
		if occupied:
			continue
		if distance > fallback_distance:
			fallback = cell
			fallback_distance = distance
		var route: PackedVector2Array = guard_grid.get_point_path(from, cell)
		if route.size() < 2:
			continue
		var initial: Vector2 = (route[1] - g.pos).normalized()
		var crowded := false
		for other in guards:
			if other.rig == g.rig or not other.alive:
				continue
			var offset: Vector2 = other.pos - g.pos
			if offset.length_squared() < (GUARD_GAP * 1.8) * (GUARD_GAP * 1.8) and initial.dot(offset.normalized()) > 0.35:
				crowded = true
				break
		if crowded:
			continue
		if distance > best_distance:
			choice = cell
			best_distance = distance
		if distance >= (CELL * 6.0) * (CELL * 6.0):
			break
	if choice == from:
		choice = fallback
	if choice == from:
		return false
	g.roam_target = _cell_center(choice.x, choice.y)
	g.roam_valid = true
	g.blocked_t = 0.0
	g.path.clear()
	return true

func _patrol(g: Dictionary, delta: float) -> void:
	if g.wait > 0:
		g.wait -= delta
		return
	if not g.roam_valid:
		if not _choose_roam_target(g):
			g.wait = 0.4
			g.face += delta * 0.45
			return
	_seek(g, g.roam_target, delta, g.speed)
	if g.pos.distance_to(g.roam_target) < 10.0 or g.blocked_t > 2.0:
		g.roam_valid = false
		g.path.clear()
		g.wait = rng.randf_range(0.15, 0.65)

func _guard_line_clear(start: Vector2, finish: Vector2) -> bool:
	if not grid.is_in_boundsv(_to_cell(finish)):
		return false
	for rect in guard_blocking_rects:
		if rect.has_point(finish):
			return false
	var motion := finish - start
	var distance := motion.length()
	return distance <= 0.0001 or _raycast_distance(start, motion / distance, distance, guard_blocking_rects) >= distance - 0.001

func _guard_step_clear(g: Dictionary, candidate: Vector2) -> bool:
	# Guard bodies need more wall clearance than the player-centre ray.
	if not _guard_line_clear(g.pos, candidate):
		return false
	var destination_cell := _to_cell(candidate)
	if not guard_grid.is_in_boundsv(destination_cell) or guard_grid.is_point_solid(destination_cell):
		return false
	for other in guards:
		if not other.alive or other.rig == g.rig:
			continue
		var before: float = g.pos.distance_to(other.pos)
		var after := candidate.distance_to(other.pos)
		if before < GUARD_GAP:
			# If a prior placement was already close, only separate further.
			if after < before - 0.0001:
				return false
		elif _segment_circle(g.pos, candidate, other.pos, GUARD_GAP - 0.05):
			return false
	return true

# Is this a single-file passage for two guard-sized bodies? Test the actual
# expanded cover, not just the rendered tiles, so the result works at any gate.
func _narrow_gate_at(point: Vector2, forward: Vector2) -> bool:
	var side := Vector2(-forward.y, forward.x) * (GUARD_GAP * 0.8)
	var open := 0
	for probe in [point + side, point - side]:
		var cell := _to_cell(probe)
		if guard_grid.is_in_boundsv(cell) and not guard_grid.is_point_solid(cell) and _guard_line_clear(point, probe):
			open += 1
	return open == 0

func _gate_axis_at(point: Vector2) -> Vector2:
	var horizontal := _narrow_gate_at(point, Vector2.RIGHT)
	var vertical := _narrow_gate_at(point, Vector2.DOWN)
	if horizontal and not vertical:
		return Vector2.RIGHT
	if vertical and not horizontal:
		return Vector2.DOWN
	return Vector2.ZERO

func _blocking_guard(g: Dictionary, desired: Vector2) -> Dictionary:
	var nearest := INF
	var blocker: Dictionary = {}
	for other in guards:
		if not other.alive or other.rig == g.rig:
			continue
		if _segment_circle(g.pos, desired, other.pos, GUARD_GAP - 0.05):
			var distance: float = g.pos.distance_squared_to(other.pos)
			if distance < nearest:
				nearest = distance
				blocker = other
	return blocker

func _guard_by_id(id: int) -> Dictionary:
	for other in guards:
		if int(other.id) == id and other.alive:
			return other
	return {}

func _yield_at_gate(g: Dictionary, movement: Vector2) -> Vector2:
	var other := _guard_by_id(int(g.yield_partner))
	var forward: Vector2 = g.yield_forward
	if other.is_empty() or (other.pos - g.pos).dot(forward) < -GUARD_GAP * 0.30:
		# The priority guard has passed. Replan from this new location.
		g.yield_partner = -1
		g.yield_side = Vector2.ZERO
		g.yield_left = 0.0
		g.path.clear()
		g.pi = 0
		g.traffic_wait = true
		return g.pos
	var step := movement.length()
	if step < 0.0001:
		g.traffic_wait = true
		return g.pos
	var side: Vector2 = g.yield_side
	if side == Vector2.ZERO and not _narrow_gate_at(g.pos, forward):
		# Once clear of the doorway, move into a side pocket. Commit to this
		# direction until there is enough space; don't flip left/right per frame.
		var perpendicular := Vector2(-forward.y, forward.x)
		var preference := signf((g.pos - other.pos).dot(perpendicular))
		if is_zero_approx(preference):
			preference = 1.0 if int(g.id) % 2 == 0 else -1.0
		for sign in [preference, -preference]:
			var trial: Vector2 = perpendicular * sign
			var probe: Vector2 = g.pos + trial * (GUARD_GAP + 8.0)
			var probe_cell := _to_cell(probe)
			if guard_grid.is_in_boundsv(probe_cell) and not guard_grid.is_point_solid(probe_cell) and _guard_line_clear(g.pos, probe):
				g.yield_side = trial
				g.yield_left = GUARD_GAP + 8.0
				side = trial
				break
	if side != Vector2.ZERO and g.yield_left > 0.0:
		var lateral: Vector2 = g.pos + side * minf(step, g.yield_left)
		if _guard_step_clear(g, lateral):
			g.yield_left = maxf(0.0, g.yield_left - step)
			g.traffic_wait = true
			return lateral
		# The grid may conservatively block the next cell even when its exact
		# edge was clear. Back farther into the room before choosing a side.
		var lateral_cell := _to_cell(lateral)
		if guard_grid.is_in_boundsv(lateral_cell) and guard_grid.is_point_solid(lateral_cell):
			g.yield_side = Vector2.ZERO
			side = Vector2.ZERO
	# In a tight gate, back out without trying to pass through the other actor.
	# If parked at the side pocket, wait for the priority guard to finish passing.
	if side == Vector2.ZERO:
		var back: Vector2 = g.pos - forward * step
		if _guard_step_clear(g, back):
			g.traffic_wait = true
			return back
		# If another lower-priority guard is immediately behind, ask it to
		# back out as well. This propagates a queue rather than trapping a
		# yielding guard between a doorway and its own follower.
		var follower := _blocking_guard(g, back)
		if not follower.is_empty() and int(follower.id) > int(g.id) and int(follower.yield_partner) < 0:
			follower.yield_partner = int(g.id)
			follower.yield_forward = forward
			follower.yield_side = Vector2.ZERO
			follower.yield_left = 0.0
			follower.avoid_time = 0.0
	g.traffic_wait = true
	return g.pos

func _guard_step(g: Dictionary, desired: Vector2, delta: float) -> Vector2:
	var movement: Vector2 = desired - g.pos
	g.traffic_wait = false
	if movement.length_squared() < 0.000001:
		return g.pos
	if int(g.yield_partner) >= 0:
		return _yield_at_gate(g, movement)
	var blocker := _blocking_guard(g, desired)
	if not blocker.is_empty():
		# The depot gates are axis-aligned. Retire straight along the doorway,
		# not along a diagonal target line that can run into the jamb.
		var forward := Vector2(signf(movement.x), 0.0) if absf(movement.x) >= absf(movement.y) else Vector2(0.0, signf(movement.y))
		var other_forward: Vector2 = blocker.travel_dir
		var dot := forward.dot(other_forward)
		var single_file := _narrow_gate_at(g.pos, forward) or _narrow_gate_at(blocker.pos, forward)
		if single_file and other_forward.length_squared() > 0.20:
			g.avoid_time = 0.0
			if dot < 0.45 and int(g.id) > int(blocker.id):
				# Stable right-of-way for opposing or crossing traffic: the
				# higher ID yields and waits until the other has passed.
				g.yield_partner = int(blocker.id)
				g.yield_forward = forward
				g.yield_side = Vector2.ZERO
				g.yield_left = 0.0
				return _yield_at_gate(g, movement)
			# Same-direction followers and the priority guard wait in place.
			g.traffic_wait = true
			return g.pos
	# Commit to a brief passing direction rather than flipping sides each frame.
	# This hysteresis prevents two approaching guards from vibrating in place.
	if g.avoid_time > 0.0:
		var held: Vector2 = g.pos + g.avoid_direction * movement.length()
		g.avoid_time = maxf(0.0, g.avoid_time - delta)
		if _guard_step_clear(g, held):
			return held
		if _guard_step_clear(g, desired):
			g.avoid_time = 0.0
			return desired
		# A wall or another body blocked the committed side. Wait briefly
		# rather than instantly flipping to the opposite side every frame.
		return g.pos
	if _guard_step_clear(g, desired):
		return desired
	# Both oncoming guards choose their own right-hand side, so they pass on
	# opposite sides. A blocked wall/guard causes a brief wait, not an overlap.
	var side: float = g.avoid_side
	for angle in [side * PI / 3.0, side * PI / 2.0, -side * PI / 3.0, -side * PI / 2.0]:
		var candidate: Vector2 = g.pos + movement.rotated(angle)
		if _guard_step_clear(g, candidate):
			g.avoid_direction = (candidate - g.pos).normalized()
			g.avoid_time = GUARD_AVOID_HOLD
			g.avoid_side = signf(angle)
			return candidate
	return g.pos

func _seek(g: Dictionary, target: Vector2, delta: float, speed: float) -> void:
	if g.path.size() == 0:
		var from := _to_cell(g.pos)
		var to := _to_cell(target)
		var region := int(guard_region_by_cell.get(from, -1))
		if region >= 0 and int(guard_region_by_cell.get(to, -1)) != region:
			# Investigate the nearest point a guard can actually reach when the
			# last-seen player is tight against cover or outside its clearance.
			var nearest := INF
			for cell in guard_walkable_regions[region]:
				var distance: float = _cell_center(cell.x, cell.y).distance_squared_to(target)
				if distance < nearest:
					nearest = distance
					to = cell
		if region >= 0 and guard_grid.is_in_boundsv(to) and not guard_grid.is_point_solid(to):
			g.path = guard_grid.get_point_path(from, to)
			if from == to:
				g.path.clear()
				if g.pos.distance_to(target) > 0.5 and _guard_line_clear(g.pos, target):
					g.path.append(target)
			elif g.path.size() > 1 and _guard_line_clear(g.pos, g.path[1]):
				g.path.remove_at(0)
			g.pi = 0
	# A sidestep may leave a cell-centre waypoint behind the guard. Skip any
	# obsolete waypoint once the next one is safely visible, instead of
	# repeatedly walking backward to that old centre and jittering.
	while g.pi + 1 < g.path.size() and _guard_line_clear(g.pos, g.path[g.pi + 1]):
		g.pi += 1
	var budget := speed * delta
	while g.pi < g.path.size() and budget > 0.0:
		var waypoint: Vector2 = g.path[g.pi]
		var d: float = g.pos.distance_to(waypoint)
		if d < 0.001:
			g.pi += 1
			continue
		var start: Vector2 = g.pos
		var step := minf(d, budget)
		var direction := (waypoint - start).normalized()
		# Do not cut diagonally into the jamb of a narrow doorway; continue
		# through the gate's axis before turning toward the next waypoint.
		var gate_axis := _gate_axis_at(start)
		if gate_axis != Vector2.ZERO:
			var along := (waypoint - start).dot(gate_axis)
			if absf(along) > 0.5:
				direction = gate_axis * signf(along)
				step = minf(step, absf(along))
		var wanted: Vector2 = start + direction * step
		g.travel_dir = direction
		var accepted := _guard_step(g, wanted, delta)
		g.pos = accepted
		var displacement := accepted - start
		if displacement.length_squared() > 0.00001:
			g.face = lerp_angle(g.face, displacement.angle(), minf(1.0, delta * 8.0))
		if accepted.distance_squared_to(wanted) > 0.0001:
			# Queueing is deliberate, but a doorway with no side pocket must
			# not strand a guard forever: after a stationary timeout, re-route
			# a patrol or search from the best currently reachable position.
			if g.traffic_wait:
				if displacement.length_squared() <= 0.00001:
					g.traffic_stall += delta
				else:
					g.traffic_stall = maxf(0.0, g.traffic_stall - delta * 2.0)
				if g.traffic_stall >= 2.5:
					g.traffic_stall = 0.0
					g.yield_partner = -1
					g.yield_side = Vector2.ZERO
					g.avoid_time = 0.0
					g.blocked_t = 3.0
					g.path.clear()
					g.pi = 0
			else:
				g.traffic_stall = 0.0
				g.blocked_t += delta
			budget = 0.0
		else:
			g.traffic_stall = maxf(0.0, g.traffic_stall - delta * 2.0)
			g.blocked_t = maxf(0.0, g.blocked_t - delta * 2.0)
			budget -= step
			if d <= step + 0.001:
				g.pi += 1
	if g.pi >= g.path.size():
		g.path.clear()

func _can_see(from: Vector2, face: float, target: Vector2, vision: float = 250.0) -> bool:
	var d := from.distance_to(target)
	# Detection matches the visible 30-degree half-cone, including when the
	# edge of the player's body touches it. Cover still blocks the whole ray.
	if d > vision + PLAYER_LIGHT_RADIUS:
		return false
	var ang := (target - from).angle()
	var body_margin := asin(clampf(PLAYER_LIGHT_RADIUS / maxf(d, 0.001), 0.0, 1.0))
	if absf(angle_difference(face, ang)) > deg_to_rad(30) + body_margin:
		return false
	return _los(from, target)

func _los(a: Vector2, b: Vector2) -> bool:
	var v := b - a
	var d := v.length()
	if d <= 0.001:
		return not _solid(a)
	return _raycast_distance(a, v / d, d) >= d - 0.001

func _update_bullets(delta: float) -> void:
	for i in range(bullets.size() - 1, -1, -1):
		var b: Dictionary = bullets[i]
		var old: Vector2 = b.pos
		var travel: Vector2 = b.vel * delta
		var distance := travel.length()
		var wall_distance := _raycast_distance(old, travel / distance, distance) if distance > 0.0001 else 0.0
		var blocked := distance > 0.0001 and wall_distance < distance - 0.001
		b.pos = old + (travel / distance * wall_distance if blocked else travel)
		b.life -= delta
		var hit := false
		# Sweep to the first wall so a low-frame-rate bullet cannot tunnel
		# through cover or hit someone who is behind it.
		if invuln <= 0 and b.life > 0 and _segment_circle(old, b.pos, player_pos, PLAYER_HIT_RADIUS):
			player_hp = maxf(0.0, player_hp - float(b.get("damage", BULLET_DAMAGE)))
			damage_taken += 1
			invuln = 0.35
			_update_player_health_bar()
			player_rig.play_anim("hurt", true)
			effects.append({"pos": player_pos, "t": 0.3, "max": 0.3, "kind": "hurt"})
			Sfx.play("hurt")
			GameState.vibrate(60)
			hit = true
			if player_hp <= 0:
				player_rig.die()
				_lose()
		elif blocked or _solid(b.pos) or b.life <= 0:
			hit = true
			effects.append({"pos": b.pos, "t": 0.15, "max": 0.15, "kind": "spark"})
		if hit:
			bullets.remove_at(i)

func _segment_circle(a: Vector2, b: Vector2, c: Vector2, r: float) -> bool:
	var ab := b - a
	var t := clampf((c - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
	return (a + ab * t).distance_to(c) <= r

func _update_gems(delta: float) -> void:
	for i in range(gems.size() - 1, -1, -1):
		var gm: Dictionary = gems[i]
		gm.t += delta
		gm.pos += gm.vel * delta
		gm.vel = gm.vel.lerp(Vector2.ZERO, delta * 6)
		var d: float = gm.pos.distance_to(player_pos)
		if d < 130:
			gm.pos = gm.pos.lerp(player_pos, delta * 9)
		if d < 22:
			gems_collected += 1
			gem_label.text = str(gems_collected)
			Sfx.play("coin")
			gems.remove_at(i)

func _update_effects(delta: float) -> void:
	for i in range(effects.size() - 1, -1, -1):
		effects[i].t -= delta
		if effects[i].t <= 0:
			effects.remove_at(i)

func _update_stealth_hud() -> void:
	var seen := false
	for g in guards:
		if g.alive and g.state == GState.ALERT:
			seen = true
	if seen:
		status_label.text = "SPOTTED!"
		status_label.add_theme_color_override("font_color", Color("ff5a6e"))
	elif in_shadow(player_pos):
		status_label.text = "IN SHADOW"
		status_label.add_theme_color_override("font_color", Color("7CFC7C"))
	else:
		status_label.text = "EXPOSED"
		status_label.add_theme_color_override("font_color", Color("ffd23f"))

func _unhandled_input(event: InputEvent) -> void:
	if finished or overlay != null:
		return
	if event.is_action_pressed("ui_cancel"):
		_pause()
		return
	var local := Vector2.ZERO
	var press := false
	var release := false
	var motion := false
	if event is InputEventScreenTouch:
		local = make_input_local(event).position
		press = event.pressed
		release = not event.pressed
	elif event is InputEventScreenDrag:
		local = make_input_local(event).position
		motion = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# A touch can also emit an emulated mouse event; handle it only once.
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		local = make_input_local(event).position
		press = event.pressed
		release = not event.pressed
	elif event is InputEventMouseMotion and dragging:
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		local = make_input_local(event).position
		motion = true
	else:
		return
	if press:
		dragging = true
		drag_target = local
		var picked := -1
		var nearest := 44.0
		for i in range(guards.size()):
			if guards[i].alive and guards[i].pos.distance_to(local) < nearest:
				nearest = guards[i].pos.distance_to(local)
				picked = i
		if picked >= 0:
			hunt_target = picked
			repath = 0.0
			dragging = false
			_path_to(guards[picked].pos)
		else:
			hunt_target = -1
			_path_to(local)
			drag_repath = DRAG_REPATH_INTERVAL
			drag_dirty = false
	elif motion and dragging:
		# Update the target immediately; the physics tick throttles replanning.
		if drag_target.distance_squared_to(local) > 1.0:
			drag_target = local
			drag_dirty = true
	elif release:
		if dragging and hunt_target < 0:
			drag_target = local
			_path_to(local)
		dragging = false
		drag_dirty = false
		drag_repath = 0.0

func _draw() -> void:
	# Highlight only the player's actual remaining path, below cover and actors.
	_draw_route()
	# Only cast cones that can actually reach the current viewport.
	var safe := ScreenUtil.safe_rect(get_viewport())
	var sc := maxf(scale.x, 0.001)
	var view_world := Rect2((safe.position - position) / sc, safe.size / sc).grow(16.0)
	for g in guards:
		var vision: float = g.vision
		var reach := Rect2(g.pos - Vector2.ONE * vision, Vector2.ONE * vision * 2.0)
		if g.alive and view_world.intersects(reach):
			_draw_cone(g)
	# Gems.
	for gm in gems:
		var bob := sin(gm.t * 6) * 3
		draw_texture_rect(GEM_TEX, Rect2(gm.pos + Vector2(-12, -12 + bob), Vector2(24, 24)), false)
	# Bullets.
	for b in bullets:
		draw_line(b.pos - b.vel.normalized() * 14, b.pos, Color(1, 0.9, 0.5, 0.9), 3)
		draw_circle(b.pos, 3, Color("ffd23f"))
	# Effects.
	for e in effects:
		var k: float = e.t / e.max
		if e.kind == "slash":
			draw_set_transform(e.pos, e.angle + PI / 2, Vector2.ONE * (1.2 - k * 0.3))
			draw_texture(SLASH_TEX, -SLASH_TEX.get_size() / 2, Color(1, 1, 1, k))
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		elif e.kind == "poof":
			draw_circle(e.pos, 30 * (1 - k), Color(0.9, 0.9, 0.9, k * 0.5))
		elif e.kind == "killring":
			var rr := 18.0 + (1.0 - k) * 62.0
			draw_arc(e.pos, rr, 0, TAU, 40, Color(1.0, 0.35, 0.3, k * 0.9), 7.0 * k + 1.5)
			draw_arc(e.pos, rr * 0.72, 0, TAU, 32, Color(1.0, 0.85, 0.5, k * 0.5), 3.0)
		elif e.kind == "backstab":
			var rise2 := (1.0 - k) * 26.0
			var fv2 := fx_font
			var t2 := "BACKSTAB!"
			var w2 := fv2.get_string_size(t2, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
			var p2: Vector2 = e.pos + Vector2(-w2 * 0.5, -rise2)
			draw_string_outline(fv2, p2, t2, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 6, Color(0.06, 0.07, 0.1, k))
			draw_string(fv2, p2, t2, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.55, 1.0, 0.65, k))
		elif e.kind == "gemtext":
			var rise := (1.0 - k) * 34.0
			var txt := "+%d" % int(e.amount)
			var fv := fx_font
			var fs := 30
			var tw2 := fv.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var tp: Vector2 = e.pos + Vector2(-tw2 * 0.5, -rise)
			draw_string_outline(fv, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 7, Color(0.06, 0.07, 0.1, k))
			draw_string(fv, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.89, 0.25, k))
		elif e.kind == "spark" or e.kind == "muzzle":
			draw_set_transform(e.pos, 0, Vector2.ONE * (0.6 + k))
			draw_texture(SPARK_TEX, -SPARK_TEX.get_size() / 2, Color(1, 1, 1, k))
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		elif e.kind == "hurt":
			draw_circle(e.pos, 26, Color(1, 0.2, 0.2, k * 0.5))

	# Guard alerts are displayed by the upright red question-mark labels above
	# their sprites (see _sync_guard_marker), not as destination/tap rings.

func _wall_colour(r: Rect2) -> String:
	var original_size := r.size / OBSTACLE_SCALE - Vector2.ONE * OBSTACLE_GROW * 2.0
	var original_pos := r.get_center() - original_size * 0.5
	return CONTAINER_KEYS[int(abs(original_pos.x * 7 + original_pos.y * 13)) % CONTAINER_KEYS.size()]

func _draw_cone(g: Dictionary) -> void:
	var rays := 40
	var vision: float = g.vision
	# Reuse the collision-clipped local light mesh for only a few frames. Move
	# and rotate it smoothly with the guard; recompute when it shifts a few
	# pixels, turns, or 75 ms elapse. Detection/LOS still run at full rate.
	if not g.light_valid or g.light_age >= 0.075 or g.pos.distance_squared_to(g.light_pos) > 6.25 or absf(angle_difference(g.light_face, g.face)) > 0.04:
		var reach := Rect2(g.pos - Vector2.ONE * vision, Vector2.ONE * vision * 2.0)
		var nearby: Array[Rect2] = []
		for rect in blocking_rects:
			if reach.intersects(rect, true):
				nearby.append(rect)
		var segments: Array[PackedVector2Array] = []
		var points := PackedVector2Array([Vector2.ZERO])
		for i in range(rays + 1):
			var a: float = g.face - deg_to_rad(30) + deg_to_rad(60) * i / rays
			var dir := Vector2.from_angle(a)
			var dist := _raycast_distance(g.pos, dir, vision, nearby)
			if dist < 0.25:
				if points.size() >= 3:
					segments.append(points)
				points = PackedVector2Array([Vector2.ZERO])
			else:
				var pt: Vector2 = dir * dist
				if pt.distance_squared_to(points[points.size() - 1]) > 0.01:
					points.append(pt)
		if points.size() >= 3:
			segments.append(points)
		g.light_segments = segments
		g.light_pos = g.pos
		g.light_face = g.face
		g.light_age = 0.0
		g.light_valid = true
	var col := Color(1.0, 0.93, 0.55, 0.30)
	var edge := Color(1.0, 0.96, 0.70, 0.55)
	if g.state == GState.ALERT:
		col = Color(1.0, 0.30, 0.26, 0.40)
		edge = Color(1.0, 0.55, 0.45, 0.75)
	elif g.state in [GState.INVESTIGATE, GState.SEARCH]:
		col = Color(1.0, 0.72, 0.22, 0.36)
		edge = Color(1.0, 0.85, 0.45, 0.68)
	draw_set_transform(g.pos, angle_difference(g.light_face, g.face), Vector2.ONE)
	for segment in g.light_segments:
		_draw_light_fan(segment, col)
		var inner := PackedVector2Array([Vector2.ZERO])
		for i in range(1, segment.size()):
			inner.append(segment[i] * 0.62)
		_draw_light_fan(inner, Color(col.r, col.g, col.b, col.a * 0.75))
		draw_polyline(segment, edge, 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(g.pos, 5.0, Color(edge.r, edge.g, edge.b, 0.85))

func _draw_light_fan(points: PackedVector2Array, color: Color) -> void:
	# The rays are angle-ordered around the origin, so this is a triangle fan.
	# Supplying indices directly avoids the renderer's polygon triangulation and
	# remains valid even when a guard grazes a cover edge.
	if points.size() < 3:
		return
	var indices := PackedInt32Array()
	for i in range(1, points.size() - 1):
		var left: Vector2 = points[i] - points[0]
		var right: Vector2 = points[i + 1] - points[0]
		if absf(left.cross(right)) > 0.01:
			indices.append(0)
			indices.append(i)
			indices.append(i + 1)
	if indices.is_empty():
		return
	var colors := PackedColorArray()
	colors.resize(points.size())
	colors.fill(color)
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), indices, points, colors)

# ---------------- End states ----------------
func _win() -> void:
	finished = true
	var level_no := GameState.current_level
	player_rig.set_moving(false)
	var stars := 3
	if was_alerted:
		stars = 2
	if damage_taken > 0:
		stars = 1
	GameState.add_gems(gems_collected)
	GameState.complete_level(kills, damage_taken == 0, stars)
	Sfx.play("win")
	_end_panel("LEVEL COMPLETE!", Color("4caf20"), "★".repeat(stars) + "  +%d cash  +%d gems" % [50 + level_no * 5, gems_collected], [
		["Next Level", func(): GameState.start_level(GameState.current_level)],
		["Home", func(): get_tree().change_scene_to_file("res://scenes/home/home.tscn")],
	])

func _lose() -> void:
	finished = true
	Sfx.play("lose")
	get_tree().create_timer(0.7).timeout.connect(func():
		_end_panel("YOU WERE SPOTTED", Color("e63946"), "Use cover and shadows. Strike from behind.", [
			["Retry", func(): get_tree().reload_current_scene()],
			["Home", func(): get_tree().change_scene_to_file("res://scenes/home/home.tscn")],
		]))

func _pause() -> void:
	if overlay != null or finished:
		return
	_end_panel("PAUSED", Color("ffc93c"), "", [
		["Resume", func(): overlay.queue_free(); overlay = null],
		["Retry", func(): get_tree().reload_current_scene()],
		["Home", func(): get_tree().change_scene_to_file("res://scenes/home/home.tscn")],
	])

func _end_panel(title: String, color: Color, sub: String, buttons: Array) -> void:
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("2b2f45")
	sb.border_color = Color("14161f")
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(20)
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	sb.content_margin_top = 26
	sb.content_margin_bottom = 26
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	var t := _label(40, 6)
	t.text = title
	t.add_theme_color_override("font_color", color)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	if sub != "":
		var s := _label(26, 0)
		s.text = sub
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(s)
	for b in buttons:
		var btn := Button.new()
		btn.text = b[0]
		btn.custom_minimum_size = Vector2(300, 60)
		var fv := FontVariation.new()
		fv.base_font = FONT
		fv.variation_embolden = 0.7
		btn.add_theme_font_override("font", fv)
		btn.add_theme_font_size_override("font_size", 26)
		var bs := StyleBoxFlat.new()
		bs.bg_color = color
		bs.set_corner_radius_all(14)
		bs.border_color = Color("14161f")
		bs.set_border_width_all(3)
		btn.add_theme_stylebox_override("normal", bs)
		btn.add_theme_color_override("font_color", Color("14161f"))
		btn.pressed.connect(b[1])
		box.add_child(btn)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_pause()
