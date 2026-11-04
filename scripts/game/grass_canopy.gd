extends Node2D
## A retained, non-colliding canopy above both player and guards. Each complete
## 40-unit tile uses the whole source texture; local footsteps briefly rustle it.
const GRASS := preload("res://assets/environment/stealth-grass-seamless.png")
const TILE := 32.0
const MAX_RIPPLES := 12
const DURATION := 0.60
var level: Node2D
var ripples: Array[Dictionary] = []
var last_point := Vector2(INF, INF)
var since_last := 1.0
var draw_count := 0

func setup(owner_level: Node2D) -> void:
	level = owner_level
	name = "GrassCanopy"
	z_index = 10
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	set_process(false)
	queue_redraw()

func disturb(point: Vector2, movement: Vector2) -> void:
	if level == null or movement.length_squared() < 0.0001 or not level.in_grass(point):
		return
	# A short trail rather than a new allocation for every actor on every frame.
	if since_last < 0.085 and point.distance_squared_to(last_point) < 100.0:
		return
	if ripples.size() >= MAX_RIPPLES:
		ripples.pop_front()
	ripples.append({"pos": point, "age": 0.0, "direction": movement.normalized()})
	last_point = point
	since_last = 0.0
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	since_last += delta
	for i in range(ripples.size() - 1, -1, -1):
		ripples[i].age = float(ripples[i].age) + delta
		if float(ripples[i].age) >= DURATION:
			ripples.remove_at(i)
	queue_redraw()
	if ripples.is_empty():
		set_process(false)

func _draw() -> void:
	draw_count += 1
	if level == null:
		return
	for tile: Rect2 in level.grass_rects:
		# Runtime layouts are whole tiles. Rectangles injected by tests are not
		# used by this renderer and cannot alter movement or collision.
		if not is_equal_approx(tile.size.x, TILE) or not is_equal_approx(tile.size.y, TILE):
			continue
		var center := tile.get_center()
		var bounce := 0.0
		var shift := Vector2.ZERO
		for ripple in ripples:
			var distance := center.distance_to(Vector2(ripple.pos))
			if distance > 72.0:
				continue
			var age := float(ripple.age)
			var influence := (1.0 - distance / 72.0) * (1.0 - age / DURATION)
			var oscillation := sin(age * 27.0 - distance * 0.07) * influence
			bounce += oscillation
			shift += Vector2(ripple.direction) * oscillation * 3.0
		bounce = clampf(bounce, -1.0, 1.0)
		# A continuous base keeps neighbours filled while a clearly visible
		# spring layer expands and tilts above it on contact.
		draw_rect(tile.grow(0.35), Color(0.18, 0.30, 0.035, 0.38), true)
		draw_texture_rect(GRASS, tile.grow(0.35), false, Color(1, 1, 1, 0.80))
		if absf(bounce) > 0.005:
			var puff := 1.0 + absf(bounce) * 0.18
			draw_set_transform(center + shift, bounce * 0.07, Vector2.ONE * puff)
			draw_texture_rect(GRASS, Rect2(-Vector2.ONE * TILE * 0.5, Vector2.ONE * TILE), false, Color(1, 1, 1, 0.70 * absf(bounce)))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
