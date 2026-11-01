extends RefCounted
## Shortest Euclidean path over the visible corners of the static rectangular
## blockers.  We route the player centre around the same collision rectangles
## used by movement; an extra sub-pixel safety margin avoids grazing a corner.
## Static edges are cached once per map and only endpoints change per tap.

const MARGIN := 0.5
const CORNER_CLEARANCE := 0.80

var bounds: Rect2
var rectangles: Array[Rect2] = []
var expanded: Array[Rect2] = []
var graph := AStar2D.new()
var points := PackedVector2Array()
var built := false

func setup(map_bounds: Rect2, blockers: Array[Rect2]) -> void:
	bounds = map_bounds
	rectangles = blockers.duplicate()
	expanded.clear()
	for rect in rectangles:
		expanded.append(rect.grow(MARGIN))
	graph.clear()
	points.clear()
	built = false

func _segment_clear(a: Vector2, b: Vector2) -> bool:
	var v := b - a
	var length := v.length()
	if length <= 0.001:
		for r in rectangles:
			if r.has_point(a):
				return false
		return true
	var min_x := minf(a.x, b.x)
	var max_x := maxf(a.x, b.x)
	var min_y := minf(a.y, b.y)
	var max_y := maxf(a.y, b.y)
	for i in range(rectangles.size()):
		var r := expanded[i]
		# A legal endpoint can be within the extra margin. Preserve access to
		# that endpoint using the original collision shape for this segment.
		if r.has_point(a) or r.has_point(b):
			r = rectangles[i]
		if max_x < r.position.x or min_x > r.end.x or max_y < r.position.y or min_y > r.end.y:
			continue
		var enter := 0.0
		var leave := 1.0
		if absf(v.x) < 0.000001:
			if a.x < r.position.x or a.x >= r.end.x:
				continue
		else:
			var x1 := (r.position.x - a.x) / v.x
			var x2 := (r.end.x - a.x) / v.x
			enter = maxf(enter, minf(x1, x2))
			leave = minf(leave, maxf(x1, x2))
			if enter > leave:
				continue
		if absf(v.y) < 0.000001:
			if a.y < r.position.y or a.y >= r.end.y:
				continue
		else:
			var y1 := (r.position.y - a.y) / v.y
			var y2 := (r.end.y - a.y) / v.y
			enter = maxf(enter, minf(y1, y2))
			leave = minf(leave, maxf(y1, y2))
			if enter > leave:
				continue
		if enter <= leave and enter < 1.0 - 0.001 / length:
			return false
	return true

func _build() -> void:
	if built:
		return
	built = true
	var seen := {}
	for source in rectangles:
		var r: Rect2 = source.grow(CORNER_CLEARANCE)
		for point in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
			if not bounds.has_point(point):
				continue
			var covered := false
			for obstacle in expanded:
				if obstacle.has_point(point):
					covered = true
					break
			if covered:
				continue
			# A pair of coincident corners is just one graph vertex.
			var key := Vector2i(roundi(point.x * 100.0), roundi(point.y * 100.0))
			if seen.has(key):
				continue
			seen[key] = true
			var id := points.size() + 2
			points.append(point)
			graph.add_point(id, point)
	for i in range(points.size()):
		for j in range(i):
			if _segment_clear(points[i], points[j]):
				graph.connect_points(i + 2, j + 2, true)

func route(start: Vector2, finish: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	if not bounds.has_point(start) or not bounds.has_point(finish):
		return result
	if _segment_clear(start, finish):
		result.append(finish)
		return result
	_build()
	graph.add_point(0, start)
	graph.add_point(1, finish)
	for i in range(points.size()):
		if _segment_clear(start, points[i]):
			graph.connect_points(0, i + 2, true)
		if _segment_clear(finish, points[i]):
			graph.connect_points(1, i + 2, true)
	var full := graph.get_point_path(0, 1)
	graph.remove_point(0)
	graph.remove_point(1)
	for i in range(1, full.size()):
		if (result.is_empty() and start.distance_squared_to(full[i]) > 0.0001) or (not result.is_empty() and result[result.size() - 1].distance_squared_to(full[i]) > 0.0001):
			result.append(full[i])
	return result
