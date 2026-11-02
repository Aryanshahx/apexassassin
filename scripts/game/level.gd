extends Node2D
## Apex Assassin core stealth loop.
## Tap floor to move, tap a guard to hunt. Auto-blade in range. Guards patrol,
## investigate noise, chase on sight, fire line-of-sight bullets, and search.
## Cover blocks sight/bullets; flashlight contact triggers immediate fire.
## Nearby guards hear gunfire. Kills award money and rare diamonds.

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
const GRADE_FLOOR := Color(1.0, 1.0, 1.0)
const GRADE_OUTSIDE := Color(0.52, 0.54, 0.56)
const GRADE_WALL := Color(1.0, 0.98, 1.0)
const GRADE_CRATE := Color(1.0, 0.98, 0.94)
const GRADE_PROP := Color(0.95, 0.97, 1.0)
## Camera: visible grid cells across the width. 15 shows 25% more world
## than the old 12-cell view (actors are 20% smaller), and still follows the player.
const CAM_VIEW_CELLS := 15.0
var cam_scale := 1.0
const FLOOR_TILE := 320.0         # 256px concept tile at world scale
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
const MONEY_TEX := preload("res://assets/ui/cash.png")
const KEY_TEX := preload("res://assets/ui/v72/key.png")
const LockerRewards := preload("res://scripts/ui/locker_rewards.gd")
const SLASH_TEX := preload("res://assets/fx/slash.png")
const SPARK_TEX := preload("res://assets/fx/spark.png")
const ActorRigScript := preload("res://scripts/game/v72_sprite_rig.gd")
const WorldBackplate := preload("res://scripts/game/world_backplate.gd")
const VisibilityRouter := preload("res://scripts/game/visibility_router.gd")
# Account for the guard artwork's visible footprint, not just its centre.
const GUARD_GAP := 78.0
# Body clearance beyond the universal four-unit blocker: wider than before.
const GUARD_WALL_MARGIN := 20.0
const GUARD_AVOID_HOLD := 0.55
const PLAYER_SCALE := 1.40
const PLAYER_HIT_RADIUS := 16.0
const PLAYER_LIGHT_RADIUS := 22.0
const ENEMY_DAMAGE_MULTIPLIER := 1.25
const BULLET_DAMAGE := 125.0 # 25% above the former 100-point fallback
const BULLET_SPEED := 660.0 # faster than v0.6.2's 420 world units/second
const ALERT_SPEED_MULTIPLIER := 2.07  # v0.6.3 chase speed * 1.15
const CHASE_MEMORY_SECONDS := 7.0  # countdown while the player is not visible
const FIRST_SHOT_DELAY := 0.50       # sight first; a real shot spreads the alarm
const KILL_ALERT_RADIUS := 320.0    # ten 32-unit cells; all takedowns
const INVESTIGATE_SPEED_MULTIPLIER := 1.45
const ALERT_STOP_DISTANCE := 36.0  # close pursuit, not the old 128-unit stand-off
const DIAMOND_LEVEL_CHANCE := 0.60 # at most one carrier per level
const MONEY_STANDARD := 10
const MONEY_HEAVY := 20
const MONEY_SILENT_BONUS := 5
const HEALTH_BAR_SIZE := Vector2(64, 8)
const ENEMY_PROFILES := {
	"scout": {"damage": 65.0, "interval": 0.325, "speed": 68.0, "vision": 250.0, "hp": 1, "tint": Color(0.55, 0.88, 1.0)},
	"guard": {"damage": 100.0, "interval": 0.50, "speed": 58.0, "vision": 250.0, "hp": 1, "tint": Color.WHITE},
	"heavy": {"damage": 160.0, "interval": 0.725, "speed": 48.0, "vision": 220.0, "hp": 2, "tint": Color(1.0, 0.78, 0.68)},
	"ranger": {"damage": 120.0, "interval": 0.40, "speed": 70.0, "vision": 290.0, "hp": 2, "tint": Color(0.50, 0.86, 1.0)},
	"breacher": {"damage": 185.0, "interval": 0.575, "speed": 62.0, "vision": 245.0, "hp": 3, "tint": Color(0.83, 0.64, 1.0)},
	"captain": {"damage": 230.0, "interval": 0.475, "speed": 68.0, "vision": 285.0, "hp": 4, "tint": Color(1.0, 0.83, 0.38)},
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
var player_router: RefCounted
var player_hp := 1000.0
var invuln := 0.0
var attack_cd := 0.0
var hunt_target := -1
var repath := 0.0
var player_rig: Node2D
var guards: Array[Dictionary] = []
var bullets: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var loot_particles: Array[Dictionary] = []
var blood_splats: Array[Dictionary] = []
var key_on_floor := false
var key_position := Vector2.ZERO
var key_icon: TextureRect
var key_label: Label
var key_guide: Button
var locker_ui: Control
var kills := 0
var total := 0
var gems_collected := 0 # legacy name; these are diamonds
var money_collected := 0
var victory_delay := -1.0
var damage_taken := 0
var was_alerted := false
var finished := false
var elapsed := 0.0
var counter: Label
var gem_label: Label
var money_label: Label
var money_caption: Label
var gem_caption: Label
var money_panel: Panel
var gem_panel: Panel
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
var money_icon: TextureRect

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
	_place_level_key()
	_build_player()
	_build_hud()
	player_hp = GameState.max_health()
	_build_player_health_bar()
	get_viewport().size_changed.connect(_fit_world)
	get_viewport().size_changed.connect(_layout_hud)
	_fit_world()
	_layout_hud()
	if GameState.locker_ready():
		call_deferred("_show_locker")
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
	_layout_hud_for_rect(ScreenUtil.safe_rect(get_viewport()))

func _layout_hud_for_rect(safe: Rect2) -> void:
	# Money, diamonds and keys share one horizontal baseline at every safe size.
	var wallet_left := safe.position.x + maxf(145.0, safe.size.x * 0.275)
	var wallet_right := safe.end.x - 92.0
	var slot := maxf(48.0, (wallet_right - wallet_left) / 3.0)
	var money_x := wallet_left
	var diamond_x := wallet_left + slot
	var key_x := wallet_left + slot * 2.0
	if money_panel:
		money_panel.position = Vector2(money_x - 4, safe.position.y + 18)
		money_panel.size = Vector2(slot - 4, 62)
	if gem_panel:
		gem_panel.position = Vector2(diamond_x - 4, safe.position.y + 18)
		gem_panel.size = Vector2(slot - 4, 62)
	if target_icon:
		target_icon.position = safe.position + Vector2(24, 26)
	if counter:
		counter.position = safe.position + Vector2(88, 25)
	if money_icon:
		money_icon.position = Vector2(money_x, safe.position.y + 26)
	if money_caption:
		money_caption.position = Vector2(money_x + 43, safe.position.y + 20)
	if money_label:
		money_label.position = Vector2(money_x + 43, safe.position.y + 29)
		money_label.size.x = maxf(1.0, slot - 46.0)
	if gem_icon:
		gem_icon.position = Vector2(diamond_x, safe.position.y + 26)
	if gem_caption:
		gem_caption.position = Vector2(diamond_x + 43, safe.position.y + 20)
	if gem_label:
		gem_label.position = Vector2(diamond_x + 43, safe.position.y + 29)
		gem_label.size.x = maxf(1.0, slot - 46.0)
	if key_icon:
		key_icon.position = Vector2(key_x, safe.position.y + 26)
	if key_label:
		key_label.position = Vector2(key_x + 43, safe.position.y + 29)
		key_label.size.x = maxf(1.0, slot - 46.0)
	if status_label:
		status_label.position = safe.position + Vector2(30, 96)
	if key_guide:
		key_guide.position = Vector2(safe.end.x - 198, safe.position.y + 92)
	if pause_btn:
		pause_btn.position = Vector2(safe.end.x - 84, safe.position.y + 24)
	if hint:
		hint.position = Vector2(safe.position.x, safe.end.y - 50)
		hint.size = Vector2(safe.size.x, 40)
	_refresh_wallet()

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
	# Cover is static between rebuilds, so invalidate cached visibility edges.
	player_router = null
	_configure_grid(grid, AStarGrid2D.DIAGONAL_MODE_NEVER)
	_configure_grid(guard_grid, AStarGrid2D.DIAGONAL_MODE_NEVER)
	# Supplied maps may have 100 rectangles. Paint their bounded cells instead
	# of testing every cell against every obstacle. has_point preserves the
	# original exact cell-centre rule, including the existing safety margins.
	for rect in blocking_rects:
		_paint_grid_rect(grid, rect)
	for rect in guard_blocking_rects:
		_paint_grid_rect(guard_grid, rect)

func _paint_grid_rect(target: AStarGrid2D, rect: Rect2) -> void:
	# Conservative bounds plus has_point preserve the former inclusive/exclusive
	# edge behavior exactly, including fractional-size source rectangles.
	var x0 := clampi(floori((rect.position.x - ORIGIN.x) / CELL) - 1, 0, int(data.width) - 1)
	var y0 := clampi(floori((rect.position.y - ORIGIN.y) / CELL) - 1, 0, int(data.height) - 1)
	var x1 := clampi(ceili((rect.end.x - ORIGIN.x) / CELL) + 1, 0, int(data.width) - 1)
	var y1 := clampi(ceili((rect.end.y - ORIGIN.y) / CELL) + 1, 0, int(data.height) - 1)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if rect.has_point(_cell_center(x, y)):
				target.set_point_solid(Vector2i(x, y), true)

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

func _place_level_key() -> void:
	key_on_floor = false
	var number := int(data.id)
	if not GameState.key_available(number):
		return
	var region_id := int(region_by_cell.get(_to_cell(player_pos), -1))
	if region_id < 0:
		return
	var cells: Array = walkable_regions[region_id].duplicate()
	var key_rng := RandomNumberGenerator.new()
	key_rng.seed = 640500 + number * 139
	# Shuffle deterministically without affecting combat/patrol RNG.
	for i in range(cells.size() - 1, 0, -1):
		var j := key_rng.randi_range(0, i)
		var temp: Variant = cells[i]
		cells[i] = cells[j]
		cells[j] = temp
	for cell in cells:
		var p: Vector2 = _cell_center(cell.x, cell.y)
		if _guard_solid(p) or p.distance_to(player_pos) < 260.0:
			continue
		var close := false
		for guard in guards:
			if p.distance_to(guard.pos) < 150.0:
				close = true
				break
		if not close:
			key_position = p
			key_on_floor = true
			return

func _guide_to_key() -> void:
	# The larger warehouse can put a key outside the camera. This optional
	# button highlights the real walkable path; players can still skip the key.
	if not key_on_floor or finished or overlay != null or locker_ui != null:
		return
	dragging = false
	hunt_target = -1
	_path_to(key_position)

func _collect_key_if_close() -> void:
	if not key_on_floor or player_pos.distance_to(key_position) > 28.0:
		return
	if GameState.collect_level_key(int(data.id)):
		key_on_floor = false
		Sfx.play("pickkey", -3.0)
		effects.append({"pos": key_position, "t": 1.0, "max": 1.0, "kind": "keytext"})
		_refresh_wallet()
		# The third key queues a persistent board; it never interrupts a level.

func _show_locker() -> void:
	if not GameState.locker_ready() or locker_ui != null or hud == null:
		return
	dragging = false
	player_path.clear()
	locker_ui = LockerRewards.new()
	hud.add_child(locker_ui)
	locker_ui.completed.connect(_locker_finished)

func _locker_finished() -> void:
	locker_ui = null
	_refresh_wallet()

func _build_player() -> void:
	player_rig = ActorRigScript.new()
	player_rig.setup(GameState.selected_assassin, "player")
	player_rig.set_knife(GameState.selected_knife)
	# Player art was smaller than the guards; enlarge only its visual rig.
	player_rig.scale = Vector2.ONE * PLAYER_SCALE
	player_rig.position = player_pos
	player_rig.rotation = player_face + PI / 2
	add_child(player_rig)

func _diamond_carrier_for_level(number: int, count: int) -> int:
	# Rare: only some levels have a carrier, and never more than one.
	# Separate seeded RNG leaves patrol/alert randomness unchanged.
	if count <= 0:
		return -1
	var loot_rng := RandomNumberGenerator.new()
	loot_rng.seed = 630000 + number * 31
	return loot_rng.randi_range(0, count - 1) if loot_rng.randf() < DIAMOND_LEVEL_CHANCE else -1

func _enemy_variant(number: int, index: int, authored: Dictionary) -> String:
	# A fresh special enemy is guaranteed from each threshold onward; the
	# original scout, guard and heavy still appear alongside it.
	if index % 6 == 0:
		if number >= 50:
			return "captain"
		if number >= 25:
			return "breacher"
		if number >= 8:
			return "ranger"
	return "heavy" if bool(authored.get("elite", false)) or index % 5 == 2 else ("scout" if index % 3 == 1 else "guard")

# Distribute guards over reachable floor instead of spawning a group together.
# Preserve level geometry and guard count; the first authored guard is the seed
# and farthest-point selection spreads the remaining starts deterministically.
func _distributed_guard_starts() -> PackedVector2Array:
	var selected := PackedVector2Array()
	# Source-priority catalogs pre-adapt guard hints or fallback roster positions.
	# Honour positions only if all runtime safety checks pass; malformed or
	# older data still uses the original safe-distribution fallback.
	if bool(data.get("use_authored_guard_starts", false)):
		var authored_safe := true
		var player_region_id := int(region_by_cell.get(_to_cell(player_pos), -1))
		for raw in data.guards:
			var point := _cell_center(int(raw.get("x", 0)), int(raw.get("y", 0)))
			var cell := _to_cell(point)
			if point.distance_to(player_pos) < 280.0 or _guard_solid(point) or not guard_region_by_cell.has(cell) or int(region_by_cell.get(cell, -2)) != player_region_id:
				authored_safe = false
				break
			for prior in selected:
				if point.distance_to(prior) < 159.9:
					authored_safe = false
					break
			if not authored_safe:
				break
			selected.append(point)
		if authored_safe and selected.size() == data.guards.size():
			return selected
		selected.clear()
	var player_region := int(region_by_cell.get(_to_cell(player_pos), -1))
	for index in range(data.guards.size()):
		var authored: Dictionary = data.guards[index]
		var authored_cell := Vector2i(int(authored.x), int(authored.y))
		var area := int(guard_region_by_cell.get(authored_cell, -1))
		var authored_position := _cell_center(authored_cell.x, authored_cell.y)
		var best := authored_position
		var best_score := -INF
		if area < 0:
			selected.append(best)
			continue
		for cell in guard_walkable_regions[area]:
			if int(region_by_cell.get(cell, -2)) != player_region:
				continue
			var point := _cell_center(cell.x, cell.y)
			if point.distance_to(player_pos) < 280.0:
				continue
			var nearest := INF
			for other in selected:
				nearest = minf(nearest, point.distance_to(other))
			# Keep one known-good authored seed; then maximize nearest-neighbor
			# separation, using a small deterministic preference for its old area.
			var score := -point.distance_to(authored_position) if selected.is_empty() else nearest - point.distance_to(authored_position) * 0.02
			if score > best_score:
				best_score = score
				best = point
		selected.append(best)
	return selected

func _build_guards() -> void:
	var starts := _distributed_guard_starts()
	var diamond_carrier := _diamond_carrier_for_level(int(data.id), data.guards.size())
	for index in range(data.guards.size()):
		var g: Dictionary = data.guards[index]
		var route := PackedVector2Array()
		for c in g.route:
			route.append(_cell_center(c[0], c[1]))
		var variant := _enemy_variant(int(data.id), index, g)
		var profile: Dictionary = ENEMY_PROFILES[variant]
		var kind := "elite" if variant in ["heavy", "breacher", "captain"] else "guard"
		# Existing AI profiles remain unchanged; later floors scale gently and
		# continuously rather than abruptly adding a new combat mechanic.
		var difficulty := float(int(data.id) - 1) / 99.0
		var damage_scale := (1.0 + float(int(data.id) - 1) * 0.0055) * ENEMY_DAMAGE_MULTIPLIER
		var extra_armor := int((int(data.id) - 1) / 40)
		var rig := ActorRigScript.new()
		rig.setup(variant, "guard")
		rig.scale = Vector2.ONE * (0.98 if kind == "elite" else 0.92)
		# The supplied character colors replace the old monochrome tints.
		rig.modulate = Color.WHITE
		rig.position = starts[index]
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
			"id": index, "variant": variant, "diamond_carrier": index == diamond_carrier, "shot_damage": float(profile.damage) * damage_scale,
			"shot_interval": float(profile.interval) * (1.0 - difficulty * 0.08), "mark": mark,
			"pos": rig.position, "home_pos": rig.position, "face": deg_to_rad(float(g.face)),
			"route": route, "ri": 0, "wait": rng.randf_range(0.0, 1.2),
			"hp": int(profile.hp) + extra_armor, "elite": kind == "elite",
			"state": GState.PATROL, "alert": 0.0, "shoot": 0.0, "burst": 0,
			"alive": true, "path": PackedVector2Array(), "pi": 0,
			"last_seen": Vector2.ZERO, "search_t": 0.0, "rig": rig,
			"speed": float(profile.speed), "vision": float(profile.vision),
			"roam_target": Vector2.ZERO, "roam_valid": false,
			"blocked_t": 0.0, "avoid_side": 1.0, "avoid_time": 0.0,
			"avoid_direction": Vector2.ZERO, "walk_hold": 0.0, "sees_player": false,
			"travel_dir": Vector2.ZERO, "traffic_wait": false, "traffic_stall": 0.0,
			"alert_repath": 0.0, "chase_left": 0.0, "route_goal": Vector2(INF, INF),
			"stuck_time": 0.0, "progress_anchor": rig.position,
			"recover_left": 0.0, "recover_direction": Vector2.ZERO, "recover_count": 0, "recover_turns": 0,
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
	# Soft dark pills keep the two totals legible over bright floor and beams.
	var wallet_style := StyleBoxFlat.new()
	wallet_style.bg_color = Color(0.04, 0.07, 0.09, 0.72)
	wallet_style.set_corner_radius_all(10)
	money_panel = Panel.new()
	money_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	money_panel.visible = false  # No currency backgrounds during gameplay.
	money_panel.add_theme_stylebox_override("panel", wallet_style)
	hud.add_child(money_panel)
	gem_panel = Panel.new()
	gem_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gem_panel.visible = false
	gem_panel.add_theme_stylebox_override("panel", wallet_style)
	hud.add_child(gem_panel)
	var mi := TextureRect.new()
	money_icon = mi
	mi.texture = MONEY_TEX
	mi.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mi.size = Vector2(40, 40)
	mi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(mi)
	money_caption = _label(19, 2)
	money_caption.text = "MONEY"
	money_caption.visible = false
	hud.add_child(money_caption)
	money_label = _label(32, 5)
	money_label.size = Vector2(120, 38)
	money_label.clip_text = true
	hud.add_child(money_label)
	var gi := TextureRect.new()
	gem_icon = gi
	gi.texture = GEM_TEX
	gi.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gi.size = Vector2(40, 40)
	gi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(gi)
	gem_caption = _label(19, 2)
	gem_caption.text = "DIAMONDS"
	gem_caption.visible = false
	hud.add_child(gem_caption)
	gem_label = _label(32, 5)
	gem_label.size = Vector2(120, 38)
	gem_label.clip_text = true
	hud.add_child(gem_label)
	key_icon = TextureRect.new()
	key_icon.name = "KeyIcon"
	key_icon.texture = KEY_TEX
	key_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	key_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	key_icon.size = Vector2(40, 40)
	key_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(key_icon)
	key_label = _label(26, 4)
	key_label.name = "KeyCount"
	key_label.size = Vector2(82, 40)
	hud.add_child(key_label)
	key_guide = Button.new()
	key_guide.name = "FindKeyButton"
	key_guide.text = "FIND KEY"
	key_guide.flat = true
	key_guide.size = Vector2(140, 36)
	key_guide.add_theme_font_override("font", FONT)
	key_guide.add_theme_font_size_override("font_size", 20)
	key_guide.add_theme_color_override("font_color", Color("ffda78"))
	key_guide.add_theme_color_override("font_outline_color", Color("181c20"))
	key_guide.add_theme_constant_override("outline_size", 3)
	key_guide.pressed.connect(_guide_to_key)
	hud.add_child(key_guide)
	_refresh_wallet()
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

func _fit_wallet_label(label: Label, amount: int) -> void:
	label.text = str(amount)
	var font: Font = label.get_theme_font("font")
	var font_size := 32
	while font_size > 9 and font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > label.size.x - 2.0:
		font_size -= 1
	label.add_theme_font_size_override("font_size", font_size)

func _refresh_wallet() -> void:
	if money_label:
		_fit_wallet_label(money_label, GameState.cash)
	if gem_label:
		_fit_wallet_label(gem_label, GameState.gems)
	if key_label:
		key_label.text = "%d/3" % GameState.displayed_key_count()
	if key_guide:
		key_guide.visible = key_on_floor

func _physics_process(delta: float) -> void:
	if finished or overlay != null or locker_ui != null:
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
	_collect_key_if_close()
	if locker_ui != null:
		return
	# Resolve light contact before melee so a guard can fire immediately even
	# when the player enters the beam at point-blank range.
	_update_guards(delta)
	_auto_attack()
	_update_bullets(delta)
	_update_loot_particles(delta)
	_update_effects(delta)
	_update_stealth_hud()
	if kills >= total and not finished:
		# Show the final money/diamond pickup before opening the win panel.
		if victory_delay < 0.0:
			victory_delay = 0.8
			bullets.clear()
		else:
			victory_delay -= delta
			if victory_delay <= 0.0:
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
		else:
			var step := minf(d, budget)
			var next := player_pos + (target - player_pos) / d * step
			# Never walk through solid cover even if a stale path is supplied.
			if not _los(player_pos, next):
				player_path.clear()
				break
			player_pos = next
			budget -= step
			if d <= step + 0.001:
				player_path.remove_at(0)
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

func _visible_player_anchors(point: Vector2, only_region: int = -1) -> Array[Vector2i]:
	# A rectangular obstacle can clip a corner of a grid cell even when that
	# cell's centre is walkable. Connect the real position only to centres that
	# are actually visible, rather than drawing an impossible first segment.
	var nearby: Array[Vector2i] = []
	var cell := _to_cell(point)
	for radius in range(0, 4):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var candidate := cell + Vector2i(dx, dy)
				if not grid.is_in_boundsv(candidate) or grid.is_point_solid(candidate):
					continue
				if only_region >= 0 and int(region_by_cell.get(candidate, -1)) != only_region:
					continue
				var centre := _cell_center(candidate.x, candidate.y)
				if _los(point, centre):
					nearby.append(candidate)
		if nearby.size() >= 3:
			break
	nearby.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return _cell_center(a.x, a.y).distance_squared_to(point) < _cell_center(b.x, b.y).distance_squared_to(point))
	if nearby.size() > 3:
		nearby.resize(3)
	return nearby

