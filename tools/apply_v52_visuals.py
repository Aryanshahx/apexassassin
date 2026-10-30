#!/usr/bin/env python3
"""v0.5.2 visuals: night-grade the depot so vision cones read clearly, and add a
player-following zoom camera that fills the whole phone screen."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
p = ROOT / "scripts/game/level.gd"
s = p.read_text()

# ---------------------------------------------------------------- grade + camera
s = s.replace(
    'const SRC_THICK := 91.0          # container width in the concept art',
    '''const SRC_THICK := 91.0          # container width in the concept art
## Night shift: the depot is darkened so guard flashlights read clearly.
const GRADE_FLOOR := Color(0.34, 0.37, 0.46)
const GRADE_OUTSIDE := Color(0.17, 0.19, 0.26)
const GRADE_WALL := Color(0.62, 0.66, 0.78)
const GRADE_CRATE := Color(0.66, 0.69, 0.80)
const GRADE_PROP := Color(0.70, 0.73, 0.84)
## Camera: how many grid cells are visible across the screen width.
const CAM_VIEW_CELLS := 12.0
var cam_scale := 1.0''')

# ---------------------------------------------------------------- fit -> zoom
old_fit = '''func _fit_world() -> void:
	if data.is_empty():
		return
	var safe := ScreenUtil.safe_rect(get_viewport())
	var map_size := Vector2(float(data.width), float(data.height)) * CELL
	var top := 140.0
	var avail := Rect2(safe.position + Vector2(12, top), safe.size - Vector2(24, top + 24))
	var s := minf(avail.size.x / map_size.x, avail.size.y / map_size.y)
	s = maxf(0.1, s)
	var pos := avail.position + (avail.size - map_size * s) * 0.5 - ORIGIN * s
	scale = Vector2.ONE * s
	position = pos
	base_position = pos
	queue_redraw()'''
new_fit = '''func _fit_world() -> void:
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
	position = base_position'''
assert old_fit in s, "fit block not found"
s = s.replace(old_fit, new_fit)

# camera follows every frame
s = s.replace('''	_apply_shake(delta)
	elapsed += delta''', '''	_update_camera(delta)
	_apply_shake(delta)
	elapsed += delta''')
s = s.replace('''		_update_effects(delta)
		_apply_shake(delta)''', '''		_update_effects(delta)
		_update_camera(delta)
		_apply_shake(delta)''')

# ---------------------------------------------------------------- floor grade
s = s.replace('draw_texture_rect(FLOOR, Rect2(ox, oy, FLOOR_TILE, FLOOR_TILE), false, Color(0.36, 0.38, 0.44))',
              'draw_texture_rect(FLOOR, Rect2(ox, oy, FLOOR_TILE, FLOOR_TILE), false, GRADE_OUTSIDE)')
s = s.replace('draw_texture_rect_region(FLOOR, vis, region)',
              'draw_texture_rect_region(FLOOR, vis, region, GRADE_FLOOR)')

# props / walls / crates grade
s = s.replace('draw_texture_rect(DRAIN_TEX, Rect2(d.pos - Vector2(20, 20), Vector2(40, 40)), false)',
              'draw_texture_rect(DRAIN_TEX, Rect2(d.pos - Vector2(20, 20), Vector2(40, 40)), false, GRADE_PROP)')
s = s.replace('draw_texture_rect(ARROW_TEX, Rect2(-23, -17, 46, 35), false)',
              'draw_texture_rect(ARROW_TEX, Rect2(-23, -17, 46, 35), false, GRADE_PROP)')
s = s.replace('draw_texture_rect(CRATE_DEPTH, Rect2(Vector2(r.position.x, r.end.y), Vector2(r.size.x, dh)), false)',
              'draw_texture_rect(CRATE_DEPTH, Rect2(Vector2(r.position.x, r.end.y), Vector2(r.size.x, dh)), false, GRADE_CRATE)')
s = s.replace('draw_texture_rect(CRATE_TOP, r, false)',
              'draw_texture_rect(CRATE_TOP, r, false, GRADE_CRATE)')
s = s.replace('draw_texture_rect(dt, Rect2(Vector2(r.position.x + i * dw, r.end.y), Vector2(dw, depth_h)), false)',
              'draw_texture_rect(dt, Rect2(Vector2(r.position.x + i * dw, r.end.y), Vector2(dw, depth_h)), false, GRADE_WALL)')
for a, b in [
    ('draw_texture_rect(_c_cap_l[key], Rect2(r.position, Vector2(cap_a, thick)), false)',
     'draw_texture_rect(_c_cap_l[key], Rect2(r.position, Vector2(cap_a, thick)), false, GRADE_WALL)'),
    ('draw_texture_rect(_c_cap_r[key], Rect2(Vector2(r.end.x - cap_b, r.position.y), Vector2(cap_b, thick)), false)',
     'draw_texture_rect(_c_cap_r[key], Rect2(Vector2(r.end.x - cap_b, r.position.y), Vector2(cap_b, thick)), false, GRADE_WALL)'),
    ('draw_texture_rect(_c_cap_a[key], Rect2(r.position, Vector2(thick, cap_a)), false)',
     'draw_texture_rect(_c_cap_a[key], Rect2(r.position, Vector2(thick, cap_a)), false, GRADE_WALL)'),
    ('draw_texture_rect(_c_cap_b[key], Rect2(Vector2(r.position.x, r.end.y - cap_b), Vector2(thick, cap_b)), false)',
     'draw_texture_rect(_c_cap_b[key], Rect2(Vector2(r.position.x, r.end.y - cap_b), Vector2(thick, cap_b)), false, GRADE_WALL)'),
    ('draw_texture_rect(tex, Rect2(Vector2(r.position.x + cap_a + i * seg, r.position.y), Vector2(seg, thick)), false)',
     'draw_texture_rect(tex, Rect2(Vector2(r.position.x + cap_a + i * seg, r.position.y), Vector2(seg, thick)), false, GRADE_WALL)'),
    ('draw_texture_rect(tex, Rect2(Vector2(r.position.x, r.position.y + cap_a + i * seg), Vector2(thick, seg)), false)',
     'draw_texture_rect(tex, Rect2(Vector2(r.position.x, r.position.y + cap_a + i * seg), Vector2(thick, seg)), false, GRADE_WALL)'),
]:
    assert a in s, a[:60]
    s = s.replace(a, b)

# ---------------------------------------------------------------- bright cones
old_cone = '''	var col := Color(1, 0.95, 0.75, 0.22)
	if g.state == GState.ALERT:
		col = Color(1, 0.35, 0.3, 0.3)
	elif g.state in [GState.INVESTIGATE, GState.SEARCH]:
		col = Color(1, 0.8, 0.3, 0.25)
	draw_polygon(pts, PackedColorArray([col]))'''
new_cone = '''	# Bright, layered flashlight beam so it reads clearly on the dark depot floor.
	var col := Color(1.0, 0.93, 0.55, 0.30)
	var edge := Color(1.0, 0.96, 0.70, 0.55)
	if g.state == GState.ALERT:
		col = Color(1.0, 0.30, 0.26, 0.40)
		edge = Color(1.0, 0.55, 0.45, 0.75)
	elif g.state in [GState.INVESTIGATE, GState.SEARCH]:
		col = Color(1.0, 0.72, 0.22, 0.36)
		edge = Color(1.0, 0.85, 0.45, 0.68)
	draw_polygon(pts, PackedColorArray([col]))
	# Hot inner core: same cone shrunk toward the guard.
	var inner := PackedVector2Array([g.pos])
	for i in range(1, pts.size()):
		inner.append(g.pos + (pts[i] - g.pos) * 0.62)
	draw_polygon(inner, PackedColorArray([Color(col.r, col.g, col.b, col.a * 0.75)]))
	# Crisp outline along the beam edges.
	draw_polyline(pts, edge, 2.0)
	draw_circle(g.pos, 5.0, Color(edge.r, edge.g, edge.b, 0.85))'''
assert old_cone in s
s = s.replace(old_cone, new_cone)

p.write_text(s)
print("v0.5.2 visuals applied: night grade, bright cones, follow-zoom camera")
