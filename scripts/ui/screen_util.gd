class_name ScreenUtil
## Viewport helpers for edge-to-edge phones with notches / gesture bars.

static func safe_rect(vp: Viewport) -> Rect2:
	var vs := vp.get_visible_rect().size
	var full := Rect2(Vector2.ZERO, vs)
	if not OS.has_feature("mobile"):
		return full
	var win := DisplayServer.window_get_size()
	if win.x <= 0 or win.y <= 0:
		return full
	var sr := DisplayServer.get_display_safe_area()
	if sr.size.x <= 0 or sr.size.y <= 0:
		return full
	var ratio := vs / Vector2(win)
	var r := Rect2(Vector2(sr.position) * ratio, Vector2(sr.size) * ratio)
	r = r.intersection(full)
	if r.size.x < vs.x * 0.5 or r.size.y < vs.y * 0.5:
		return full
	return r