func _smooth_segment_clear(a: Vector2, b: Vector2) -> bool:
	# Do not shortcut exactly across a cover corner. Tiny floating-point drift
	# during real movement can otherwise turn a nominal tangent into a hit.
	var motion := b - a
	var distance := motion.length()
	if distance <= 0.001:
		return not _solid(a)
	var margin_rects: Array[Rect2] = []
	for rect in blocking_rects:
		var expanded: Rect2 = rect.grow(0.5)
		# Valid user endpoints may already be within the half-pixel margin.
		margin_rects.append(rect if expanded.has_point(a) or expanded.has_point(b) else expanded)
	return _raycast_distance(a, motion / distance, distance, margin_rects) >= distance - 0.001

func _simplify_player_route(points: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	var start := player_pos
	var index := 0
	while index < points.size():
		var last_visible := index
		for j in range(index + 1, points.size()):
			if not _smooth_segment_clear(start, points[j]):
				break
			last_visible = j
		var next: Vector2 = points[last_visible]
		if start.distance_squared_to(next) > 0.01:
			result.append(next)
		start = next
		index = last_visible + 1
	return result

func _player_anchor_options(point: Vector2, only_region: int = -1) -> Array[Dictionary]:
	# A valid point may be inside a narrow corner pocket with no visible grid
	# centre, even though it can escape by first walking around a cover corner.
	var options: Array[Dictionary] = []
	for cell in _visible_player_anchors(point, only_region):
		options.append({"cell": cell, "has_corner": false, "cost": point.distance_to(_cell_center(cell.x, cell.y))})
	if not options.is_empty():
		return options
	for rect in blocking_rects:
		if not rect.grow(CELL * 3.0).has_point(point):
			continue
		var r: Rect2 = rect.grow(1.25)
		for corner in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
			if _solid(corner) or not _los(point, corner):
				continue
			for cell in _visible_player_anchors(corner, only_region):
				options.append({"cell": cell, "has_corner": true, "corner": corner,
					"cost": point.distance_to(corner) + corner.distance_to(_cell_center(cell.x, cell.y))})
	options.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.cost) < float(b.cost))
	if options.size() > 6:
		options.resize(6)
	return options

func _path_to(target: Vector2) -> void:
	player_path.clear()
	var map_rect := Rect2(ORIGIN, Vector2(float(data.width), float(data.height)) * CELL)
	if not map_rect.has_point(player_pos) or _solid(player_pos):
		return
	if map_rect.has_point(target) and not _solid(target):
		# Direct movement remains genuinely straight, with no grid centre detour.
		if _los(player_pos, target):
			if player_pos.distance_to(target) > 0.5:
				player_path.append(target)
			return
		if player_router == null:
			player_router = VisibilityRouter.new()
			player_router.setup(map_rect, blocking_rects)
		var candidate: PackedVector2Array = player_router.route(player_pos, target)
		var previous := player_pos
		var legal := not candidate.is_empty()
		for p in candidate:
			if not _los(previous, p):
				legal = false
				break
			previous = p
		if legal and previous.distance_to(target) < 0.1:
			player_path = candidate
			return
	# Cover taps or truly unreachable islands keep the established safe snap-to-
	# reachable-floor behavior; the grid is a fallback, never the primary route.
	_path_to_grid(target)

func _path_to_grid(target: Vector2) -> void:
	player_path.clear()
	var map_rect := Rect2(ORIGIN, Vector2(float(data.width), float(data.height)) * CELL)
	var target_is_floor := map_rect.has_point(target) and not _solid(target)
	if _solid(player_pos):
		return
	if target_is_floor and _los(player_pos, target):
		if player_pos.distance_to(target) > 0.5:
			player_path.append(target)
		return
	var starts := _player_anchor_options(player_pos)
	var best_route := PackedVector2Array()
	var best_distance := INF
	var region_ends := {}
	for start in starts:
		var first: Vector2i = start.cell
		var rid := int(region_by_cell.get(first, -1))
		if rid < 0:
			continue
		if not region_ends.has(rid):
			var ends: Array[Dictionary] = []
			if target_is_floor:
				ends = _player_anchor_options(target, rid)
			if ends.is_empty():
				# A tap on cover/outside/island ends at the nearest reachable
				# grid point, not at a fictional point behind the obstacle.
				var nearest := INF
				var nearest_cell := first
				for c in walkable_regions[rid]:
					var dist: float = _cell_center(c.x, c.y).distance_squared_to(target)
					if dist < nearest:
						nearest = dist
						nearest_cell = c
				ends.append({"cell": nearest_cell, "has_corner": false})
			region_ends[rid] = ends
		for end in region_ends[rid]:
			var last: Vector2i = end.cell
			var cells_route: PackedVector2Array = grid.get_point_path(first, last)
			if cells_route.is_empty():
				continue
			var route := PackedVector2Array()
			if bool(start.has_corner):
				route.append(start.corner)
			route.append_array(cells_route)
			var previous := player_pos
			var cost := 0.0
			var legal := true
			for waypoint in route:
				if not _los(previous, waypoint):
					legal = false
					break
				cost += previous.distance_to(waypoint)
				previous = waypoint
			if not legal:
				continue
			if target_is_floor and bool(end.has_corner) and _los(previous, end.corner):
				route.append(end.corner)
				cost += previous.distance_to(end.corner)
				previous = end.corner
			if target_is_floor and _los(previous, target):
				cost += previous.distance_to(target)
				route.append(target)
			else:
				# Prefer approaching a blocked tap as closely as possible.
				cost += previous.distance_to(target) * 4.0
			if cost < best_distance:
				best_distance = cost
				best_route = route
	player_path = _simplify_player_route(best_route)

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
	draw_polyline(points, Color(0.34, 0.10, 0.00, 0.80), 7.0, true)
	draw_polyline(points, Color(1.0, 0.65, 0.08, 0.97), 3.2, true)
	# A small arrowhead belongs to the actual path endpoint, not a tap pulse.
	var arrow := _route_arrow_points()
	if arrow.size() == 3:
		draw_colored_polygon(arrow, Color(1.0, 0.67, 0.08, 0.98))

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
	# Behind the guard's facing arc gives a silent-bonus instant kill. Nearby
	# witnesses still react to any takedown, including from behind.
	var to_player: Vector2 = (player_pos - g.pos).normalized()
	var facing := Vector2.from_angle(g.face)
	var from_behind := facing.dot(to_player) < -0.25
	var unaware: bool = g.state != GState.ALERT
	player_face = (g.pos - player_pos).angle()
	player_rig.rotation = player_face + PI / 2
	player_rig.play_anim("attack", true)
	# The real MP3 supplied by the player is installed on their Pi.
	Sfx.play("stab")
	GameState.vibrate(18)
	if from_behind and unaware:
		g.hp = 0
		backstabs += 1
	else:
		g.hp -= GameState.player_damage()
	if g.hp <= 0:
		_kill_guard(best, from_behind and unaware)
	else:
		# The slash is non-lethal feedback only. A kill leaves blood alone.
		effects.append({"pos": g.pos, "t": 0.22, "max": 0.22, "kind": "slash", "angle": player_face})
		g.alert = 1.0
		g.state = GState.ALERT
		g.last_seen = player_pos
		g.chase_left = _chase_duration(g)
		g.rig.play_anim("hurt", true)

func _kill_guard(index: int, silent := false) -> void:
	var g: Dictionary = guards[index]
	if not g.alive:
		return
	g.alive = false
	g.state = GState.DEAD
	_sync_guard_marker(g)
	g.rig.die()
	g.rig.visible = false  # No corpse, poof, kill ring or kill-only animation.
	kills += 1
	_update_counter()
	_add_blood_splatter(g.pos)
	# Keep credit and save exactly as before; no kill-only particles or text.
	var money := MONEY_HEAVY if g.elite else MONEY_STANDARD
	if silent:
		money += MONEY_SILENT_BONUS
	var diamonds := 1 if bool(g.get("diamond_carrier", false)) else 0
	money_collected += money
	gems_collected += diamonds
	GameState.add_combat_loot(money, diamonds)
	_refresh_wallet()
	# Any takedown, including a backstab, alerts nearby reachable guards.
	# Unlike a gunshot this is local: distant guards stay on patrol.
	var area := int(guard_region_by_cell.get(_to_cell(g.pos), -1))
	for other in guards:
		if not other.alive or other.pos.distance_to(g.pos) > KILL_ALERT_RADIUS:
			continue
		if area < 0 or int(guard_region_by_cell.get(_to_cell(other.pos), -2)) != area:
			continue
		_alert_guard(other, player_pos)
		was_alerted = true
	if hunt_target == index:
		hunt_target = -1

func _add_blood_splatter(point: Vector2) -> void:
	var drops := []
	for i in range(12):
		var angle := rng.randf_range(0.0, TAU)
		var distance := rng.randf_range(7.0, 43.0)
		drops.append({"offset": Vector2.from_angle(angle) * distance, "radius": rng.randf_range(2.2, 6.4)})
	# Stains belong to this level instance and are never faded or capped. A new
	# level/restart constructs a fresh instance and thus clears them naturally.
	blood_splats.append({"pos": point, "drops": drops})

func _alert_guard(g: Dictionary, reported: Vector2) -> void:
	var target_changed: bool = g.last_seen.distance_squared_to(reported) > CELL * CELL * 4.0
	var entering: bool = g.state != GState.ALERT
	g.state = GState.ALERT
	g.alert = 1.0
	g.last_seen = reported
	g.chase_left = _chase_duration(g)
	if entering or target_changed:
		g.blocked_t = 0.0
		g.avoid_time = 0.0
		g.path.clear()
		g.pi = 0
		g.route_goal = Vector2(INF, INF)
	_sync_guard_marker(g)

func _any_guard_alerted() -> bool:
	# A search or investigation remains an alarm episode; suppress repeated
	# detection audio until all living guards have returned to calm patrol.
	for guard in guards:
		if guard.alive and guard.state in [GState.ALERT, GState.INVESTIGATE, GState.SEARCH]:
			return true
	return false

func _alarm_others(source: Dictionary) -> void:
	# The connected, guard-traversable area defines who hears the alarm. This
	# does not depend on each witness's cone or an arbitrary 480-pixel radius.
	var area := int(guard_region_by_cell.get(_to_cell(source.pos), -1))
	if area < 0:
		return
	var reported: Vector2 = player_pos
	for other in guards:
		if int(other.id) == int(source.id) or not other.alive:
			continue
		if int(guard_region_by_cell.get(_to_cell(other.pos), -2)) != area:
			continue
		_alert_guard(other, reported)

func _investigate(g: Dictionary, p: Vector2) -> void:
	g.state = GState.INVESTIGATE
	g.last_seen = p
	g.search_t = 3.0
	g.blocked_t = 0.0
	g.avoid_time = 0.0
	g.path.clear()

func _chase_duration(g: Dictionary) -> float:
	# Different guards stop chasing at different times, not in a single wave.
	return CHASE_MEMORY_SECONDS + float(int(g.id) % 5) * 0.45

func _search_duration(g: Dictionary) -> float:
	return 3.0 + float(int(g.id) % 5) * 0.55

func _pursuit_goal(g: Dictionary, target: Vector2) -> Vector2:
	# Give nearby pursuers different approach lanes instead of sending everyone
	# to the exact same point. A lone guard follows the actual last-known point.
	var nearby := 0
	for other in guards:
		if int(other.id) == int(g.id) or not other.alive:
			continue
		if other.state in [GState.ALERT, GState.INVESTIGATE] and other.last_seen.distance_to(target) < 145.0:
			nearby += 1
	if nearby == 0:
		return target
	var radial: Vector2 = g.pos - target
	if radial.length_squared() < 1.0:
		radial = Vector2.from_angle(float(int(g.id) % 8) * TAU / 8.0)
	# Stay on the guard's current approach ray. Rotating this ray every frame
	# makes an arrived guard orbit the player forever instead of settling.
	return target + radial.normalized() * 40.0

func _request_traffic_space(stuck: Dictionary) -> void:
	# A guard can be pinned between cover and a row of teammates. Ask nearby
	# alert guards that have room to step away; moving a guard farther back in
	# the queue can release space for the entire line. No teleporting/pushing.
	var helpers := 0
	for other in guards:
		if not other.alive or int(other.id) == int(stuck.id) or other.state != GState.ALERT:
			continue
		if float(other.speed) <= 0.0 or float(other.recover_left) > 0.0 or other.pos.distance_to(stuck.pos) > GUARD_GAP * 2.5:
			continue
		var away: Vector2 = (other.pos - stuck.pos).normalized()
		var chosen := Vector2.ZERO
		var best := 0.15
		for probe_length in [80.0, 48.0, 24.0]:
			for i in range(16):
				var direction := Vector2.from_angle(float(i) * TAU / 16.0)
				var score := direction.dot(away)
				if score > best and _guard_step_clear(other, other.pos + direction * probe_length):
					best = score
					chosen = direction
			if chosen != Vector2.ZERO:
				break
		if chosen == Vector2.ZERO:
			continue
		other.recover_direction = chosen
		other.recover_left = 1.5
		other.recover_turns = 0
		other.stuck_time = 0.0
		other.progress_anchor = other.pos
		other.yield_left = 0.0
		other.avoid_time = 0.0
		other.path.clear()
		other.pi = 0
		helpers += 1
		if helpers >= 2:
			break

func _begin_traffic_recovery(g: Dictionary, target: Vector2) -> bool:
	# A queue can otherwise wait forever behind a stationary guard. Pick a
	# collision-checked escape direction and commit briefly, making room before
	# retrying pursuit. Never move through another guard or through cover.
	var away: Vector2 = (g.pos - target).normalized()
	var home_dir: Vector2 = (Vector2(g.get("home_pos", g.pos)) - g.pos).normalized()
	var best := -INF
	var chosen := Vector2.ZERO
	var chosen_length := 0.0
	for probe_length in [80.0, 48.0, 24.0, 8.0, 2.0]:
		for i in range(16):
			var direction := Vector2.from_angle(float(i) * TAU / 16.0)
			var probe: Vector2 = g.pos + direction * probe_length
			if not _guard_step_clear(g, probe):
				continue
			var side_preference := 1.0 if (int(g.id) + int(g.recover_count)) % 2 == 0 else -1.0
			var lateral := Vector2(-away.y, away.x) * side_preference
			var score := direction.dot(away) * 2.0 + direction.dot(home_dir) * 0.35 + direction.dot(lateral) * 0.65
			if score > best:
				best = score
				chosen = direction
				chosen_length = probe_length
		if chosen != Vector2.ZERO:
			break
	if chosen_length < 24.0:
		_request_traffic_space(g)
	if chosen == Vector2.ZERO:
		# Avoid requesting help on every frame if the jam cannot yet move.
		g.stuck_time = 0.0
		return false
	g.recover_direction = chosen
	g.recover_left = 2.5
	g.recover_turns = 0
	g.recover_count = int(g.recover_count) + 1
	g.stuck_time = 0.0
	g.progress_anchor = g.pos
	g.yield_partner = -1
	g.yield_side = Vector2.ZERO
	g.yield_left = 0.0
	g.avoid_time = 0.0
	g.traffic_stall = 0.0
	g.blocked_t = 0.0
	g.path.clear()
	g.pi = 0
	return true

func _redirect_traffic_recovery(g: Dictionary, target: Vector2) -> bool:
	# A safe escape ray can eventually meet the end of a wall. Follow the
	# corridor instead of instantly turning back into the original queue.
	var away: Vector2 = (g.pos - target).normalized()
	for probe_length in [80.0, 48.0, 24.0, 8.0]:
		var chosen := Vector2.ZERO
		var best := 0.0
		for i in range(16):
			var direction := Vector2.from_angle(float(i) * TAU / 16.0)
			var score := direction.dot(away)
			if score > best and _guard_step_clear(g, g.pos + direction * probe_length):
				best = score
				chosen = direction
		if chosen != Vector2.ZERO:
			g.recover_direction = chosen
			g.recover_turns = int(g.recover_turns) + 1
			return true
	return false

func _update_guards(delta: float) -> void:
	for g in guards:
		if not g.alive:
			_sync_guard_marker(g)
			continue
		var previous_position: Vector2 = g.pos
		g.light_age += delta
		var cone_sees := _can_see(g.pos, g.face, player_pos, g.vision)
		# An informed guard can turn toward and fire at a directly visible
		# player outside its old cone; walls and vision range still block shots.
		var informed_sees: bool = g.state == GState.ALERT and not cone_sees and g.pos.distance_to(player_pos) <= float(g.vision) + PLAYER_LIGHT_RADIUS and _los(g.pos, player_pos)
		var sees: bool = cone_sees or informed_sees
		var first_contact: bool = sees and not g.sees_player
		if sees:
			if first_contact:
				var already_in_alarm := _any_guard_alerted()
				var newly_spotted: bool = g.state != GState.ALERT
				if not already_in_alarm:
					Sfx.play("suspect")
				if newly_spotted:
					# The spotter begins to chase first. Only an actual shot
					# informs the other guards in this connected area.
					g.shoot = FIRST_SHOT_DELAY
				g.burst = 0
				g.path.clear()
				g.pi = 0
				g.alert_repath = 0.0
				g.route_goal = Vector2(INF, INF)
				was_alerted = true
			g.alert = 1.0
			g.last_seen = player_pos
			g.chase_left = _chase_duration(g)
			g.state = GState.ALERT
		else:
			g.alert = maxf(0, g.alert - delta * 0.7)
		g.sees_player = sees
		match g.state:
			GState.PATROL:
				_patrol(g, delta)
			GState.INVESTIGATE:
				var investigate_goal := _pursuit_goal(g, g.last_seen)
				_seek(g, investigate_goal, delta, g.speed * INVESTIGATE_SPEED_MULTIPLIER)
				if g.pos.distance_to(investigate_goal) < 18 or g.blocked_t > 2.5:
					# If other guards occupy the target, search from here rather
					# than endlessly squeezing together and jittering.
					g.state = GState.SEARCH
					g.search_t = _search_duration(g)
					g.blocked_t = 0.0
					g.path.clear()
			GState.ALERT:
				# Pursue the moving player for a bounded time after sight is lost.
				# A fresh sighting or actual alarm resets the timer; without either,
				# search and eventually resume patrol instead of alerting forever.
				if not sees:
					g.chase_left = maxf(0.0, float(g.chase_left) - delta)
					if g.chase_left <= 0.0:
						g.state = GState.SEARCH
						g.search_t = _search_duration(g)
						g.path.clear()
						g.pi = 0
						g.blocked_t = 0.0
						g.avoid_time = 0.0
						g.yield_partner = -1
						g.rig.set_aiming(false)
					else:
						g.last_seen = player_pos  # live pursuit during the short memory window
				var target_angle: float = (player_pos - g.pos).angle()
				if sees and g.state == GState.ALERT:
					g.face = target_angle if first_contact else lerp_angle(g.face, target_angle, minf(1.0, delta * 10))
					g.rig.set_aiming(true, angle_difference(g.face, target_angle), first_contact)
					g.shoot -= delta
					if g.shoot <= 0:
						_fire(g)
						g.shoot = float(g.shot_interval)
				else:
					g.rig.set_aiming(false)
				if g.state == GState.ALERT:
					# Keep a committed path until its goal has moved materially. The
					# old unconditional 0.2-second reset caused doorway jitter/stalls.
					var goal: Vector2 = _pursuit_goal(g, g.last_seen)
					g.alert_repath -= delta
					if g.alert_repath <= 0.0:
						if g.route_goal.distance_squared_to(goal) > CELL * CELL * 2.25:
							g.path.clear()
							g.pi = 0
						g.route_goal = goal
						g.alert_repath = 0.35
					if float(g.recover_left) > 0.0:
						var escape: Vector2 = g.pos + Vector2(g.recover_direction) * g.speed * ALERT_SPEED_MULTIPLIER * delta
						if _guard_step_clear(g, escape):
							g.pos = escape
							g.face = lerp_angle(g.face, Vector2(g.recover_direction).angle(), minf(1.0, delta * 8.0))
							g.recover_left = maxf(0.0, float(g.recover_left) - delta)
						elif int(g.recover_turns) >= 2 or not _redirect_traffic_recovery(g, g.last_seen):
							g.recover_left = 0.0
					elif g.pos.distance_to(g.last_seen) > ALERT_STOP_DISTANCE:
						_seek(g, goal, delta, g.speed * ALERT_SPEED_MULTIPLIER)
						if sees:
							var aim_after_move: float = (player_pos - g.pos).angle()
							g.face = lerp_angle(g.face, aim_after_move, minf(1.0, delta * 10))
					if g.blocked_t > 1.2:
						# A timed retry clears stale traffic state, without teleporting.
						g.path.clear()
						g.pi = 0
						g.avoid_time = 0.0
						g.yield_partner = -1
						g.blocked_t = 0.0
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
		# A close guard with a clean firing lane may stand and shoot; do not
		# make it jitter just because a teammate blocks further approach.
		var needs_escape: bool = not sees or g.pos.distance_to(g.last_seen) > float(g.vision) * 0.80
		if g.state == GState.ALERT and needs_escape and float(g.speed) > 0.0 and g.pos.distance_to(g.last_seen) > GUARD_GAP * 1.25:
			# Tiny left/right oscillations are not progress. Require a real
			# displacement from a rolling anchor before resetting the timeout.
			if g.pos.distance_to(Vector2(g.progress_anchor)) >= 24.0:
				g.progress_anchor = g.pos
				g.stuck_time = 0.0
			else:
				g.stuck_time = float(g.stuck_time) + delta
			if float(g.stuck_time) >= 1.8 and float(g.recover_left) <= 0.0:
				_begin_traffic_recovery(g, g.last_seen)
		else:
			g.stuck_time = 0.0
			g.progress_anchor = g.pos
			if g.state != GState.ALERT:
				g.recover_left = 0.0
		g.walk_hold = 0.12 if did_move else maxf(0.0, g.walk_hold - delta)
		g.rig.set_moving(did_move or g.walk_hold > 0.0)
		var player_direction: Vector2 = player_pos - g.pos
		var aim_offset: float = angle_difference(g.face, player_direction.angle()) if player_direction.length_squared() > 0.001 else 0.0
		g.rig.set_aiming(sees, aim_offset)
		_sync_guard_marker(g)

func _fire(g: Dictionary) -> void:
	# Defense in depth: even a direct caller cannot shoot through cover.
	if not _los(g.pos, player_pos):
		return
	var toward_player: Vector2 = player_pos - g.pos
	var dir: Vector2 = toward_player.normalized() if toward_player.length_squared() > 0.001 else Vector2.from_angle(g.face)
	# Never place a point-blank muzzle beyond the player.
	var muzzle_offset := minf(24.0, maxf(0.0, toward_player.length() - PLAYER_HIT_RADIUS * 0.5))
	bullets.append({"pos": g.pos + dir * muzzle_offset, "vel": dir * BULLET_SPEED,
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
	var home: Vector2 = g.get("home_pos", g.pos)
	var candidates: Array[Dictionary] = []
	for attempt in range(mini(60, cells.size() * 2)):
		var cell: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
		var point := _cell_center(cell.x, cell.y)
		var distance: float = point.distance_to(g.pos)
		if distance < CELL * 2.5:
			continue
		var nearest := 400.0
		var occupied := false
		for other in guards:
			if other.rig == g.rig or not other.alive:
				continue
			var gap: float = point.distance_to(other.pos)
			nearest = minf(nearest, gap)
			if gap < GUARD_GAP * 1.30:
				occupied = true
				break
		if occupied:
			continue
		# Give patrols local territories and favor destinations away from one
		# another, but still roam meaningfully across guard-reachable floor.
		var score := minf(nearest, 350.0) * 1.4 + minf(distance, 300.0) * 0.65 - point.distance_to(home) * 0.55
		candidates.append({"cell": cell, "point": point, "score": score})
	if candidates.is_empty():
		return false
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.score) > float(b.score))
	var choice: Vector2i = candidates[0].cell
	for index in range(mini(12, candidates.size())):
		var cell: Vector2i = candidates[index].cell
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
		if not crowded:
			choice = cell
			break
	g.roam_target = _cell_center(choice.x, choice.y)
	g.roam_valid = true
	g.blocked_t = 0.0
	g.path.clear()
	g.pi = 0
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
		# A clear, guard-sized direct lane should not wait for a grid-centre
		# path or stop merely because target and guard share one cell.
		if guard_grid.is_in_boundsv(to) and not guard_grid.is_point_solid(to) and _guard_line_clear(g.pos, target):
			g.path.append(target)
			g.pi = 0
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
		if g.path.is_empty() and region >= 0 and guard_grid.is_in_boundsv(to) and not guard_grid.is_point_solid(to):
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

func _update_loot_particles(delta: float) -> void:
	for i in range(loot_particles.size() - 1, -1, -1):
		var part: Dictionary = loot_particles[i]
		part.t += delta
		part.pos += part.vel * delta
		part.vel = part.vel.lerp(Vector2.ZERO, minf(1.0, delta * 6))
		if part.t > 0.18 and part.pos.distance_to(player_pos) < 150:
			part.pos = part.pos.lerp(player_pos, minf(1.0, delta * 8))
		if part.t >= 1.0 or (part.t > 0.18 and part.pos.distance_to(player_pos) < 18):
			loot_particles.remove_at(i)

func _update_effects(delta: float) -> void:
	# Blood is level-permanent; only transient, non-kill effects expire.
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
	if finished or overlay != null or locker_ui != null:
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
		# The camera may have moved between finger-down and finger-up.
		# Keep the last actual drag target in world space instead of silently
		# moving the destination underneath a stationary finger on release.
		if dragging and hunt_target < 0 and drag_dirty:
			_path_to(drag_target)
		dragging = false
		drag_dirty = false
		drag_repath = 0.0

func _draw() -> void:
	# Only the blood remains under actors, at full opacity for this level.
	for splat in blood_splats:
		draw_circle(splat.pos, 15.0, Color(0.42, 0.025, 0.035, 0.78))
		for drop in splat.drops:
			draw_circle(splat.pos + drop.offset, float(drop.radius), Color(0.52, 0.035, 0.045, 0.82))
	if key_on_floor:
		var bob := sin(elapsed * 4.0) * 3.0
		# Keep the new portrait-shaped icon from stretching in world space.
		var key_height := 48.0
		var key_width := key_height * float(KEY_TEX.get_width()) / float(KEY_TEX.get_height())
		draw_texture_rect(KEY_TEX, Rect2(key_position + Vector2(-key_width / 2.0, -key_height / 2.0 + bob), Vector2(key_width, key_height)), false)
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
	# Money flies out after every kill; a blue diamond appears only for carriers.
	for part in loot_particles:
		var icon: Texture2D = GEM_TEX if part.kind == "diamond" else MONEY_TEX
		var bob: float = sin(part.t * 6) * 3
		draw_texture_rect(icon, Rect2(part.pos + Vector2(-12, -12 + bob), Vector2(24, 24)), false)
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
		elif e.kind == "keytext":
			var pos: Vector2 = e.pos + Vector2(-20, -28 - (1.0-k)*28.0)
			draw_string_outline(fx_font, pos, "+ KEY", HORIZONTAL_ALIGNMENT_LEFT, -1, 25, 5, Color(0.08,0.05,0.01,k))
			draw_string(fx_font, pos, "+ KEY", HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color(1.0,0.83,0.24,k))
		elif e.kind == "moneytext" or e.kind == "diamondtext":
			var rise := (1.0 - k) * 38.0
			var txt := "+%d" % int(e.amount)
			var icon: Texture2D = GEM_TEX if e.kind == "diamondtext" else MONEY_TEX
			var fv := fx_font
			var fs := 27
			var tw2 := fv.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var tp: Vector2 = e.pos + Vector2(-(tw2 + 28.0) * 0.5 + 28.0, -rise)
			draw_texture_rect(icon, Rect2(tp + Vector2(-30, -23), Vector2(26, 26)), false, Color(1, 1, 1, k))
			draw_string_outline(fv, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0.06, 0.07, 0.1, k))
			var tint := Color(0.53, 0.95, 1.0, k) if e.kind == "diamondtext" else Color(0.55, 1.0, 0.43, k)
			draw_string(fv, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, tint)
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
	if finished:
		return
	finished = true
	var level_no := GameState.current_level
	player_rig.set_moving(false)
	var stars := 3
	if was_alerted:
		stars = 2
	if damage_taken > 0:
		stars = 1
	GameState.complete_level(kills, damage_taken == 0, stars)
	_refresh_wallet()
	Sfx.play("win")
	_end_panel("LEVEL COMPLETE!", Color("4caf20"), "★".repeat(stars) + "  +%d cash  +%d diamonds" % [50 + level_no * 5 + money_collected, gems_collected], [
		["Next Level", func(): GameState.start_level(GameState.current_level)],
		["Home", func(): get_tree().change_scene_to_file("res://scenes/home/home.tscn")],
	])
	if GameState.locker_ready():
		call_deferred("_show_locker")

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
